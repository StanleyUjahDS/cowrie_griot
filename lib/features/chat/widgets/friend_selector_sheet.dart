import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/messaging_provider.dart';
import '../../users/models/user_model.dart';
import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/ui/widgets/griot_bottom_sheet.dart';

class FriendSelectorSheet extends StatefulWidget {
  final List<String> initialSelectedIds;
  final List<String> disabledIds;
  final String title;

  const FriendSelectorSheet({
    super.key,
    this.initialSelectedIds = const [],
    this.disabledIds = const [],
    this.title = 'Select Friends',
  });

  static Future<List<UserModel>?> show(
    BuildContext context, {
    List<String> initialSelectedIds = const [],
    List<String> disabledIds = const [],
    String title = 'Select Friends',
  }) {
    return showModalBottomSheet<List<UserModel>>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FriendSelectorSheet(
        initialSelectedIds: initialSelectedIds,
        disabledIds: disabledIds,
        title: title,
      ),
    );
  }

  @override
  State<FriendSelectorSheet> createState() => _FriendSelectorSheetState();
}

class _FriendSelectorSheetState extends State<FriendSelectorSheet> {
  late List<UserModel> _selectedFriends;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedFriends = [];

    // We'll populate _selectedFriends after friends are loaded if we have initial IDs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MessagingProvider>();
      if (provider.friends.isEmpty) {
        provider.loadFriends();
      }
    });
  }

  void _toggleFriend(UserModel friend) {
    setState(() {
      final index = _selectedFriends.indexWhere((f) => f.id == friend.id);
      if (index != -1) {
        _selectedFriends.removeAt(index);
      } else {
        _selectedFriends.add(friend);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.80,
      child: GriotBottomSheet(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selectedFriends),
                    child: Text(
                      'Done (${_selectedFriends.length})',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                onChanged: (v) =>
                    setState(() => _searchQuery = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search friends...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Consumer<MessagingProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoadingFriends && provider.friends.isEmpty) {
                    return const Center(child: GriotLoader());
                  }

                  final filteredFriends = provider.friends.where((f) {
                    final name = (f.displayName ?? '').toLowerCase();
                    final username = (f.username ?? '').toLowerCase();
                    return name.contains(_searchQuery) ||
                        username.contains(_searchQuery);
                  }).toList();

                  if (filteredFriends.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No friends found.'
                            : 'No matches found.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                    itemCount: filteredFriends.length,
                    itemBuilder: (context, index) {
                      final friend = filteredFriends[index];
                      final isSelected = _selectedFriends.any(
                        (f) => f.id == friend.id,
                      );
                      final isDisabled = widget.disabledIds.contains(friend.id);

                      return CheckboxListTile(
                        value: isSelected || isDisabled,
                        onChanged: isDisabled
                            ? null
                            : (_) => _toggleFriend(friend),
                        title: Text(
                          friend.displayName ?? friend.username ?? 'Griot User',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDisabled
                                ? colors.onSurface.withValues(alpha: 0.3)
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          isDisabled
                              ? 'Already a member'
                              : '@${friend.username ?? friend.shortWalletAddress}',
                          style: TextStyle(
                            color: isDisabled
                                ? colors.onSurface.withValues(alpha: 0.3)
                                : null,
                          ),
                        ),
                        secondary: Opacity(
                          opacity: isDisabled ? 0.5 : 1.0,
                          child: CircleAvatar(
                            backgroundImage: friend.avatarUrl != null
                                ? NetworkImage(friend.avatarUrl!)
                                : null,
                            child: friend.avatarUrl == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                        ),
                        checkboxShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        activeColor: isDisabled
                            ? colors.onSurface.withValues(alpha: 0.1)
                            : colors.primary,
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
