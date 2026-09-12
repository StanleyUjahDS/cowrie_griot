import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:cryptography/cryptography.dart';

import '../models/chat_message.dart';
import '../models/conversation_model.dart';
import '../models/chat_user.dart';
import '../data/local/chat_database.dart';
import '../data/local/tables/local_conversations_table.dart';
import '../data/local/tables/local_profiles_table.dart';
import '../../users/models/user_model.dart';

class MessageCacheService {
  static const String _tableName = 'cached_messages';
  static const String _storageKey = 'message_cache_encryption_key';

  final ChatDatabase _chatDb;
  final FlutterSecureStorage _secureStorage;
  final AesGcm _algorithm = AesGcm.with256bits();
  SecretKey? _encryptionKey;
  Future<void>? _initializationFuture;

  MessageCacheService({
    ChatDatabase? chatDb,
    FlutterSecureStorage? secureStorage,
  }) : _chatDb = chatDb ?? ChatDatabase(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  // ==========================================================
  // INITIALIZATION
  // ==========================================================

  Future<void> initialize() async {
    if (_initializationFuture != null) return _initializationFuture!;
    _initializationFuture = _initializeInternal();
    try {
      await _initializationFuture!;
    } catch (_) {
      _initializationFuture = null;
      rethrow;
    }
  }

  Future<void> _initializeInternal() async {
    await _chatDb.database; // Ensure DB is open
    await _initEncryptionKey();
  }

  Future<void> _initEncryptionKey() async {
    final storedKey = await _secureStorage.read(key: _storageKey);
    if (storedKey != null) {
      _encryptionKey = SecretKey(base64Decode(storedKey));
    } else {
      final newKey = await _algorithm.newSecretKey();
      final keyBytes = await newKey.extractBytes();
      await _secureStorage.write(
        key: _storageKey,
        value: base64Encode(keyBytes),
      );
      _encryptionKey = newKey;
    }
  }

  // ==========================================================
  // ENCRYPTION
  // ==========================================================

  Future<Map<String, String?>> _encryptFixed(String? text) async {
    if (text == null || text.isEmpty) return {'encrypted': null, 'nonce': null};
    if (_encryptionKey == null) {
      throw Exception('Encryption key not initialized');
    }

    final secretBox = await _algorithm.encrypt(
      utf8.encode(text),
      secretKey: _encryptionKey!,
    );

    // Concatenate cipherText and MAC for storage if we only want two columns
    final combined = [...secretBox.cipherText, ...secretBox.mac.bytes];

    return {
      'encrypted': base64Encode(combined),
      'nonce': base64Encode(secretBox.nonce),
    };
  }

  Future<String?> _decryptFixed(String? encrypted, String? nonce) async {
    if (encrypted == null || nonce == null) return null;
    if (_encryptionKey == null) {
      throw Exception('Encryption key not initialized');
    }

    try {
      final encryptedBytes = base64Decode(encrypted);
      final nonceBytes = base64Decode(nonce);

      final macLength = 16; // AES-GCM tag is 16 bytes
      final cipherText = encryptedBytes.sublist(
        0,
        encryptedBytes.length - macLength,
      );
      final macBytes = encryptedBytes.sublist(
        encryptedBytes.length - macLength,
      );

      final secretBox = SecretBox(
        cipherText,
        nonce: nonceBytes,
        mac: Mac(macBytes),
      );

      final clearText = await _algorithm.decrypt(
        secretBox,
        secretKey: _encryptionKey!,
      );

      return utf8.decode(clearText);
    } catch (e) {
      debugPrint('Decryption error: $e');
      return null;
    }
  }

  // ==========================================================
  // CRUD OPERATIONS - MESSAGES
  // ==========================================================

  Future<void> saveMessage(ChatMessage message) async {
    await saveMessages([message]);
  }

  Future<void> saveMessages(List<ChatMessage> messages) async {
    final db = await _chatDb.database;

    final batch = db.batch();
    for (final message in messages) {
      final encryptionData = await _encryptFixed(message.text);

      batch.insert(_tableName, {
        'id': message.id,
        'conversation_id': message.conversationId,
        'sender_id': message.senderId,
        'content': null, // We store in encrypted_content
        'encrypted_content': encryptionData['encrypted'],
        'nonce': encryptionData['nonce'],
        'message_type': message.type.name,
        'created_at': message.createdAt.toIso8601String(),
        'status': message.status.name,
        'is_deleted': message.isDeleted ? 1 : 0,
        'server_synced': 1, // Messages from API are synced
        'last_synced_at': DateTime.now().toIso8601String(),
        'media_url': message.mediaUrl,
        'thumbnail_url': message.thumbnailUrl,
        'reply_to_message_id': message.replyToMessageId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    DateTime? before,
  }) async {
    final db = await _chatDb.database;

    String where = 'conversation_id = ?';
    List<dynamic> whereArgs = [conversationId];

    if (before != null) {
      where += ' AND created_at < ?';
      whereArgs.add(before.toIso8601String());
    }

    final results = await db.query(
      _tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    final List<ChatMessage> messages = [];
    for (final row in results) {
      final decryptedText = await _decryptFixed(
        row['encrypted_content'] as String?,
        row['nonce'] as String?,
      );

      messages.add(
        ChatMessage(
          id: row['id'] as String,
          conversationId: row['conversation_id'] as String,
          senderId: row['sender_id'] as String,
          text: decryptedText ?? '',
          type: _messageTypeFromString(row['message_type'] as String?),
          status: _messageStatusFromString(row['status'] as String?),
          createdAt: DateTime.parse(row['created_at'] as String),
          isDeleted: (row['is_deleted'] as int) == 1,
          mediaUrl: row['media_url'] as String?,
          thumbnailUrl: row['thumbnail_url'] as String?,
          replyToMessageId: row['reply_to_message_id'] as String?,
        ),
      );
    }

    return messages;
  }

  Future<ChatMessage?> getMessage(String messageId) async {
    final db = await _chatDb.database;

    final results = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    final row = results.first;

    final decryptedText = await _decryptFixed(
      row['encrypted_content'] as String?,
      row['nonce'] as String?,
    );

    return ChatMessage(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      senderId: row['sender_id'] as String,
      text: decryptedText ?? '',
      type: _messageTypeFromString(row['message_type'] as String?),
      status: _messageStatusFromString(row['status'] as String?),
      createdAt: DateTime.parse(row['created_at'] as String),
      isDeleted: (row['is_deleted'] as int) == 1,
      mediaUrl: row['media_url'] as String?,
      thumbnailUrl: row['thumbnail_url'] as String?,
      replyToMessageId: row['reply_to_message_id'] as String?,
    );
  }

  Future<void> updateMessage(ChatMessage message) async {
    await saveMessage(message);
  }

  Future<void> updateMessageStatus(
    String messageId,
    MessageStatus status,
  ) async {
    final db = await _chatDb.database;

    await db.update(
      _tableName,
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> markSynced(String messageId) async {
    final db = await _chatDb.database;

    await db.update(
      _tableName,
      {'server_synced': 1, 'last_synced_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> markDeleted(String messageId) async {
    final db = await _chatDb.database;

    await db.update(
      _tableName,
      {'is_deleted': 1, 'encrypted_content': null, 'nonce': null},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<List<ChatMessage>> getPendingMessages() async {
    final db = await _chatDb.database;

    final results = await db.query(
      _tableName,
      where: 'server_synced = 0 AND is_deleted = 0',
      orderBy: 'created_at ASC',
    );

    final List<ChatMessage> messages = [];
    for (final row in results) {
      final decryptedText = await _decryptFixed(
        row['encrypted_content'] as String?,
        row['nonce'] as String?,
      );

      messages.add(
        ChatMessage(
          id: row['id'] as String,
          conversationId: row['conversation_id'] as String,
          senderId: row['sender_id'] as String,
          text: decryptedText ?? '',
          type: _messageTypeFromString(row['message_type'] as String?),
          status: _messageStatusFromString(row['status'] as String?),
          createdAt: DateTime.parse(row['created_at'] as String),
          isDeleted: (row['is_deleted'] as int) == 1,
          mediaUrl: row['media_url'] as String?,
          thumbnailUrl: row['thumbnail_url'] as String?,
          replyToMessageId: row['reply_to_message_id'] as String?,
        ),
      );
    }

    return messages;
  }

  Future<void> deleteLocalMessage(String messageId) async {
    final db = await _chatDb.database;

    await db.delete(_tableName, where: 'id = ?', whereArgs: [messageId]);
  }

  Future<void> clearAllMessages() async {
    final db = await _chatDb.database;

    await db.delete(_tableName);
  }

  Future<void> deleteMessages(String conversationId) async {
    final db = await _chatDb.database;
    await db.delete(
      _tableName,
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<void> wipe() async {
    try {
      final db = await _chatDb.database;
      await db.transaction((txn) async {
        await txn.delete(_tableName);
        await txn.delete(LocalConversationsTable.tableName);
        await txn.delete(LocalProfilesTable.tableName);
      });

      // Close the database connection so the file can be safely deleted or recreated
      await _chatDb.close();

      await _secureStorage.delete(key: _storageKey);
      _encryptionKey = null;
      debugPrint('MessageCacheService: All data and keys wiped.');
    } catch (e) {
      debugPrint('MessageCacheService: Error during wipe: $e');
    }
  }

  // ==========================================================
  // CRUD OPERATIONS - CONVERSATIONS
  // ==========================================================

  Future<void> saveConversations(List<Conversation> conversations) async {
    final db = await _chatDb.database;
    final batch = db.batch();

    for (final conv in conversations) {
      batch.insert(LocalConversationsTable.tableName, {
        LocalConversationsTable.columnId: conv.id,
        LocalConversationsTable.columnType: conv.type.name,
        LocalConversationsTable.columnTitle: conv.name,
        LocalConversationsTable.columnAvatarUrl: conv.imageUrl,
        LocalConversationsTable.columnOtherUserId: conv.otherUser?.id,
        LocalConversationsTable.columnUnreadCount: conv.unreadCount,
        LocalConversationsTable.columnLastMessageId: conv.lastMessage?.id,
        LocalConversationsTable.columnUpdatedAt: conv.updatedAt
            .toIso8601String(),
        LocalConversationsTable.columnCreatedAt: conv.createdAt
            .toIso8601String(),
        LocalConversationsTable.columnOwnerId: conv.ownerId,
        LocalConversationsTable.columnVisibility: conv.visibility,
        LocalConversationsTable.columnRole: conv.role,
        LocalConversationsTable.columnStatus: conv.status,
        LocalConversationsTable.columnMemberCount: conv.memberCount,
        LocalConversationsTable.columnSubscriberCount: conv.subscriberCount,
        LocalConversationsTable.columnPostCount: conv.postCount,
        LocalConversationsTable.columnUsername: conv.username,
        LocalConversationsTable.columnDescription: conv.description,
        LocalConversationsTable.columnMessagesLocked: conv.messagesLocked
            ? 1
            : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      if (conv.otherUser != null) {
        await saveChatUser(conv.otherUser!);
      }
    }
    await batch.commit(noResult: true);
  }

  Future<List<Conversation>> getConversations() async {
    final db = await _chatDb.database;
    final results = await db.query(
      LocalConversationsTable.tableName,
      orderBy: '${LocalConversationsTable.columnUpdatedAt} DESC',
    );

    final List<Conversation> conversations = [];
    for (final row in results) {
      final otherUserId =
          row[LocalConversationsTable.columnOtherUserId] as String?;
      ChatUser? otherUser;
      if (otherUserId != null) {
        otherUser = await getChatUser(otherUserId);
      }

      final lastMessageId =
          row[LocalConversationsTable.columnLastMessageId] as String?;
      ChatMessage? lastMessage;
      if (lastMessageId != null) {
        lastMessage = await getMessage(lastMessageId);
      }

      conversations.add(
        Conversation(
          id: row[LocalConversationsTable.columnId] as String,
          type: _conversationTypeFromString(
            row[LocalConversationsTable.columnType] as String?,
          ),
          name: row[LocalConversationsTable.columnTitle] as String?,
          imageUrl: row[LocalConversationsTable.columnAvatarUrl] as String?,
          memberIds: [], // We don't store members locally yet
          otherUser: otherUser,
          lastMessage: lastMessage,
          unreadCount: row[LocalConversationsTable.columnUnreadCount] as int,
          updatedAt: DateTime.parse(
            row[LocalConversationsTable.columnUpdatedAt] as String,
          ),
          createdAt: DateTime.parse(
            row[LocalConversationsTable.columnCreatedAt] as String,
          ),
          ownerId: row[LocalConversationsTable.columnOwnerId] as String?,
          visibility:
              (row[LocalConversationsTable.columnVisibility] ?? 'public')
                  as String,
          role: row[LocalConversationsTable.columnRole] as String?,
          status: row[LocalConversationsTable.columnStatus] as String?,
          memberCount:
              (row[LocalConversationsTable.columnMemberCount] ?? 0) as int,
          subscriberCount:
              (row[LocalConversationsTable.columnSubscriberCount] ?? 0) as int,
          postCount: (row[LocalConversationsTable.columnPostCount] ?? 0) as int,
          username: row[LocalConversationsTable.columnUsername] as String?,
          description:
              row[LocalConversationsTable.columnDescription] as String?,
          messagesLocked:
              (row[LocalConversationsTable.columnMessagesLocked] ?? 0) == 1,
        ),
      );
    }
    return conversations;
  }

  Future<void> deleteConversation(String conversationId) async {
    final db = await _chatDb.database;
    await db.delete(
      LocalConversationsTable.tableName,
      where: '${LocalConversationsTable.columnId} = ?',
      whereArgs: [conversationId],
    );
  }

  // ==========================================================
  // CRUD OPERATIONS - PROFILES
  // ==========================================================

  Future<void> saveChatUser(ChatUser user) async {
    final db = await _chatDb.database;
    await db.insert(LocalProfilesTable.tableName, {
      LocalProfilesTable.columnId: user.id,
      LocalProfilesTable.columnWalletAddress: user.walletAddress,
      LocalProfilesTable.columnUsername: user.username,
      LocalProfilesTable.columnDisplayName: user.displayName,
      LocalProfilesTable.columnAvatarUrl: user.profileUrl,
      LocalProfilesTable.columnBio: user.bio,
      LocalProfilesTable.columnReputationTier: user.reputation?.tierName,
      LocalProfilesTable.columnReputationColor: user.reputation?.badgeColor,
      LocalProfilesTable.columnRelationshipStatus: user.relationshipStatus,
      LocalProfilesTable.columnIsPlus: user.isPlus ? 1 : 0,
      LocalProfilesTable.columnLastSeenAt: user.timestamp.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ChatUser?> getChatUser(String userId) async {
    final db = await _chatDb.database;
    final results = await db.query(
      LocalProfilesTable.tableName,
      where: '${LocalProfilesTable.columnId} = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    final row = results.first;

    UserReputationBadge? reputation;
    final tier = row[LocalProfilesTable.columnReputationTier] as String?;
    final color = row[LocalProfilesTable.columnReputationColor] as String?;
    if (tier != null && color != null) {
      reputation = UserReputationBadge(tierName: tier, badgeColor: color);
    }

    return ChatUser(
      id: row[LocalProfilesTable.columnId] as String,
      walletAddress: row[LocalProfilesTable.columnWalletAddress] as String,
      username: row[LocalProfilesTable.columnUsername] as String?,
      displayName: row[LocalProfilesTable.columnDisplayName] as String?,
      profileUrl: row[LocalProfilesTable.columnAvatarUrl] as String?,
      bio: row[LocalProfilesTable.columnBio] as String?,
      timestamp: DateTime.parse(
        row[LocalProfilesTable.columnLastSeenAt] as String,
      ),
      reputation: reputation,
      relationshipStatus:
          row[LocalProfilesTable.columnRelationshipStatus] as String?,
      isPlus: (row[LocalProfilesTable.columnIsPlus] as int? ?? 0) == 1,
    );
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  MessageType _messageTypeFromString(String? value) {
    return MessageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageType.text,
    );
  }

  MessageStatus _messageStatusFromString(String? value) {
    return MessageStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageStatus.sent,
    );
  }

  ConversationType _conversationTypeFromString(String? value) {
    return ConversationType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ConversationType.dm,
    );
  }
}
