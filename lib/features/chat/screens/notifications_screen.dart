import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/navigation_scroll_service.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/messaging_provider.dart';
import '../models/message_request.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  DateTime? _visitTime;
  final ScrollController _scrollController = ScrollController();
  final Set<String> _expandedTipIds = <String>{};

  @override
  void initState() {
    super.initState();
    NavigationScrollService.instance.addListener(_onNavTap);

    if (!mounted) return;
    final provider = Provider.of<MessagingProvider>(context, listen: false);
    _visitTime = provider.lastSeenNotificationTime;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        provider.refreshNotifications();
        provider.markNotificationsSeen();
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
    if (NavigationScrollService.instance.tappedIndex == 1) {
      // Activity index
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  bool _onScrollNotification(
    ScrollNotification notification,
    MessagingProvider provider,
  ) {
    if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 300 &&
        provider.hasMoreNotifications &&
        !provider.isLoadingMoreNotifications) {
      provider.loadMoreNotifications();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GradientScaffold(
      useSafeArea: false,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text('Updates'),
        centerTitle: true,
        backgroundColor: colors.surface,
        elevation: 0,
        toolbarHeight: 56,
        automaticallyImplyLeading: false,
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

    // Combine all social activity sources
    final requestItems = provider.requestNotifications;
    final genericItems = provider.notificationEvents;

    final List<dynamic> allItems = [...requestItems, ...genericItems];
    allItems.sort((a, b) {
      final timeA = a is MessageRequest
          ? (a.respondedAt ?? a.createdAt)
          : (a['timestamp'] as DateTime);
      final timeB = b is MessageRequest
          ? (b.respondedAt ?? b.createdAt)
          : (b['timestamp'] as DateTime);
      return timeB.compareTo(timeA);
    });

    if (allItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: provider.refreshNotifications,
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
      onRefresh: provider.refreshNotifications,
      displacement: 100,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) =>
            _onScrollNotification(notification, provider),
        child: ListView.separated(
          key: const ValueKey('content'),
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          itemCount:
              allItems.length +
              (provider.isLoadingMoreNotifications ||
                      !provider.hasMoreNotifications
                  ? 1
                  : 0),
          separatorBuilder: (context, index) => const SizedBox(height: 2),
          itemBuilder: (context, index) {
            if (index >= allItems.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: provider.isLoadingMoreNotifications
                      ? const CircularProgressIndicator()
                      : const Text('No more updates'),
                ),
              );
            }
            final rawItem = allItems[index];

            String title = '';
            String subtitle = '';
            String? avatarUrl;
            IconData icon = Icons.info_outline_rounded;
            Widget? customIcon;
            Color color = colors.primary;
            DateTime timestamp;
            VoidCallback? onTap;
            Map<String, String>? details;

            if (rawItem is MessageRequest) {
              timestamp = rawItem.respondedAt ?? rawItem.createdAt;
              final isReceived = provider.receivedRequests.any(
                (r) => r.id == rawItem.id,
              );
              avatarUrl = rawItem.profileUrl;

              if (isReceived) {
                switch (rawItem.status) {
                  case RequestStatus.pending:
                    title = 'New Request';
                    subtitle =
                        '${rawItem.displayName} wants to connect with you.';
                    icon = Icons.person_add_rounded;
                    onTap = () => context.push('/chat/requests');
                    break;
                  case RequestStatus.accepted:
                    title = 'Request Accepted';
                    subtitle =
                        'You are now connected with ${rawItem.displayName}.';
                    icon = Icons.person_add_alt_1_rounded;
                    color = AppColors.success;
                    onTap = () =>
                        context.push('/chat/user/${rawItem.senderId}');
                    break;
                  case RequestStatus.declined:
                    title = 'Request Declined';
                    subtitle =
                        'You declined a request from ${rawItem.displayName}.';
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
                    subtitle =
                        '${rawItem.receiverDisplayName ?? rawItem.receiverWalletAddress} accepted your request!';
                    icon = Icons.person_add_alt_1_rounded;
                    color = AppColors.success;
                    onTap = () =>
                        context.push('/chat/user/${rawItem.receiverId}');
                    break;
                  case RequestStatus.declined:
                    title = 'Request Declined';
                    subtitle =
                        '${rawItem.receiverDisplayName ?? rawItem.receiverWalletAddress} declined your request.';
                    icon = Icons.person_remove_rounded;
                    color = colors.error;
                    break;
                  case RequestStatus.withdrawn:
                    title = 'Request Canceled';
                    subtitle =
                        'You withdrew your request to ${rawItem.receiverDisplayName ?? rawItem.receiverWalletAddress}.';
                    icon = Icons.undo_rounded;
                    color = colors.onSurfaceVariant;
                    break;
                  case RequestStatus.pending:
                    title = 'Request Sent';
                    subtitle =
                        'Your connection request is waiting for a response.';
                    icon = Icons.outgoing_mail;
                    color = colors.primary;
                    break;
                }
              }
            } else {
              // Generic Activity
              title = rawItem['title'];
              subtitle = rawItem['message'];
              timestamp = rawItem['timestamp'];
              icon = rawItem['icon'] ?? Icons.notifications_rounded;
              avatarUrl = rawItem['avatarUrl']?.toString();

              final colorName = rawItem['color'];
              if (colorName == 'amber') color = colors.primary;
              if (colorName == 'indigo') color = colors.primary;
              if (colorName == 'green') color = AppColors.success;

              if (rawItem['type'] == 'tip_received') {
                final metadata = rawItem['metadata'] is Map
                    ? Map<String, dynamic>.from(rawItem['metadata'])
                    : <String, dynamic>{};
                final isRecipient = rawItem['isRecipient'] != false;
                final counterpartyWallet = rawItem['counterpartyWalletAddress']
                    ?.toString();
                final transactionHash = metadata['hash']?.toString();
                final network = metadata['network']?.toString();
                final assetType = metadata['assetType']?.toString();
                final tokenAddress = metadata['tokenAddress']?.toString();
                final amount = metadata['amountRaw'];
                final amountText = amount is List
                    ? amount.map((value) => value.toString()).join(', ')
                    : amount?.toString();
                final counterpartyName =
                    rawItem['displayName']?.toString() ?? 'Griot user';

                final groupedItems = rawItem['tipItems'] is List
                    ? (rawItem['tipItems'] as List)
                          .whereType<Map>()
                          .toList()
                    : const <Map>[];
                final isGrouped = groupedItems.length > 1;
                final people = groupedItems
                    .map((item) => item['displayName']?.toString())
                    .whereType<String>()
                    .where((name) => name.trim().isNotEmpty)
                    .toSet()
                    .toList();

                details = {
                  if (isGrouped)
                    'Summary':
                        '${groupedItems.length} tips in one blockchain transaction',
                  isRecipient ? 'Sent by' : 'Sent to': counterpartyName,
                  if (isGrouped && people.isNotEmpty)
                    'Participants': people.join(', '),
                  if (counterpartyWallet != null &&
                      counterpartyWallet.isNotEmpty)
                    'Wallet': _shortAddress(counterpartyWallet),
                  if (amountText != null && amountText.isNotEmpty)
                    'Amount': amountText,
                  if (assetType != null && assetType.isNotEmpty)
                    'Asset': assetType,
                  if (tokenAddress != null && tokenAddress.isNotEmpty)
                    'Token': _shortAddress(tokenAddress),
                  if (network != null && network.isNotEmpty) 'Network': network,
                  if (transactionHash != null && transactionHash.isNotEmpty)
                    'Transaction': _shortAddress(transactionHash),
                };

                if (isGrouped) {
                  for (var index = 0; index < groupedItems.length; index++) {
                    final item = groupedItems[index];
                    final itemMetadata = item['metadata'] is Map
                        ? Map<String, dynamic>.from(item['metadata'])
                        : <String, dynamic>{};
                    final itemAmount = itemMetadata['amountRaw'];
                    final itemAsset = itemMetadata['assetType']?.toString();
                    final itemName = item['displayName']?.toString() ??
                        'Griot user';
                    final amount = itemAmount is List
                        ? itemAmount.map((value) => value.toString()).join(', ')
                        : itemAmount?.toString();
                    details['${index + 1}. $itemName'] = [
                      if (amount != null && amount.isNotEmpty) amount,
                      if (itemAsset != null && itemAsset.isNotEmpty) itemAsset,
                    ].join(' ');
                  }
                }
                customIcon = Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    rawItem['isRecipient'] == false
                        ? Icons.north_east_rounded
                        : Icons.volunteer_activism_outlined,
                    size: 20,
                    color: color,
                  ),
                );
              } else if (rawItem['type'] == 'mining') {
                onTap = () => context.push('/miner');
              } else if (rawItem['type'] == 'subscription') {
                onTap = () => context.push('/settings/griot-plus');
              }
            }

            final isNew = timestamp.isAfter(
              _visitTime ?? DateTime.fromMillisecondsSinceEpoch(0),
            );

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
                  avatarUrl: avatarUrl,
                  details: details,
                  isExpanded:
                      details != null &&
                      _expandedTipIds.contains(rawItem['id']?.toString()),
                  onToggleDetails: details == null
                      ? null
                      : () {
                          final id = rawItem['id']?.toString();
                          if (id == null) return;
                          setState(() {
                            if (!_expandedTipIds.add(id)) {
                              _expandedTipIds.remove(id);
                            }
                          });
                        },
                )
                .animate()
                .fadeIn(duration: 400.ms, delay: (index * 50).ms)
                .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad);
          },
        ),
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
    String? avatarUrl,
    Map<String, String>? details,
    bool isExpanded = false,
    VoidCallback? onToggleDetails,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggleDetails ?? onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border(
                top: BorderSide(
                  color: (isNew ? color : colors.primary).withValues(
                    alpha: 0.15,
                  ),
                  width: 1.2,
                ),
                bottom: BorderSide(
                  color: (isNew ? color : colors.primary).withValues(
                    alpha: 0.15,
                  ),
                  width: 1.2,
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        if (avatarUrl != null && avatarUrl.isNotEmpty)
                          CircleAvatar(
                            radius: 22,
                            backgroundImage: NetworkImage(avatarUrl),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child:
                                customIcon ??
                                Icon(icon, color: color, size: 20),
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
                                border: Border.all(
                                  color: colors.surface,
                                  width: 2,
                                ),
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
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: isNew
                                        ? FontWeight.w900
                                        : FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (isNew)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'NEW',
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: colors.onSurfaceVariant.withValues(
                                alpha: isNew ? 0.9 : 0.7,
                              ),
                              fontSize: 13,
                              fontWeight: isNew
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isPlaceholder ? '--' : _formatTime(time),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        if (details != null) ...[
                          const SizedBox(height: 4),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                if (details != null && isExpanded) ...[
                  const SizedBox(height: 12),
                  Divider(color: colors.outline.withValues(alpha: 0.12)),
                  const SizedBox(height: 4),
                  ...details.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 92,
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shortAddress(String value) {
    if (value.length <= 14) return value;
    return '${value.substring(0, 6)}…${value.substring(value.length - 6)}';
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
            child: Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: colors.primary.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Updates',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'New requests, tips, and alerts will appear here.',
            style: TextStyle(
              color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
// Restore from Unicode escapes
