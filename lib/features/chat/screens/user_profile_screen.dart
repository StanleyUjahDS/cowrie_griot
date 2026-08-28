import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/messaging_provider.dart';
import '../models/message_request.dart';
import '../../users/models/user_model.dart';
import '../../users/providers/user_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';

class UserProfileScreen extends StatefulWidget {
  final UserModel user;
  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isActionLoading = false;
  final ScrollController _scrollController = ScrollController();
  double _scrollOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messaging = context.read<MessagingProvider>();
      messaging.loadBlocks();
      messaging.loadRequests();
      messaging.loadFriends();
      
      if (widget.user.relationshipStatus == 'self') {
        context.read<UserProvider>().loadUser();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final opacity = (_scrollController.offset / 150).clamp(0.0, 1.0);
    if (opacity != _scrollOpacity) {
      setState(() => _scrollOpacity = opacity);
    }
  }

  Future<void> _handleConnect() async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().sendRequest(widget.user.id);
      if (mounted) NotificationService.showSuccess(context, 'Request sent!');
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, e.toString().contains('409') ? 'Request already exists' : 'Failed to send');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleAccept(String requestId) async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().acceptRequest(requestId);
      if (mounted) NotificationService.showSuccess(context, 'Connected!');
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Failed to accept');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleWithdraw(String requestId) async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().withdrawRequest(requestId);
      if (mounted) NotificationService.showSuccess(context, 'Request withdrawn');
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Failed to withdraw');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleDecline(String requestId) async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().declineRequest(requestId);
    } catch (_) {
      // Silence errors for decline as per spec
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _handleBlockToggle(bool isBlocked) async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      final provider = context.read<MessagingProvider>();
      if (isBlocked) {
        await provider.unblockUser(widget.user.id);
        if (mounted) NotificationService.showSuccess(context, 'User unblocked');
      } else {
        await provider.blockUser(widget.user.id);
        if (mounted) NotificationService.showSuccess(context, 'User blocked');
      }
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Failed to update block status');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
    return Consumer2<MessagingProvider, UserProvider>(
      builder: (context, messaging, userProvider, child) {
        final bool isSelf = widget.user.relationshipStatus == 'self' || 
                           widget.user.id == userProvider.user?.id;
        
        final UserModel user = isSelf && userProvider.user != null ? userProvider.user! : widget.user;
        final relationship = messaging.getRelationship(user.id);
        final pendingReq = messaging.getPendingRequest(user.id);
        
        final isBlocked = relationship == RelationshipState.blocked;
        final isFriend = relationship == RelationshipState.friends;
        
        final bool isBlockedByThem = user.relationshipStatus == 'blocked_by_user';

        return GradientScaffold(
          useSafeArea: false,
          appBar: AppBar(
            backgroundColor: colors.surface.withValues(alpha: _scrollOpacity),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: Center(
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
              ),
            ),
            title: Opacity(
              opacity: _scrollOpacity,
              child: Text(
                user.displayName ?? 'Profile',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
            actions: [
              if (!isSelf)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onSelected: (val) {
                    if (val == 'block') {
                      _handleBlockToggle(isBlocked);
                    } else if (val == 'tip') {
                      NotificationService.showInfo(context, 'Tipping coming soon');
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'tip',
                      child: Row(
                        children: [
                          Icon(Icons.volunteer_activism_rounded, size: 18, color: Colors.amber),
                          const SizedBox(width: 12),
                          const Text('Tip User'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(isBlocked ? Icons.check_circle_outline_rounded : Icons.block_rounded, 
                               color: isBlocked ? Colors.green : Colors.red, size: 18),
                          const SizedBox(width: 12),
                          Text(isBlocked ? 'Unblock' : 'Block User', 
                               style: TextStyle(color: isBlocked ? Colors.green : Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(width: 8),
            ],
          ),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Immersive Header
              SliverToBoxAdapter(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 240,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colors.primary.withValues(alpha: 0.2),
                            colors.surface.withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (user.avatarUrl != null)
                            Positioned.fill(
                              child: ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                                child: Opacity(
                                  opacity: 0.15,
                                  child: Image.network(user.avatarUrl!, fit: BoxFit.cover),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: -50,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 124,
                            height: 124,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.surface, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 25,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: colors.surfaceContainerHighest,
                              backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                              child: user.avatarUrl == null 
                                ? SvgPicture.asset('assets/coins_logo/hbadger_logo.svg', width: 64, height: 64)
                                : null,
                            ),
                          ),
                          if (isFriend)
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colors.surface, width: 3),
                                ),
                                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                              ),
                            ),
                        ],
                      ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 64)),

              // 2. Identity Info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        user.displayName ?? 'Griot User',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      if (user.username != null) ...[
                        const SizedBox(height: 4),
                        Text('@${user.username}', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // 3. Interaction Hub
              if (!isSelf && !isBlockedByThem)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildInteractionRow(context, relationship, pendingReq, colors),
                  ).animate().fadeIn(delay: 300.ms),
                )
              else if (isBlockedByThem)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: _LockIndicatorCard())),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // 4. Bio & Network Info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user.bio != null && user.bio!.isNotEmpty) ...[
                        _buildSectionLabel('BIOGRAPHY'),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: colors.outline.withValues(alpha: 0.05)),
                          ),
                          child: Text(user.bio!, style: theme.textTheme.bodyLarge),
                        ),
                        const SizedBox(height: 32),
                      ],
                      _buildSectionLabel('NETWORK IDENTITY'),
                      const SizedBox(height: 16),
                      _IdentityDetailsCard(user: user),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        );
      }
    );
  }

  Widget _buildInteractionRow(BuildContext context, RelationshipState state, MessageRequest? request, ColorScheme colors) {
    switch (state) {
      case RelationshipState.none:
        return _ProfileHubButton(
          label: 'Connect',
          icon: Icons.person_add_alt_1_rounded,
          color: colors.primary,
          isPrimary: true,
          isLoading: _isActionLoading,
          onTap: _handleConnect,
        );
      case RelationshipState.pendingSent:
        return Row(
          children: [
            Expanded(
              child: _ProfileHubButton(
                label: 'Request Sent',
                icon: Icons.hourglass_top_rounded,
                color: colors.primary.withValues(alpha: 0.6),
                isPrimary: false,
                onTap: null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProfileHubButton(
                label: 'Withdraw',
                icon: Icons.close_rounded,
                color: colors.error,
                isPrimary: true,
                isLoading: _isActionLoading,
                onTap: () => _handleWithdraw(request!.id),
              ),
            ),
          ],
        );
      case RelationshipState.pendingReceived:
        return Row(
          children: [
            Expanded(
              child: _ProfileHubButton(
                label: 'Decline',
                icon: Icons.close_rounded,
                color: colors.error,
                isPrimary: false,
                isLoading: _isActionLoading,
                onTap: () => _handleDecline(request!.id),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProfileHubButton(
                label: 'Accept',
                icon: Icons.check_rounded,
                color: Colors.green,
                isPrimary: true,
                isLoading: _isActionLoading,
                onTap: () => _handleAccept(request!.id),
              ),
            ),
          ],
        );
      case RelationshipState.friends:
        return Row(
          children: [
            Expanded(
              child: _ProfileHubButton(
                label: 'Friends',
                icon: Icons.people_rounded,
                color: Colors.green,
                isPrimary: false,
                onTap: null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProfileHubButton(
                label: 'Message',
                icon: Icons.chat_bubble_rounded,
                color: colors.primary,
                isPrimary: true,
                onTap: () => context.push('/chat/user/${widget.user.id}'),
              ),
            ),
          ],
        );
      case RelationshipState.blocked:
        return _ProfileHubButton(
          label: 'Unblock User',
          icon: Icons.security_rounded,
          color: colors.error,
          isPrimary: true,
          isLoading: _isActionLoading,
          onTap: () => _handleBlockToggle(true),
        );
    }
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    );
  }
}

class _ProfileHubButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isPrimary;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ProfileHubButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isPrimary,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: 250.ms,
          height: 56,
          decoration: BoxDecoration(
            color: isPrimary ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: isPrimary ? null : Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Center(
            child: isLoading 
              ? GriotLoader(size: 20, color: isPrimary ? Colors.white : color)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20, color: isPrimary ? Colors.white : color),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(color: isPrimary ? Colors.white : color, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

class _IdentityDetailsCard extends StatelessWidget {
  final UserModel user;
  const _IdentityDetailsCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outline.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _row(context, Icons.fingerprint_rounded, 'Griot Digital ID', _shorten(user.walletAddress)),
          _divider(context),
          _row(context, Icons.calendar_today_rounded, 'Member Since', 
            user.createdAt != null ? DateFormat('MMMM yyyy').format(user.createdAt!) : 'NEW USER'),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.primary.withValues(alpha: 0.6)),
        const SizedBox(width: 16),
        Text(label, style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.7), fontWeight: FontWeight.w600, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
      ],
    );
  }

  Widget _divider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.05)),
    );
  }

  String _shorten(String addr) {
    if (addr.length < 8) return addr;
    return '${addr.substring(0, 3)}...${addr.substring(addr.length - 3)}';
  }
}

class _LockIndicatorCard extends StatelessWidget {
  const _LockIndicatorCard();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.error.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_rounded, color: Colors.red, size: 40),
          const SizedBox(height: 16),
          const Text('PROFILE LOCKED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          Text('This identity is private. Connect to see more.', 
               textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
