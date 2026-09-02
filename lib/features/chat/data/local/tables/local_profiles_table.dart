class LocalProfilesTable {
  static const String tableName = 'local_profiles';

  static const String columnId = 'id';
  static const String columnWalletAddress = 'wallet_address';
  static const String columnUsername = 'username';
  static const String columnDisplayName = 'display_name';
  static const String columnAvatarUrl = 'avatar_url';
  static const String columnBio = 'bio';
  static const String columnReputationTier = 'reputation_tier';
  static const String columnReputationColor = 'reputation_color';
  static const String columnRelationshipStatus = 'relationship_status';
  static const String columnLastSeenAt = 'last_seen_at';

  static const String createTable = '''
    CREATE TABLE $tableName (
      $columnId TEXT PRIMARY KEY,
      $columnWalletAddress TEXT NOT NULL,
      $columnUsername TEXT,
      $columnDisplayName TEXT,
      $columnAvatarUrl TEXT,
      $columnBio TEXT,
      $columnReputationTier TEXT,
      $columnReputationColor TEXT,
      $columnRelationshipStatus TEXT,
      $columnLastSeenAt TEXT
    )
  ''';
}
