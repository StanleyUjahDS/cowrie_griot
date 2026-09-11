class LocalConversationsTable {
  static const String tableName = 'local_conversations';

  static const String columnId = 'id';
  static const String columnType = 'type'; // dm, group, channel
  static const String columnTitle = 'title'; // name
  static const String columnAvatarUrl = 'avatar_url'; // image_url
  static const String columnOtherUserId = 'other_user_id';
  static const String columnUnreadCount = 'unread_count';
  static const String columnLastMessageId = 'last_message_id';
  static const String columnUpdatedAt = 'updated_at';
  static const String columnCreatedAt = 'created_at';

  // Expanded metadata
  static const String columnOwnerId = 'owner_id';
  static const String columnVisibility = 'visibility';
  static const String columnRole = 'role';
  static const String columnStatus = 'status';
  static const String columnMemberCount = 'member_count';
  static const String columnSubscriberCount = 'subscriber_count';
  static const String columnPostCount = 'post_count';
  static const String columnUsername = 'username';
  static const String columnDescription = 'description';
  static const String columnMessagesLocked = 'messages_locked';

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
      $columnCreatedAt TEXT NOT NULL,
      $columnOwnerId TEXT,
      $columnVisibility TEXT DEFAULT 'public',
      $columnRole TEXT,
      $columnStatus TEXT,
      $columnMemberCount INTEGER DEFAULT 0,
      $columnSubscriberCount INTEGER DEFAULT 0,
      $columnPostCount INTEGER DEFAULT 0,
      $columnUsername TEXT,
      $columnDescription TEXT,
      $columnMessagesLocked INTEGER DEFAULT 0
    )
  ''';
}
