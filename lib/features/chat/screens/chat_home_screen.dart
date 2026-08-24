import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:griot_cowrie/core/startup/app_startup_service.dart';
import 'package:griot_cowrie/core/services/notification_service.dart';
import 'package:griot_cowrie/core/services/navigation_scroll_service.dart';
import 'package:griot_cowrie/features/chat/providers/messaging_provider.dart';
import 'package:griot_cowrie/core/ui/scaffolds/gradient_scaffold.dart';
import 'package:griot_cowrie/features/chat/models/conversation_model.dart';
import 'package:griot_cowrie/features/chat/models/chat_group.dart';
import 'package:griot_cowrie/features/chat/models/chat_channel.dart';
import 'package:griot_cowrie/features/chat/widgets/chat_list_item.dart';
import 'package:griot_cowrie/features/chat/widgets/chat_loading.dart';
import 'package:griot_cowrie/features/chat/widgets/group_list_item.dart' as group_widgets;
import 'package:griot_cowrie/features/chat/widgets/channel_list_item.dart';

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

class _ChatHomeViewState extends State<_ChatHomeView> with SingleTickerProviderStateMixin {
  String searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  HubSection selectedHub = HubSection.direct;

  @override
  void initState() {
    super.initState();
    NavigationScrollService.instance.addListener(_onNavTap);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppStartupService>().initialize();
      final messaging = context.read<MessagingProvider>();
      messaging.loadConversations();
      messaging.loadRequests();
      messaging.loadFriends();
      messaging.loadGroups();
      messaging.loadChannels();
    });
  }

  @override
  void dispose() {
    NavigationScrollService.instance.removeListener(_onNavTap);
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onNavTap() {
    if (NavigationScrollService.instance.tappedIndex == 0) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
      }
    }
  }

  void _onSectionChanged(HubSection section) {
    setState(() {
      selectedHub = section;
      searchQuery = '';
    });
    _pageController.animateToPage(
      section.index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      selectedHub = HubSection.values[index];
      searchQuery = '';
    });
  }

  // ==============================================================
  // FILTERS
  // ==============================================================

  List<Conversation> get filteredConversations {
    final conversations = context.read<MessagingProvider>().conversations;
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return List<Conversation>.from(conversations);
    return conversations.where((conv) {
      final user = conv.otherUser;
      if (user == null) return false;
      return (user.displayName ?? '').toLowerCase().contains(query) ||
          user.walletAddress.toLowerCase().contains(query) ||
          (conv.lastMessage?.text ?? '').toLowerCase().contains(query);
    }).toList();
  }

  List<ChatGroup> get filteredGroups {
    final groups = context.read<MessagingProvider>().groups;
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return List<ChatGroup>.from(groups);
    return groups.where((group) => group.name.toLowerCase().contains(query)).toList();
  }

  List<ChatChannel> get filteredChannels {
    final channels = context.read<MessagingProvider>().channels;
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return List<ChatChannel>.from(channels);
    return channels.where((channel) => channel.name.toLowerCase().contains(query)).toList();
  }

  // ==============================================================
  // ACTIONS
  // ==============================================================

  void _openNewChat() => context.push('/chat/discover');
  void _openFriends() => context.push('/chat/friends');
  void _openRequests() => context.push('/chat/requests');

  void _handleFabAction() {
    if (selectedHub == HubSection.direct) {
      _openNewChat();
    } else if (selectedHub == HubSection.groups) {
      _showCreateGroupSheet();
    } else if (selectedHub == HubSection.channels) {
      _showCreateChannelSheet();
    }
  }

  void _showCreateGroupSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Create Group', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              TextField(controller: controller, decoration: const InputDecoration(labelText: 'Group Name', prefixIcon: Icon(Icons.groups_rounded))),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    try {
                      await context.read<MessagingProvider>().createGroup(name: name);
                      if (context.mounted) {
                        Navigator.pop(sheetContext);
                        NotificationService.showSuccess(context, 'Group "$name" created');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        NotificationService.showError(context, 'Failed to create group: $e');
                      }
                    }
                  },
                  child: const Text('Create Group', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateChannelSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Create Channel', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              TextField(controller: controller, decoration: const InputDecoration(labelText: 'Channel Name', prefixIcon: Icon(Icons.campaign_rounded))),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    try {
                      await context.read<MessagingProvider>().createChannel(name: name);
                      if (context.mounted) {
                        Navigator.pop(sheetContext);
                        NotificationService.showSuccess(context, 'Channel "$name" created');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        NotificationService.showError(context, 'Failed to create channel: $e');
                      }
                    }
                  },
                  child: const Text('Create Channel', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Chat', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _openNewChat, icon: const Icon(Icons.person_search_rounded), tooltip: 'Discover'),
          IconButton(onPressed: _openFriends, icon: const Icon(Icons.people_outline_rounded), tooltip: 'Friends'),
          Consumer<MessagingProvider>(
            builder: (context, provider, child) {
              final count = provider.pendingRequestCount;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(onPressed: _openRequests, icon: const Icon(Icons.notifications_none_rounded), tooltip: 'Requests'),
                  if (count > 0)
                    Positioned(
                      right: 10, top: 10,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: colors.error, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton(
          heroTag: 'chat_fab',
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          onPressed: _handleFabAction,
          child: Icon(_getFabIcon()),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: _buildContent()),
          Positioned(top: 8, left: 16, right: 16, child: _buildFloatingControls()),
        ],
      ),
    );
  }

  Widget _buildFloatingControls() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: TextField(
            onChanged: (v) => setState(() => searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search ${selectedHub.name}...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _ChatSectionSwitcher(
          selected: selectedHub,
          onChanged: _onSectionChanged,
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (searchQuery.isNotEmpty) {
      return _buildSearchResults();
    }

    return PageView(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      children: [
        _buildDirect(),
        _buildGroups(),
        _buildChannels(),
      ],
    );
  }

  Widget _buildSearchResults() {
    final direct = filteredConversations;
    final groups = filteredGroups;
    final channels = filteredChannels;

    if (direct.isEmpty && groups.isEmpty && channels.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results found',
        message: 'No chats, groups, or channels match your search.',
      );
    }

    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 120, 16, 100),
      physics: const BouncingScrollPhysics(),
      children: [
        if (direct.isNotEmpty) ...[
          _SearchSectionHeader(title: 'DIRECT CHATS', count: direct.length),
          ...direct.map((conv) {
            final other = conv.otherUser;
            if (other == null) return const SizedBox.shrink();
            return ChatListItem(
              user: other.copyWith(lastMessage: conv.lastMessage?.text ?? '', timestamp: conv.updatedAt, unreadCount: conv.unreadCount),
              time: _formatTime(conv.updatedAt),
              onTap: () => context.push('/conversation/${conv.id}'),
            );
          }),
          const SizedBox(height: 24),
        ],
        if (groups.isNotEmpty) ...[
          _SearchSectionHeader(title: 'GROUPS', count: groups.length),
          ...groups.map((g) => group_widgets.GroupListItem(group: g, onTap: () => context.push('/conversation/${g.id}'))),
          const SizedBox(height: 24),
        ],
        if (channels.isNotEmpty) ...[
          _SearchSectionHeader(title: 'CHANNELS', count: channels.length),
          ...channels.map((c) => ChannelListItem(channel: c)),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  IconData _getFabIcon() {
    switch (selectedHub) {
      case HubSection.direct: return Icons.chat_bubble_outline_rounded;
      case HubSection.groups: return Icons.group_add_rounded;
      case HubSection.channels: return Icons.campaign_rounded;
    }
  }

  Widget _buildDirect() {
    return Consumer<MessagingProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingConversations && provider.conversations.isEmpty) return const ChatLoading();
        final list = filteredConversations;
        if (list.isEmpty) return const _EmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'No direct chats', message: 'Search for people to start chatting.');
        return RefreshIndicator(
          onRefresh: provider.loadConversations,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: 120, bottom: 100),
            itemCount: list.length,
            separatorBuilder: (context, index) => Divider(height: 1, indent: 80, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
            itemBuilder: (context, index) {
              final conv = list[index];
              final other = conv.otherUser;
              if (other == null) return const SizedBox.shrink();
              return ChatListItem(
                user: other.copyWith(lastMessage: conv.lastMessage?.text ?? '', timestamp: conv.updatedAt, unreadCount: conv.unreadCount),
                time: _formatTime(conv.updatedAt),
                onTap: () => context.push('/conversation/${conv.id}'),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGroups() {
    return Consumer<MessagingProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingGroups && provider.groups.isEmpty) return const ChatLoading();
        final list = filteredGroups;
        if (list.isEmpty) return const _EmptyState(icon: Icons.groups_outlined, title: 'No groups', message: 'Create or join a group to start.');
        return RefreshIndicator(
          onRefresh: provider.loadGroups,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: 120, bottom: 100),
            itemCount: list.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
            itemBuilder: (context, index) => group_widgets.GroupListItem(group: list[index], onTap: () => context.push('/conversation/${list[index].id}')),
          ),
        );
      },
    );
  }

  Widget _buildChannels() {
    return Consumer<MessagingProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingChannels && provider.channels.isEmpty) return const ChatLoading();
        final list = filteredChannels;
        if (list.isEmpty) return const _EmptyState(icon: Icons.campaign_outlined, title: 'No channels', message: 'Subscribe to channels for updates.');
        return RefreshIndicator(
          onRefresh: provider.loadChannels,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: 120, bottom: 100),
            itemCount: list.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
            itemBuilder: (context, index) => ChannelListItem(channel: list[index]),
          ),
        );
      },
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

enum HubSection { direct, groups, channels }

class _ChatSectionSwitcher extends StatelessWidget {
  final HubSection selected;
  final ValueChanged<HubSection> onChanged;
  const _ChatSectionSwitcher({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1))),
      child: Row(
        children: HubSection.values.map((s) {
          final colors = Theme.of(context).colorScheme;
          final isSelected = selected == s;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(s),
              child: Container(
                decoration: BoxDecoration(color: isSelected ? colors.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Text(s.name.toUpperCase(), style: TextStyle(color: isSelected ? colors.onPrimary : colors.onSurfaceVariant, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _EmptyState({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SearchSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SearchSectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(color: colors.primary, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(
              count.toString(),
              style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
          const Expanded(child: Divider(indent: 16)),
        ],
      ),
    );
  }
}
