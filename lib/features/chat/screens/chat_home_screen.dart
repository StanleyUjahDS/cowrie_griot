import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

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
import '../../../core/services/notification_service.dart';

enum HubSection { direct, groups, channels }

class ChatHomeScreen extends StatelessWidget {
  final String initialTab;

  const ChatHomeScreen({super.key, this.initialTab = 'direct'});

  @override
  Widget build(BuildContext context) {
    return _ChatHomeView(initialSection: _sectionFromTab(initialTab));
  }

  static HubSection _sectionFromTab(String tab) => switch (tab.toLowerCase()) {
    'group' || 'groups' => HubSection.groups,
    'channel' || 'channels' => HubSection.channels,
    _ => HubSection.direct,
  };
}

class _ChatHomeView extends StatefulWidget {
  final HubSection initialSection;

  const _ChatHomeView({required this.initialSection});

  @override
  State<_ChatHomeView> createState() => _ChatHomeViewState();
}

class _ChatHomeViewState extends State<_ChatHomeView> {
  String searchQuery = '';
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  final Map<HubSection, ScrollController> _scrollControllers = {
    HubSection.direct: ScrollController(),
    HubSection.groups: ScrollController(),
    HubSection.channels: ScrollController(),
  };
  late final PageController _pageController;
  late HubSection selectedHub;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    selectedHub = widget.initialSection;
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
  void didUpdateWidget(covariant _ChatHomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection == widget.initialSection ||
        selectedHub == widget.initialSection) {
      return;
    }

    selectedHub = widget.initialSection;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(selectedHub.index);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(selectedHub.index);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
        // Keep every direct conversation in the inbox, including a newly
        // created DM that has not received its first message yet.
        return conv.type == ConversationType.dm;
      }
      if (section == HubSection.groups) {
        return conv.type == ConversationType.group;
      }
      if (section == HubSection.channels) {
        return conv.type == ConversationType.channel;
      }
      return true;
    }).toList();

    if (query.isEmpty) return _sortConversations(provider, sectionFiltered);

    return _sortConversations(
      provider,
      sectionFiltered.where((conv) {
        final title = conv.title?.toLowerCase() ?? '';
        final user = conv.otherUser?.effectiveDisplayName.toLowerCase() ?? '';
        final lastMsg = conv.lastMessage?.previewText.toLowerCase() ?? '';

        return title.contains(query) ||
            user.contains(query) ||
            lastMsg.contains(query);
      }).toList(),
    );
  }

  List<Conversation> _sortConversations(
    MessagingProvider provider,
    List<Conversation> conversations,
  ) {
    conversations.sort((a, b) {
      final aPinned = provider.isConversationPinned(a.id);
      final bPinned = provider.isConversationPinned(b.id);
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return conversations;
  }

  void _openPrimaryAction() {
    // Keep the inline field for searching conversations already in this
    // account. The floating action is the broader network discovery entry
    // point for users, groups, and channels.
    context.push('/chat/discover');
  }

  Future<void> _removeConversation(Conversation conversation) async {
    final isDirect = conversation.type == ConversationType.dm;
    final actionLabel = switch (conversation.type) {
      ConversationType.dm => 'Remove from my chats',
      ConversationType.group => 'Leave circle',
      ConversationType.channel => 'Leave channel',
    };
    final targetName =
        conversation.otherUser?.effectiveDisplayName ??
        conversation.title ??
        'this conversation';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$actionLabel?'),
        content: Text(
          isDirect
              ? 'This removes "$targetName" only from your chat list. It does not delete the conversation for the other person. New messages will show it again.'
              : 'You will no longer see "$targetName" in your conversation list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final provider = context.read<MessagingProvider>();
    try {
      switch (conversation.type) {
        case ConversationType.dm:
          await provider.deleteConversation(conversation.id);
        case ConversationType.group:
          await provider.leaveGroup(conversation.id);
        case ConversationType.channel:
          await provider.unsubscribeFromChannel(conversation.id);
      }
      if (mounted) {
        NotificationService.showSuccess(context, '$actionLabel completed');
      }
    } catch (error) {
      if (mounted) {
        NotificationService.showError(context, 'Unable to $actionLabel');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final unreadNotifications = context.select<MessagingProvider, int>(
      (provider) => provider.unreadNotificationCount,
    );

    return GradientScaffold(
      useSafeArea: false,
      resizeToAvoidBottomInset: false,
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
        actions: [
          IconButton(
            tooltip: 'Updates',
            onPressed: () => context.go('/notifications'),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_none_rounded, color: colors.primary),
                if (unreadNotifications > 0)
                  Positioned(
                    right: -10,
                    top: -10,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: colors.error,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.surface, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadNotifications > 99
                            ? '99+'
                            : '$unreadNotifications',
                        style: TextStyle(
                          color: colors.onError,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButtonLocation: _ChatSearchFabLocation(
        keyboardInset: _windowKeyboardInset(context),
      ),
      floatingActionButton: HeroMode(
        // This action is persistent across provider updates; a Hero animation
        // here restarts whenever notifications or presence change and looks
        // like the search icon is flickering.
        enabled: false,
        child: FloatingActionButton(
          heroTag: 'chat-search-fab',
          onPressed: _openPrimaryAction,
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 6,
          child: const Icon(Icons.search_rounded, size: 30),
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _searchFocusNode.unfocus(),
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
      ),
    );
  }

  double _windowKeyboardInset(BuildContext context) {
    final view = View.of(context);
    return view.viewInsets.bottom / view.devicePixelRatio;
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
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (v) => setState(() => searchQuery = v),
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
                        suffixIcon: searchQuery.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => searchQuery = '');
                                },
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: colors.onSurfaceVariant,
                                ),
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
                actionLabel: null,
                onAction: null,
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
                        conv.lastMessage?.previewText ?? 'No messages yet';

                    item = ChatListItem(
                      user: other.copyWith(
                        lastMessage: lastMsgText,
                        timestamp: conv.updatedAt,
                        unreadCount: conv.unreadCount,
                      ),
                      lastMessage: conv.lastMessage,
                      time: _formatTime(conv.updatedAt),
                      isPinned: provider.isConversationPinned(conv.id),
                      onTap: () =>
                          context.push('/conversation/${conv.id}', extra: conv),
                      onPinToggle: () {
                        provider.toggleConversationPin(conv.id);
                      },
                      onRemove: () => _removeConversation(conv),
                    );
                  } else if (type == ConversationType.group) {
                    item = group_widgets.GroupListItem(
                      conversation: conv,
                      isPinned: provider.isConversationPinned(conv.id),
                      onTap: () =>
                          context.push('/conversation/${conv.id}', extra: conv),
                      onPinToggle: () {
                        provider.toggleConversationPin(conv.id);
                      },
                      onRemove: () => _removeConversation(conv),
                    );
                  } else if (type == ConversationType.channel) {
                    item = ChannelListItem(
                      conversation: conv,
                      isPinned: provider.isConversationPinned(conv.id),
                      onPinToggle: () {
                        provider.toggleConversationPin(conv.id);
                      },
                      onRemove: () => _removeConversation(conv),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }

                  // Provider updates are frequent (presence, receipts,
                  // realtime messages). Replaying an entrance animation on
                  // every notifyListeners makes the whole Chat home appear
                  // to flicker and can restart avatar image composition.
                  return KeyedSubtree(
                    key: ValueKey('${type.name}:${conv.id}'),
                    child: item,
                  );
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
        .where((c) => c.type == ConversationType.dm)
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
      final lastMsg = conv.lastMessage?.previewText.toLowerCase() ?? '';
      return title.contains(query) ||
          user.contains(query) ||
          lastMsg.contains(query);
    }

    final dmResults = _sortConversations(provider, dms.where(matches).toList());
    final groupResults = _sortConversations(
      provider,
      groups.where(matches).toList(),
    );
    final channelResults = _sortConversations(
      provider,
      channels.where(matches).toList(),
    );

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
                lastMessage: conv.lastMessage?.previewText ?? 'No messages yet',
                timestamp: conv.updatedAt,
                unreadCount: conv.unreadCount,
              ),
              lastMessage: conv.lastMessage,
              time: _formatTime(conv.updatedAt),
              isPinned: provider.isConversationPinned(conv.id),
              onTap: () =>
                  context.push('/conversation/${conv.id}', extra: conv),
              onPinToggle: () {
                provider.toggleConversationPin(conv.id);
              },
              onRemove: () => _removeConversation(conv),
            ),
          ),
        ],
        if (groupResults.isNotEmpty) ...[
          _SearchSectionHeader(title: 'Circles'),
          ...groupResults.map(
            (conv) => group_widgets.GroupListItem(
              conversation: conv,
              isPinned: provider.isConversationPinned(conv.id),
              onTap: () =>
                  context.push('/conversation/${conv.id}', extra: conv),
              onPinToggle: () {
                provider.toggleConversationPin(conv.id);
              },
              onRemove: () => _removeConversation(conv),
            ),
          ),
        ],
        if (channelResults.isNotEmpty) ...[
          _SearchSectionHeader(title: 'Channels'),
          ...channelResults.map(
            (conv) => ChannelListItem(
              conversation: conv,
              isPinned: provider.isConversationPinned(conv.id),
              onPinToggle: () {
                provider.toggleConversationPin(conv.id);
              },
              onRemove: () => _removeConversation(conv),
            ),
          ),
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
  final String? actionLabel;
  final VoidCallback? onAction;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.group_add_rounded),
                label: Text(actionLabel!),
              ),
            ],
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

/// Keeps the Chat Home search action fixed above the persistent GNav.
/// Flutter's default endFloat location can use keyboard insets and lift the
/// button when a search field receives focus.
class _ChatSearchFabLocation extends FloatingActionButtonLocation {
  final double keyboardInset;

  const _ChatSearchFabLocation({required this.keyboardInset});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final x =
        geometry.scaffoldSize.width -
        geometry.floatingActionButtonSize.width -
        16;
    final y =
        geometry.scaffoldSize.height -
        geometry.floatingActionButtonSize.height -
        125 +
        keyboardInset;
    return Offset(x, y.clamp(0.0, double.infinity).toDouble());
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
