import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/navigation_scroll_service.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../providers/messaging_provider.dart';
import '../models/message_request.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  DateTime? _visitTime;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    NavigationScrollService.instance.addListener(_onNavTap);
    
    if (!mounted) return;
    final provider = Provider.of<MessagingProvider>(context, listen: false);
    _visitTime = provider.lastSeenActivityTime;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        provider.refreshActivity();
        provider.markActivitiesSeen();
      }
    });
  }

  @override
  void dispose() {
    NavigationScrollService.instance.removeListener(_onNavTap);
    _scrollController.dispose();
    super.dispose();
  }

  void _onNavTap() {
    if (NavigationScrollService.instance.tappedIndex == 1) { // Activity index
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Consumer<MessagingProvider>(
        builder: (context, provider, child) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeOutQuart,
            child: _buildBody(context, provider),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, MessagingProvider provider) {
    final colors = Theme.of(context).colorScheme;
    
    // Combine all activity sources
    final requestItems = provider.activityItems;
    final miningItems = provider.miningActivities;
    final walletItems = provider.walletActivities;
    final genericItems = provider.genericActivities;
    
    final List<dynamic> allItems = [...requestItems, ...miningItems, ...walletItems, ...genericItems];
    allItems.sort((a, b) {
      final timeA = a is MessageRequest ? (a.respondedAt ?? a.createdAt) : (a['timestamp'] as DateTime);
      final timeB = b is MessageRequest ? (b.respondedAt ?? b.createdAt) : (b['timestamp'] as DateTime);
      return timeB.compareTo(timeA);
    });

    if (allItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: provider.refreshActivity,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: _buildEmptyState(context, key: const ValueKey('empty')),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refreshActivity,
      child: ListView.separated(
        key: const ValueKey('content'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: allItems.length,
        separatorBuilder: (context, index) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final rawItem = allItems[index];
          
          String title = '';
          String subtitle = '';
          IconData icon = Icons.info_outline_rounded;
          Widget? customIcon;
          Color color = colors.primary;
          DateTime timestamp;
          VoidCallback? onTap;

          if (rawItem is MessageRequest) {
            timestamp = rawItem.respondedAt ?? rawItem.createdAt;
            final isReceived = provider.receivedRequests.any((r) => r.id == rawItem.id);
            
            if (isReceived) {
              switch (rawItem.status) {
                case RequestStatus.pending:
                  title = 'New Request';
                  subtitle = '${rawItem.displayName} wants to connect with you.';
                  icon = Icons.person_add_rounded;
                  onTap = () => context.push('/chat/requests');
                  break;
                case RequestStatus.accepted:
                  title = 'Request Accepted';
                  subtitle = 'You are now connected with ${rawItem.displayName}.';
                  icon = Icons.person_add_alt_1_rounded;
                  color = Colors.green;
                  onTap = () => context.push('/chat/user/${rawItem.senderId}');
                  break;
                case RequestStatus.declined:
                  title = 'Request Declined';
                  subtitle = 'You declined a request from ${rawItem.displayName}.';
                  icon = Icons.person_remove_rounded;
                  color = colors.error;
                  break;
                case RequestStatus.withdrawn:
                  title = 'Request Withdrawn';
                  subtitle = '${rawItem.displayName} withdrew their request.';
                  icon = Icons.undo_rounded;
                  color = colors.onSurfaceVariant;
                  break;
              }
            } else {
              switch (rawItem.status) {
                case RequestStatus.accepted:
                  title = 'Connection Confirmed';
                  subtitle = '${rawItem.receiverDisplayName ?? rawItem.receiverWalletAddress} accepted your request!';
                  icon = Icons.person_add_alt_1_rounded;
                  color = Colors.green;
                  onTap = () => context.push('/chat/user/${rawItem.receiverId}');
                  break;
                case RequestStatus.declined:
                  title = 'Request Declined';
                  subtitle = '${rawItem.receiverDisplayName ?? rawItem.receiverWalletAddress} declined your request.';
                  icon = Icons.person_remove_rounded;
                  color = colors.error;
                  break;
                case RequestStatus.withdrawn:
                  title = 'Request Canceled';
                  subtitle = 'You withdrew your request to ${rawItem.receiverDisplayName ?? rawItem.receiverWalletAddress}.';
                  icon = Icons.undo_rounded;
                  color = colors.onSurfaceVariant;
                  break;
                case RequestStatus.pending:
                  return const SizedBox.shrink();
              }
            }
          } else {
            // Generic Activity
            title = rawItem['title'];
            subtitle = rawItem['message'];
            timestamp = rawItem['timestamp'];
            icon = rawItem['icon'] ?? Icons.notifications_rounded;
            
            final colorName = rawItem['color'];
            if (colorName == 'amber') color = Colors.amber;
            if (colorName == 'indigo') color = Colors.indigo;
            if (colorName == 'green') color = Colors.green;

            if (rawItem['type'] == 'tip' || rawItem['isTip'] == true) {
              onTap = () => context.push('/wallet');
              customIcon = SvgPicture.asset(
                'assets/cowrie_images/cowriesvg.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              );
            } else if (rawItem['type'] == 'mining') {
              onTap = () => context.push('/miner');
            } else if (rawItem['type'] == 'subscription') {
              onTap = () => context.push('/settings/griot-plus');
            }
          }

          final isNew = timestamp.isAfter(_visitTime ?? DateTime.fromMillisecondsSinceEpoch(0));

          return _buildActivityTile(
            context,
            icon: icon,
            customIcon: customIcon,
            color: color,
            title: title,
            subtitle: subtitle,
            time: timestamp,
            onTap: onTap,
            isNew: isNew,
          ).animate().fadeIn(duration: 400.ms, delay: (index * 50).ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad);
        },
      ),
    );
  }

  Widget _buildActivityTile(
    BuildContext context, {
    IconData? icon,
    Widget? customIcon,
    required Color color,
    required String title,
    required String subtitle,
    required DateTime time,
    required VoidCallback? onTap,
    bool isPlaceholder = false,
    bool isNew = false,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isNew ? color.withValues(alpha: 0.3) : colors.outline.withValues(alpha: 0.05), width: isNew ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: customIcon ?? Icon(icon, color: color, size: 20),
                    ),
                    if (isNew)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.surface, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(fontWeight: isNew ? FontWeight.w900 : FontWeight.w800, fontSize: 15),
                          ),
                          if (isNew)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                child: Text('NEW', style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.onSurfaceVariant.withValues(alpha: isNew ? 0.9 : 0.7),
                          fontSize: 13,
                          fontWeight: isNew ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isPlaceholder ? '--' : _formatTime(time),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return DateFormat('MMM d').format(time);
  }

  Widget _buildEmptyState(BuildContext context, {Key? key}) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded, size: 64, color: colors.primary.withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 24),
          const Text(
            'All Caught Up',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'New requests, tips, and alerts will appear here.',
            style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
// Restore from Unicode escapes
