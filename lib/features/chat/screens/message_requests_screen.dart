import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/messaging_provider.dart';
import '../models/message_request.dart';
import '../../users/models/user_model.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/services/notification_service.dart';

class MessageRequestsScreen extends StatefulWidget {
  const MessageRequestsScreen({super.key});

  @override
  State<MessageRequestsScreen> createState() => _MessageRequestsScreenState();
}

class _MessageRequestsScreenState extends State<MessageRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessagingProvider>().loadRequests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Message Requests'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.primary,
          labelColor: colors.onSurface,
          unselectedLabelColor: colors.onSurfaceVariant,
          tabs: const [
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      child: TabBarView(
        controller: _tabController,
        children: [
          _ReceivedRequestsList(),
          _SentRequestsList(),
        ],
      ),
    );
  }
}

class _ReceivedRequestsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<MessagingProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingRequests && provider.receivedRequests.isEmpty) {
          return const Center(child: GriotLoader(size: 44));
        }

        final requests = provider.receivedRequests.where((r) => r.status == RequestStatus.pending).toList();

        if (requests.isEmpty) {
          return const _EmptyRequests(
            title: 'No pending requests',
            message: 'Incoming requests will appear here.',
            icon: Icons.mark_email_read_outlined,
          );
        }

        return RefreshIndicator(
          onRefresh: provider.loadRequests,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) => _RequestCard(
              request: requests[index],
              isReceived: true,
            ),
          ),
        );
      },
    );
  }
}

class _SentRequestsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<MessagingProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingRequests && provider.sentRequests.isEmpty) {
          return const Center(child: GriotLoader(size: 44));
        }

        final requests = provider.sentRequests.where((r) => r.status == RequestStatus.pending).toList();

        if (requests.isEmpty) {
          return const _EmptyRequests(
            title: 'No sent requests',
            message: 'Pending sent requests will appear here.',
            icon: Icons.send_rounded,
          );
        }

        return RefreshIndicator(
          onRefresh: provider.loadRequests,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) => _RequestCard(
              request: requests[index],
              isReceived: false,
            ),
          ),
        );
      },
    );
  }
}

class _RequestCard extends StatefulWidget {
  final MessageRequest request;
  final bool isReceived;

  const _RequestCard({required this.request, required this.isReceived});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _isLoading = false;

  Future<void> _handleAction(Future<void> Function() action, String successMsg) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await action();
      if (mounted && successMsg.isNotEmpty) NotificationService.showSuccess(context, successMsg);
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Action failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final request = widget.request;
    final isReceived = widget.isReceived;

    final String targetId = (isReceived ? request.senderId : request.receiverId) ?? '';
    final String targetWallet = isReceived ? request.senderWalletAddress : request.receiverWalletAddress;
    final String? targetUsername = isReceived ? request.senderUsername : request.receiverUsername;
    final String? targetDisplayName = isReceived ? request.senderDisplayName : request.receiverDisplayName;
    final String? targetProfileUrl = isReceived ? request.senderProfileUrl : request.receiverProfileUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final user = UserModel(
              id: targetId,
              walletAddress: targetWallet,
              username: targetUsername,
              displayName: targetDisplayName,
              avatarUrl: targetProfileUrl,
            );
            context.push('/user/profile', extra: user);
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: colors.surfaceContainerHighest,
                      backgroundImage: targetProfileUrl != null ? NetworkImage(targetProfileUrl) : null,
                      child: targetProfileUrl == null 
                        ? SvgPicture.asset('assets/coins_logo/hbadger_logo.svg', width: 32, height: 32)
                        : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            targetDisplayName ?? targetUsername ?? _formatAddress(targetWallet),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatAddress(targetWallet),
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
                    Text(
                      DateFormat('MMM d').format(request.createdAt),
                      style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: isReceived 
                    ? [
                        Expanded(
                          child: _ActionButton(
                            label: 'Decline',
                            onTap: () => _handleAction(() => context.read<MessagingProvider>().declineRequest(request.id), ''),
                            color: colors.error,
                            isLoading: _isLoading,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            label: 'Accept',
                            onTap: () => _handleAction(() => context.read<MessagingProvider>().acceptRequest(request.id), 'Connected!'),
                            color: colors.primary,
                            isFilled: true,
                            isLoading: _isLoading,
                          ),
                        ),
                      ]
                    : [
                        Expanded(
                          child: _ActionButton(
                            label: 'Withdraw',
                            onTap: () => _handleAction(() => context.read<MessagingProvider>().withdrawRequest(request.id), 'Request withdrawn'),
                            color: colors.error,
                            isLoading: _isLoading,
                          ),
                        ),
                      ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatAddress(String addr) {
    if (addr.length < 8) return addr;
    return '${addr.substring(0, 3)}...${addr.substring(addr.length - 3)}';
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool isFilled;
  final bool isLoading;

  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.color,
    this.isFilled = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isLoading ? color.withValues(alpha: 0.1) : (isFilled ? color : color.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: isLoading 
          ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: isFilled ? Colors.white : color))
          : Text(
              label,
              style: TextStyle(
                color: isFilled ? Colors.white : color,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _EmptyRequests({required this.title, required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: colors.onSurfaceVariant.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
