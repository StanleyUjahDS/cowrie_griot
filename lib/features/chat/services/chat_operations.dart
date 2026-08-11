import '../models/chat_user.dart';

class ChatOperations {
  // ==========================================================
  // MOCK USERS
  // ==========================================================

  final List<ChatUser> _users = [
    ChatUser(
      id: 'user_1',
      walletAddress:
      '0x7A31B4C2D8E9F01234567890ABCDEF123456E921',
      username: 'davidk',
      displayName: 'David K',
      phoneNumber: null,
      phoneDiscoveryEnabled: false,
      profileUrl:
      'https://i.pravatar.cc/150?img=12',
      lastMessage: 'Hey, how are you?',
      timestamp: const Duration(minutes: 5) == Duration.zero
          ? DateTime.now()
          : DateTime.now().subtract(
        const Duration(minutes: 5),
      ),
      unreadCount: 2,
      isOnline: true,
    ),

    ChatUser(
      id: 'user_2',
      walletAddress:
      '0x91BC72A4E8215678901234567890ABCDEF123456',
      username: 'amara',
      displayName: 'Amara Okafor',
      phoneNumber: '+2348012345678',
      phoneDiscoveryEnabled: true,
      profileUrl:
      'https://i.pravatar.cc/150?img=32',
      lastMessage: 'See you tomorrow 👋',
      timestamp: DateTime.now().subtract(
        const Duration(hours: 1),
      ),
      unreadCount: 0,
      isOnline: false,
    ),

    ChatUser(
      id: 'user_3',
      walletAddress:
      '0x22EF72A4719A5678901234567890ABCDEF123456',
      username: null,
      displayName: 'Michael Johnson',
      phoneNumber: null,
      phoneDiscoveryEnabled: false,
      profileUrl:
      'https://i.pravatar.cc/150?img=14',
      lastMessage: 'Hello 👋',
      timestamp: DateTime.now().subtract(
        const Duration(hours: 3),
      ),
      unreadCount: 4,
      isOnline: true,
    ),

    ChatUser(
      id: 'user_4',
      walletAddress:
      '0xA8127BC93DE45678901234567890ABCDEF12345',
      username: 'sarah',
      displayName: 'Sarah Williams',
      phoneNumber: '+447700900123',
      phoneDiscoveryEnabled: true,
      profileUrl:
      'https://i.pravatar.cc/150?img=44',
      lastMessage: 'That sounds good.',
      timestamp: DateTime.now().subtract(
        const Duration(days: 1),
      ),
      unreadCount: 0,
      isOnline: true,
    ),

    ChatUser(
      id: 'user_5',
      walletAddress:
      '0xB7218CD94EF5678901234567890ABCDEF123456',
      username: 'crypto_mike',
      displayName: 'Mike Thompson',
      phoneNumber: '+447700900456',
      phoneDiscoveryEnabled: false,
      profileUrl:
      'https://i.pravatar.cc/150?img=51',
      lastMessage: 'Check this out.',
      timestamp: DateTime.now().subtract(
        const Duration(days: 2),
      ),
      unreadCount: 1,
      isOnline: false,
    ),

    ChatUser(
      id: 'user_6',
      walletAddress:
      '0xC8319DE05FA678901234567890ABCDEF123456',
      username: 'james',
      displayName: 'James Carter',
      phoneNumber: null,
      phoneDiscoveryEnabled: false,
      profileUrl:
      'https://i.pravatar.cc/150?img=68',
      lastMessage: 'Nice!',
      timestamp: DateTime.now().subtract(
        const Duration(days: 3),
      ),
      unreadCount: 0,
      isOnline: false,
    ),
  ];

  // ==========================================================
  // GET ALL USERS
  // ==========================================================

  Future<List<ChatUser>> getUsers() async {
    return List<ChatUser>.from(_users);
  }

  // ==========================================================
  // GET CHATS
  // ==========================================================

  Future<List<ChatUser>> getChats() async {
    return List<ChatUser>.from(_users);
  }

  // ==========================================================
  // FIND USER BY WALLET
  // ==========================================================

  Future<ChatUser?> findUserByWallet(
      String walletAddress,
      ) async {
    try {
      return _users.firstWhere(
            (user) =>
        user.walletAddress.toLowerCase() ==
            walletAddress.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  // ==========================================================
  // FIND USER BY USERNAME
  // ==========================================================

  Future<ChatUser?> findUserByUsername(
      String username,
      ) async {
    final normalized = username
        .trim()
        .toLowerCase()
        .replaceFirst('@', '');

    try {
      return _users.firstWhere(
            (user) =>
        user.username != null &&
            user.username!
                .trim()
                .toLowerCase()
                .replaceFirst('@', '') ==
                normalized,
      );
    } catch (_) {
      return null;
    }
  }

  // ==========================================================
  // SEARCH USERS
  // ==========================================================

  Future<List<ChatUser>> searchUsers(
      String query,
      ) async {
    final normalized = query.trim().toLowerCase();

    if (normalized.isEmpty) {
      return [];
    }

    final walletQuery =
    normalized.startsWith('0x')
        ? normalized
        : normalized;

    final usernameQuery =
    normalized.startsWith('@')
        ? normalized.substring(1)
        : normalized;

    return _users.where((user) {
      final username =
          user.username?.toLowerCase() ?? '';

      final displayName =
          user.displayName?.toLowerCase() ?? '';

      final wallet =
      user.walletAddress.toLowerCase();

      return username.contains(usernameQuery) ||
          displayName.contains(normalized) ||
          wallet.contains(walletQuery);
    }).toList();
  }

  // ==========================================================
  // FIND USERS BY PHONE NUMBERS
  // ==========================================================
  //
  // IMPORTANT:
  //
  // In the real decentralized version, the app should NOT
  // download everyone's phone numbers.
  //
  // The backend can perform a privacy-preserving lookup and
  // return only users who:
  //
  // 1. Have linked a phone number.
  // 2. Have enabled phone discovery.
  // 3. Match one of the user's contacts.
  //
  // For now this mock simply compares the supplied numbers.
  // ==========================================================

  Future<List<ChatUser>> findUsersByPhoneNumbers(
      List<String> phoneNumbers,
      ) async {
    final normalizedNumbers = phoneNumbers
        .map(_normalizePhoneNumber)
        .where((phone) => phone.isNotEmpty)
        .toSet();

    if (normalizedNumbers.isEmpty) {
      return [];
    }

    return _users.where((user) {
      if (!user.isDiscoverableByPhone) {
        return false;
      }

      final phone =
          user.phoneNumber;

      if (phone == null ||
          phone.trim().isEmpty) {
        return false;
      }

      return normalizedNumbers.contains(
        _normalizePhoneNumber(phone),
      );
    }).toList();
  }

  // ==========================================================
  // SEARCH SINGLE PHONE NUMBER
  // ==========================================================

  Future<ChatUser?> findUserByPhoneNumber(
      String phoneNumber,
      ) async {
    final normalized =
    _normalizePhoneNumber(phoneNumber);

    if (normalized.isEmpty) {
      return null;
    }

    try {
      return _users.firstWhere(
            (user) =>
        user.isDiscoverableByPhone &&
            user.phoneNumber != null &&
            _normalizePhoneNumber(
              user.phoneNumber!,
            ) ==
                normalized,
      );
    } catch (_) {
      return null;
    }
  }

  // ==========================================================
  // UPDATE PHONE DISCOVERY
  // ==========================================================

  Future<ChatUser?> updatePhoneDiscovery({
    required String walletAddress,
    required bool enabled,
  }) async {
    final index = _users.indexWhere(
          (user) =>
      user.walletAddress.toLowerCase() ==
          walletAddress.toLowerCase(),
    );

    if (index == -1) {
      return null;
    }

    final user = _users[index];

    final updatedUser = user.copyWith(
      phoneDiscoveryEnabled: enabled,
    );

    _users[index] = updatedUser;

    return updatedUser;
  }

  // ==========================================================
  // UPDATE PHONE NUMBER
  // ==========================================================

  Future<ChatUser?> updatePhoneNumber({
    required String walletAddress,
    String? phoneNumber,
  }) async {
    final index = _users.indexWhere(
          (user) =>
      user.walletAddress.toLowerCase() ==
          walletAddress.toLowerCase(),
    );

    if (index == -1) {
      return null;
    }

    final user = _users[index];

    final updatedUser = user.copyWith(
      phoneNumber: phoneNumber,
    );

    _users[index] = updatedUser;

    return updatedUser;
  }

  // ==========================================================
  // UPDATE USERNAME
  // ==========================================================

  Future<ChatUser?> updateUsername({
    required String walletAddress,
    String? username,
  }) async {
    final index = _users.indexWhere(
          (user) =>
      user.walletAddress.toLowerCase() ==
          walletAddress.toLowerCase(),
    );

    if (index == -1) {
      return null;
    }

    final user = _users[index];

    final updatedUser = user.copyWith(
      username: username,
    );

    _users[index] = updatedUser;

    return updatedUser;
  }

  // ==========================================================
  // UPDATE DISPLAY NAME
  // ==========================================================

  Future<ChatUser?> updateDisplayName({
    required String walletAddress,
    String? displayName,
  }) async {
    final index = _users.indexWhere(
          (user) =>
      user.walletAddress.toLowerCase() ==
          walletAddress.toLowerCase(),
    );

    if (index == -1) {
      return null;
    }

    final user = _users[index];

    final updatedUser = user.copyWith(
      displayName: displayName,
    );

    _users[index] = updatedUser;

    return updatedUser;
  }

  // ==========================================================
  // CHECK USERNAME AVAILABILITY
  // ==========================================================

  Future<bool> isUsernameAvailable(
      String username, {
        String? excludingWalletAddress,
      }) async {
    final normalized = username
        .trim()
        .toLowerCase()
        .replaceFirst('@', '');

    if (normalized.isEmpty) {
      return false;
    }

    return !_users.any((user) {
      if (excludingWalletAddress != null &&
          user.walletAddress.toLowerCase() ==
              excludingWalletAddress.toLowerCase()) {
        return false;
      }

      return user.username != null &&
          user.username!
              .trim()
              .toLowerCase()
              .replaceFirst('@', '') ==
              normalized;
    });
  }

  // ==========================================================
  // NORMALIZE PHONE NUMBER
  // ==========================================================

  String _normalizePhoneNumber(
      String phoneNumber,
      ) {
    return phoneNumber.replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );
  }

  // ==========================================================
  // RESET MOCK USERS
  // ==========================================================

  void resetMockData() {
    _users
      ..clear()
      ..addAll([
        ChatUser(
          id: 'user_1',
          walletAddress:
          '0x7A31B4C2D8E9F01234567890ABCDEF123456E921',
          username: 'davidk',
          displayName: 'David K',
          phoneNumber: null,
          phoneDiscoveryEnabled: false,
          profileUrl:
          'https://i.pravatar.cc/150?img=12',
          lastMessage: 'Hey, how are you?',
          timestamp: DateTime.now().subtract(
            const Duration(minutes: 5),
          ),
          unreadCount: 2,
          isOnline: true,
        ),
        ChatUser(
          id: 'user_2',
          walletAddress:
          '0x91BC72A4E8215678901234567890ABCDEF123456',
          username: 'amara',
          displayName: 'Amara Okafor',
          phoneNumber: '+2348012345678',
          phoneDiscoveryEnabled: true,
          profileUrl:
          'https://i.pravatar.cc/150?img=32',
          lastMessage: 'See you tomorrow 👋',
          timestamp: DateTime.now().subtract(
            const Duration(hours: 1),
          ),
          unreadCount: 0,
          isOnline: false,
        ),
        ChatUser(
          id: 'user_3',
          walletAddress:
          '0x22EF72A4719A5678901234567890ABCDEF123456',
          username: null,
          displayName: 'Michael Johnson',
          phoneNumber: null,
          phoneDiscoveryEnabled: false,
          profileUrl:
          'https://i.pravatar.cc/150?img=14',
          lastMessage: 'Hello 👋',
          timestamp: DateTime.now().subtract(
            const Duration(hours: 3),
          ),
          unreadCount: 4,
          isOnline: true,
        ),
        ChatUser(
          id: 'user_4',
          walletAddress:
          '0xA8127BC93DE45678901234567890ABCDEF12345',
          username: 'sarah',
          displayName: 'Sarah Williams',
          phoneNumber: '+447700900123',
          phoneDiscoveryEnabled: true,
          profileUrl:
          'https://i.pravatar.cc/150?img=44',
          lastMessage: 'That sounds good.',
          timestamp: DateTime.now().subtract(
            const Duration(days: 1),
          ),
          unreadCount: 0,
          isOnline: true,
        ),
      ]);
  }
}