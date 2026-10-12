import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:griot_cowrie/features/users/providers/user_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../../core/ui/widgets/griot_loader.dart';
import '../../../../core/services/notification_service.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/conversation_model.dart';
import '../providers/messaging_provider.dart';
import '../services/messaging_api_service.dart';
import '../services/realtime_call_service.dart';
import '../../../../core/network/api_client.dart';
import '../widgets/chatting/attachment_sheet.dart';
import '../widgets/chatting/media_preview_sheet.dart';
import '../widgets/chatting/day_separator.dart';
import '../widgets/chatting/message_bubble.dart';
import '../widgets/chatting/reply_swipe.dart';
import '../widgets/chatting/message_input.dart';
import '../widgets/chatting/pinned_messages_banner.dart';
import '../widgets/chatting/tip_sheet.dart';
import '../widgets/chatting/voice_recording_sheet.dart';
import '../widgets/conversation_campfire_button.dart';
import '../widgets/conversation_call_button.dart';
import '../widgets/friend_selector_sheet.dart';
import '../widgets/chat_wallpaper.dart';

class GroupChatScreen extends StatefulWidget {
  final String conversationId;
  final Conversation? initialConversation;
  final String? initialMessageId;

  const GroupChatScreen({
    super.key,
    required this.conversationId,
    this.initialConversation,
    this.initialMessageId,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};

  Conversation? _conversation;
  Map<String, ChatUser> _groupMembers = <String, ChatUser>{};
  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;
  Timer? _typingTimer;
  Timer? _highlightTimer;
  String? _highlightedMessageId;
  bool _lastTypingState = false;
  bool _showScrollToBottom = false;
  Map<String, dynamic>? _activeGroupCall;
  Timer? _activeCallRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MessagingProvider>().markNotificationsSeen();
    });
    if (widget.initialMessageId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _jumpToMessage(widget.initialMessageId!);
      });
    }
    controller.addListener(_onComposerChanged);
    scrollController.addListener(_onScrollChanged);
    _conversation = widget.initialConversation;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<MessagingProvider>(context, listen: false);
      _initConversation();
      _loadGroupMembers();
      _loadActiveGroupCall();
      _activeCallRefreshTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _loadActiveGroupCall(),
      );
      provider.loadTipConfig();
      if (widget.initialMessageId == null) {
        Future.delayed(
          const Duration(milliseconds: 700),
          _positionAtUnreadBoundary,
        );
      }
    });
  }

  void _positionAtUnreadBoundary() {
    if (!mounted || !scrollController.hasClients || _conversation == null) {
      return;
    }
    final unread = _conversation!.unreadCount;
    if (unread <= 0) return;
    final target = (unread * 76.0).clamp(
      0.0,
      scrollController.position.maxScrollExtent,
    );
    scrollController.jumpTo(target);
    if (!_showScrollToBottom) setState(() => _showScrollToBottom = true);
  }

  Future<void> _loadActiveGroupCall() async {
    try {
      final calls = await RealtimeCallService(
        context.read<ApiClient>(),
      ).activeCalls();
      final match = calls.where((call) {
        final conversationId =
            (call['conversationId'] ?? call['conversation_id'])?.toString();
        final contextType = (call['contextType'] ?? call['context_type'])
            ?.toString();
        final status = (call['status'] ?? '').toString().toLowerCase();
        return conversationId == widget.conversationId &&
            contextType == 'group' &&
            (status.isEmpty || status == 'ringing' || status == 'active');
      }).firstOrNull;
      if (mounted) setState(() => _activeGroupCall = match);
    } catch (_) {}
  }

  Future<void> _initConversation() async {
    final provider = Provider.of<MessagingProvider>(context, listen: false);
    provider.joinConversation(widget.conversationId);
    provider.loadMessages(widget.conversationId, refresh: true);
    provider.loadPinnedMessages(widget.conversationId);

    if (_conversation == null) {
      if (!mounted) return;
      final apiService = context.read<MessagingApiService>();
      try {
        final conversation = await apiService.getGroup(widget.conversationId);
        if (mounted) {
          setState(() => _conversation = conversation);
        }
      } catch (e) {
        debugPrint('Failed to load group details: $e');
      }
    }
  }

  Future<void> _loadGroupMembers() async {
    final members = await context
        .read<MessagingProvider>()
        .getConversationMembers(widget.conversationId, isGroup: true);
    if (!mounted) return;
    setState(() {
      _groupMembers = {for (final member in members) member.id: member};
    });
  }

  @override
  void dispose() {
    _activeCallRefreshTimer?.cancel();
    _typingTimer?.cancel();
    _highlightTimer?.cancel();
    try {
      final provider = context.read<MessagingProvider>();
      provider.setTyping(widget.conversationId, false);
      provider.leaveConversation(widget.conversationId);
    } catch (e) {
      debugPrint('MessagingProvider was already disposed: $e');
    }
    controller.removeListener(_onComposerChanged);
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _onComposerChanged() {
    final text = controller.text.trim();
    final isTyping = text.isNotEmpty;
    if (isTyping != _lastTypingState) {
      _lastTypingState = isTyping;
      context.read<MessagingProvider>().setTyping(
        widget.conversationId,
        isTyping,
      );
    }
    _typingTimer?.cancel();
    if (isTyping) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _lastTypingState) {
          _lastTypingState = false;
          context.read<MessagingProvider>().setTyping(
            widget.conversationId,
            false,
          );
        }
      });
    }
    if (mounted) setState(() {});
  }

  void _onScrollChanged() {
    if (!scrollController.hasClients) return;
    final bool show = scrollController.offset > 400;
    if (show != _showScrollToBottom) {
      setState(() => _showScrollToBottom = show);
    }
  }

  bool get _hasText => controller.text.trim().isNotEmpty;

  String _typingLabel(Set<String> typingUserIds) {
    final names = typingUserIds
        .map((id) => _groupMembers[id]?.effectiveDisplayName)
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .toList();
    if (names.isEmpty) {
      return typingUserIds.length == 1
          ? 'Someone is typing...'
          : '${typingUserIds.length} people are typing...';
    }
    if (names.length == 1) return '${names.first} is typing...';
    if (names.length == 2) return '${names[0]} and ${names[1]} are typing...';
    return '${names.take(2).join(', ')}, and ${names.length - 2} others are typing...';
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _openSenderProfile(String userId) async {
    try {
      final user = await context
          .read<UserProvider>()
          .userApiService
          .getUserById(userId);
      if (mounted) context.push('/user/profile', extra: user);
    } catch (_) {
      if (mounted) {
        NotificationService.showError(context, 'Unable to open this profile');
      }
    }
  }

  Future<void> _jumpToMessage(String messageId) async {
    final provider = context.read<MessagingProvider>();
    for (var attempt = 0; attempt < 3; attempt++) {
      final messages = provider.getMessagesForConversation(
        widget.conversationId,
      );
      final index = messages.indexWhere((item) => item.id == messageId);
      if (index >= 0) {
        _highlightTimer?.cancel();
        if (mounted) setState(() => _highlightedMessageId = messageId);

        final targetContext = _messageKeys[messageId]?.currentContext;
        if (targetContext != null && targetContext.mounted) {
          await Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: 0.45,
          );
        } else if (scrollController.hasClients) {
          final estimated = (index * 96.0)
              .clamp(
                scrollController.position.minScrollExtent,
                scrollController.position.maxScrollExtent,
              )
              .toDouble();
          await scrollController.animateTo(
            estimated,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
          final builtContext = _messageKeys[messageId]?.currentContext;
          if (builtContext != null && builtContext.mounted) {
            await Scrollable.ensureVisible(
              builtContext,
              duration: const Duration(milliseconds: 180),
              alignment: 0.45,
            );
          }
        }

        _highlightTimer = Timer(const Duration(seconds: 2), () {
          if (mounted && _highlightedMessageId == messageId) {
            setState(() => _highlightedMessageId = null);
          }
        });
        return;
      }
      await provider.loadMessages(widget.conversationId);
    }

    if (mounted) {
      NotificationService.showInfo(
        context,
        'The original message is no longer available.',
      );
    }
  }

  Future<void> _showMessageSearch() async {
    final provider = context.read<MessagingProvider>();
    final messages = provider.getMessagesForConversation(widget.conversationId);
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var query = '';
        var visibleCount = 40;
        return StatefulBuilder(
          builder: (context, setState) {
            final results = messages
                .where(
                  (m) =>
                      m.text.toLowerCase().contains(query.toLowerCase().trim()),
                )
                .toList(growable: false);
            return Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('Search messages'),
                  leading: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      TextField(
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          hintText: 'Search this group',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (value) => setState(() {
                          query = value;
                          visibleCount = 40;
                        }),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: query.trim().isEmpty
                            ? const Center(
                                child: Text('Search messages in this group'),
                              )
                            : results.isEmpty
                            ? const Center(child: Text('No messages found'))
                            : ListView.builder(
                                itemCount:
                                    results.take(visibleCount).length +
                                    (results.length > visibleCount ? 1 : 0),
                                itemBuilder: (_, index) {
                                  if (index >= visibleCount) {
                                    return Center(
                                      child: TextButton.icon(
                                        onPressed: () => setState(() {
                                          visibleCount += 40;
                                        }),
                                        icon: const Icon(
                                          Icons.expand_more_rounded,
                                        ),
                                        label: Text(
                                          'View more (${results.length - visibleCount} remaining)',
                                        ),
                                      ),
                                    );
                                  }
                                  final result = results[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: ListTile(
                                      leading: const Icon(Icons.forum_outlined),
                                      title: Text(
                                        result.text,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        '${result.createdAt.hour.toString().padLeft(2, '0')}:${result.createdAt.minute.toString().padLeft(2, '0')}',
                                      ),
                                      onTap: () => Navigator.pop(
                                        dialogContext,
                                        result.id,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (selected != null && mounted) await _jumpToMessage(selected);
  }

  Future<void> _sendMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty || text.length > 4000) return;

    final provider = Provider.of<MessagingProvider>(context, listen: false);

    if (_editingMessage != null) {
      final message = _editingMessage!;
      if (text == message.text) {
        _cancelEditing();
        return;
      }
      try {
        await provider.editMessage(message.id, text);
        if (mounted) {
          _cancelEditing();
          NotificationService.showSuccess(context, 'Message edited');
        }
      } catch (_) {
        if (mounted) {
          NotificationService.showError(context, 'Could not edit message');
        }
      }
      return;
    }

    controller.clear();
    final replyId = _replyingTo?.id;
    setState(() => _replyingTo = null);

    try {
      await provider.sendMessage(
        widget.conversationId,
        text,
        replyToMessageId: replyId,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Message failed to send');
      }
    }
  }

  void _beginEditing(ChatMessage message) {
    setState(() {
      _editingMessage = message;
      _replyingTo = null;
      controller.text = message.text;
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    });
  }

  void _cancelEditing() {
    if (!mounted) return;
    setState(() {
      _editingMessage = null;
      controller.clear();
    });
  }

  void _showChatOptionsSheet(
    Conversation conversation,
    MessagingProvider provider,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildOptionTile(
                icon: Icons.search_rounded,
                label: 'Search Messages',
                onTap: () {
                  Navigator.pop(context);
                  _showMessageSearch();
                },
              ),
              _buildOptionTile(
                icon: Icons.people_rounded,
                label: 'View Members',
                onTap: () {
                  Navigator.pop(context);
                  context.push(
                    '/chat/groups/${conversation.id}/details',
                    extra: conversation,
                  );
                },
              ),
              _buildOptionTile(
                icon: Icons.person_add_rounded,
                label: 'Add Member',
                onTap: () {
                  Navigator.pop(context);
                  _handleAddMember(conversation, provider);
                },
              ),
              _buildOptionTile(
                icon: Icons.volunteer_activism_outlined,
                label: 'Tip Members',
                onTap: () {
                  Navigator.pop(context);
                  TipSheet.show(
                    context,
                    recipients: [],
                    conversationId: widget.conversationId,
                    conversationType: ConversationType.group,
                  );
                },
              ),
              _buildOptionTile(
                icon: Icons.logout_rounded,
                label: 'Leave Circle',
                color: colorScheme.error,
                onTap: () {
                  Navigator.pop(context);
                  _handleLeaveGroup(conversation, provider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAddMember(
    Conversation conversation,
    MessagingProvider provider,
  ) async {
    final results = await FriendSelectorSheet.show(
      context,
      title: 'Add Member',
      disabledIds: conversation.memberIds,
    );
    if (results != null && results.isNotEmpty) {
      try {
        for (final user in results) {
          await provider.addGroupMember(conversation.id, user.id);
        }
        if (mounted) {
          NotificationService.showSuccess(context, 'Member(s) added!');
        }
      } catch (e) {
        if (mounted) {
          NotificationService.showError(context, 'Failed to add member');
        }
      }
    }
  }

  Future<void> _handleLeaveGroup(
    Conversation conversation,
    MessagingProvider provider,
  ) async {
    try {
      await provider.leaveGroup(conversation.id);
      if (mounted) {
        Navigator.of(context).pop();
        NotificationService.showSuccess(context, 'You left the circle');
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to leave circle');
      }
    }
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: color ?? colorScheme.primary),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
      onTap: onTap,
    );
  }

  Widget _buildAvatar(Conversation conversation) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.25),
            colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: ClipOval(
        child: conversation.imageUrl?.trim().isNotEmpty == true
            ? Image.network(
                conversation.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.people_rounded, color: colorScheme.primary),
              )
            : Icon(Icons.people_rounded, color: colorScheme.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final canPopRoute = context.canPop();

    return PopScope(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && context.mounted) context.go('/chat?tab=groups');
      },
      child: Consumer<MessagingProvider>(
        builder: (context, provider, child) {
          final providerConversation = provider.conversations
              .where((c) => c.id == widget.conversationId)
              .firstOrNull;
          // The detail response contains the authoritative member role. Keep
          // it ahead of the lightweight conversation-list row so owners and
          // admins do not lose the pin action while the list is stale.
          final seedConversation = _conversation ?? providerConversation!;
          // Conversation-list rows can be stale when the group avatar was
          // just updated. Prefer the provider's refreshed image/name while
          // retaining the detail response for fields it does not include.
          final currentConversation = seedConversation.copyWith(
            imageUrl:
                providerConversation?.imageUrl ?? seedConversation.imageUrl,
            name: providerConversation?.name ?? seedConversation.name,
            role: providerConversation?.role ?? seedConversation.role,
            ownerId: providerConversation?.ownerId ?? seedConversation.ownerId,
          );
          final currentUserId = context.read<UserProvider>().user?.id;
          final canManageMessages =
              currentConversation.role == 'owner' ||
              currentConversation.role == 'admin' ||
              currentConversation.ownerId == currentUserId;

          final typingUsers = provider.typingUsers[widget.conversationId] ?? {};

          return GestureDetector(
            onTap: _dismissKeyboard,
            child: GradientScaffold(
              useSafeArea: true,
              resizeToAvoidBottomInset: true,
              floatingActionButton: _showScrollToBottom
                  ? HeroMode(
                      enabled: false,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 84),
                        child: FloatingActionButton.small(
                          heroTag: 'group-scroll-to-bottom-fab',
                          onPressed: _scrollToBottom,
                          backgroundColor: colorScheme.surface.withValues(
                            alpha: 0.9,
                          ),
                          foregroundColor: colorScheme.primary,
                          elevation: 4,
                          shape: const CircleBorder(),
                          child: const Icon(
                            Icons.arrow_downward_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                    )
                  : null,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: colorScheme.surface,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  onPressed: () => context.go('/chat?tab=groups'),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                ),
                title: InkWell(
                  onTap: () => context.push(
                    '/chat/groups/${currentConversation.id}/details',
                    extra: currentConversation,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    children: [
                      _buildAvatar(currentConversation),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentConversation.title ?? 'Group Chat',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${currentConversation.memberCount > 0 ? currentConversation.memberCount : (currentConversation.memberIds.isNotEmpty ? currentConversation.memberIds.length : 1)} members',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color:
                                    colorScheme.primary.computeLuminance() > 0.4
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  GroupConversationCallButton(
                    conversationId: widget.conversationId,
                    canCreateCampfire:
                        currentConversation.role == 'owner' ||
                        currentConversation.role == 'admin' ||
                        currentConversation.ownerId ==
                            context.read<UserProvider>().user?.id,
                  ),
                  IconButton(
                    onPressed: () => TipSheet.show(
                      context,
                      recipients: [],
                      conversationId: widget.conversationId,
                      conversationType: ConversationType.group,
                    ),
                    icon: const Icon(Icons.volunteer_activism_outlined),
                    color: colorScheme.primary,
                  ),
                  IconButton(
                    onPressed: () =>
                        _showChatOptionsSheet(currentConversation, provider),
                    icon: const Icon(Icons.more_vert_rounded),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              child: ChatWallpaper(
                child: Column(
                  children: [
                    // Keep the conversation-scoped Campfire visible in the
                    // chat itself, not only on the group details page.
                    ConversationCampfireStatusCard(
                      conversationId: widget.conversationId,
                      conversationType: 'group',
                      canCreate: canManageMessages,
                    ),
                    if (_activeGroupCall != null)
                      MaterialBanner(
                        leading: Icon(
                          Icons.phone_in_talk_rounded,
                          color: colorScheme.primary,
                        ),
                        content: Text(
                          'Live group call • ${_activeGroupCall!['participantCount'] ?? _activeGroupCall!['participant_count'] ?? ''} joined',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => context.push(
                              '/calls/${widget.conversationId}',
                              extra: {
                                'type': 'group',
                                'mode': _activeGroupCall!['mode'] ?? 'voice',
                                'callId':
                                    _activeGroupCall!['id'] ??
                                    _activeGroupCall!['callId'] ??
                                    _activeGroupCall!['call_id'],
                                'roomId':
                                    _activeGroupCall!['roomId'] ??
                                    _activeGroupCall!['room_id'],
                              },
                            ),
                            child: const Text('Join'),
                          ),
                        ],
                      ),
                    Builder(
                      builder: (context) {
                        final pinnedIds = provider.pinnedMessageIds(
                          widget.conversationId,
                        );
                        final pinned =
                            provider
                                .getMessagesForConversation(
                                  widget.conversationId,
                                )
                                .where(
                                  (message) =>
                                      pinnedIds.contains(message.id) ||
                                      (message.clientMessageId != null &&
                                          pinnedIds.contains(
                                            message.clientMessageId,
                                          )),
                                )
                                .toList()
                              ..sort((a, b) {
                                int indexOf(ChatMessage message) {
                                  final index = pinnedIds.indexOf(message.id);
                                  if (index >= 0) return index;
                                  final clientId = message.clientMessageId;
                                  return clientId == null
                                      ? pinnedIds.length
                                      : pinnedIds.indexOf(clientId);
                                }

                                return indexOf(a).compareTo(indexOf(b));
                              });
                        return PinnedMessagesBanner(
                          messages: pinned,
                          onMessageTap: (message) => _jumpToMessage(message.id),
                        );
                      },
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                        itemCount: provider
                            .getMessagesForConversation(widget.conversationId)
                            .length,
                        itemBuilder: (context, index) {
                          final messages = provider.getMessagesForConversation(
                            widget.conversationId,
                          );
                          final message = messages[index];
                          final isMe =
                              message.senderId ==
                              context.read<UserProvider>().user?.id;
                          final nextMessage = index > 0
                              ? messages[index - 1]
                              : null;
                          final prevMessage = index < messages.length - 1
                              ? messages[index + 1]
                              : null;

                          final bool isLastInGroup =
                              nextMessage == null ||
                              nextMessage.senderId != message.senderId;
                          final bool isFirstInGroup =
                              prevMessage == null ||
                              prevMessage.senderId != message.senderId;
                          final startsNewDay =
                              index == messages.length - 1 ||
                              message.createdAt.day !=
                                  messages[index + 1].createdAt.day;

                          final messageKey = _messageKeys.putIfAbsent(
                            message.id,
                            GlobalKey.new,
                          );
                          return KeyedSubtree(
                            key: messageKey,
                            child: Column(
                              children: [
                                if (startsNewDay)
                                  DaySeparator(
                                    date: message.createdAt,
                                    colorScheme: colorScheme,
                                  ),
                                ReplySwipe(
                                  key: ValueKey('reply-${message.id}'),
                                  background: _replySwipeBackground(
                                    colorScheme,
                                  ),
                                  onReply: () =>
                                      setState(() => _replyingTo = message),
                                  child: MessageBubble(
                                    key: ValueKey(message.id),
                                    message: message,
                                    isMe: isMe,
                                    isDark: isDark,
                                    colorScheme: colorScheme,
                                    onReply: (m) =>
                                        setState(() => _replyingTo = m),
                                    sender: _groupMembers[message.senderId],
                                    memberDirectory: _groupMembers,
                                    onSenderTap: isMe
                                        ? null
                                        : () => _openSenderProfile(
                                            message.senderId,
                                          ),
                                    onReplyTap: message.replyToMessageId == null
                                        ? null
                                        : () => _jumpToMessage(
                                            message.replyToMessageId!,
                                          ),
                                    isHighlighted:
                                        _highlightedMessageId == message.id,
                                    conversation: currentConversation,
                                    canPinMessage: canManageMessages,
                                    isPinned: provider
                                        .pinnedMessageIds(widget.conversationId)
                                        .contains(message.id),
                                    onEdit: () => _beginEditing(message),
                                    isFirstInGroup: isFirstInGroup,
                                    isLastInGroup: isLastInGroup,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (typingUsers.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
                        child: Row(
                          children: [
                            GriotPulseIndicator(
                              size: 14,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _typingLabel(typingUsers),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color:
                                    colorScheme.primary.computeLuminance() > 0.4
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.primary.withValues(
                                        alpha: 0.7,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildComposer(currentConversation, provider),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _replySwipeBackground(ColorScheme colors) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Icon(Icons.reply_rounded, color: colors.primary),
    ),
  );

  Widget _buildComposer(Conversation conversation, MessagingProvider provider) {
    final role = conversation.role;
    final currentUserId = context.read<UserProvider>().user?.id;
    final isOwner =
        role == 'owner' ||
        (currentUserId != null && conversation.ownerId == currentUserId);
    final isAdmin = role == 'admin';
    final isOwnerOrAdmin = isOwner || isAdmin;
    final isLocked = conversation.messagesLocked == true;
    final canPost = !isLocked || isOwnerOrAdmin;

    if (!canPost) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Text(
          'Admins only can post in this circle.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyingTo != null) _buildReplyPreview(),
        if (_editingMessage != null) const SizedBox(height: 0),
        MessageInput(
          controller: controller,
          colorScheme: Theme.of(context).colorScheme,
          textTheme: Theme.of(context).textTheme,
          onSend: _sendMessage,
          onAttachment: _showAttachmentSheet,
          onCamera: () => _pickImage(ImageSource.camera),
          onMicTap: () => VoiceRecordingSheet.show(
            context,
            conversationId: widget.conversationId,
            replyToMessageId: _replyingTo?.id,
          ),
          hasText: _hasText,
          isEditing: _editingMessage != null,
          onCancelEdit: _cancelEditing,
        ),
      ],
    );
  }

  Widget _buildReplyPreview() {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: colors.primary, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${_groupMembers[_replyingTo!.senderId]?.effectiveDisplayName ?? 'member'}',
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _replyingTo?.text ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  void _showAttachmentSheet() {
    _dismissKeyboard();
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => AttachmentSheet(
        onImage: () {
          Navigator.pop(sheetContext);
          _pickImage(ImageSource.gallery);
        },
        onCamera: () {
          Navigator.pop(sheetContext);
          _pickImage(ImageSource.camera);
        },
        onVideo: () {
          Navigator.pop(sheetContext);
          _pickVideo();
        },
        onFile: () {
          Navigator.pop(sheetContext);
          _pickFile();
        },
        onTip: () {
          Navigator.pop(sheetContext);
          TipSheet.show(
            context,
            recipients: [],
            conversationId: widget.conversationId,
            conversationType: ConversationType.group,
          );
        },
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source);
    if (file != null) {
      if (!mounted) return;
      await MediaPreviewSheet.show(
        context,
        filePath: file.path,
        type: MessageType.image,
        onSend: (caption) => context.read<MessagingProvider>().sendMediaMessage(
          conversationId: widget.conversationId,
          filePath: file.path,
          type: MessageType.image,
          content: caption.isEmpty ? null : caption,
          replyToMessageId: _replyingTo?.id,
        ),
      );
      if (mounted) {
        setState(() => _replyingTo = null);
      }
      _scrollToBottom();
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      if (!mounted) return;
      await MediaPreviewSheet.show(
        context,
        filePath: file.path,
        type: MessageType.video,
        onSend: (caption) => context.read<MessagingProvider>().sendMediaMessage(
          conversationId: widget.conversationId,
          filePath: file.path,
          type: MessageType.video,
          content: caption.isEmpty ? null : caption,
          replyToMessageId: _replyingTo?.id,
        ),
      );
      if (mounted) {
        setState(() => _replyingTo = null);
      }
      _scrollToBottom();
    }
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile();
    if (file != null && file.path != null) {
      if (!mounted) return;
      await MediaPreviewSheet.show(
        context,
        filePath: file.path!,
        type: MessageType.file,
        onSend: (caption) => context.read<MessagingProvider>().sendMediaMessage(
          conversationId: widget.conversationId,
          filePath: file.path!,
          type: MessageType.file,
          content: caption.isEmpty ? null : caption,
          replyToMessageId: _replyingTo?.id,
        ),
      );
      if (mounted) {
        setState(() => _replyingTo = null);
      }
      _scrollToBottom();
    }
  }
}
