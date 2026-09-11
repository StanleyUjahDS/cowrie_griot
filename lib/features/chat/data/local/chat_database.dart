import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'tables/local_conversations_table.dart';
import 'tables/local_profiles_table.dart';

class ChatDatabase {
  static const String _dbName = 'griot_chat_v2.db';
  static const int _dbVersion = 3;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // For simplicity in dev, we just drop and recreate
      await db.execute('DROP TABLE IF EXISTS ${LocalConversationsTable.tableName}');
      await db.execute(LocalConversationsTable.createTable);
    }
    if (oldVersion < 3) {
      // Add messages_locked column to local_conversations
      await db.execute(
        'ALTER TABLE ${LocalConversationsTable.tableName} ADD COLUMN ${LocalConversationsTable.columnMessagesLocked} INTEGER DEFAULT 0',
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Messages Table (Moved from MessageCacheService)
    await db.execute('''
      CREATE TABLE cached_messages (
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
      ON cached_messages(conversation_id, created_at DESC)
    ''');

    // 2. Conversations Table
    await db.execute(LocalConversationsTable.createTable);

    // 3. Profiles Table
    await db.execute(LocalProfilesTable.createTable);
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
