import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/messaging_provider.dart';
import '../models/message_request.dart';
import '../../users/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/notification_service.dart';

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
      builder: (context) => UserProfileSheet(user: user),
    );
  }

  @override
  State<UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<UserProfileSheet> {
  bool _isActionLoading = false;

  Future<void> _sendRequest() async {
    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().sendRequest(widget.user.id);
      if (context.mounted) {
        NotificationService.showSuccess(context, 'Request sent!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        NotificationService.showError(context, e.toString().contains('409') ? 'Already sent' : 'Failed to send');
      }
    } finally {
      if (context.mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = widget.user;

    return Consumer<MessagingProvider>(
      builder: (context, provider, child) {
        // SYNCHRONIZED STATE CHECKS
        final conversation = provider.conversations.where((c) => c.otherUser?.id == user.id).firstOrNull;
        final isFriend = provider.friends.any((f) => f.id == user.id);
        final sentReq = provider.sentRequests.where((r) => 
          r.receiverWalletAddress.toLowerCase() == user.walletAddress.toLowerCase() && r.status == RequestStatus.pending
        ).firstOrNull;
        final receivedReq = provider.receivedRequests.where((r) => 
          r.senderWalletAddress.toLowerCase() == user.walletAddress.toLowerCase() && r.status == RequestStatus.pending
        ).firstOrNull;
        
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(32)),
            child: Stack(
              children: [
                // Branded Backgrounds
                Positioned(right: -60, top: 40, child: Opacity(opacity: 0.05, child: Image.asset('assets/cowrie_images/cowrie_ring.png', width: 200))),
                Positioned(left: -50, bottom: -30, child: Opacity(opacity: 0.05, child: Image.asset('assets/cowrie_images/cowrie_stack.png', width: 180))),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.onSurfaceVariant.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 32),
                      
                      // Avatar & Reputation
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: colors.primary.withValues(alpha: 0.1),
                        backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                        child: user.avatarUrl == null ? Icon(Icons.person_rounded, size: 50, color: colors.primary) : null,
                      ),
                      const SizedBox(height: 16),
                      Text(user.displayName ?? 'Griot User', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                      if (user.username != null) Text('@${user.username}', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      if (user.reputation != null) _ReputationBadge(reputation: user.reputation!),
                      
                      const SizedBox(height: 24),
                      if (user.bio != null && user.bio!.isNotEmpty)
                        Text(user.bio!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
                      
                      const SizedBox(height: 32),
                      
                      // SYNCED ACTIONS
                      Row(
                        children: [
                          Expanded(
                            child: _buildMainAction(
                              context, 
                              provider,
                              isFriend: isFriend, 
                              conversationId: conversation?.id, 
                              sentReq: sentReq, 
                              receivedReq: receivedReq
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ProfileActionButton(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'View Wallet',
                              color: colors.secondary,
                              onTap: () {
                                Navigator.pop(context);
                                context.push('/wallet/send', extra: user.walletAddress);
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () => NotificationService.showInfo(context, 'User blocked'),
                            icon: Icon(Icons.block_rounded, size: 14, color: colors.error),
                            label: Text('Block User', style: TextStyle(color: colors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 24),
                          _ProfileActionButton(
                            icon: Icons.volunteer_activism_outlined,
                            label: 'Tip',
                            color: Colors.amber[700],
                            onTap: () => NotificationService.showInfo(context, 'Tipping coming soon'),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      Text('Wallet: ${user.walletAddress}', style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 10, fontFamily: 'Monospace')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainAction(BuildContext context, MessagingProvider provider, {required bool isFriend, String? conversationId, MessageRequest? sentReq, MessageRequest? receivedReq}) {
    final colors = Theme.of(context).colorScheme;

    if (isFriend || conversationId != null) {
      return _ProfileActionButton(
        icon: Icons.chat_bubble_rounded,
        label: 'Open Chat',
        onTap: () {
          if (context.mounted) {
            Navigator.pop(context);
            if (conversationId != null) {
              context.push('/conversation/$conversationId');
            } else {
              context.push('/chat/user/${widget.user.id}');
            }
          }
        },
      );
    }

    if (sentReq != null) {
      return _ProfileActionButton(icon: Icons.hourglass_empty_rounded, label: 'Request Sent', color: colors.onSurfaceVariant, onTap: null);
    }

    if (receivedReq != null) {
      return _ProfileActionButton(
        icon: Icons.check_circle_outline_rounded,
        label: 'Accept',
        color: Colors.green,
        onTap: () async {
          try {
            await provider.acceptRequest(receivedReq.id);
            if (context.mounted) {
              NotificationService.showSuccess(context, 'Connected!');
            }
          } catch (_) {}
        },
      );
    }

    return _ProfileActionButton(
      icon: Icons.person_add_alt_1_rounded,
      label: 'Send Request',
      onTap: _isActionLoading ? null : _sendRequest,
      isLoading: _isActionLoading,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(reputation.tierName.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool isLoading;

  const _ProfileActionButton({required this.icon, required this.label, this.onTap, this.color, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: btnColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: btnColor.withValues(alpha: 0.2))),
          child: isLoading 
            ? Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: btnColor)))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: btnColor, size: 20),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: btnColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ]),
        ),
      ),
    );
  }
}
