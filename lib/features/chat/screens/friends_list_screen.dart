import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:griot_cowrie/features/chat/providers/messaging_provider.dart';
import 'package:griot_cowrie/features/users/models/user_model.dart';
import 'package:griot_cowrie/core/theme/app_colors.dart';
import 'package:griot_cowrie/core/services/notification_service.dart';
import 'package:griot_cowrie/features/chat/widgets/chat_loading.dart';
import 'package:griot_cowrie/core/ui/scaffolds/gradient_scaffold.dart';
import 'package:griot_cowrie/core/ui/widgets/griot_loader.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessagingProvider>().loadFriends();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<MessagingProvider>().loadMoreFriends();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.read<MessagingProvider>().searchFriends(value.trim());
      }
    });
  }

  Future<void> _startChat(UserModel friend) async {
    try {
      final provider = context.read<MessagingProvider>();
      final conversation = await provider.startDirectChat(friend.id);
      if (mounted) {
        context.push('/conversation/${conversation.id}');
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to open chat: $e');
      }
    }
  }

  void _showUnfriendDialog(UserModel friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unfriend?'),
        content: Text('Are you sure you want to remove ${friend.displayName ?? friend.username} from your friends?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<MessagingProvider>().removeFriend(friend.id);
                if (context.mounted) NotificationService.showSuccess(context, 'User removed from friends');
              } catch (e) {
                if (context.mounted) NotificationService.showError(context, 'Failed to unfriend: $e');
              }
            },
            child: const Text('Unfriend', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBlockUserDialog(UserModel friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User?'),
        content: Text('Are you sure you want to block ${friend.displayName ?? friend.username}? They will no longer be able to message you.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<MessagingProvider>().blockUser(friend.id);
                if (context.mounted) NotificationService.showSuccess(context, 'User blocked');
              } catch (e) {
                if (context.mounted) NotificationService.showError(context, 'Failed to block user: $e');
              }
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
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
        centerTitle: true,
        title: Consumer<MessagingProvider>(
          builder: (context, provider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Friends'),
                Text(
                  '${provider.friendsTotal} active',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
          },
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
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
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search friends...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            context.read<MessagingProvider>().loadFriends();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          Expanded(
            child: Consumer<MessagingProvider>(
              builder: (context, provider, child) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  switchInCurve: Curves.easeOutQuart,
                  child: _buildBody(context, provider),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, MessagingProvider provider) {
    final colors = Theme.of(context).colorScheme;

    if (provider.isLoadingFriends && provider.friends.isEmpty) {
      return const ChatLoading(key: ValueKey('loading'));
    }

    final friends = provider.friends;

    if (friends.isEmpty) {
      return Center(
        key: const ValueKey('empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _searchController.text.isNotEmpty ? Icons.search_off_rounded : Icons.people_outline_rounded,
              size: 64,
              color: colors.onSurfaceVariant.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty ? 'No matching friends found' : 'No friends found',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      key: const ValueKey('content'),
      onRefresh: () => provider.loadFriends(),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 40),
        itemCount: friends.length + (provider.hasMoreFriends ? 1 : 0),
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 80,
          color: colors.outline.withValues(alpha: 0.1),
        ),
        itemBuilder: (context, index) {
          if (index == friends.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: GriotLoader(size: 24.0)),
            );
          }
          final f = friends[index];
          return _FriendTile(
            user: f,
            onTap: () => _startChat(f),
            onProfileTap: () => context.push('/user/profile', extra: f),
            onUnfriend: () => _showUnfriendDialog(f),
            onBlock: () => _showBlockUserDialog(f),
          ).animate().fadeIn(duration: 400.ms, delay: (index * 40).ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad);
        },
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  final VoidCallback onProfileTap;
  final VoidCallback onUnfriend;
  final VoidCallback onBlock;

  const _FriendTile({
    required this.user,
    required this.onTap,
    required this.onProfileTap,
    required this.onUnfriend,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    
    final String displayName = user.displayName ?? user.username ?? 'Unknown';
    final String? username = user.username != null ? '@${user.username}' : null;
    final String shortAddress = user.walletAddress.length > 8
        ? '${user.walletAddress.substring(0, 3)}...${user.walletAddress.substring(user.walletAddress.length - 3)}'
        : user.walletAddress;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: GestureDetector(
        onTap: onProfileTap,
        child: CircleAvatar(
          radius: 24,
          backgroundColor: colors.primary.withValues(alpha: 0.1),
          backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
          child: user.avatarUrl == null 
            ? SvgPicture.asset('assets/coins_logo/hbadger_logo.svg')
            : null,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (user.reputation != null) ...[
            const SizedBox(width: 8),
            _ReputationBadge(reputation: user.reputation!),
          ],
        ],
      ),
      subtitle: Text(
        username ?? shortAddress,
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
      ),
      trailing: PopupMenuButton<String>(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.primary.withValues(alpha: 0.1), width: 1.5),
        ),
        elevation: 12,
        offset: const Offset(0, 40),
        onSelected: (val) {
          if (val == 'chat') {
            onTap();
          } else if (val == 'profile') {
            onProfileTap();
          } else if (val == 'unfriend') {
            onUnfriend();
          } else if (val == 'block') {
            onBlock();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'chat', 
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 20, color: colors.primary),
                const SizedBox(width: 12),
                const Text('Message', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'profile', 
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 20, color: colors.primary),
                const SizedBox(width: 12),
                const Text('View Profile', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'unfriend',
            child: Row(
              children: [
                const Icon(Icons.person_remove_rounded, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                const Text('Unfriend', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'block',
            child: Row(
              children: [
                const Icon(Icons.block_rounded, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                const Text('Block', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
              ],
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
