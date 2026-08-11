import 'package:flutter/material.dart';

import '../models/chat_user.dart';

class NewChatSheet extends StatefulWidget {
  final void Function(
      String username,
      String walletAddress,
      ) onSendRequest;

  const NewChatSheet({
    super.key,
    required this.onSendRequest,
  });

  @override
  State<NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<NewChatSheet> {
  final TextEditingController searchController =
  TextEditingController();

  // ==========================================================
  // MOCK USERS
  // ==========================================================

  final List<ChatUser> mockChatUsers = [
    ChatUser(
      id: 'mock_1',
      username: 'ambassadorjoe',
      displayName: 'Ambassador Joe',
      walletAddress: '0x82A491F2A821',
      phoneNumber: '+2348012345678',
      phoneDiscoveryEnabled: true,
      profileUrl: 'https://i.pravatar.cc/150?img=1',
      lastMessage: '',
      timestamp: DateTime(2026, 8, 10),
      unreadCount: 0,
      isOnline: true,
    ),

    ChatUser(
      id: 'mock_2',
      username: null,
      displayName: 'Sarah Williams',
      walletAddress: '0x71C842AE9281',
      phoneNumber: '+447700900123',
      phoneDiscoveryEnabled: true,
      profileUrl: 'https://i.pravatar.cc/150?img=2',
      lastMessage: '',
      timestamp: DateTime(2026, 8, 10),
      unreadCount: 0,
      isOnline: false,
    ),

    ChatUser(
      id: 'mock_3',
      username: 'xperxperience',
      displayName: 'Xper Xperience',
      walletAddress: '0x9B218CD4A921',
      phoneNumber: null,
      phoneDiscoveryEnabled: false,
      profileUrl: 'https://i.pravatar.cc/150?img=3',
      lastMessage: '',
      timestamp: DateTime(2026, 8, 10),
      unreadCount: 0,
      isOnline: true,
    ),
  ];

  // ==========================================================
  // SEARCH RESULTS
  // ==========================================================

  List<ChatUser> get results {
    final query = searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return [];
    }

    return mockChatUsers.where((user) {
      final username =
          user.username?.toLowerCase() ?? '';

      final displayName =
          user.displayName?.toLowerCase() ?? '';

      final wallet =
      user.walletAddress.toLowerCase();

      return username.contains(query) ||
          displayName.contains(query) ||
          wallet.contains(query);
    }).toList();
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),

            // ==================================================
            // HANDLE
            // ==================================================

            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),

            const SizedBox(height: 18),

            // ==================================================
            // HEADER
            // ==================================================

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: Row(
                children: [
                  Text(
                    'New Chat',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // SEARCH
            // ==================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                4,
                16,
                12,
              ),
              child: SizedBox(
                height: 46,
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText:
                    'Search username, name or wallet',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                    ),
                    filled: true,
                    fillColor: colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),

            // ==================================================
            // RESULTS
            // ==================================================

            Expanded(
              child: results.isEmpty
                  ? const _NewChatEmptyState()
                  : ListView.separated(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                itemCount: results.length,
                separatorBuilder: (_, __) =>
                const Divider(height: 1),
                itemBuilder:
                    (context, index) {
                  final user = results[index];

                  return _UserSearchItem(
                    user: user,
                    onRequest: () {
                      widget.onSendRequest(
                        user.username ?? '',
                        user.walletAddress,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// USER SEARCH ITEM
// ==========================================================

class _UserSearchItem extends StatelessWidget {
  final ChatUser user;
  final VoidCallback onRequest;

  const _UserSearchItem({
    required this.user,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final profileUrl =
        user.profileUrl?.trim() ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        vertical: 5,
      ),

      // ======================================================
      // AVATAR
      // ======================================================

      leading: Stack(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundImage: profileUrl.isNotEmpty
                ? NetworkImage(profileUrl)
                : null,
            child: profileUrl.isEmpty
                ? const Icon(
              Icons.person_rounded,
            )
                : null,
          ),

          if (user.isOnline)
            Positioned(
              right: 0,
              bottom: 1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),

      // ======================================================
      // USER NAME
      // ======================================================

      title: Row(
        children: [
          Flexible(
            child: Text(
              user.effectiveDisplayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),

      // ======================================================
      // USERNAME / WALLET
      // ======================================================

      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            if (user.formattedUsername != null)
              Text(
                user.formattedUsername!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color:
                  colorScheme.onSurfaceVariant,
                ),
              ),

            Text(
              user.shortWalletAddress,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),

      // ======================================================
      // REQUEST BUTTON
      // ======================================================

      trailing: FilledButton(
        onPressed: onRequest,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          minimumSize: const Size(0, 36),
          tapTargetSize:
          MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('Request'),
      ),
    );
  }
}

// ==========================================================
// EMPTY STATE
// ==========================================================

class _NewChatEmptyState
    extends StatelessWidget {
  const _NewChatEmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final textTheme =
        Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 46,
              color:
              colorScheme.onSurfaceVariant,
            ),

            const SizedBox(height: 12),

            Text(
              'Find someone on Griot',
              style:
              textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Search by username, display name or '
                  'wallet address to start a conversation.',
              textAlign: TextAlign.center,
              style:
              textTheme.bodySmall?.copyWith(
                color:
                colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}