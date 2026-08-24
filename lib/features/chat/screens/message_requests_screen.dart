import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/messaging_provider.dart';
import '../models/message_request.dart';
import '../widgets/user_profile_sheet.dart';
import '../../users/models/user_model.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_loader.dart';

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Message Requests'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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

        final requests = provider.receivedRequests;

        if (requests.isEmpty) {
          return const _EmptyRequests(
            title: 'No message requests',
            message: 'New requests will appear here.',
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

        final requests = provider.sentRequests;

        if (requests.isEmpty) {
          return const _EmptyRequests(
            title: 'No sent requests',
            message: 'Find someone to start a conversation.',
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

class _RequestCard extends StatelessWidget {
  final MessageRequest request;
  final bool isReceived;

  const _RequestCard({required this.request, required this.isReceived});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: colors.surfaceContainerLow.withValues(alpha: 0.6),
      elevation: 0,
      child: InkWell(
        onTap: () {
          // Construct a partial UserModel to show the profile
          final user = UserModel(
            id: isReceived ? (request.senderId ?? '') : (request.receiverId ?? ''),
            walletAddress: isReceived ? request.senderWalletAddress : request.receiverWalletAddress,
            username: isReceived ? request.senderUsername : null,
            displayName: isReceived ? request.senderDisplayName : null,
            avatarUrl: isReceived ? request.senderProfileUrl : null,
          );
          UserProfileSheet.show(context, user);
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colors.primary.withValues(alpha: 0.1),
                    backgroundImage: request.profileUrl != null ? NetworkImage(request.profileUrl!) : null,
                    child: request.profileUrl == null ? Icon(Icons.person_rounded, color: colors.primary) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                request.displayName,
                                style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              DateFormat('MMM d').format(request.createdAt),
                              style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                        if (request.username != null)
                          Text('@${request.username}', style: text.bodySmall?.copyWith(color: colors.primary, fontWeight: FontWeight.w600)),
                        Text(
                          request.shortWalletAddress,
                          style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant, fontFamily: 'Monospace'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: isReceived 
                  ? [
                      _ActionButton(
                        label: 'Decline',
                        onTap: () => context.read<MessagingProvider>().declineRequest(request.id),
                        color: colors.error,
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        label: 'Accept',
                        onTap: () => context.read<MessagingProvider>().acceptRequest(request.id),
                        color: colors.primary,
                        isFilled: true,
                      ),
                    ]
                  : [
                      if (request.status == RequestStatus.pending)
                        _ActionButton(
                          label: 'Cancel Request',
                          onTap: () => context.read<MessagingProvider>().cancelRequest(request.id),
                          color: colors.onSurfaceVariant,
                        ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(request.status, colors).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          request.status.name.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(request.status, colors),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(RequestStatus status, ColorScheme colors) {
    switch (status) {
      case RequestStatus.pending: return colors.primary;
      case RequestStatus.accepted: return Colors.green;
      case RequestStatus.declined: return colors.error;
      case RequestStatus.cancelled: return colors.onSurfaceVariant;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool isFilled;

  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.color,
    this.isFilled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isFilled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isFilled ? null : Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isFilled ? Colors.white : color,
            fontWeight: FontWeight.bold,
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
