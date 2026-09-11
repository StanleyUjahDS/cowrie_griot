import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/messaging_provider.dart';
import '../models/message_request.dart';
import '../models/chat_user.dart';
import '../widgets/chatting/tip_sheet.dart';
import '../../users/models/user_model.dart';
import '../../users/providers/user_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/ui/widgets/griot_avatar.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../widgets/chatting/fullscreen_media_viewer.dart';

class UserProfileScreen extends StatefulWidget {
  final UserModel user;
  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserModel? _canonicalUser;
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
      _loadCanonicalProfile();

      if (widget.user.relationshipStatus == 'self') {
        context.read<UserProvider>().loadUser();
      }
    });
  }

  Future<void> _loadCanonicalProfile() async {
    if (widget.user.id.isEmpty) return;
    try {
      final user = await context
          .read<UserProvider>()
          .userApiService
          .getUserById(widget.user.id);
      if (mounted) setState(() => _canonicalUser = user);
    } catch (_) {
      // Keep the route payload visible if the refresh is temporarily unavailable.
    }
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
    final provider = context.read<MessagingProvider>();
    setState(() => _isActionLoading = true);
    try {
      await provider.sendConnectionRequest(widget.user.id);
      if (mounted) NotificationService.showSuccess(context, 'Request sent!');
    } catch (e) {
      if (mounted) {
        NotificationService.showError(
          context,
          e.toString().contains('409')
              ? 'Request already exists'
              : 'Failed to send',
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleAccept(String requestId) async {
    if (_isActionLoading) return;
    final provider = context.read<MessagingProvider>();
    setState(() => _isActionLoading = true);
    try {
      await provider.acceptRequest(requestId);
      if (mounted) NotificationService.showSuccess(context, 'Connected!');
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Failed to accept');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleWithdraw(String requestId) async {
    if (_isActionLoading) return;
    final provider = context.read<MessagingProvider>();
    setState(() => _isActionLoading = true);
    try {
      await provider.withdrawRequest(requestId);
      if (mounted)
        NotificationService.showSuccess(context, 'Request withdrawn');
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Failed to withdraw');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleDecline(String requestId) async {
    if (_isActionLoading) return;
    final provider = context.read<MessagingProvider>();
    setState(() => _isActionLoading = true);
    try {
      await provider.declineRequest(requestId);
    } catch (_) {
      // Silence errors for decline as per spec
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleUnfriend() async {
    final messenger = context.read<MessagingProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unfriend?'),
        content: const Text(
          'Are you sure you want to remove this user from your friends?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Unfriend',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      await messenger.removeFriend(widget.user.id);
      if (!mounted) return;
      NotificationService.showSuccess(context, 'User removed from friends');
    } catch (e) {
      if (!mounted) return;
      NotificationService.showError(context, 'Failed to unfriend');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _handleBlockToggle(bool isBlocked) async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    final provider = context.read<MessagingProvider>();
    try {
      if (isBlocked) {
        await provider.unblockUser(widget.user.id);
        if (mounted) NotificationService.showSuccess(context, 'User unblocked');
      } else {
        await provider.blockUser(widget.user.id);
        if (mounted) NotificationService.showSuccess(context, 'User blocked');
      }
    } catch (e) {
      if (mounted)
        NotificationService.showError(context, 'Failed to update block status');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _showTipSheet() {
    TipSheet.show(context, recipients: [ChatUser.fromUserModel(widget.user)]);
  }

  RelationshipState _getEffectiveRelationship(
    RelationshipState local,
    String? initialStatus,
  ) {
    if (local != RelationshipState.none) return local;

    switch (initialStatus?.trim().toLowerCase()) {
      case 'friend':
      case 'friends':
      case 'accepted':
      case 'connected':
        return RelationshipState.friends;
      case 'request_sent':
        return RelationshipState.pendingSent;
      case 'request_received':
        return RelationshipState.pendingReceived;
      case 'blocked':
        return RelationshipState.blocked;
      default:
        return RelationshipState.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Consumer2<MessagingProvider, UserProvider>(
      builder: (context, messaging, userProvider, child) {
        final bool isSelf =
            widget.user.relationshipStatus == 'self' ||
            widget.user.id == userProvider.user?.id;

        final UserModel user = isSelf && userProvider.user != null
            ? userProvider.user!
            : (_canonicalUser ?? widget.user);
        final relationship = messaging.getRelationship(user.id);
        final effectiveRelationship = _getEffectiveRelationship(
          relationship,
          user.relationshipStatus ?? widget.user.relationshipStatus,
        );
        final pendingReq = messaging.getPendingRequest(user.id);

        final isBlocked = effectiveRelationship == RelationshipState.blocked;
        final isFriend = effectiveRelationship == RelationshipState.friends;

        final bool isBlockedByThem =
            user.relationshipStatus == 'blocked_by_user';

        return GradientScaffold(
          useSafeArea: false,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Immersive Modern SliverAppBar
              SliverAppBar(
                expandedHeight: 340,
                pinned: true,
                stretch: false,
                backgroundColor: colors.surface.withValues(
                  alpha: _scrollOpacity,
                ),
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                leading: Center(
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          top: BorderSide(
                            color: colors.primary.withValues(alpha: 0.6),
                            width: 1.2,
                          ),
                          bottom: BorderSide(
                            color: colors.primary.withValues(alpha: 0.6),
                            width: 1.2,
                          ),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
                actions: [
                  if (!isSelf)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              top: BorderSide(
                                color: colors.primary.withValues(alpha: 0.6),
                                width: 1.2,
                              ),
                              bottom: BorderSide(
                                color: colors.primary.withValues(alpha: 0.6),
                                width: 1.2,
                              ),
                            ),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                            ),
                            child: PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: colors.primary,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                                side: BorderSide(
                                  color: colors.primary.withValues(alpha: 0.1),
                                  width: 1.5,
                                ),
                              ),
                              elevation: 4,
                              offset: const Offset(0, 50),
                              onSelected: (val) {
                                if (val == 'block') {
                                  _handleBlockToggle(isBlocked);
                                } else if (val == 'unfriend') {
                                  _handleUnfriend();
                                } else if (val == 'tip') {
                                  _showTipSheet();
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'tip',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.volunteer_activism_outlined,
                                        color: colors.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Tip User',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isFriend)
                                  PopupMenuItem(
                                    value: 'unfriend',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person_remove_rounded,
                                          color: colors.error,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Unfriend',
                                          style: TextStyle(
                                            color: colors.error,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                PopupMenuItem(
                                  value: 'block',
                                  child: Row(
                                    children: [
                                      Icon(
                                        isBlocked
                                            ? Icons.check_circle_outline_rounded
                                            : Icons.block_rounded,
                                        color: isBlocked
                                            ? AppColors.success
                                            : colors.error,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        isBlocked ? 'Unblock' : 'Block User',
                                        style: TextStyle(
                                          color: isBlocked
                                              ? AppColors.success
                                              : colors.error,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [],
                  centerTitle: true,
                  titlePadding: const EdgeInsets.only(bottom: 16),
                  title: Opacity(
                    opacity: _scrollOpacity,
                    child: Text(
                      user.displayName ?? 'Profile',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  background: Center(
                    child: Opacity(
                      opacity: (1.0 - (_scrollOpacity * 1.5)).clamp(0.0, 1.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 40),
                          // Avatar
                          _buildPreviewAvatar(context, user),
                          const SizedBox(height: 16),
                          // Name
                          Text(
                            user.displayName ?? 'Griot User',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: colors.onSurface,
                            ),
                          ),
                          // Username
                          if (user.username != null)
                            Text(
                              '@${user.username}',
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          const SizedBox(height: 12),
                          // Reputation Badge
                          if (user.reputation != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.parseHexColor(
                                  user.reputation?.badgeColor,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.parseHexColor(
                                    user.reputation?.badgeColor,
                                  ).withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.workspace_premium_rounded,
                                    size: 14,
                                    color: AppColors.parseHexColor(
                                      user.reputation?.badgeColor,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    user.reputation?.tierName ??
                                        'Initiate Badger',
                                    style: TextStyle(
                                      color: AppColors.parseHexColor(
                                        user.reputation?.badgeColor,
                                      ),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // 2. Interaction Hub
              if (!isSelf && !isBlockedByThem)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildInteractionRow(
                      context,
                      effectiveRelationship,
                      pendingReq,
                      colors,
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                )
              else if (isBlockedByThem)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: _LockIndicatorCard(),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

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
                            border: Border(
                              top: BorderSide(
                                color: colors.primary.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                              bottom: BorderSide(
                                color: colors.primary.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: Text(
                            user.bio!,
                            style: theme.textTheme.bodyLarge,
                          ),
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
      },
    );
  }

  Widget _buildPreviewAvatar(BuildContext context, UserModel user) {
    final avatarUrl = user.avatarUrl?.trim();
    final avatar = GriotAvatar(
      avatarUrl: avatarUrl,
      radius: 55,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );

    if (avatarUrl == null || avatarUrl.isEmpty) return avatar;

    return GestureDetector(
      onTap: () => FullscreenMediaViewer.show(context, avatarUrl),
      child: avatar,
    );
  }

  Widget _buildInteractionRow(
    BuildContext context,
    RelationshipState state,
    MessageRequest? request,
    ColorScheme colors,
  ) {
    switch (state) {
      case RelationshipState.none:
        return Row(
          children: [
            Expanded(
              child: _ProfileHubButton(
                label: 'Tip',
                icon: Icons.volunteer_activism_outlined,
                color: colors.primary,
                isPrimary: false,
                onTap: () {
                  TipSheet.show(
                    context,
                    recipients: [ChatUser.fromUserModel(widget.user)],
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProfileHubButton(
                label: 'Connect',
                icon: Icons.person_add_alt_1_rounded,
                color: colors.primary,
                isPrimary: true,
                isLoading: _isActionLoading,
                onTap: _handleConnect,
              ),
            ),
          ],
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
                color: AppColors.success,
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
                label: 'Tip User',
                icon: Icons.volunteer_activism_outlined,
                color: colors.primary,
                isPrimary: false,
                onTap: () {
                  TipSheet.show(
                    context,
                    recipients: [ChatUser.fromUserModel(widget.user)],
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProfileHubButton(
                label: 'Message',
                icon: Icons.chat_bubble_rounded,
                color: colors.primary,
                isPrimary: true,
                onTap: () => context.push(
                  '/chat/user/${widget.user.id}',
                  extra: ChatUser.fromUserModel(widget.user),
                ),
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
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    );
  }
}

class _ProfileHubButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool isPrimary;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ProfileHubButton({
    required this.label,
    this.icon,
    required this.color,
    required this.isPrimary,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
            border: isPrimary
                ? null
                : Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Center(
            child: isLoading
                ? GriotLoader(
                    size: 20,
                    color: isPrimary ? colors.onPrimary : color,
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null)
                        Icon(
                          icon,
                          size: 20,
                          color: isPrimary ? colors.onPrimary : color,
                        ),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: TextStyle(
                          color: isPrimary ? colors.onPrimary : color,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
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
        border: Border(
          top: BorderSide(
            color: colors.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
          bottom: BorderSide(
            color: colors.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _row(
            context,
            Icons.fingerprint_rounded,
            'Griot Digital ID',
            user.shortWalletAddress,
          ),
          _divider(context),
          _row(
            context,
            Icons.calendar_today_rounded,
            'Member Since',
            user.createdAt != null
                ? DateFormat('MMMM yyyy').format(user.createdAt!)
                : 'NEW USER',
          ),
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
        Text(
          label,
          style: TextStyle(
            color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
      ],
    );
  }

  Widget _divider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(
        height: 1,
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.05),
      ),
    );
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
          Icon(Icons.lock_rounded, color: colors.error, size: 40),
          const SizedBox(height: 16),
          const Text(
            'PROFILE LOCKED',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This identity is private. Connect to see more.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
