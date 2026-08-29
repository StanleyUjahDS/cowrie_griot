import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_svg/flutter_svg.dart';
import '../../users/models/user_model.dart';
import '../../users/services/user_api_service.dart';
import '../providers/messaging_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_loader.dart';

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
      final apiService = context.read<UserApiService>();
      final results = await apiService.searchUsers(query);
      if (!mounted) return;
      
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e, stack) {
      debugPrint('DISCOVERY SEARCH ERROR: $e');
      debugPrint('$stack');

      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _error = e.toString();
      });
    }
  }

  void _showUserProfile(UserModel user) {
    context.push('/user/profile', extra: user);
  }

  Future<void> _handleAction(UserModel user) async {
    final status = user.relationshipStatus;
    final provider = context.read<MessagingProvider>();

    try {
      switch (status) {
        case 'friend':
          _showUserProfile(user);
          break;
        case 'request_received':
          _showUserProfile(user);
          break;
        case 'not_connected':
          await provider.sendConnectionRequest(user.id);
          if (mounted) NotificationService.showSuccess(context, 'Request sent!');
          _performSearch(_searchController.text);
          break;
        case 'blocked':
          await provider.unblockUser(user.id);
          if (mounted) NotificationService.showSuccess(context, 'User unblocked');
          _performSearch(_searchController.text);
          break;
        default:
          _showUserProfile(user);
          break;
      }
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Action failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text(
          'Discover',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 50, // Slightly more compact
        leading: Center(
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            ),
          ),
        ),
      ),
      child: Column(
        children: [
          // Premium Floating Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    autofocus: true,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Search username or wallet...',
                      hintStyle: TextStyle(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(Icons.search_rounded, color: colors.primary, size: 22),
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                      filled: true,
                      fillColor: colors.surface.withValues(alpha: 0.7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: colors.primary.withValues(alpha: 0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: colors.primary.withValues(alpha: 0.05)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: colors.primary.withValues(alpha: 0.2), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeOutQuart,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isSearching) {
      return const Center(
        key: ValueKey('loading'),
        child: GriotLoader(size: 44),
      );
    }

    if (_error != null) {
      return _ErrorState(key: const ValueKey('error'), message: _error!);
    }

    if (_searchController.text.isEmpty) {
      return const _InitialState(key: ValueKey('initial'));
    }

    if (_results.isEmpty) {
      return const _EmptySearch(
        key: ValueKey('empty'),
        title: 'No results found',
        message: 'Try a different username, name, or wallet address.',
      );
    }

    return ListView.builder(
      key: const ValueKey('results'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index];
        return _UserResultTile(
          user: user,
          onTap: () => _showUserProfile(user),
          onActionPressed: () => _handleAction(user),
        ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
      },
    );
  }
}

class _InitialState extends StatelessWidget {
  const _InitialState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_search_rounded, size: 64, color: colors.primary.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 24),
          Text(
            'Find your Circle',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colors.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for friends across the network',
            style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: Colors.red.withValues(alpha: 0.3)),
            const SizedBox(height: 24),
            Text(
              'Connection Lost',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  final String title;
  final String message;

  const _EmptySearch({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.manage_search_rounded, size: 64, color: colors.onSurfaceVariant.withValues(alpha: 0.2)),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text(
              message, 
              style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.7), height: 1.5), 
              textAlign: TextAlign.center
            ),
          ],
        ),
      ),
    );
  }
}

class _UserResultTile extends StatefulWidget {
  final UserModel user;
  final VoidCallback onTap;
  final Future<void> Function() onActionPressed;

  const _UserResultTile({
    required this.user, 
    required this.onTap,
    required this.onActionPressed,
  });

  @override
  State<_UserResultTile> createState() => _UserResultTileState();
}

class _UserResultTileState extends State<_UserResultTile> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reputation = widget.user.reputation;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _Avatar(user: widget.user, reputation: reputation),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.displayName ?? 'Griot User',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.user.username != null)
                        Text(
                          '@${widget.user.username}', 
                          style: TextStyle(color: colors.primary, fontSize: 13, fontWeight: FontWeight.w700)
                        ),
                      const SizedBox(height: 2),
                      Text(
                        _shortenAddress(widget.user.walletAddress),
                        style: TextStyle(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.4), 
                          fontSize: 10, 
                          fontFamily: 'monospace', 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Action(
                  status: widget.user.relationshipStatus, 
                  isLoading: _isLoading,
                  onAction: () async {
                    if (_isLoading) return;
                    setState(() => _isLoading = true);
                    try {
                      await widget.onActionPressed();
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  }
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shortenAddress(String addr) {
    if (addr.length < 8) return addr;
    return '${addr.substring(0, 3)}...${addr.substring(addr.length - 3)}';
  }
}

class _Avatar extends StatelessWidget {
  final UserModel user;
  final UserReputationBadge? reputation;
  const _Avatar({required this.user, this.reputation});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: colors.surfaceContainerHighest,
          backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
          child: user.avatarUrl == null 
            ? SvgPicture.asset('assets/coins_logo/hbadger_logo.svg', width: 32, height: 32)
            : null,
        ),
        if (reputation != null)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.parseHexColor(reputation!.badgeColor),
              shape: BoxShape.circle,
              border: Border.all(color: colors.surface, width: 2),
            ),
            child: Icon(
              reputation!.tierName.toLowerCase().contains('ultimate') 
                  ? Icons.stars_rounded 
                  : Icons.workspace_premium_rounded,
              size: 10,
              color: Colors.white,
            ),
          ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final String? status;
  final bool isLoading;
  final VoidCallback onAction;
  const _Action({this.status, required this.onAction, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (status == 'self') return const SizedBox.shrink();

    IconData icon;
    Color color;
    bool filled = false;

    switch (status) {
      case 'friend':
        icon = Icons.chat_bubble_rounded;
        color = colors.primary;
        break;
      case 'request_received':
        icon = Icons.check_circle_rounded;
        color = Colors.green;
        filled = true;
        break;
      case 'request_sent':
        icon = Icons.hourglass_top_rounded;
        color = colors.onSurfaceVariant.withValues(alpha: 0.5);
        break;
      case 'blocked':
        icon = Icons.block_rounded;
        color = colors.error;
        break;
      default:
        icon = Icons.person_add_alt_1_rounded;
        color = colors.primary;
        filled = true;
    }

    return GestureDetector(
      onTap: isLoading ? null : onAction,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icon, size: 20, color: filled ? Colors.white : color),
      ),
    );
  }
}
