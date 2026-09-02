import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/messaging_provider.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/message_request.dart';
import '../models/conversation_model.dart';
import '../widgets/friend_selector_sheet.dart';
import '../widgets/chatting/tip_sheet.dart';
import '../services/messaging_api_service.dart';
import 'package:griot_cowrie/features/users/models/user_model.dart';
import 'package:griot_cowrie/features/users/providers/user_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/ui/widgets/griot_loader.dart';

class ChatScreen extends StatefulWidget {
  final String? userId;
  final String? conversationId;
  final Conversation? initialConversation;
  final ChatUser? initialUser;

  const ChatScreen({
    super.key,
    this.userId,
    this.conversationId,
    this.initialConversation,
    this.initialUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  String? _conversationId;
  Conversation? _conversation;
  ChatMessage? _replyingTo;
  late final AnimationController _recordAnimationController;
  late final AudioRecorder _audioRecorder;

  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordingTimer;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();

    _audioRecorder = AudioRecorder();

    _recordAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
      lowerBound: 0.92,
      upperBound: 1.08,
    );

    controller.addListener(_onComposerChanged);

    // Initialize with provided data if possible
    _conversationId = widget.conversationId ?? widget.initialConversation?.id;
    _conversation = widget.initialConversation;

    // Initialize Conversation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<MessagingProvider>(context, listen: false);
      if (_conversationId != null) {
        _initConversationById(_conversationId!);
      } else if (widget.userId != null) {
        _initDirectConversation();
      }

      // Pre-load Tip Config
      provider.loadTipConfig();
    });
  }

  Future<void> _initConversationById(String conversationId) async {
    if (!mounted) return;
    final provider = Provider.of<MessagingProvider>(context, listen: false);
    provider.joinConversation(conversationId);
    provider.loadMessages(conversationId, refresh: true);

    // If we don't have full conversation details yet, fetch them
    if (_conversation == null) {
      if (!mounted) return;
      final apiService = context.read<MessagingApiService>();
      try {
        final conversation = await apiService.getConversation(conversationId);
        if (mounted) setState(() => _conversation = conversation);
      } catch (e) {
        debugPrint('Failed to load conversation details: $e');
      }
    }
  }

  Future<void> _initDirectConversation() async {
    // If we have initial user data, use it for the header immediately
    if (widget.initialUser != null) {
      setState(() {
        _conversation = Conversation(
          id: '', // Temporary
          type: ConversationType.dm,
          otherUser: widget.initialUser,
          memberIds: [],
          updatedAt: DateTime.now(),
          createdAt: DateTime.now(),
        );
      });
    }

    try {
      if (!mounted) return;
      final provider = Provider.of<MessagingProvider>(context, listen: false);
      final conversation = await provider.startDirectChat(widget.userId!);

      if (mounted) {
        setState(() {
          _conversationId = conversation.id;
          _conversation = conversation;
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
    _recordAnimationController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // ============================================================
  // COMPOSER
  // ============================================================

  Timer? _typingTimer;
  bool _lastTypingState = false;

  void _onComposerChanged() {
    final text = controller.text.trim();
    final isTyping = text.isNotEmpty;

    if (isTyping != _lastTypingState) {
      _lastTypingState = isTyping;
      if (_conversationId != null) {
        context.read<MessagingProvider>().setTyping(_conversationId!, isTyping);
      }
    }

    // Auto-stop typing after 3 seconds of inactivity
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

    if (mounted) {
      setState(() {});
    }
  }

  bool get _hasText => controller.text.trim().isNotEmpty;

  // ============================================================
  // KEYBOARD
  // ============================================================

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  // ============================================================
  // SCROLL
  // ============================================================

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

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage() async {
    final text = controller.text.trim();
    final conversationId = _conversationId;

    if (text.isEmpty || conversationId == null) return;
    if (text.length > 4000) return; // Validation handled in UI

    if (!mounted) return;
    final provider = Provider.of<MessagingProvider>(context, listen: false);

    // Clear first for better UX
    controller.clear();
    final replyId = _replyingTo?.id;
    setState(() => _replyingTo = null);

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

  Widget _buildAvatar(Conversation? conversation, MessagingProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final otherUser = conversation?.otherUser;
    final heroTag =
        'user_avatar_${otherUser?.id ?? widget.userId ?? widget.conversationId ?? "unknown"}';

    final bool isOnline =
        (otherUser != null && provider.presenceMap[otherUser.id] == true) ||
        (otherUser?.isOnline ?? false);

    return Hero(
      tag: heroTag,
      child: Stack(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary.withValues(alpha: 0.25),
                  colorScheme.primary.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.20),
              ),
            ),
            child: ClipOval(
              child:
                  (otherUser?.profileUrl != null)
                      ? Image.network(otherUser!.profileUrl!, fit: BoxFit.cover)
                      : SvgPicture.asset(
                        'assets/coins_logo/hbadger_logo.svg',
                        fit: BoxFit.cover,
                        placeholderBuilder:
                            (context) => Icon(
                              Icons.person_outline_rounded,
                              color: colorScheme.primary,
                            ),
                      ),
            ),
          ),
          if (conversation?.type == ConversationType.dm && isOnline)
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getDisplayName(Conversation? conversation) {
    if (conversation != null) {
      if (conversation.type == ConversationType.dm) {
        return conversation.otherUser?.effectiveDisplayName ?? 'User';
      }
      return conversation.title ??
          (conversation.type == ConversationType.group
              ? 'Group Chat'
              : 'Channel');
    }
    return 'Chat';
  }

  Widget _buildSubtitle(Conversation? conversation, MessagingProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final type = conversation?.type;

    // 1. Handle Typing Status First (Priority)
    if (conversation != null) {
      final typingSet = provider.typingUsers[conversation.id];
      if (typingSet != null && typingSet.isNotEmpty) {
        return Text(
          'typing...',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        );
      }
    }

    // 2. Groups/Channels
    if (type == ConversationType.group || type == ConversationType.channel) {
      final members = conversation?.memberIds.length ?? 0;
      return Text(
        type == ConversationType.group ? '$members members' : 'channel',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    // 3. Direct Messages (Online Status)
    final otherUser = conversation?.otherUser;
    final bool isOnline = (otherUser != null && provider.presenceMap[otherUser.id] == true) || 
                          (otherUser?.isOnline ?? false);

    return Text(
      isOnline ? 'online' : 'offline',
      style: theme.textTheme.labelSmall?.copyWith(
        color: isOnline ? Colors.green : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        fontWeight: isOnline ? FontWeight.w700 : FontWeight.normal,
      ),
    );
  }

  // ============================================================
  // PROFILE
  // ============================================================

  void _openUserProfile() {
    final otherUser = _conversation?.otherUser;
    if (otherUser != null) {
      context.push('/user/profile', extra: otherUser.toUserModel());
    }
  }

  Future<void> _handleBlockUser() async {
    final otherUser = _conversation?.otherUser;
    if (otherUser == null) return;

    if (!mounted) return;
    final provider = Provider.of<MessagingProvider>(context, listen: false);
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

  void _handleAddMember(Conversation conversation) async {
    final results = await FriendSelectorSheet.show(
      context,
      title: 'Add Member',
    );
    if (results != null && results.isNotEmpty) {
      if (!mounted) return;
      final provider = context.read<MessagingProvider>();
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

  void _handleLeaveGroup(Conversation conversation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text(
          'Are you sure you want to leave this group conversation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirm == true) {
      try {
        await context.read<MessagingProvider>().leaveGroup(conversation.id);
        if (mounted) {
          context.pop();
          NotificationService.showSuccess(context, 'You left the group');
        }
      } catch (e) {
        if (mounted) {
          NotificationService.showError(context, 'Failed to leave group');
        }
      }
    }
  }

  // ============================================================
  // AUDIO RECORDING
  // ============================================================

  void _startTimer() {
    _recordDuration = 0;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) {
        setState(() {
          _recordDuration++;
        });
      }
    });
  }

  void _stopTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  Future<void> _startRecording() async {
    try {
      if (await Permission.microphone.request().isGranted) {
        if (_isRecording) return;

        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        _dismissKeyboard();

        const config = RecordConfig();

        await _audioRecorder.start(config, path: path);

        setState(() {
          _isRecording = true;
          _isCancelling = false;
          _recordDuration = 0;
        });

        _startTimer();
        _recordAnimationController.repeat(reverse: true);
        
        if (Platform.isIOS || Platform.isAndroid) {
          HapticFeedback.mediumImpact();
        }
      } else {
        if (mounted) {
          NotificationService.showError(
            context,
            'Microphone permission is required to record voice messages.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    if (_isCancelling) {
      await _cancelRecording();
      return;
    }

    _stopTimer();

    try {
      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
      });

      _recordAnimationController.stop();
      _recordAnimationController.value = 1;

      if (path != null && _conversationId != null) {
        if (mounted) {
          await context.read<MessagingProvider>().sendMediaMessage(
            conversationId: _conversationId!,
            filePath: path,
            type: MessageType.voice,
            replyToMessageId: _replyingTo?.id,
          );
          setState(() => _replyingTo = null);
          _scrollToBottom();
          
          if (Platform.isIOS || Platform.isAndroid) {
            HapticFeedback.lightImpact();
          }
        }
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _cancelRecording() async {
    _stopTimer();
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }

      setState(() {
        _isRecording = false;
        _isCancelling = false;
      });

      _recordAnimationController.stop();
      _recordAnimationController.value = 1;

      if (Platform.isIOS || Platform.isAndroid) {
        HapticFeedback.selectionClick();
      }
    } catch (e) {
      debugPrint('Error cancelling recording: $e');
    }
  }

  void _onRecordingMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isRecording) return;

    // Standard swipe to cancel is usually to the left
    if (details.localOffsetFromOrigin.dx < -80) {
      if (!_isCancelling) {
        setState(() => _isCancelling = true);
        HapticFeedback.lightImpact();
      }
    } else {
      if (_isCancelling) {
        setState(() => _isCancelling = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);

    if (pickedFile != null && _conversationId != null) {
      if (!mounted) return;
      try {
        await context.read<MessagingProvider>().sendMediaMessage(
          conversationId: _conversationId!,
          filePath: pickedFile.path,
          type: MessageType.image,
          replyToMessageId: _replyingTo?.id,
        );
        setState(() => _replyingTo = null);
        _scrollToBottom();
      } catch (e) {
        if (mounted) {
          NotificationService.showError(context, 'Failed to send image');
        }
      }
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null && _conversationId != null) {
      if (!mounted) return;
      try {
        await context.read<MessagingProvider>().sendMediaMessage(
          conversationId: _conversationId!,
          filePath: pickedFile.path,
          type: MessageType.video,
          replyToMessageId: _replyingTo?.id,
        );
        setState(() => _replyingTo = null);
        _scrollToBottom();
      } catch (e) {
        if (mounted) {
          NotificationService.showError(context, 'Failed to send video');
        }
      }
    }
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile();

    if (file != null && file.path != null && _conversationId != null) {
      if (!mounted) return;
      try {
        await context.read<MessagingProvider>().sendMediaMessage(
          conversationId: _conversationId!,
          filePath: file.path!,
          type: MessageType.file,
          content: file.name,
          replyToMessageId: _replyingTo?.id,
        );
        setState(() => _replyingTo = null);
        _scrollToBottom();
      } catch (e) {
        if (mounted) {
          NotificationService.showError(context, 'Failed to send file');
        }
      }
    }
  }

  // ============================================================
  // ATTACHMENTS
  // ============================================================

  void _showAttachmentSheet() {
    _dismissKeyboard();

    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SheetHandle(),

                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SHARE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: colorScheme.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _AttachmentOption(
                        icon: Icons.image_outlined,
                        label: 'Gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AttachmentOption(
                        icon: Icons.camera_alt_outlined,
                        label: 'Camera',
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AttachmentOption(
                        icon: Icons.videocam_outlined,
                        label: 'Video',
                        onTap: () {
                          Navigator.pop(context);
                          _pickVideo();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AttachmentOption(
                        icon: Icons.insert_drive_file_outlined,
                        label: 'File',
                        onTap: () {
                          Navigator.pop(context);
                          _pickFile();
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _AttachmentOption(
                        icon: Icons.location_on_outlined,
                        label: 'Location',
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AttachmentOption(
                        icon: Icons.contact_page_outlined,
                        label: 'Contact',
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AttachmentOption(
                        customIcon: SvgPicture.asset(
                          'assets/cowrie_images/cowriesvg.svg',
                          colorFilter: ColorFilter.mode(
                            colorScheme.primary,
                            BlendMode.srcIn,
                          ),
                        ),
                        label: 'Payment',
                        onTap: () {
                          Navigator.pop(context);
                          _showTipSheet();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // TIP SHEET
  // ============================================================

  void _showTipSheet({List<ChatUser>? initialRecipients}) {
    TipSheet.show(
      context,
      recipients:
          initialRecipients ??
          (_conversation?.otherUser != null ? [_conversation!.otherUser!] : []),
      conversationId: _conversationId,
      conversationType: _conversation?.type,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final isDark = theme.brightness == Brightness.dark;

    // Resolve the latest conversation data from the provider to ensure
    // real-time updates (like online status) are reflected in the header.
    return Consumer<MessagingProvider>(
      builder: (context, provider, child) {
        final cid = _conversationId;
        final currentConversation = cid != null
            ? provider.conversations.firstWhere(
                (c) => c.id == cid,
                orElse: () => _conversation!,
              )
            : _conversation;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _dismissKeyboard,
          child: Scaffold(
            extendBodyBehindAppBar: true,

            // ======================================================
            // APP BAR
            // ======================================================
            appBar: AppBar(
              automaticallyImplyLeading: true,
              backgroundColor: colorScheme.surface.withValues(alpha: 0.8),
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.transparent),
                ),
              ),
              titleSpacing: 0,
              leading: Center(
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              title: InkWell(
                onTap: currentConversation?.type == ConversationType.dm
                    ? _openUserProfile
                    : null,
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  children: [
                    _buildAvatar(currentConversation, provider),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getDisplayName(currentConversation),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 1),
                          _buildSubtitle(currentConversation, provider),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                PopupMenuButton<String>(
                  tooltip: 'More',
                  padding: EdgeInsets.zero,
                  offset: const Offset(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'profile':
                        _openUserProfile();
                        break;
                      case 'tip':
                        _showTipSheet();
                        break;
                      case 'search':
                        break;
                      case 'mute':
                        break;
                      case 'settings':
                        break;
                      case 'block':
                        _handleBlockUser();
                        break;
                      case 'members':
                        context.push('/chat/groups/${currentConversation!.id}/details', extra: currentConversation);
                        break;
                      case 'add_member':
                        _handleAddMember(currentConversation!);
                        break;
                      case 'leave':
                        _handleLeaveGroup(currentConversation!);
                        break;
                    }
                  },
                  itemBuilder: (context) {
                    final isBlocked =
                        currentConversation?.otherUser != null &&
                        provider.blockedUserIds.contains(
                          currentConversation!.otherUser!.id,
                        );

                    final isDM =
                        currentConversation?.type == ConversationType.dm;

                    return [
                      const PopupMenuItem(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person_outline_rounded),
                            SizedBox(width: 12),
                            Text('View profile'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'tip',
                        child: Row(
                          children: [
                            const Icon(Icons.volunteer_activism_outlined),
                            const SizedBox(width: 12),
                            Text(isDM ? 'Tip user' : 'Tip members'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'search',
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded),
                            SizedBox(width: 12),
                            Text('Search messages'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'mute',
                        child: Row(
                          children: [
                            Icon(Icons.notifications_off_outlined),
                            SizedBox(width: 12),
                            Text('Mute notifications'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'settings',
                        child: Row(
                          children: [
                            Icon(Icons.settings_outlined),
                            SizedBox(width: 12),
                            Text('Chat settings'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(
                              isBlocked
                                  ? Icons.block_flipped
                                  : Icons.block_rounded,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isBlocked ? 'Unblock user' : 'Block user',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                      if (!isDM &&
                          currentConversation?.type ==
                              ConversationType.group) ...[
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'members',
                          child: Row(
                            children: [
                              Icon(Icons.people_rounded),
                              SizedBox(width: 12),
                              Text('View members'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'add_member',
                          child: Row(
                            children: [
                              Icon(Icons.person_add_rounded),
                              SizedBox(width: 12),
                              Text('Add member'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'leave',
                          child: Row(
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Leave group',
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ];
                  },
                ),

                const SizedBox(width: 5),
              ],
            ),

            // ======================================================
            // BODY
            // ======================================================
            body: SafeArea(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: colorScheme.primary.withValues(
                      alpha: isDark ? 0.05 : 0.1,
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    children: [
                      // Subtle Pattern/Gradient
                      Positioned.fill(
                        child: Opacity(
                          opacity: isDark ? 0.03 : 0.05,
                          child: Image.asset(
                            'assets/cowrie_images/real_chat_background.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      Column(
                        children: [
                          // ==================================================
                          // MESSAGES
                          // ==================================================

                          Expanded(
                            child: Builder(
                              builder: (context) {
                                if (cid == null) {
                                  return const Center(child: GriotLoader());
                                }

                                final messages = provider
                                    .getMessagesForConversation(cid);
                                final currentUserId = context
                                    .watch<UserProvider>()
                                    .user
                                    ?.id;

                                if (provider.isLoadingMessages(cid) &&
                                    messages.isEmpty) {
                                  return const Center(child: GriotLoader());
                                }

                                return ListView.builder(
                                  controller: scrollController,
                                  reverse: true,
                                  physics: const BouncingScrollPhysics(),
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    20,
                                    16,
                                    20,
                                  ),
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final message = messages[index];
                                    final isMe =
                                        message.senderId == currentUserId;
                                    final startsNewDay =
                                        index == messages.length - 1 ||
                                        !_isSameCalendarDay(
                                          message.createdAt,
                                          messages[index + 1].createdAt,
                                        );

                                    return Column(
                                      children: [
                                        _MessageBubble(
                                          message: message,
                                          isMe: isMe,
                                          isDark: isDark,
                                          colorScheme: colorScheme,
                                          onReply: (m) =>
                                              setState(() => _replyingTo = m),
                                          conversation: currentConversation,
                                        ),
                                        if (startsNewDay)
                                          _DaySeparator(
                                            date: message.createdAt,
                                            colorScheme: colorScheme,
                                          ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),

                          // ==================================================
                          // TYPING INDICATOR & COMPOSER
                          // ==================================================
                          Builder(
                            builder: (context) {
                              final otherUser = currentConversation?.otherUser;
                              final isDM =
                                  currentConversation?.type ==
                                  ConversationType.dm;

                              final typingUsers =
                                  provider.typingUsers[cid] ?? {};

                              final relationship = otherUser != null 
                                  ? provider.getRelationship(otherUser.id) 
                                  : RelationshipState.none;
                              final bool isFriend = relationship == RelationshipState.friends || 
                                                 otherUser?.relationshipStatus == 'friend';
                              final bool isBlockedByMe = relationship == RelationshipState.blocked ||
                                                      (otherUser != null && provider.blockedUserIds.contains(otherUser.id));
                              final bool isBlockedByThem = otherUser?.relationshipStatus == 'blocked_by_user';

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_replyingTo != null)
                                    _buildReplyPreview(
                                      context,
                                      colorScheme,
                                      textTheme,
                                    ),

                                  if (typingUsers.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        0,
                                        16,
                                        8,
                                      ),
                                      child: Row(
                                        children: [
                                          const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Someone is typing...',
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant
                                                      .withValues(alpha: 0.6),
                                                  fontStyle: FontStyle.italic,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  if (isDM && otherUser != null) ...[
                                    if (!isFriend || isBlockedByMe || isBlockedByThem)
                                      _buildClosedComposer(provider, otherUser)
                                    else
                                      _MessageInput(
                                        controller: controller,
                                        colorScheme: colorScheme,
                                        textTheme: textTheme,
                                        onSend: _sendMessage,
                                        onAttachment: _showAttachmentSheet,
                                        isRecording: _isRecording,
                                        isCancelling: _isCancelling,
                                        recordDuration: _recordDuration,
                                        onRecordingMoveUpdate: _onRecordingMoveUpdate,
                                        hasText: _hasText,
                                        onStartRecording: _startRecording,
                                        onStopRecording: _stopRecording,
                                        animation: _recordAnimationController,
                                      ),
                                  ] else
                                    _MessageInput(
                                      controller: controller,
                                      colorScheme: colorScheme,
                                      textTheme: textTheme,
                                      onSend: _sendMessage,
                                      onAttachment: _showAttachmentSheet,
                                      isRecording: _isRecording,
                                      isCancelling: _isCancelling,
                                      recordDuration: _recordDuration,
                                      onRecordingMoveUpdate: _onRecordingMoveUpdate,
                                      hasText: _hasText,
                                      onStartRecording: _startRecording,
                                      onStopRecording: _stopRecording,
                                      animation: _recordAnimationController,
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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

  Widget _buildReplyPreview(
    BuildContext context,
    ColorScheme colors,
    TextTheme text,
  ) {
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
                  style: text.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _replyingTo?.text ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
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
    final colors = Theme.of(context).colorScheme;

    // 1. Blocked by Me
    final isBlockedByMe = provider.blockedUserIds.contains(otherUser.id);
    if (isBlockedByMe) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(color: colors.outline.withValues(alpha: 0.1)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block_rounded,
              color: colors.error.withValues(alpha: 0.5),
              size: 32,
            ),
            const SizedBox(height: 12),
            const Text(
              'User Blocked',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 4),
            const Text(
              'You have blocked this user. Unblock them to resume messaging.',
              style: TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
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

    // 2. Blocked by Them
    final isBlockedByThem = otherUser.relationshipStatus == 'blocked_by_user';
    if (isBlockedByThem) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(color: colors.outline.withValues(alpha: 0.1)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: colors.onSurfaceVariant.withValues(alpha: 0.3),
              size: 32,
            ),
            const SizedBox(height: 12),
            const Text(
              'Messaging Unavailable',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // 3. Not Friends (including Request Pending)
    final receivedReq = provider.receivedRequests
        .where(
          (r) =>
              r.senderId == otherUser.id && r.status == RequestStatus.pending,
        )
        .firstOrNull;

    final sentReq = provider.sentRequests
        .where(
          (r) =>
              r.receiverId == otherUser.id && r.status == RequestStatus.pending,
        )
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: colors.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            receivedReq != null
                ? Icons.waving_hand_rounded
                : Icons.lock_person_rounded,
            color: colors.primary.withValues(alpha: 0.5),
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            receivedReq != null
                ? '${otherUser.effectiveDisplayName} wants to chat!'
                : 'You are no longer friends.',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            receivedReq != null
                ? 'Accept their request to start messaging.'
                : 'Send a new friend request to continue messaging.',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          if (receivedReq != null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => provider.declineRequest(receivedReq.id),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => provider.acceptRequest(receivedReq.id),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            )
          else if (sentReq != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hourglass_top_rounded, size: 18),
                  const SizedBox(width: 10),
                  const Text(
                    'Request Pending',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  try {
                    await provider.sendConnectionRequest(otherUser.id);
                    if (nav.mounted) {
                      NotificationService.showSuccess(
                        nav.context,
                        'Friend request sent',
                      );
                    }
                  } catch (e) {
                    if (nav.mounted) {
                      NotificationService.showError(
                        nav.context,
                        'Failed to send request',
                      );
                    }
                  }
                },
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Send Friend Request'),
              ),
            ),
        ],
      ),
    );
  }
}

// ================================================================
// SHEET HANDLE
// ================================================================

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

// ================================================================
// ATTACHMENT OPTION
// ================================================================

class _AttachmentOption extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final VoidCallback onTap;

  const _AttachmentOption({
    this.icon,
    this.customIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            children: [
              if (customIcon != null)
                SizedBox(width: 24, height: 24, child: customIcon)
              else if (icon != null)
                Icon(icon, color: colorScheme.primary, size: 24),
              const SizedBox(height: 7),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
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
// MESSAGE BUBBLE
// ================================================================

class _DaySeparator extends StatelessWidget {
  final DateTime date;
  final ColorScheme colorScheme;

  const _DaySeparator({required this.date, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final localDate = date.toLocal();
    final today = DateTime.now();
    final todayOnly = DateUtils.dateOnly(today);
    final dateOnly = DateUtils.dateOnly(localDate);
    final label = dateOnly == todayOnly
        ? 'Today'
        : dateOnly == todayOnly.subtract(const Duration(days: 1))
        ? 'Yesterday'
        : DateFormat('d MMMM yyyy').format(localDate);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Divider(color: colorScheme.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Divider(color: colorScheme.outlineVariant)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isDark;
  final ColorScheme colorScheme;
  final Function(ChatMessage) onReply;
  final Conversation? conversation;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.colorScheme,
    required this.onReply,
    this.conversation,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return _buildDeletedBubble(context);
    }

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: isMe
                ? colorScheme.primary
                : colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(isMe ? 22 : 6),
              bottomRight: Radius.circular(isMe ? 6 : 22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: isMe
                ? null
                : Border.all(
                    color: colorScheme.outline.withValues(
                      alpha: isDark ? 0.08 : 0.12,
                    ),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe && conversation?.type == ConversationType.group)
                _buildGroupSenderInfo(context),
              if (message.hasReply) _buildReplyHeader(context),
              _buildMessageText(context),
              if (message.reactions.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildReactions(context),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('HH:mm').format(message.createdAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isMe
                          ? colorScheme.onPrimary.withValues(alpha: 0.7)
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isMe) ...[const SizedBox(width: 4), _buildStatusIcon()],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeletedBubble(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block_rounded,
              size: 14,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Text(
              'This message was deleted',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final provider = context.read<MessagingProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick Reactions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '🔥'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      provider.toggleReaction(message.id, emoji);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply(message);
              },
            ),
            if (isMe)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: colors.error,
                ),
                title: Text(
                  'Delete Message',
                  style: TextStyle(
                    color: colors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy Text'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(context);
                NotificationService.showSuccess(
                  context,
                  'Text copied to clipboard',
                );
              },
            ),
            if (message.mediaUrl != null) ...[
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Download Media'),
                onTap: () async {
                  Navigator.pop(context);
                  await _downloadMedia(context, message.mediaUrl!);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share Media'),
                onTap: () {
                  Navigator.pop(context);
                  SharePlus.instance.share(
                    ShareParams(uri: Uri.parse(message.mediaUrl!)),
                  );
                },
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadMedia(BuildContext context, String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Download failed (${response.statusCode})');
      }
      final directory = await getApplicationDocumentsDirectory();
      final filename = path.basename(Uri.parse(url).path).isEmpty
          ? 'griot_media_${DateTime.now().millisecondsSinceEpoch}'
          : path.basename(Uri.parse(url).path);
      final file = File(path.join(directory.path, filename));
      await file.writeAsBytes(response.bodyBytes, flush: true);
      if (context.mounted) {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], text: 'Downloaded from Griot'),
        );
      }
    } catch (error) {
      if (context.mounted) {
        NotificationService.showError(context, 'Unable to download media');
      }
    }
  }

  void _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (context.mounted == false) return;

    if (confirm == true) {
      try {
        await context.read<MessagingProvider>().deleteMessage(message.id);
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(context, 'Failed to delete message');
        }
      }
    }
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color = colorScheme.onPrimary.withValues(alpha: 0.68);

    switch (message.status) {
      case MessageStatus.sending:
        icon = Icons.access_time_rounded;
        break;
      case MessageStatus.sent:
        // Stored by the server, but not yet confirmed on the recipient device.
        icon = Icons.cloud_upload_outlined;
        break;
      case MessageStatus.delivered:
        // Delivered to the recipient's device, but not opened yet.
        icon = Icons.cloud_done_outlined;
        break;
      case MessageStatus.read:
        // The recipient has opened the conversation and seen the message.
        icon = Icons.visibility_rounded;
        color = Colors.lightBlueAccent;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline_rounded;
        color = colorScheme.error;
        break;
    }

    return Icon(icon, size: 12, color: color);
  }

  Widget _buildGroupSenderInfo(BuildContext context) {
    final provider = context.watch<MessagingProvider>();

    // 1. Try to find in friends
    final friend = provider.friends.firstWhere(
      (f) => f.id == message.senderId,
      orElse: () => const UserModel(id: '', walletAddress: ''),
    );

    String? name = friend.id.isNotEmpty
        ? (friend.displayName ?? friend.username)
        : null;

    // 2. TODO: In the future, fetch from a member cache if not a friend.
    name ??= 'User ${message.senderId.substring(0, 4)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 2),
      child: Text(
        name,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildReplyHeader(BuildContext context) {
    final provider = context.read<MessagingProvider>();
    final parent = provider
        .getMessagesForConversation(message.conversationId)
        .firstWhere(
          (m) => m.id == message.replyToMessageId,
          orElse: () => ChatMessage(
            id: '',
            conversationId: '',
            senderId: '',
            text: 'Original message not found',
            createdAt: DateTime.now(),
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.15)
            : colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white : colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parent.senderId == context.read<UserProvider>().user?.id
                ? 'You'
                : 'Friend',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.8)
                  : colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
          ),
          Text(
            parent.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.6)
                  : colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactions(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: message.reactions.entries.map((entry) {
        final emoji = entry.key;
        final users = entry.value;
        final currentUserId = context.read<UserProvider>().user?.id;
        final hasReacted = users.contains(currentUserId);

        return GestureDetector(
          onTap: () => context.read<MessagingProvider>().toggleReaction(
            message.id,
            emoji,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasReacted
                  ? colorScheme.primary.withValues(alpha: 0.2)
                  : (isMe
                        ? Colors.white.withValues(alpha: 0.1)
                        : colorScheme.primary.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasReacted
                    ? colorScheme.primary.withValues(alpha: 0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 12)),
                if (users.length > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    users.length.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isMe ? Colors.white : colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMessageText(BuildContext context) {
    if (message.type == MessageType.image) {
      return _buildImageContent(context);
    }

    if (message.type == MessageType.video) {
      return _buildVideoContent(context);
    }

    if (message.type == MessageType.file) {
      return _buildFileContent(context);
    }

    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
    );

    final addressRegex = RegExp(r'0x[a-fA-F0-9]{40}');
    final matches = addressRegex.allMatches(message.text);

    if (matches.isEmpty) {
      return Text(message.text, style: textStyle);
    }

    final children = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        children.add(
          TextSpan(
            text: message.text.substring(lastEnd, match.start),
            style: textStyle,
          ),
        );
      }

      final address = match.group(0)!;
      children.add(
        TextSpan(
          text: address,
          style: textStyle?.copyWith(
            color: isMe ? Colors.white : colorScheme.primary,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            decorationColor: isMe
                ? Colors.white.withValues(alpha: 0.5)
                : colorScheme.primary.withValues(alpha: 0.5),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              context.push('/wallet/search', extra: address);
            },
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < message.text.length) {
      children.add(
        TextSpan(text: message.text.substring(lastEnd), style: textStyle),
      );
    }

    return RichText(text: TextSpan(children: children));
  }

  Widget _buildImageContent(BuildContext context) {
    final url = message.mediaUrl;
    if (url == null) return const SizedBox.shrink();

    final isLocal = url.startsWith('/') || url.startsWith('file://');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.status == MessageStatus.failed) _buildRetryOverlay(context),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: isLocal
              ? Image.file(
                  File(url),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                )
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                  placeholder: (context, url) =>
                      const Center(child: GriotLoader(size: 20)),
                  errorWidget: (context, url, error) =>
                      const Center(child: Icon(Icons.error_outline_rounded)),
                ),
        ),
        if (message.text.isNotEmpty && !message.text.startsWith('📷')) ...[
          const SizedBox(height: 8),
          Text(
            message.text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: isMe ? Colors.white : null),
          ),
        ],
      ],
    );
  }

  Widget _buildVideoContent(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white.withValues(alpha: 0.8),
            size: 48,
          ),
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'VIDEO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (message.status == MessageStatus.failed)
            _buildRetryOverlay(context),
        ],
      ),
    );
  }

  Widget _buildFileContent(BuildContext context) {
    final isPdf = message.text.toLowerCase().endsWith('.pdf');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.status == MessageStatus.failed) _buildRetryOverlay(context),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.white.withValues(alpha: 0.1)
                : colorScheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.insert_drive_file_rounded,
                color: isMe ? Colors.white : colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isMe ? Colors.white : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isPdf ? 'PDF Document' : 'File',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isMe
                            ? Colors.white70
                            : colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRetryOverlay(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 14),
          const SizedBox(width: 6),
          Text(
            'Failed to send',
            style: TextStyle(
              color: Colors.red.shade300,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              try {
                await context.read<MessagingProvider>().retryMediaMessage(
                  message,
                );
              } catch (error) {
                if (context.mounted) {
                  NotificationService.showError(
                    context,
                    error.toString().replaceFirst('Exception: ', ''),
                  );
                }
              }
            },
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// MESSAGE INPUT
// ================================================================

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  final VoidCallback onSend;
  final VoidCallback onAttachment;

  final bool isRecording;
  final bool isCancelling;
  final int recordDuration;
  final bool hasText;

  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final Function(LongPressMoveUpdateDetails) onRecordingMoveUpdate;

  final Animation<double> animation;

  const _MessageInput({
    required this.controller,
    required this.colorScheme,
    required this.textTheme,
    required this.onSend,
    required this.onAttachment,
    required this.isRecording,
    required this.isCancelling,
    required this.recordDuration,
    required this.hasText,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onRecordingMoveUpdate,
    required this.animation,
  });

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final textLength = controller.text.length;
    final isLimitExceeded = textLength > 4000;
    final showWarning = textLength > 3500;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showWarning)
            Padding(
              padding: const EdgeInsets.only(right: 60, bottom: 4),
              child: Text(
                '$textLength / 4000',
                style: textTheme.labelSmall?.copyWith(
                  color: isLimitExceeded
                      ? colorScheme.error
                      : colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // ==================================================
                  // ATTACHMENT BUTTON
                  // ==================================================

                  if (!isRecording)
                    _ComposerIconButton(
                      icon: Icons.add_rounded,
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      iconColor: colorScheme.primary,
                      onTap: onAttachment,
                    ),

                  if (!isRecording) const SizedBox(width: 8),

                  // ==================================================
                  // TEXT FIELD / RECORDING UI
                  // ==================================================
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isLimitExceeded
                              ? colorScheme.error
                              : isRecording
                                  ? (isCancelling
                                      ? colorScheme.error
                                      : colorScheme.primary)
                                  : colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                      child: isRecording
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.mic_rounded,
                                    color: isCancelling
                                        ? colorScheme.error
                                        : colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDuration(recordDuration),
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: isCancelling
                                          ? colorScheme.error
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    isCancelling
                                        ? 'Release to cancel'
                                        : 'Slide to cancel <',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: isCancelling
                                          ? colorScheme.error
                                          : colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.7),
                                      fontWeight: isCancelling
                                          ? FontWeight.w900
                                          : FontWeight.normal,
                                    ),
                                  ).animate(
                                    onPlay: (c) => c.repeat(reverse: true),
                                  ).fade(
                                    duration: 800.ms,
                                    begin: 0.3,
                                    end: 1.0,
                                  ),
                                ],
                              ),
                            )
                          : TextField(
                              controller: controller,
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.newline,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // ==================================================
                  // SEND BUTTON
                  // ==================================================
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: hasText
                        ? _FloatingComposerButton(
                            key: const ValueKey('send'),
                            icon: Icons.send_rounded,
                            background: isLimitExceeded
                                ? Colors.grey
                                : colorScheme.primary,
                            foreground: colorScheme.onPrimary,
                            onTap: isLimitExceeded
                                ? () {
                                    NotificationService.showError(
                                      context,
                                      'Message is too long (max 4000 chars)',
                                    );
                                  }
                                : onSend,
                          )
                        : GestureDetector(
                            key: const ValueKey('audio'),
                            onLongPressStart: (_) => onStartRecording(),
                            onLongPressEnd: (_) => onStopRecording(),
                            onLongPressMoveUpdate: onRecordingMoveUpdate,
                            child: Transform.scale(
                              scale: isRecording ? animation.value : 1.0,
                              child: _FloatingComposerButton(
                                icon: isRecording
                                    ? Icons.mic_rounded
                                    : Icons.mic_none_rounded,
                                background: isRecording
                                    ? (isCancelling
                                        ? colorScheme.error
                                        : colorScheme.primary)
                                    : colorScheme.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                foreground: isRecording
                                    ? colorScheme.onPrimary
                                    : colorScheme.primary,
                                onTap: () {},
                              ),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ================================================================
// FLOATING COMPOSER BUTTON
// ================================================================

class _FloatingComposerButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _FloatingComposerButton({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: background.withValues(alpha: 0.35),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Icon(icon, color: foreground, size: 23),
        ),
      ),
    );
  }
}

// ================================================================
// COMPOSER ICON BUTTON
// ================================================================

class _ComposerIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _ComposerIconButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: iconColor, size: 25),
        ),
      ),
    );
  }
}
