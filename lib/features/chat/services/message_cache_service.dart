import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:cryptography/cryptography.dart';

import '../models/chat_message.dart';

class MessageCacheService {
  static const String _dbName = 'griot_messages.db';
  static const int _dbVersion = 1;
  static const String _tableName = 'cached_messages';
  
  static const String _storageKey = 'message_cache_encryption_key';

  Database? _db;
  final FlutterSecureStorage _secureStorage;
  final AesGcm _algorithm = AesGcm.with256bits();
  SecretKey? _encryptionKey;

  MessageCacheService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  // ==========================================================
  // INITIALIZATION
  // ==========================================================

  Future<void> initialize() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );

    await _initEncryptionKey();
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        content TEXT,
        encrypted_content TEXT,
        nonce TEXT,
        message_type TEXT NOT NULL DEFAULT 'text',
        created_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'sent',
        is_deleted INTEGER NOT NULL DEFAULT 0,
        server_synced INTEGER NOT NULL DEFAULT 0,
        last_synced_at TEXT,
        media_url TEXT,
        thumbnail_url TEXT,
        reply_to_message_id TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_cached_messages_conversation_created
      ON $_tableName(conversation_id, created_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_cached_messages_sync
      ON $_tableName(server_synced, created_at)
    ''');
  }

  Future<void> _initEncryptionKey() async {
    final storedKey = await _secureStorage.read(key: _storageKey);
    if (storedKey != null) {
      _encryptionKey = SecretKey(base64Decode(storedKey));
    } else {
      final newKey = await _algorithm.newSecretKey();
      final keyBytes = await newKey.extractBytes();
      await _secureStorage.write(key: _storageKey, value: base64Encode(keyBytes));
      _encryptionKey = newKey;
    }
  }

  // ==========================================================
  // ENCRYPTION
  // ==========================================================

  Future<Map<String, String?>> _encryptFixed(String? text) async {
    if (text == null || text.isEmpty) return {'encrypted': null, 'nonce': null};
    if (_encryptionKey == null) throw Exception('Encryption key not initialized');

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
    if (_encryptionKey == null) throw Exception('Encryption key not initialized');

    try {
      final encryptedBytes = base64Decode(encrypted);
      final nonceBytes = base64Decode(nonce);
      
      final macLength = 16; // AES-GCM tag is 16 bytes
      final cipherText = encryptedBytes.sublist(0, encryptedBytes.length - macLength);
      final macBytes = encryptedBytes.sublist(encryptedBytes.length - macLength);

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
  // CRUD OPERATIONS
  // ==========================================================

  Future<void> saveMessage(ChatMessage message) async {
    await saveMessages([message]);
  }

  Future<void> saveMessages(List<ChatMessage> messages) async {
    final db = _db;
    if (db == null) return;

    final batch = db.batch();
    for (final message in messages) {
      final encryptionData = await _encryptFixed(message.text);
      
      batch.insert(
        _tableName,
        {
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
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    DateTime? before,
  }) async {
    final db = _db;
    if (db == null) return [];

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

      messages.add(ChatMessage(
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
      ));
    }

    return messages;
  }

  Future<ChatMessage?> getMessage(String messageId) async {
    final db = _db;
    if (db == null) return null;

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

  Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    final db = _db;
    if (db == null) return;

    await db.update(
      _tableName,
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> markSynced(String messageId) async {
    final db = _db;
    if (db == null) return;

    await db.update(
      _tableName,
      {
        'server_synced': 1,
        'last_synced_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> markDeleted(String messageId) async {
    final db = _db;
    if (db == null) return;

    await db.update(
      _tableName,
      {
        'is_deleted': 1,
        'encrypted_content': null,
        'nonce': null,
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<List<ChatMessage>> getPendingMessages() async {
    final db = _db;
    if (db == null) return [];

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

      messages.add(ChatMessage(
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
      ));
    }

    return messages;
  }

  Future<void> deleteLocalMessage(String messageId) async {
    final db = _db;
    if (db == null) return;

    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> clearAllMessages() async {
    final db = _db;
    if (db == null) return;

    await db.delete(_tableName);
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
}
