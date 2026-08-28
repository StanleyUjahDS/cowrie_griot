import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_svg/flutter_svg.dart';
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
import 'package:griot_cowrie/features/users/models/user_model.dart';
import 'package:griot_cowrie/features/users/services/user_api_service.dart';
import 'package:griot_cowrie/core/ui/widgets/griot_loader.dart';

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
  final ScrollController _scrollController = ScrollController();
  HubSection selectedHub = HubSection.direct;
  
  List<UserModel> _globalUserResults = [];
  bool _isGlobalSearching = false;
  Timer? _globalSearchTimer;

  @override
  void initState() {
    super.initState();
    NavigationScrollService.instance.addListener(_onNavTap);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messaging = context.read<MessagingProvider>();
      // CONTRACT: Initial load if list is empty
      if (messaging.conversations.isEmpty) {
        messaging.loadConversations();
      }
      if (messaging.receivedRequests.isEmpty && messaging.sentRequests.isEmpty) {
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
    _scrollController.dispose();
    _globalSearchTimer?.cancel();
    super.dispose();
  }

  void _onNavTap() {
    if (NavigationScrollService.instance.tappedIndex == 0) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
      }
    }
  }

  // ==============================================================
  // FILTERS
  // ==============================================================

  List<Conversation> get filteredConversations {
    final provider = context.read<MessagingProvider>();
    final conversations = provider.conversations;
    final query = searchQuery.trim().toLowerCase();
    
    // 0. Hide blocked users
    final visibleConversations = conversations.where((conv) {
      if (conv.type == ConversationType.dm && conv.otherUser != null) {
        return !provider.blockedUserIds.contains(conv.otherUser!.id);
      }
      return true;
    }).toList();
    
    // 1. Filter by Section
    final sectionFiltered = visibleConversations.where((conv) {
      if (selectedHub == HubSection.direct) return conv.type == ConversationType.dm;
      if (selectedHub == HubSection.groups) return conv.type == ConversationType.group;
      if (selectedHub == HubSection.channels) return conv.type == ConversationType.channel;
      return true;
    }).toList();

    // 2. Filter by Query
    if (query.isEmpty) return sectionFiltered;
    
    return sectionFiltered.where((conv) {
      final title = conv.title?.toLowerCase() ?? '';
      final user = conv.otherUser?.effectiveDisplayName.toLowerCase() ?? '';
      final lastMsg = conv.lastMessage?.text.toLowerCase() ?? '';
      
      return title.contains(query) || user.contains(query) || lastMsg.contains(query);
    }).toList();
  }

  // ==============================================================
  // ACTIONS
  // ==============================================================

  void _openNewChat() => context.push('/chat/discover');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Messenger'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        leadingWidth: 78,
        leading: GestureDetector(
          onTap: () => Scaffold.of(context).openDrawer(),
          child: Center(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: colors.surface.withValues(alpha: 0.95),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: SvgPicture.asset(
                  'assets/cowrie_images/cowriesvg.svg',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        actions: const [
          SizedBox(width: 16),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: FloatingActionButton(
          onPressed: _openNewChat,
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 6,
          child: const Icon(Icons.add_rounded, size: 32),
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

  // _buildDrawer was here, but we've removed it as it's now in the shell.
  // We've also removed _drawerTile.

  Widget _buildFloatingControls() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Search Row
                  SizedBox(
                    height: 48,
                    child: TextField(
                      onChanged: (v) {
                        setState(() => searchQuery = v);
                        _onSearchChanged(v);
                      },
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search ${selectedHub.name}...',
                        hintStyle: TextStyle(
                            color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600),
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 22, color: colors.primary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 2. Switcher Row
                  _ChatSectionSwitcher(
                    selected: selectedHub,
                    onChanged: (section) => setState(() => selectedHub = section),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onSearchChanged(String v) {
    _globalSearchTimer?.cancel();
    if (v.trim().length < 2) {
      setState(() {
        _globalUserResults = [];
        _isGlobalSearching = false;
      });
      return;
    }

    _globalSearchTimer = Timer(const Duration(milliseconds: 500), () {
      _performGlobalSearch(v.trim());
    });
  }

  Future<void> _performGlobalSearch(String query) async {
    if (!mounted) return;
    setState(() => _isGlobalSearching = true);
    try {
      final results = await context.read<UserApiService>().searchUsers(query);
      if (!mounted) return;
      setState(() {
        _globalUserResults = results;
        _isGlobalSearching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isGlobalSearching = false);
    }
  }

  Widget _buildContent() {
    if (searchQuery.isNotEmpty) {
      return _buildSearchResults();
    }

    return _buildUnifiedConversations();
  }

  Widget _buildUnifiedConversations() {
    return Consumer<MessagingProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingConversations && provider.conversations.isEmpty) return const ChatLoading();
        
        final list = filteredConversations;
        
        if (list.isEmpty) {
          String emptyTitle = '';
          String emptyMsg = '';
          IconData icon = Icons.chat_bubble_outline_rounded;

          switch (selectedHub) {
            case HubSection.direct:
              emptyTitle = 'Start a Story';
              emptyMsg = 'Connect with friends and start your first decentralized chat.';
              icon = Icons.chat_bubble_outline_rounded;
              break;
            case HubSection.groups:
              emptyTitle = 'Private Circles';
              emptyMsg = 'Create a secure group for your community or inner circle.';
              icon = Icons.groups_rounded;
              break;
            case HubSection.channels:
              emptyTitle = 'Broadcasting';
              emptyMsg = 'Follow channels to stay updated with the latest Griot stories.';
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
          onRefresh: provider.loadConversations,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(0, 140, 0, 120),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final conv = list[index];
              final type = conv.type;
              
              if (type == ConversationType.dm) {
                final other = conv.otherUser;
                if (other == null) return const SizedBox.shrink();
                return ChatListItem(
                  user: other.copyWith(
                    lastMessage: conv.lastMessage?.text ?? '', 
                    timestamp: conv.updatedAt, 
                    unreadCount: conv.unreadCount
                  ),
                  time: _formatTime(conv.updatedAt),
                  onTap: () => context.push('/conversation/${conv.id}'),
                  onAvatarTap: () => context.push('/user/profile', extra: other),
                );
              } else if (type == ConversationType.group) {
                return group_widgets.GroupListItem(
                  group: ChatGroup(
                    id: conv.id,
                    name: conv.title ?? 'Unknown Group',
                    description: '',
                    ownerWalletAddress: '',
                    imageUrl: conv.avatarUrl,
                    lastMessage: conv.lastMessage?.text ?? '',
                    lastMessageAt: conv.updatedAt,
                    memberCount: 0,
                    unreadCount: conv.unreadCount,
                  ),
                  onTap: () => context.push('/conversation/${conv.id}'),
                );
              } else if (type == ConversationType.channel) {
                return ChannelListItem(
                  channel: ChatChannel(
                    id: conv.id,
                    name: conv.title ?? 'Unknown Channel',
                    imageUrl: conv.avatarUrl,
                    description: '',
                    subscriberCount: 0,
                    verified: false,
                    lastPost: conv.lastMessage?.text ?? '',
                    timestamp: conv.updatedAt,
                  ),
                );
              }
              
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    final list = filteredConversations;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 120, 0, 100),
      children: [
        if (list.isNotEmpty) ...[
          _SearchSectionHeader(title: 'Conversations'),
          ...list.map((conv) {
            if (conv.type == ConversationType.dm) {
              final other = conv.otherUser;
              if (other == null) return const SizedBox.shrink();
              return ChatListItem(
                user: other.copyWith(lastMessage: conv.lastMessage?.text ?? '', timestamp: conv.updatedAt, unreadCount: conv.unreadCount),
                time: _formatTime(conv.updatedAt),
                onTap: () => context.push('/conversation/${conv.id}'),
                onAvatarTap: () => context.push('/user/profile', extra: other),
              );
            } else if (conv.type == ConversationType.group) {
              return group_widgets.GroupListItem(
                group: ChatGroup(
                  id: conv.id,
                  name: conv.title ?? 'Unknown Group',
                  description: '',
                  ownerWalletAddress: '',
                  imageUrl: conv.avatarUrl,
                  lastMessage: conv.lastMessage?.text ?? '',
                  lastMessageAt: conv.updatedAt,
                  memberCount: 0,
                  unreadCount: conv.unreadCount,
                ),
                onTap: () => context.push('/conversation/${conv.id}'),
              );
            } else if (conv.type == ConversationType.channel) {
              return ChannelListItem(
                channel: ChatChannel(
                  id: conv.id,
                  name: conv.title ?? 'Unknown Channel',
                  imageUrl: conv.avatarUrl,
                  description: '',
                  subscriberCount: 0,
                  verified: false,
                  lastPost: conv.lastMessage?.text ?? '',
                  timestamp: conv.updatedAt,
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          const SizedBox(height: 24),
        ],

        _SearchSectionHeader(title: 'Discover Users'),
        if (_isGlobalSearching)
          Padding(padding: EdgeInsets.all(32), child: Center(child: GriotLoader(size: 32)))
        else if (_globalUserResults.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No new users found.', style: TextStyle(color: Colors.grey, fontSize: 13))),
          )
        else
          ..._globalUserResults.map((UserModel user) => ListTile(
            onTap: () => context.push('/user/profile', extra: user),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child: user.avatarUrl == null 
                ? SvgPicture.asset('assets/coins_logo/hbadger_logo.svg')
                : null,
            ),
            title: Text(user.displayName ?? user.username ?? 'Griot User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text('@${user.username ?? (user.walletAddress.length > 8 ? "${user.walletAddress.substring(0, 3)}...${user.walletAddress.substring(user.walletAddress.length - 3)}" : user.walletAddress)}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
          )),
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
          
          switch(s) {
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
            child: GestureDetector(
              onTap: () => onChanged(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon, 
                      size: 16, 
                      color: isSelected ? colors.onPrimary : colors.onSurfaceVariant.withValues(alpha: 0.4)
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? colors.onPrimary : colors.onSurfaceVariant.withValues(alpha: 0.6),
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
