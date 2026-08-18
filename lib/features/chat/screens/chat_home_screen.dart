import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';

import '../models/chat_user.dart';
import '../models/message_request.dart';
import '../models/chat_group.dart';
import '../models/chat_channel.dart';

import '../widgets/chat_list_item.dart';
import '../widgets/group_list_item.dart' as group_widgets;
import '../widgets/channel_list_item.dart';
import '../widgets/message_request_card.dart' as request_widgets;

// ================================================================
// CHAT HOME SCREEN
// ================================================================

class ChatHomeScreen extends StatelessWidget {
  const ChatHomeScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatController>(
      create: (_) => ChatController()..initialize(),
      child: const _ChatHomeView(),
    );
  }
}

// ================================================================
// CHAT HOME VIEW
// ================================================================

class _ChatHomeView extends StatefulWidget {
  const _ChatHomeView();

  @override
  State<_ChatHomeView> createState() => _ChatHomeViewState();
}

class _ChatHomeViewState extends State<_ChatHomeView> {
  String searchQuery = '';

  ChatSection selectedSection = ChatSection.chats;

  // ==============================================================
  // FORMAT TIME
  // ==============================================================

  String formatTime(DateTime time) {
    final difference = DateTime.now().difference(time);

    if (difference.inMinutes < 1) {
      return 'now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }

    return '${time.day}/${time.month}';
  }

  // ==============================================================
  // FILTER CHATS
  // ==============================================================

  List<ChatUser> get filteredUsers {
    final controller = context.read<ChatController>();
    final users = controller.users;

    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return List<ChatUser>.from(users);
    }

    return users.where((user) {
      final displayName =
      (user.displayName ?? '').toLowerCase();

      final walletAddress =
      (user.walletAddress ?? '').toLowerCase();

      final lastMessage =
      (user.lastMessage ?? '').toLowerCase();

      return displayName.contains(query) ||
          walletAddress.contains(query) ||
          lastMessage.contains(query);
    }).toList();
  }

  // ==============================================================
  // FILTER GROUPS
  // ==============================================================

  List<ChatGroup> get filteredGroups {
    final List<ChatGroup> groups = [];

    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return groups;
    }

    return groups.where((group) {
      final name =
      (group.name ?? '').toLowerCase();

      final description =
      (group.description ?? '').toLowerCase();

      return name.contains(query) ||
          description.contains(query);
    }).toList();
  }

  // ==============================================================
  // FILTER CHANNELS
  // ==============================================================

  List<ChatChannel> get filteredChannels {
    final List<ChatChannel> channels = [];

    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return channels;
    }

    return channels.where((channel) {
      final name =
      (channel.name ?? '').toLowerCase();

      final description =
      (channel.description ?? '').toLowerCase();

      return name.contains(query) ||
          description.contains(query);
    }).toList();
  }

  // ==============================================================
  // ACCEPT REQUEST
  // ==============================================================

  Future<void> _acceptRequest(
      MessageRequest request,
      ) async {
    final controller =
    context.read<ChatController>();

    try {
      await controller.acceptRequest(request);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message request accepted',
          ),
        ),
      );
    } catch (_) {
      // Controller handles the underlying error.
    }
  }

  // ==============================================================
  // DECLINE REQUEST
  // ==============================================================

  Future<void> _declineRequest(
      MessageRequest request,
      ) async {
    final controller =
    context.read<ChatController>();

    try {
      await controller.declineRequest(request);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message request declined',
          ),
        ),
      );
    } catch (_) {
      // Controller handles the underlying error.
    }
  }

  // ==============================================================
  // MESSAGE REQUESTS
  // ==============================================================

  void _openMessageRequests() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Consumer<ChatController>(
          builder: (
              context,
              controller,
              child,
              ) {
            final requests = controller.requests
                .where(
                  (request) =>
              request.status ==
                  RequestStatus.pending,
            )
                .toList();

            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final textTheme = theme.textTheme;

            return Container(
              constraints: const BoxConstraints(
                maxHeight: 650,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius:
                const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.3),
                        borderRadius:
                        BorderRadius.circular(20),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Padding(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colorScheme
                                  .primary
                                  .withValues(
                                alpha: 0.10,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons
                                  .person_add_alt_1_rounded,
                              color:
                              colorScheme.primary,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Message Requests',
                                  style: textTheme
                                      .titleLarge
                                      ?.copyWith(
                                    fontWeight:
                                    FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(
                                  height: 2,
                                ),
                                Text(
                                  '${requests.length} pending',
                                  style: textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color: colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            onPressed: () {
                              Navigator.of(
                                sheetContext,
                              ).pop();
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    Expanded(
                      child: requests.isEmpty
                          ? Center(
                        child: Padding(
                          padding:
                          const EdgeInsets
                              .all(30),
                          child: Column(
                            mainAxisSize:
                            MainAxisSize.min,
                            children: [
                              Icon(
                                Icons
                                    .mark_email_read_outlined,
                                size: 48,
                                color: colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(
                                height: 12,
                              ),
                              Text(
                                'No message requests',
                                style: textTheme
                                    .titleMedium
                                    ?.copyWith(
                                  fontWeight:
                                  FontWeight
                                      .w600,
                                ),
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              Text(
                                'When someone wants to connect with you, '
                                    'their request will appear here.',
                                textAlign:
                                TextAlign.center,
                                style: textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  color: colorScheme
                                      .onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          : ListView.separated(
                        padding:
                        const EdgeInsets
                            .fromLTRB(
                          16,
                          8,
                          16,
                          24,
                        ),
                        itemCount:
                        requests.length,
                        separatorBuilder:
                            (context, index) =>
                        const SizedBox(
                          height: 10,
                        ),
                        itemBuilder:
                            (context, index) {
                          final request =
                          requests[index];

                          return request_widgets
                              .MessageRequestCard(
                            request: request,
                            onAccept: () {
                              _acceptRequest(
                                request,
                              );
                            },
                            onDecline: () {
                              _declineRequest(
                                request,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==============================================================
  // NEW CHAT
  // ==============================================================

  void _openNewChat() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _NewChatSheet(
          onSendRequest: (user) async {
            final controller =
            context.read<ChatController>();

            try {
              await controller.sendMessageRequest(
                senderWalletAddress:
                user.walletAddress ?? '',
                receiverWalletAddress:
                user.walletAddress ?? '',
              );

              if (!mounted) {
                return;
              }

              Navigator.of(sheetContext).pop();

              ScaffoldMessenger.of(context)
                  .showSnackBar(
                SnackBar(
                  content: Text(
                    'Message request sent to '
                        '${user.displayName ?? 'user'}',
                  ),
                ),
              );
            } catch (_) {
              // Controller handles the underlying error.
            }
          },
        );
      },
    );
  }

  // ==============================================================
  // CREATE GROUP
  // ==============================================================

  void _createGroup() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;

        final controller =
        TextEditingController();

        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext)
                .viewInsets
                .bottom +
                20,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius:
            const BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'Create Group',
                style:
                textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Create a private group for conversations.',
                style:
                textTheme.bodySmall?.copyWith(
                  color:
                  colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 18),

              TextField(
                controller: controller,
                decoration:
                const InputDecoration(
                  labelText: 'Group name',
                  prefixIcon:
                  Icon(Icons.group_rounded),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final name =
                    controller.text.trim();

                    if (name.isEmpty) {
                      return;
                    }

                    Navigator.of(
                      sheetContext,
                    ).pop();

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Group "$name" created',
                        ),
                      ),
                    );
                  },
                  child:
                  const Text('Create Group'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==============================================================
  // CREATE CHANNEL
  // ==============================================================

  void _createChannel() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;

        final controller =
        TextEditingController();

        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext)
                .viewInsets
                .bottom +
                20,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius:
            const BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'Create Channel',
                style:
                textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Create a channel for announcements and broadcasts.',
                style:
                textTheme.bodySmall?.copyWith(
                  color:
                  colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 18),

              TextField(
                controller: controller,
                decoration:
                const InputDecoration(
                  labelText: 'Channel name',
                  prefixIcon: Icon(
                    Icons.campaign_rounded,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final name =
                    controller.text.trim();

                    if (name.isEmpty) {
                      return;
                    }

                    Navigator.of(
                      sheetContext,
                    ).pop();

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Channel "$name" created',
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Create Channel',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==============================================================
  // SECTION ACTION
  // ==============================================================

  void _handleSectionAction() {
    if (selectedSection == ChatSection.chats) {
      _openNewChat();
      return;
    }

    if (selectedSection == ChatSection.groups) {
      _createGroup();
      return;
    }

    _createChannel();
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor:
      theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Chat',
          style:
          theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor:
        theme.scaffoldBackgroundColor,
        foregroundColor:
        colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          Consumer<ChatController>(
            builder: (
                context,
                controller,
                child,
                ) {
              final count =
                  controller.pendingRequestCount;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Message requests',
                    onPressed:
                    _openMessageRequests,
                    icon: const Icon(
                      Icons
                          .person_add_alt_1_rounded,
                    ),
                  ),

                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        constraints:
                        const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 4,
                        ),
                        alignment:
                        Alignment.center,
                        decoration:
                        BoxDecoration(
                          color:
                          colorScheme.primary,
                          shape:
                          BoxShape.circle,
                        ),
                        child: Text(
                          count > 9
                              ? '9+'
                              : count.toString(),
                          style: TextStyle(
                            color: colorScheme
                                .onPrimary,
                            fontSize: 9,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          IconButton(
            tooltip:
            selectedSection ==
                ChatSection.chats
                ? 'New chat'
                : selectedSection ==
                ChatSection.groups
                ? 'Create group'
                : 'Create channel',
            onPressed:
            _handleSectionAction,
            icon: Icon(
              selectedSection ==
                  ChatSection.chats
                  ? Icons.edit_square
                  : selectedSection ==
                  ChatSection.groups
                  ? Icons.group_add_rounded
                  : Icons.campaign_rounded,
            ),
          ),

          const SizedBox(width: 4),
        ],
      ),

      body: _buildFloatingBody(),

      floatingActionButtonLocation:
      FloatingActionButtonLocation.endFloat,

      floatingActionButton: Padding(
        padding:
        const EdgeInsets.only(bottom: 75),
        child: FloatingActionButton(
          heroTag: 'chat_section_fab',
          tooltip:
          selectedSection ==
              ChatSection.chats
              ? 'New chat'
              : selectedSection ==
              ChatSection.groups
              ? 'Create group'
              : 'Create channel',
          backgroundColor:
          colorScheme.primary,
          foregroundColor:
          colorScheme.onPrimary,
          elevation: 3,
          onPressed:
          _handleSectionAction,
          child: Icon(
            selectedSection ==
                ChatSection.chats
                ? Icons.edit_rounded
                : selectedSection ==
                ChatSection.groups
                ? Icons.group_add_rounded
                : Icons.campaign_rounded,
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // FLOATING BODY
  // ==============================================================

  Widget _buildFloatingBody() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _buildSectionContent(),
        ),

        Positioned(
          top: 8,
          left: 12,
          right: 12,
          child: _buildFloatingControls(),
        ),
      ],
    );
  }

  // ==============================================================
  // FLOATING CONTROLS
  // ==============================================================

  Widget _buildFloatingControls() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: colorScheme.surface
                .withValues(alpha: 0.96),
            borderRadius:
            BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline
                  .withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow
                    .withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
            textAlignVertical:
            TextAlignVertical.center,
            decoration: InputDecoration(
              hintText:
              selectedSection ==
                  ChatSection.chats
                  ? 'Search chats or people'
                  : selectedSection ==
                  ChatSection.groups
                  ? 'Search groups'
                  : 'Search channels',
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 21,
              ),
              suffixIcon:
              searchQuery.isNotEmpty
                  ? IconButton(
                onPressed: () {
                  setState(() {
                    searchQuery = '';
                  });
                },
                icon: const Icon(
                  Icons.close_rounded,
                  size: 19,
                ),
              )
                  : null,
              filled: true,
              fillColor: Colors.transparent,
              contentPadding:
              const EdgeInsets.symmetric(
                horizontal: 14,
              ),
              border: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder:
              OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder:
              OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: colorScheme.primary,
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        _ChatSectionSwitcher(
          selectedSection:
          selectedSection,
          onChanged: (section) {
            setState(() {
              selectedSection = section;
              searchQuery = '';
            });
          },
        ),
      ],
    );
  }

  // ==============================================================
  // SECTION CONTENT
  // ==============================================================

  Widget _buildSectionContent() {
    if (selectedSection ==
        ChatSection.chats) {
      return _buildChats();
    }

    if (selectedSection ==
        ChatSection.groups) {
      return _buildGroups();
    }

    return _buildChannels();
  }

  // ==============================================================
  // CHATS
  // ==============================================================

  Widget _buildChats() {
    return Consumer<ChatController>(
      builder: (
          context,
          controller,
          child,
          ) {
        if (controller.isLoading &&
            controller.users.isEmpty) {
          return const Center(
            child:
            CircularProgressIndicator(),
          );
        }

        if (controller.error != null &&
            controller.users.isEmpty) {
          return _EmptyState(
            icon:
            Icons.error_outline_rounded,
            title:
            'Unable to load chats',
            message:
            controller.error!,
          );
        }

        final filtered =
            filteredUsers;

        if (filtered.isEmpty) {
          return const _EmptyState(
            icon:
            Icons.search_off_rounded,
            title:
            'No chats found',
            message:
            'Try searching for another chat or start a new one.',
          );
        }

        return RefreshIndicator(
          onRefresh:
          controller.refresh,
          child: ListView.separated(
            padding:
            const EdgeInsets.only(
              top: 116,
              bottom: 170,
            ),
            physics:
            const BouncingScrollPhysics(),
            itemCount:
            filtered.length,
            separatorBuilder:
                (context, index) =>
                Divider(
                  height: 1,
                  indent: 80,
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.12),
                ),
            itemBuilder:
                (context, index) {
              final user =
              filtered[index];

              return ChatListItem(
                user: user,
                time:
                formatTime(
                  user.timestamp,
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ==============================================================
  // GROUPS
  // ==============================================================

  Widget _buildGroups() {
    final groups =
        filteredGroups;

    if (groups.isEmpty) {
      return const _EmptyState(
        icon:
        Icons.groups_outlined,
        title:
        'No groups found',
        message:
        'Create a group or search for another group.',
      );
    }

    return ListView.separated(
      padding:
      const EdgeInsets.only(
        top: 116,
        bottom: 170,
      ),
      physics:
      const BouncingScrollPhysics(),
      itemCount:
      groups.length,
      separatorBuilder:
          (context, index) =>
      const Divider(
        height: 1,
        indent: 82,
      ),
      itemBuilder:
          (context, index) {
        final group =
        groups[index];

        return group_widgets
            .GroupListItem(
          group: group,
        );
      },
    );
  }

  // ==============================================================
  // CHANNELS
  // ==============================================================

  Widget _buildChannels() {
    final channels =
        filteredChannels;

    if (channels.isEmpty) {
      return const _EmptyState(
        icon:
        Icons.campaign_outlined,
        title:
        'No channels found',
        message:
        'Create a channel or search for another channel.',
      );
    }

    return ListView.separated(
      padding:
      const EdgeInsets.only(
        top: 116,
        bottom: 170,
      ),
      physics:
      const BouncingScrollPhysics(),
      itemCount:
      channels.length,
      separatorBuilder:
          (context, index) =>
      const Divider(
        height: 1,
        indent: 82,
      ),
      itemBuilder:
          (context, index) {
        return ChannelListItem(
          channel: channels[index],
        );
      },
    );
  }
}

// ================================================================
// CHAT SECTION ENUM
// ================================================================

enum ChatSection {
  chats,
  groups,
  channels,
}

// ================================================================
// FLOATING SECTION SWITCHER
// ================================================================

class _ChatSectionSwitcher
    extends StatelessWidget {
  final ChatSection selectedSection;
  final ValueChanged<ChatSection> onChanged;

  const _ChatSectionSwitcher({
    required this.selectedSection,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    return Container(
      height: 50,
      padding:
      const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surface
            .withValues(alpha: 0.96),
        borderRadius:
        BorderRadius.circular(17),
        border: Border.all(
          color: colorScheme.outline
              .withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow
                .withValues(alpha: 0.07),
            blurRadius: 14,
            offset:
            const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SectionButton(
              label: 'Chats',
              icon: Icons
                  .chat_bubble_outline_rounded,
              selected:
              selectedSection ==
                  ChatSection.chats,
              onTap: () {
                onChanged(
                  ChatSection.chats,
                );
              },
            ),
          ),

          Expanded(
            child: _SectionButton(
              label: 'Groups',
              icon:
              Icons.groups_outlined,
              selected:
              selectedSection ==
                  ChatSection.groups,
              onTap: () {
                onChanged(
                  ChatSection.groups,
                );
              },
            ),
          ),

          Expanded(
            child: _SectionButton(
              label: 'Channels',
              icon: Icons
                  .campaign_outlined,
              selected:
              selectedSection ==
                  ChatSection.channels,
              onTap: () {
                onChanged(
                  ChatSection.channels,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// SECTION BUTTON
// ================================================================

class _SectionButton
    extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SectionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme =
        theme.colorScheme;
    final textTheme =
        theme.textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(13),
        child: AnimatedContainer(
          duration:
          const Duration(
            milliseconds: 180,
          ),
          curve:
          Curves.easeOutCubic,
          alignment:
          Alignment.center,
          decoration:
          BoxDecoration(
            color: selected
                ? colorScheme
                .surfaceContainerHighest
                : Colors.transparent,
            borderRadius:
            BorderRadius.circular(
              13,
            ),
          ),
          child: Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? colorScheme.primary
                    : colorScheme
                    .onSurfaceVariant,
              ),

              const SizedBox(
                width: 6,
              ),

              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: textTheme
                      .labelMedium
                      ?.copyWith(
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: selected
                        ? colorScheme
                        .onSurface
                        : colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// EMPTY STATE
// ================================================================

class _EmptyState
    extends StatelessWidget {
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
    final colorScheme =
        Theme.of(context).colorScheme;

    final textTheme =
        Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(30),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 46,
              color: colorScheme
                  .onSurfaceVariant,
            ),

            const SizedBox(
              height: 12,
            ),

            Text(
              title,
              style: textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight:
                FontWeight.w600,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              message,
              textAlign:
              TextAlign.center,
              style: textTheme
                  .bodySmall
                  ?.copyWith(
                color: colorScheme
                    .onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// NEW CHAT SHEET
// ================================================================

class _NewChatSheet
    extends StatefulWidget {
  final Future<void> Function(
      ChatUser user,
      ) onSendRequest;

  const _NewChatSheet({
    required this.onSendRequest,
  });

  @override
  State<_NewChatSheet> createState() =>
      _NewChatSheetState();
}

class _NewChatSheetState
    extends State<_NewChatSheet> {
  final TextEditingController
  searchController =
  TextEditingController();

  List<ChatUser> results = [];

  bool isSearching = false;

  // ==============================================================
  // DISPOSE
  // ==============================================================

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ==============================================================
  // SEARCH
  // ==============================================================

  Future<void> _search(
      String value,
      ) async {
    final query =
    value.trim();

    if (query.isEmpty) {
      setState(() {
        results = [];
        isSearching = false;
      });

      return;
    }

    setState(() {
      isSearching = true;
    });

    final controller =
    context.read<ChatController>();

    final found =
    await controller.searchUsers(
      query,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      results =
      List<ChatUser>.from(found);
      isSearching = false;
    });
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme =
        theme.colorScheme;
    final textTheme =
        theme.textTheme;

    return Container(
      height:
      MediaQuery.of(context)
          .size
          .height *
          0.72,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius:
        const BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(
              height: 10,
            ),

            Container(
              width: 40,
              height: 4,
              decoration:
              BoxDecoration(
                color: colorScheme
                    .onSurfaceVariant
                    .withValues(
                  alpha: 0.3,
                ),
                borderRadius:
                BorderRadius.circular(
                  20,
                ),
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            Padding(
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 20,
              ),
              child: Row(
                children: [
                  Text(
                    'New Chat',
                    style: textTheme
                        .titleLarge
                        ?.copyWith(
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),

                  const Spacer(),

                  IconButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop();
                    },
                    icon: const Icon(
                      Icons
                          .close_rounded,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding:
              const EdgeInsets
                  .fromLTRB(
                16,
                4,
                16,
                12,
              ),
              child: SizedBox(
                height: 46,
                child: TextField(
                  controller:
                  searchController,
                  autofocus: true,
                  onChanged: _search,
                  decoration:
                  InputDecoration(
                    hintText:
                    'Search name or wallet address',
                    prefixIcon:
                    const Icon(
                      Icons
                          .search_rounded,
                    ),
                    filled: true,
                    fillColor:
                    colorScheme
                        .surfaceContainerHighest
                        .withValues(
                      alpha: 0.5,
                    ),
                    border:
                    OutlineInputBorder(
                      borderRadius:
                      BorderRadius
                          .circular(
                        15,
                      ),
                      borderSide:
                      BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: isSearching
                  ? const Center(
                child:
                CircularProgressIndicator(),
              )
                  : results.isEmpty
                  ? const _EmptyState(
                icon: Icons
                    .person_search_rounded,
                title:
                'Find someone on Griot',
                message:
                'Search by name or wallet address to start a conversation.',
              )
                  : ListView
                  .separated(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 16,
                ),
                itemCount:
                results.length,
                separatorBuilder:
                    (context,
                    index) =>
                const Divider(
                  height: 1,
                ),
                itemBuilder:
                    (context,
                    index) {
                  final user =
                  results[
                  index];

                  final profileUrl =
                      user.profileUrl ??
                          '';

                  return ListTile(
                    leading:
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                      colorScheme
                          .surfaceContainerHighest,
                      backgroundImage:
                      profileUrl
                          .isNotEmpty
                          ? NetworkImage(
                        profileUrl,
                      )
                          : null,
                      child: profileUrl
                          .isEmpty
                          ? Icon(
                        Icons
                            .person_rounded,
                        color: colorScheme
                            .onSurfaceVariant,
                      )
                          : null,
                    ),

                    title: Text(
                      user.displayName ??
                          'Unknown user',
                      style: textTheme
                          .bodyLarge
                          ?.copyWith(
                        fontWeight:
                        FontWeight
                            .w700,
                      ),
                    ),

                    subtitle:
                    Text(
                      user.walletAddress ??
                          '',
                      overflow:
                      TextOverflow
                          .ellipsis,
                    ),

                    trailing:
                    ElevatedButton(
                      onPressed:
                          () async {
                        await widget
                            .onSendRequest(
                          user,
                        );
                      },
                      child:
                      const Text(
                        'Request',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}