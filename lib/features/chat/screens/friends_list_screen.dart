import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:griot_cowrie/features/chat/providers/messaging_provider.dart';
import 'package:griot_cowrie/features/chat/models/chat_user.dart';
import 'package:griot_cowrie/features/users/models/user_model.dart';
import 'package:griot_cowrie/core/theme/app_colors.dart';
import 'package:griot_cowrie/core/services/notification_service.dart';
import 'package:griot_cowrie/features/chat/widgets/chat_loading.dart';
import 'package:griot_cowrie/features/chat/widgets/user_profile_sheet.dart';
import 'package:griot_cowrie/core/ui/scaffolds/gradient_scaffold.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessagingProvider>().loadFriends();
    });
  }

  void _showRemoveFriendDialog(UserModel friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend?'),
        content: Text('Are you sure you want to remove ${friend.displayName ?? friend.username} from your friends?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<MessagingProvider>().removeFriend(friend.id);
                if (context.mounted) NotificationService.showSuccess(context, 'Friend removed');
              } catch (e) {
                if (context.mounted) NotificationService.showError(context, 'Failed to remove friend: $e');
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GradientScaffold(
      appBar: AppBar(
        title: Consumer<MessagingProvider>(
          builder: (context, provider, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Friends', style: TextStyle(fontWeight: FontWeight.w900)),
                Text('${provider.friends.length} total', style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
              ],
            );
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
              ),
              child: TextField(
                onChanged: (v) => setState(() => searchQuery = v),
                decoration: const InputDecoration(
                  hintText: 'Search friends...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          Expanded(
            child: Consumer<MessagingProvider>(
              builder: (context, provider, child) {
                if (provider.isLoadingFriends && provider.friends.isEmpty) {
                  return const ChatLoading();
                }

                final friends = provider.friends.where((user) {
                  final q = searchQuery.trim().toLowerCase();
                  if (q.isEmpty) return true;
                  return (user.displayName ?? '').toLowerCase().contains(q) ||
                      (user.username ?? '').toLowerCase().contains(q) ||
                      user.walletAddress.toLowerCase().contains(q);
                }).toList();

                if (friends.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline_rounded, size: 64, color: colors.onSurfaceVariant.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        const Text('No friends found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: provider.loadFriends,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 40),
                    itemCount: friends.length,
                    separatorBuilder: (context, index) => Divider(height: 1, indent: 80, color: colors.outline.withValues(alpha: 0.1)),
                    itemBuilder: (context, index) {
                      final f = friends[index];
                      final chatUser = ChatUser(
                        id: f.id,
                        walletAddress: f.walletAddress,
                        username: f.username,
                        displayName: f.displayName,
                        profileUrl: f.avatarUrl,
                        timestamp: DateTime.now(),
                        reputation: f.reputation,
                      );
                      return ListTile(
                        onTap: () => UserProfileSheet.show(context, f),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: colors.primary.withValues(alpha: 0.1),
                          backgroundImage: chatUser.profileUrl != null ? NetworkImage(chatUser.profileUrl!) : null,
                          child: chatUser.profileUrl == null ? Icon(Icons.person_rounded, color: colors.primary) : null,
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(chatUser.effectiveDisplayName, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                            if (f.reputation != null) ...[
                              const SizedBox(width: 8),
                              _ReputationBadge(reputation: f.reputation!),
                            ],
                          ],
                        ),
                        subtitle: Text(chatUser.formattedUsername ?? chatUser.shortWalletAddress, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'chat') {
                              context.push('/chat/user/${f.id}');
                            } else if (val == 'remove') {
                              _showRemoveFriendDialog(f);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'chat', child: Text('Open Chat')),
                            const PopupMenuItem(value: 'remove', child: Text('Remove Friend', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReputationBadge extends StatelessWidget {
  final UserReputationBadge reputation;
  const _ReputationBadge({required this.reputation});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.parseHexColor(reputation.badgeColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        reputation.tierName.toUpperCase(),
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }
}
