import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../users/models/user_model.dart';
import '../../users/services/user_api_service.dart';
import '../providers/messaging_provider.dart';
import '../models/message_request.dart';
import '../widgets/user_profile_sheet.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/services/notification_service.dart';

class UserDiscoveryScreen extends StatefulWidget {
  const UserDiscoveryScreen({super.key});

  @override
  State<UserDiscoveryScreen> createState() => _UserDiscoveryScreenState();
}

class _UserDiscoveryScreenState extends State<UserDiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;
  List<UserModel> _results = [];
  bool _isSearching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MessagingProvider>();
      provider.loadConversations();
      provider.loadRequests();
      provider.loadFriends();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    final query = value.trim();

    if (query.length < 2) {
      setState(() {
        _results = [];
        _isSearching = false;
        _error = null;
      });
      return;
    }

    _searchTimer = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await context.read<UserApiService>().searchUsers(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _error = 'Search failed. Please try again.';
      });
    }
  }

  void _showUserProfile(UserModel user) {
    UserProfileSheet.show(context, user);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Discover Users'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search username, name or wallet',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
                filled: true,
                fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isSearching) {
      return const Center(child: GriotLoader(size: 44));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_rounded, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text('Start typing to find users', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return const _EmptySearch(
        title: 'No users found',
        message: 'Try a username, name, or wallet address.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index];
        return _UserResultTile(
          user: user,
          onTap: () => _showUserProfile(user),
        );
      },
    );
  }
}

class _EmptySearch extends StatelessWidget {
  final String title;
  final String message;

  const _EmptySearch({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: colors.onSurfaceVariant.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _UserResultTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const _UserResultTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reputation = user.reputation;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: colors.primary.withValues(alpha: 0.1),
        backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
        child: user.avatarUrl == null ? Icon(Icons.person_rounded, color: colors.primary) : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              user.displayName ?? user.username ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (reputation != null) ...[
            const SizedBox(width: 8),
            _ReputationBadge(reputation: reputation),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.username != null)
            Text('@${user.username}', style: TextStyle(color: colors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
          Text(
            _shortenAddress(user.walletAddress),
            style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 11, fontFamily: 'Monospace'),
          ),
        ],
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant.withValues(alpha: 0.3)),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0);
  }

  String _shortenAddress(String addr) {
    if (addr.length < 10) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
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

// REMOVED LOCAL _UserProfileSheet as it is now global in widgets/user_profile_sheet.dart

