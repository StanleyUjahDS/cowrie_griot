import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:griot_cowrie/core/services/navigation_scroll_service.dart';
import 'package:griot_cowrie/features/chat/providers/messaging_provider.dart';
import 'package:griot_cowrie/core/ui/scaffolds/gradient_scaffold.dart';
import 'package:griot_cowrie/features/chat/models/conversation_model.dart';
import 'package:griot_cowrie/features/chat/widgets/chat_list_item.dart';
import 'package:griot_cowrie/features/chat/widgets/chat_loading.dart';
import 'package:griot_cowrie/features/chat/widgets/group_list_item.dart'
    as group_widgets;
import 'package:griot_cowrie/features/chat/widgets/channel_list_item.dart';
import 'package:griot_cowrie/core/router/main_navigation.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';

enum HubSection { direct, groups, channels }

class ChatHomeScreen extends StatelessWidget {
  const ChatHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ChatHomeView();
  }
}

class _ChatHomeView extends StatefulWidget {
  const _ChatHomeView();

  @override
  State<_ChatHomeView> createState() => _ChatHomeViewState();
}

class _ChatHomeViewState extends State<_ChatHomeView> {
  String searchQuery = '';
  final Map<HubSection, ScrollController> _scrollControllers = {
    HubSection.direct: ScrollController(),
    HubSection.groups: ScrollController(),
    HubSection.channels: ScrollController(),
  };
  late final PageController _pageController;
  HubSection selectedHub = HubSection.direct;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: selectedHub.index);
    NavigationScrollService.instance.addListener(_onNavTap);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messaging = Provider.of<MessagingProvider>(context, listen: false);
      // Load the cache immediately, then always reconcile it with the server.
      // Otherwise a non-empty stale cache prevents newly-created groups from
      // appearing after returning to the chat screen.
      messaging.loadConversations(force: true);
      if (messaging.receivedRequests.isEmpty &&
          messaging.sentRequests.isEmpty) {
        messaging.loadRequests();
      }
      if (messaging.friends.isEmpty) {
        messaging.loadFriends();
      }
    });
  }

  @override
  void dispose() {
    NavigationScrollService.instance.removeListener(_onNavTap);
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _onNavTap() {
    if (NavigationScrollService.instance.tappedIndex == 0) {
      final controller = _scrollControllers[selectedHub];
      if (controller != null && controller.hasClients) {
        controller.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  List<Conversation> getFilteredConversations(
    MessagingProvider provider,
    HubSection section,
  ) {
    final conversations = provider.conversations;
    final query = searchQuery.trim().toLowerCase();

    final sectionFiltered = conversations.where((conv) {
      if (section == HubSection.direct) {
        // A DM conversation can be created before the first message is sent.
        // Keep those conversations out of the inbox; friends remain available
        // through the Friends/Discover views and can still start the chat.
        return conv.type == ConversationType.dm && conv.lastMessage != null;
      }
      if (section == HubSection.groups) {
        return conv.type == ConversationType.group;
      }
      if (section == HubSection.channels) {
        return conv.type == ConversationType.channel;
      }
      return true;
    }).toList();

    if (query.isEmpty) return sectionFiltered;

    return sectionFiltered.where((conv) {
      final title = conv.title?.toLowerCase() ?? '';
      final user = conv.otherUser?.effectiveDisplayName.toLowerCase() ?? '';
      final lastMsg = conv.lastMessage?.text.toLowerCase() ?? '';

      return title.contains(query) ||
          user.contains(query) ||
          lastMsg.contains(query);
    }).toList();
  }

  void _openNewChat() => context.push('/chat/discover');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GradientScaffold(
      useSafeArea: false,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text('Messenger'),
        centerTitle: true,
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        leadingWidth: 70,
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (context) => GestureDetector(
            onTap: () =>
                MainNavigationShell.scaffoldKey.currentState?.openDrawer(),
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: colors.surface.withValues(alpha: 0.95),
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.menu_rounded,
                      color: colors.primary,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: const [SizedBox(width: 16)],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: FloatingActionButton(
          onPressed: _openNewChat,
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 6,
          child: const Icon(Icons.search_rounded, size: 30),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: _buildContent()),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: _buildFloatingControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingControls() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.88),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 44,
                    child: TextField(
                      onChanged: (v) {
                        setState(() => searchQuery = v);
                      },
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search conversations...',
                        hintStyle: TextStyle(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: colors.primary,
                        ),
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ChatSectionSwitcher(
                    selected: selectedHub,
                    onChanged: (section) {
                      _pageController.animateToPage(
                        section.index,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutQuart,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (searchQuery.isNotEmpty) {
      return _buildSearchResults();
    }

    return _buildUnifiedConversations();
  }

  Widget _buildUnifiedConversations() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          selectedHub = HubSection.values[index];
        });
      },
      itemCount: HubSection.values.length,
      itemBuilder: (context, sectionIndex) {
        final section = HubSection.values[sectionIndex];
        return Consumer<MessagingProvider>(
          builder: (context, provider, child) {
            if (provider.isLoadingConversations &&
                provider.conversations.isEmpty) {
              return const ChatLoading(key: ValueKey('loading'));
            }

            final list = getFilteredConversations(provider, section);

            if (list.isEmpty) {
              String emptyTitle = '';
              String emptyMsg = '';
              IconData icon = Icons.chat_bubble_outline_rounded;

              switch (section) {
                case HubSection.direct:
                  emptyTitle = 'Start a Story';
                  emptyMsg =
                      'Connect with friends and start your first decentralized chat.';
                  icon = Icons.chat_bubble_outline_rounded;
                  break;
                case HubSection.groups:
                  emptyTitle = 'Private Circles';
                  emptyMsg =
                      'Create a secure group for your community or inner circle.';
                  icon = Icons.groups_rounded;
                  break;
                case HubSection.channels:
                  emptyTitle = 'Broadcasting';
                  emptyMsg =
                      'Follow channels to stay updated with the latest Griot stories.';
                  icon = Icons.campaign_rounded;
                  break;
              }

              return _EmptyState(
                icon: icon,
                title: emptyTitle,
                message: emptyMsg,
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                if (mounted) await provider.loadConversations(force: true);
              },
              child: ListView.builder(
                controller: _scrollControllers[section],
                padding: const EdgeInsets.fromLTRB(0, 140, 0, 140),
                itemCount: list.length + 1,
                itemBuilder: (context, index) {
                  // 1. TOP HEADER
                  if (index == 0) {
                    String title = '';
                    switch (section) {
                      case HubSection.direct:
                        title = 'Direct Messages';
                        break;
                      case HubSection.groups:
                        title = 'Your Circles';
                        break;
                      case HubSection.channels:
                        title = 'Channels';
                        break;
                    }
                    return _ListSectionHeader(title: title);
                  }

                  // 2. LIST ITEMS
                  final dataIndex = index - 1;
                  final conv = list[dataIndex];
                  final type = conv.type;

                  Widget item;
                  if (type == ConversationType.dm) {
                    final other = conv.otherUser;
                    if (other == null) return const SizedBox.shrink();

                    final lastMsgText =
                        conv.lastMessage?.text ?? 'No messages yet';

                    item = ChatListItem(
                      user: other.copyWith(
                        lastMessage: lastMsgText,
                        timestamp: conv.updatedAt,
                        unreadCount: conv.unreadCount,
                      ),
                      time: _formatTime(conv.updatedAt),
                      onTap: () =>
                          context.push('/conversation/${conv.id}', extra: conv),
                      onAvatarTap: () =>
                          context.push('/user/profile', extra: other),
                    );
                  } else if (type == ConversationType.group) {
                    item = group_widgets.GroupListItem(
                      conversation: conv,
                      onTap: () =>
                          context.push('/conversation/${conv.id}', extra: conv),
                    );
                  } else if (type == ConversationType.channel) {
                    item = ChannelListItem(conversation: conv);
                  } else {
                    return const SizedBox.shrink();
                  }

                  return item
                      .animate()
                      .fadeIn(duration: 400.ms, delay: (index * 40).ms)
                      .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    final provider = context.watch<MessagingProvider>();
    final query = searchQuery.trim().toLowerCase();

    final dms = provider.conversations
        .where((c) => c.type == ConversationType.dm && c.lastMessage != null)
        .toList();
    final groups = provider.conversations
        .where((c) => c.type == ConversationType.group)
        .toList();
    final channels = provider.conversations
        .where((c) => c.type == ConversationType.channel)
        .toList();

    bool matches(Conversation conv) {
      final title = conv.title?.toLowerCase() ?? '';
      final user = conv.otherUser?.effectiveDisplayName.toLowerCase() ?? '';
      final lastMsg = conv.lastMessage?.text.toLowerCase() ?? '';
      return title.contains(query) ||
          user.contains(query) ||
          lastMsg.contains(query);
    }

    final dmResults = dms.where(matches).toList();
    final groupResults = groups.where(matches).toList();
    final channelResults = channels.where(matches).toList();

    if (dmResults.isEmpty && groupResults.isEmpty && channelResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 180, horizontal: 40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 16),
              Text(
                'No conversations found matching "$searchQuery"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 140, 0, 120),
      children: [
        if (dmResults.isNotEmpty) ...[
          _SearchSectionHeader(title: 'Messages'),
          ...dmResults.map(
            (conv) => ChatListItem(
              user: conv.otherUser!.copyWith(
                lastMessage: conv.lastMessage?.text ?? 'No messages yet',
                timestamp: conv.updatedAt,
                unreadCount: conv.unreadCount,
              ),
              time: _formatTime(conv.updatedAt),
              onTap: () =>
                  context.push('/conversation/${conv.id}', extra: conv),
              onAvatarTap: () =>
                  context.push('/user/profile', extra: conv.otherUser),
            ),
          ),
        ],
        if (groupResults.isNotEmpty) ...[
          _SearchSectionHeader(title: 'Circles'),
          ...groupResults.map(
            (conv) => group_widgets.GroupListItem(
              conversation: conv,
              onTap: () =>
                  context.push('/conversation/${conv.id}', extra: conv),
            ),
          ),
        ],
        if (channelResults.isNotEmpty) ...[
          _SearchSectionHeader(title: 'Channels'),
          ...channelResults.map((conv) => ChannelListItem(conversation: conv)),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${time.day}/${time.month}';
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GriotBrandedContainer(
              padding: const EdgeInsets.all(20),
              borderRadius: 28,
              child: Icon(icon, size: 40, color: colors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatSectionSwitcher extends StatelessWidget {
  final HubSection selected;
  final ValueChanged<HubSection> onChanged;
  const _ChatSectionSwitcher({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: HubSection.values.map((s) {
          final isSelected = selected == s;
          String label = '';
          IconData icon;

          switch (s) {
            case HubSection.direct:
              label = 'Direct';
              icon = Icons.chat_bubble_rounded;
              break;
            case HubSection.groups:
              label = 'Groups';
              icon = Icons.groups_rounded;
              break;
            case HubSection.channels:
              label = 'Channels';
              icon = Icons.sensors_rounded;
              break;
          }

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => onChanged(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.primary
                        : colors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border(
                      top: BorderSide(
                        color: colors.primary.withValues(
                          alpha: isSelected ? 0 : 0.6,
                        ),
                        width: 1.5,
                      ),
                      bottom: BorderSide(
                        color: colors.primary.withValues(
                          alpha: isSelected ? 0 : 0.6,
                        ),
                        width: 1.5,
                      ),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: isSelected
                            ? colors.onPrimary
                            : colors.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? colors.onPrimary
                              : colors.onSurfaceVariant.withValues(alpha: 0.7),
                          fontWeight: isSelected
                              ? FontWeight.w900
                              : FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SearchSectionHeader extends StatelessWidget {
  final String title;
  const _SearchSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _ListSectionHeader extends StatelessWidget {
  final String title;
  const _ListSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: colors.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
