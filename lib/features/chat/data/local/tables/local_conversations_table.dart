class LocalConversationsTable {
  static const String tableName = 'local_conversations';

  static const String columnId = 'id';
  static const String columnType = 'type'; // dm, group, channel
  static const String columnTitle = 'title';
  static const String columnAvatarUrl = 'avatar_url';
  static const String columnOtherUserId = 'other_user_id';
  static const String columnUnreadCount = 'unread_count';
  static const String columnLastMessageId = 'last_message_id';
  static const String columnUpdatedAt = 'updated_at';
  static const String columnCreatedAt = 'created_at';

  static const String createTable = '''
    CREATE TABLE $tableName (
      $columnId TEXT PRIMARY KEY,
      $columnType TEXT NOT NULL,
      $columnTitle TEXT,
      $columnAvatarUrl TEXT,
      $columnOtherUserId TEXT,
      $columnUnreadCount INTEGER NOT NULL DEFAULT 0,
      $columnLastMessageId TEXT,
      $columnUpdatedAt TEXT NOT NULL,
      $columnCreatedAt TEXT NOT NULL
    )
  ''';
}
