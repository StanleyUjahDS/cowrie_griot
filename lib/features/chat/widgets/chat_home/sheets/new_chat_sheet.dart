import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../users/models/user_model.dart';
import '../../../../users/services/user_api_service.dart';
import '../../../../../core/ui/widgets/griot_loader.dart';

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
  
  Timer? _searchTimer;
  List<UserModel> _results = [];
  bool _isSearching = false;

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _isSearching = true;
    });

    try {
      final apiService = context.read<UserApiService>();
      final results = await apiService.searchUsers(query);
      if (!mounted) return;
      
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(26),
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: BoxDecoration(
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
                    onChanged: _onSearchChanged,
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
                child: _isSearching
                    ? const Center(child: GriotLoader(size: 32))
                    : _results.isEmpty
                        ? const _NewChatEmptyState()
                        : ListView.separated(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  itemCount: _results.length,
                  separatorBuilder: (_, _) =>
                  const Divider(height: 1),
                  itemBuilder:
                      (context, index) {
                    final user = _results[index];
  
                    return _UserSearchItem(
                      key: ValueKey(user.id),
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
      ),
    );
  }
}

// ==========================================================
// USER SEARCH ITEM
// ==========================================================

class _UserSearchItem extends StatelessWidget {
  final UserModel user;
  final VoidCallback onRequest;

  const _UserSearchItem({
    super.key,
    required this.user,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final avatarUrl = user.avatarUrl;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        vertical: 5,
      ),

      // ======================================================
      // AVATAR
      // ======================================================

      leading: CircleAvatar(
        radius: 25,
        backgroundImage: avatarUrl != null
            ? NetworkImage(avatarUrl)
            : null,
        child: avatarUrl == null
            ? const Icon(
          Icons.person_rounded,
        )
            : null,
      ),

      // ======================================================
      // USER NAME
      // ======================================================

      title: Row(
        children: [
          Flexible(
            child: Text(
              user.effectiveName,
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
            if (user.username != null && user.username!.isNotEmpty)
              Text(
                user.formattedUsername,
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