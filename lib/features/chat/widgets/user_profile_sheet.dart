import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/messaging_provider.dart';
import '../models/message_request.dart';
import '../../users/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/ui/widgets/griot_loader.dart';

class UserProfileSheet extends StatefulWidget {
  final UserModel user;
  const UserProfileSheet({super.key, required this.user});

  static void show(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => UserProfileSheet(user: user),
    );
  }

  @override
  State<UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<UserProfileSheet> {
  bool _isActionLoading = false;

  Future<void> _handleAccept(String requestId) async {
    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().acceptRequest(requestId);
      if (mounted) {
        NotificationService.showSuccess(context, 'Connected!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Failed to accept');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleConnect() async {
    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().sendConnectionRequest(widget.user.id);
      if (mounted) {
        NotificationService.showSuccess(context, 'Request sent!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Failed to send request');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = widget.user;

    return Consumer<MessagingProvider>(
      builder: (context, provider, child) {
        final conversation = provider.conversations.where((c) => c.otherUser?.id == user.id).firstOrNull;
        final isFriend = provider.friends.any((f) => f.id == user.id);
        final receivedReq = provider.receivedRequests.where((r) => 
          r.senderId == user.id && r.status == RequestStatus.pending
        ).firstOrNull;
        final sentReq = provider.sentRequests.where((r) => 
          r.receiverId == user.id && r.status == RequestStatus.pending
        ).firstOrNull;

        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(44),
              border: Border.all(color: colors.primary.withValues(alpha: 0.1), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(44),
              child: Stack(
                children: [
                  // Modern Branded Background Pattern
                  Positioned(
                    top: -60, right: -60,
                    child: Opacity(
                      opacity: 0.04,
                      child: SvgPicture.asset('assets/cowrie_images/cowriesvg.svg', width: 240),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Minimal Drag Handle
                        Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: colors.onSurfaceVariant.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Identity Header
                        _buildIdentityHeader(context, user),
                        
                        const SizedBox(height: 24),
                        
                        // Bio Card
                        if (user.bio != null && user.bio!.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerLow.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: colors.outline.withValues(alpha: 0.05)),
                            ),
                            child: Text(
                              user.bio!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        
                        const SizedBox(height: 32),
                        
                        // Premium Action Grid
                        _buildActionGrid(context, provider, isFriend, conversation?.id, receivedReq, sentReq),
                        
                        const SizedBox(height: 28),
                        
                        // Digital ID Section
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'GRIOT ID: ${_shortenAddress(user.walletAddress)}',
                            style: TextStyle(
                              color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate().slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuart, duration: 400.ms).fadeIn();
      },
    );
  }

  Widget _buildIdentityHeader(BuildContext context, UserModel user) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.primary.withValues(alpha: 0.15), width: 2),
              ),
              child: CircleAvatar(
                radius: 56,
                backgroundColor: colors.surfaceContainerHighest,
                backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                child: user.avatarUrl == null 
                  ? SvgPicture.asset('assets/coins_logo/hbadger_logo.svg', width: 56)
                  : null,
              ),
            ),
            if (user.reputation != null)
              _buildReputationIcon(context, user.reputation!),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          user.displayName ?? 'Griot User',
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.6),
        ),
        if (user.username != null)
          Text(
            '@${user.username}',
            style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.2),
          ),
      ],
    );
  }

  Widget _buildReputationIcon(BuildContext context, UserReputationBadge rep) {
    final color = AppColors.parseHexColor(rep.badgeColor);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: const Icon(Icons.stars_rounded, color: Colors.white, size: 20),
    );
  }

  Widget _buildActionGrid(
    BuildContext context, 
    MessagingProvider provider, 
    bool isFriend, 
    String? conversationId,
    MessageRequest? receivedReq,
    MessageRequest? sentReq,
  ) {
    return Column(
      children: [
        Row(
          children: [
            // High-Impact Primary Action
            Expanded(
              flex: 3,
              child: _buildMainButton(context, provider, isFriend, conversationId, receivedReq, sentReq),
            ),
            const SizedBox(width: 12),
            // Tipping - Quick Action
            _buildQuickActionButton(
              context, 
              icon: Icons.volunteer_activism_rounded,
              color: Colors.amber,
              onTap: () {
                Navigator.pop(context);
                context.push('/wallet/send', extra: widget.user.walletAddress);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                context, 
                label: 'View Assets', 
                icon: Icons.account_balance_wallet_rounded,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/wallet/search', extra: widget.user.walletAddress);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSecondaryButton(
                context, 
                label: 'Full Identity', 
                icon: Icons.person_search_rounded,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/user/profile', extra: widget.user);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainButton(
    BuildContext context, 
    MessagingProvider provider, 
    bool isFriend, 
    String? conversationId,
    MessageRequest? receivedReq,
    MessageRequest? sentReq,
  ) {
    final colors = Theme.of(context).colorScheme;

    if (isFriend || conversationId != null) {
      return _ActionPill(
        label: 'Message',
        icon: Icons.chat_bubble_rounded,
        color: colors.primary,
        onTap: () {
          Navigator.pop(context);
          if (conversationId != null) {
            context.push('/conversation/$conversationId');
          } else {
            context.push('/chat/user/${widget.user.id}');
          }
        },
      );
    }

    if (receivedReq != null) {
      return _ActionPill(
        label: 'Accept Request',
        icon: Icons.check_circle_rounded,
        color: Colors.green,
        isLoading: _isActionLoading,
        onTap: () => _handleAccept(receivedReq.id),
      );
    }

    if (sentReq != null) {
      return _ActionPill(
        label: 'Pending Approval',
        icon: Icons.hourglass_top_rounded,
        color: colors.onSurfaceVariant.withValues(alpha: 0.4),
        onTap: null,
      );
    }

    return _ActionPill(
      label: 'Connect',
      icon: Icons.person_add_alt_1_rounded,
      color: colors.primary,
      isLoading: _isActionLoading,
      onTap: _handleConnect,
    );
  }

  Widget _buildQuickActionButton(BuildContext context, {required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildSecondaryButton(BuildContext context, {required String label, required IconData icon, required VoidCallback onTap}) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outline.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: colors.onSurfaceVariant.withValues(alpha: 0.8)),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  String _shortenAddress(String addr) {
    if (addr.length < 12) return addr;
    return '${addr.substring(0, 8)}...${addr.substring(addr.length - 6)}';
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionPill({
    required this.label,
    required this.icon,
    required this.color,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              if (onTap != null)
                BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 15, offset: const Offset(0, 8)),
            ],
          ),
          child: Center(
            child: isLoading 
              ? const GriotLoader(size: 22, color: Colors.white)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.2),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}
