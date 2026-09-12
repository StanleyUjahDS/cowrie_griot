import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:griot_cowrie/features/users/providers/user_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/notification_service.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/ui/widgets/griot_avatar.dart';
import '../../../core/ui/widgets/griot_plus_badge.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/conversation_model.dart';
import '../providers/messaging_provider.dart';
import '../services/messaging_api_service.dart';
import '../widgets/chatting/attachment_sheet.dart';
import '../widgets/chatting/media_preview_sheet.dart';
import '../widgets/chatting/day_separator.dart';
import '../widgets/chatting/message_bubble.dart';
import '../widgets/chatting/message_input.dart';
import '../widgets/chatting/tip_sheet.dart';
import '../widgets/chatting/voice_recording_sheet.dart';

class DMChatScreen extends StatefulWidget {
  final String? userId;
  final String? conversationId;
  final Conversation? initialConversation;
  final ChatUser? initialUser;

  const DMChatScreen({
    super.key,
    this.userId,
    this.conversationId,
    this.initialConversation,
    this.initialUser,
  });

  @override
  State<DMChatScreen> createState() => _DMChatScreenState();
}

class _DMChatScreenState extends State<DMChatScreen> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  String? _conversationId;
  Conversation? _conversation;
  ChatMessage? _replyingTo;
  Timer? _typingTimer;
  bool _lastTypingState = false;
  bool _showScrollToBottom = false;
  bool _loading = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    controller.addListener(_onComposerChanged);
    scrollController.addListener(_onScrollChanged);
    _conversationId = widget.conversationId ?? widget.initialConversation?.id;
    _conversation = widget.initialConversation;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<MessagingProvider>(context, listen: false);
      if (_conversationId != null) {
        _initConversationById(_conversationId!);
      } else if (widget.userId != null) {
        _initDirectConversation();
      }
      provider.loadTipConfig();
    });
  }

  Future<void> _initConversationById(String conversationId) async {
    final provider = Provider.of<MessagingProvider>(context, listen: false);
    provider.joinConversation(conversationId);
    provider.loadMessages(conversationId, refresh: true);

    if (_conversation == null) {
      if (!mounted) return;
      final apiService = context.read<MessagingApiService>();
      try {
        final conversation = await apiService.getConversation(conversationId);
        if (mounted) {
          final existingOtherUser = _conversation?.otherUser;
          setState(() {
            _conversation =
                conversation.otherUser == null && existingOtherUser != null
                ? conversation.copyWith(otherUser: existingOtherUser)
                : conversation;
          });
        }
      } catch (e) {
        debugPrint('Failed to load conversation details: $e');
      }
    }
  }

  Future<void> _initDirectConversation() async {
    if (widget.initialUser != null) {
      setState(() {
        _conversation = Conversation(
          id: '',
          type: ConversationType.dm,
          otherUser: widget.initialUser,
          memberIds: [],
          updatedAt: DateTime.now(),
          createdAt: DateTime.now(),
        );
      });
    }

    try {
      final provider = Provider.of<MessagingProvider>(context, listen: false);
      final conversation = await provider.startDirectChat(
        widget.userId!,
        otherUser: widget.initialUser,
      );
      if (mounted) {
        setState(() {
          _conversationId = conversation.id;
          _conversation =
              conversation.otherUser == null && widget.initialUser != null
              ? conversation.copyWith(otherUser: widget.initialUser)
              : conversation;
        });
        provider.joinConversation(conversation.id);
        provider.loadMessages(conversation.id, refresh: true);
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to connect to chat: $e');
      }
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_conversationId != null) {
      try {
        final provider = context.read<MessagingProvider>();
        provider.setTyping(_conversationId!, false);
        provider.leaveConversation(_conversationId!);
      } catch (e) {
        debugPrint('MessagingProvider was already disposed: $e');
      }
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
      if (_conversationId != null) {
        context.read<MessagingProvider>().setTyping(_conversationId!, isTyping);
      }
    }
    _typingTimer?.cancel();
    if (isTyping) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _lastTypingState) {
          _lastTypingState = false;
          if (_conversationId != null) {
            context.read<MessagingProvider>().setTyping(
              _conversationId!,
              false,
            );
          }
        }
      });
    }
    if (mounted) setState(() {});
  }

  void _onScrollChanged() {
    if (!scrollController.hasClients) return;
    // Since reverse: true, 0 is bottom.
    // If offset > 400, user has scrolled up significantly.
    final bool show = scrollController.offset > 400;
    if (show != _showScrollToBottom) {
      setState(() => _showScrollToBottom = show);
    }
  }

  bool get _hasText => controller.text.trim().isNotEmpty;

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

  Future<void> _sendMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    if (text.length > 4000) return;

    final provider = Provider.of<MessagingProvider>(context, listen: false);

    // If conversation is still being initialized, we wait or try to get it.
    String? conversationId = _conversationId;
    if (conversationId == null) {
      if (mounted) {
        setState(() {
          _loading = true; // We should add this bool to state
          _message = 'Initializing chat...'; // And this string
        });
      }
      try {
        if (widget.userId != null) {
          final conv = await provider.startDirectChat(widget.userId!);
          conversationId = conv.id;
          if (mounted) {
            final participant = _conversation?.otherUser ?? widget.initialUser;
            setState(() {
              _conversationId = conv.id;
              _conversation = conv.otherUser == null && participant != null
                  ? conv.copyWith(otherUser: participant)
                  : conv;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          NotificationService.showError(context, 'Failed to start chat: $e');
          setState(() => _loading = false);
        }
        return;
      }
    }

    if (conversationId == null) return;

    controller.clear();
    final replyId = _replyingTo?.id;
    setState(() {
      _replyingTo = null;
      _loading = false;
    });

    try {
      await provider.sendMessage(
        conversationId,
        text,
        replyToMessageId: replyId,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Message failed to send';
        if (e.toString().contains('403')) {
          errorMsg = 'You are no longer friends or have been blocked.';
        }
        NotificationService.showError(context, errorMsg);
      }
    }
  }

  void _showChatOptionsSheet(
    Conversation conversation,
    MessagingProvider provider,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final otherUser = conversation.otherUser;
    final isBlocked =
        otherUser != null && provider.blockedUserIds.contains(otherUser.id);

    showModalBottomSheet(
      context: context,
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
              icon: Icons.person_outline_rounded,
              label: 'View Profile',
              onTap: () {
                Navigator.pop(context);
                if (otherUser != null) {
                  context.push('/user/profile', extra: otherUser.toUserModel());
                }
              },
            ),
            _buildOptionTile(
              icon: Icons.volunteer_activism_outlined,
              label: 'Tip User',
              onTap: () {
                Navigator.pop(context);
                TipSheet.show(
                  context,
                  recipients: otherUser != null ? [otherUser] : [],
                  conversationId: _conversationId,
                  conversationType: ConversationType.dm,
                );
              },
            ),
            _buildOptionTile(
              icon: isBlocked ? Icons.block_flipped : Icons.block_rounded,
              label: isBlocked ? 'Unblock User' : 'Block User',
              color: colorScheme.error,
              onTap: () {
                Navigator.pop(context);
                _handleBlockUser(otherUser, provider);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBlockUser(
    ChatUser? otherUser,
    MessagingProvider provider,
  ) async {
    if (otherUser == null) return;
    final isBlocked = provider.blockedUserIds.contains(otherUser.id);
    try {
      if (isBlocked) {
        await provider.unblockUser(otherUser.id);
        if (mounted) {
          NotificationService.showSuccess(context, 'User unblocked');
        }
      } else {
        await provider.blockUser(otherUser.id);
        if (mounted) {
          NotificationService.showSuccess(context, 'User blocked');
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to update block status');
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

  Widget _buildAvatar(Conversation? conversation, MessagingProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final otherUser = conversation?.otherUser;
    final bool isOnline =
        (otherUser != null && provider.presenceMap[otherUser.id] == true) ||
        (otherUser?.isOnline ?? false);

    return Stack(
      children: [
        Container(
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
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.20),
            ),
          ),
          child: GriotAvatar(
            avatarUrl: otherUser?.profileUrl,
            radius: 22,
            backgroundColor: Colors.transparent,
          ),
        ),
        if (isOnline)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<MessagingProvider>(
      builder: (context, provider, child) {
        final cid = _conversationId;
        final baseConversation = cid != null
            ? provider.conversations.firstWhere(
                (c) => c.id == cid,
                orElse: () => _conversation!,
              )
            : _conversation;
        final providerOtherUser = baseConversation?.otherUser;
        final fallbackOtherUser = _conversation?.otherUser;
        final otherUser = providerOtherUser == null
            ? fallbackOtherUser
            : ((providerOtherUser.profileUrl == null ||
                      providerOtherUser.profileUrl!.trim().isEmpty) &&
                  fallbackOtherUser?.profileUrl != null &&
                  fallbackOtherUser!.profileUrl!.trim().isNotEmpty)
            ? providerOtherUser.copyWith(
                profileUrl: fallbackOtherUser.profileUrl,
              )
            : providerOtherUser;
        final currentConversation = baseConversation?.copyWith(
          otherUser: otherUser,
        );
        final bool isOnline =
            (otherUser != null && provider.presenceMap[otherUser.id] == true) ||
            (otherUser?.isOnline ?? false);
        final bool isOtherUserTyping =
            otherUser != null &&
            (provider.typingUsers[cid ?? '']?.contains(otherUser.id) ?? false);

        return GestureDetector(
          onTap: _dismissKeyboard,
          child: GradientScaffold(
            useSafeArea: true,
            floatingActionButton: _showScrollToBottom
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 60),
                    child: FloatingActionButton.small(
                      onPressed: _scrollToBottom,
                      backgroundColor: colorScheme.surface.withValues(
                        alpha: 0.9,
                      ),
                      foregroundColor: colorScheme.primary,
                      elevation: 4,
                      shape: const CircleBorder(),
                      child: const Icon(Icons.arrow_downward_rounded, size: 18),
                    ),
                  )
                : null,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: colorScheme.surface,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
              title: InkWell(
                onTap: () {
                  if (otherUser != null) {
                    context.push(
                      '/user/profile',
                      extra: otherUser.toUserModel(),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  children: [
                    _buildAvatar(currentConversation, provider),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  otherUser?.effectiveDisplayName ?? 'Chat',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              if (otherUser?.isPlus == true) ...[
                                const SizedBox(width: 6),
                                const GriotPlusBadge(
                                  isPlus: true,
                                  compact: true,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            isOtherUserTyping
                                ? 'typing...'
                                : (isOnline ? 'online' : 'offline'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isOtherUserTyping || isOnline
                                  ? (colorScheme.primary.computeLuminance() >
                                            0.4
                                        ? colorScheme.onSurfaceVariant
                                        : colorScheme.primary)
                                  : colorScheme.onSurfaceVariant.withValues(
                                      alpha: 0.6,
                                    ),
                              fontWeight: isOnline
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (currentConversation != null) ...[
                  IconButton(
                    onPressed: () => TipSheet.show(
                      context,
                      recipients: otherUser != null ? [otherUser] : [],
                      conversationId: _conversationId,
                      conversationType: ConversationType.dm,
                    ),
                    icon: const Icon(Icons.volunteer_activism_outlined),
                    color: colorScheme.primary,
                  ),
                  IconButton(
                    onPressed: () =>
                        _showChatOptionsSheet(currentConversation, provider),
                    icon: const Icon(Icons.more_vert_rounded),
                  ),
                ],
                const SizedBox(width: 8),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: (cid == null && otherUser == null)
                      ? const Center(child: GriotLoader())
                      : ListView.builder(
                          controller: scrollController,
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                          itemCount: provider
                              .getMessagesForConversation(cid ?? '')
                              .length,
                          itemBuilder: (context, index) {
                            final messages = provider
                                .getMessagesForConversation(cid ?? '');
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
                                !_isSameCalendarDay(
                                  message.createdAt,
                                  messages[index + 1].createdAt,
                                );

                            return Column(
                              children: [
                                if (startsNewDay)
                                  DaySeparator(
                                    date: message.createdAt,
                                    colorScheme: colorScheme,
                                  ),
                                MessageBubble(
                                  key: ValueKey(message.id),
                                  message: message,
                                  isMe: isMe,
                                  isDark: isDark,
                                  colorScheme: colorScheme,
                                  onReply: (m) =>
                                      setState(() => _replyingTo = m),
                                  conversation: currentConversation,
                                  isFirstInGroup: isFirstInGroup,
                                  isLastInGroup: isLastInGroup,
                                ),
                              ],
                            );
                          },
                        ),
                ),
                _buildComposer(provider, cid, otherUser),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isSameCalendarDay(DateTime first, DateTime second) {
    final a = first.toLocal();
    final b = second.toLocal();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildComposer(
    MessagingProvider provider,
    String? cid,
    ChatUser? otherUser,
  ) {
    if (otherUser == null) return const SizedBox.shrink();

    final relationship = provider.getRelationship(otherUser.id);
    final bool isFriend =
        relationship == RelationshipState.friends ||
        otherUser.relationshipStatus == 'friend';
    final bool isBlockedByMe =
        relationship == RelationshipState.blocked ||
        provider.blockedUserIds.contains(otherUser.id);
    final bool isBlockedByThem =
        otherUser.relationshipStatus == 'blocked_by_user';

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isBlockedByMe || isBlockedByThem || !isFriend) {
      return _buildClosedComposer(provider, otherUser);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyingTo != null) _buildReplyPreview(),
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GriotPulseIndicator(size: 14, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(_message, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        MessageInput(
          controller: controller,
          colorScheme: Theme.of(context).colorScheme,
          textTheme: Theme.of(context).textTheme,
          onSend: _sendMessage,
          onAttachment: _showAttachmentSheet,
          onCamera: () => _pickImage(ImageSource.camera),
          onMicTap: () {
            if (cid == null) {
              NotificationService.showInfo(
                context,
                'Waiting for chat session...',
              );
              return;
            }
            VoiceRecordingSheet.show(
              context,
              conversationId: cid,
              replyToMessageId: _replyingTo?.id,
            );
          },
          hasText: _hasText,
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
                  'Replying to',
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

  Widget _buildClosedComposer(MessagingProvider provider, ChatUser otherUser) {
    final isBlockedByMe = provider.blockedUserIds.contains(otherUser.id);

    if (isBlockedByMe) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          children: [
            Icon(
              Icons.block_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 32,
            ),
            const SizedBox(height: 12),
            const Text(
              'User Blocked',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => provider.unblockUser(otherUser.id),
                child: const Text('Unblock User'),
              ),
            ),
          ],
        ),
      );
    }

    final isBlockedByThem = otherUser.relationshipStatus == 'blocked_by_user';
    if (isBlockedByThem) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Text(
          'Messaging Unavailable',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    // Handled Friend Request logic here similarly to chatting_screen.dart
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: const Text('Send a friend request to start messaging.'),
    );
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
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
        onContact: () {
          Navigator.pop(sheetContext);
          _pickContact();
        },
        onTip: () {
          Navigator.pop(sheetContext);
          TipSheet.show(
            context,
            recipients: _conversation?.otherUser != null
                ? [_conversation!.otherUser!]
                : [],
            conversationId: _conversationId,
            conversationType: ConversationType.dm,
          );
        },
      ),
    );
  }

  Future<void> _pickContact() async {
    final conversationId = _conversationId;
    if (conversationId == null) {
      if (mounted) {
        NotificationService.showInfo(context, 'Waiting for chat session...');
      }
      return;
    }

    try {
      final contact = await FlutterContacts.native.showPicker(
        properties: {ContactProperty.name, ContactProperty.phone},
      );
      if (!mounted || contact == null) return;

      final name = contact.displayName?.trim().isNotEmpty == true
          ? contact.displayName!.trim()
          : 'Contact';
      final phone = contact.phones.isNotEmpty
          ? contact.phones.first.number.trim()
          : '';

      if (phone.isEmpty) {
        NotificationService.showError(
          context,
          'This contact does not have a phone number.',
        );
        return;
      }

      await context.read<MessagingProvider>().sendContactMessage(
        conversationId: conversationId,
        contactName: name,
        contactPhone: phone,
        replyToMessageId: _replyingTo?.id,
      );
      if (mounted) {
        setState(() => _replyingTo = null);
        _scrollToBottom();
      }
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not share contact. Please try again.',
        );
      }
      debugPrint('Contact sharing failed: $error');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source);
    if (file != null && _conversationId != null) {
      if (!mounted) return;
      await MediaPreviewSheet.show(
        context,
        filePath: file.path,
        type: MessageType.image,
        onSend: (caption) => context.read<MessagingProvider>().sendMediaMessage(
          conversationId: _conversationId!,
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
    if (file != null && _conversationId != null) {
      if (!mounted) return;
      await MediaPreviewSheet.show(
        context,
        filePath: file.path,
        type: MessageType.video,
        onSend: (caption) => context.read<MessagingProvider>().sendMediaMessage(
          conversationId: _conversationId!,
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
    if (file != null && file.path != null && _conversationId != null) {
      if (!mounted) return;
      await MediaPreviewSheet.show(
        context,
        filePath: file.path!,
        type: MessageType.file,
        onSend: (caption) => context.read<MessagingProvider>().sendMediaMessage(
          conversationId: _conversationId!,
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
