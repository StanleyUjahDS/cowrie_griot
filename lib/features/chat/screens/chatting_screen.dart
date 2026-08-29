import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:griot_cowrie/features/chat/providers/messaging_provider.dart';
import 'package:griot_cowrie/features/chat/models/chat_message.dart';
import 'package:griot_cowrie/features/chat/models/chat_user.dart';
import 'package:griot_cowrie/features/chat/models/message_request.dart';
import 'package:griot_cowrie/features/chat/models/conversation_model.dart';
import 'package:griot_cowrie/features/chat/services/messaging_api_service.dart';
import 'package:griot_cowrie/features/users/providers/user_provider.dart';
import 'package:griot_cowrie/core/services/notification_service.dart';
import 'package:griot_cowrie/core/ui/widgets/griot_loader.dart';

class ChatScreen extends StatefulWidget {
  final String? userId;
  final String? conversationId;

  const ChatScreen({
    super.key,
    this.userId,
    this.conversationId,
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
  late final AnimationController _recordAnimationController;

  bool _isRecording = false;
  bool _isUsdInput = false;

  CryptoToken _selectedToken = cryptoTokens.first;

  @override
  void initState() {
    super.initState();

    _recordAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
      lowerBound: 0.92,
      upperBound: 1.08,
    );

    controller.addListener(_onComposerChanged);

    // Initialize Conversation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.conversationId != null) {
        _initConversationById(widget.conversationId!);
      } else if (widget.userId != null) {
        _initDirectConversation();
      }
    });
  }

  Future<void> _initConversationById(String conversationId) async {
    setState(() => _conversationId = conversationId);
    final provider = context.read<MessagingProvider>();
    provider.loadMessages(conversationId, refresh: true);
    
    // Fetch conversation details to show correct header
    try {
      final conversation = await context.read<MessagingApiService>().getConversation(conversationId);
      if (mounted) setState(() => _conversation = conversation);
    } catch (e) {
      debugPrint('Failed to load conversation details: $e');
    }
  }

  Future<void> _initDirectConversation() async {
    try {
      final provider = context.read<MessagingProvider>();
      final conversation = await provider.startDirectChat(widget.userId!);
      
      if (mounted) {
        setState(() {
          _conversationId = conversation.id;
          _conversation = conversation;
        });
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
    controller.removeListener(_onComposerChanged);
    controller.dispose();
    scrollController.dispose();
    _recordAnimationController.dispose();
    super.dispose();
  }

  // ============================================================
  // COMPOSER
  // ============================================================

  void _onComposerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _hasText =>
      controller.text.trim().isNotEmpty;

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
    Future.delayed(
      const Duration(milliseconds: 100),
          () {
        if (!scrollController.hasClients) return;

        scrollController.animateTo(
          scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      },
    );
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage() async {
    final text = controller.text.trim();
    final conversationId = _conversationId;

    if (text.isEmpty || conversationId == null) return;

    final provider = context.read<MessagingProvider>();
    
    // Clear first for better UX
    controller.clear();
    
    try {
      await provider.sendMessage(conversationId, text);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Message failed to send: $e');
      }
    }
  }

  Widget _buildAvatar() {
    final colorScheme = Theme.of(context).colorScheme;
    final otherUser = _conversation?.otherUser;
    
    return Hero(
      tag: 'user_avatar_${widget.userId ?? widget.conversationId}',
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [colorScheme.primary.withValues(alpha: 0.25), colorScheme.primary.withValues(alpha: 0.05)],
          ),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.20)),
        ),
        child: ClipOval(
          child: (otherUser?.profileUrl != null)
            ? Image.network(otherUser!.profileUrl!, fit: BoxFit.cover)
            : SvgPicture.asset(
                'assets/coins_logo/hbadger_logo.svg',
                fit: BoxFit.cover,
                placeholderBuilder: (context) => Icon(Icons.person_outline_rounded, color: colorScheme.primary),
              ),
        ),
      ),
    );
  }

  String _getDisplayName() {
    if (_conversation != null) {
      if (_conversation!.type == ConversationType.dm) {
        return _conversation!.otherUser?.effectiveDisplayName ?? 'User';
      }
      return _conversation!.title ?? (_conversation!.type == ConversationType.group ? 'Group Chat' : 'Channel');
    }
    return 'Chat';
  }

  Widget _buildSubtitle() {
    final theme = Theme.of(context);
    final type = _conversation?.type;
    
    if (type == ConversationType.group || type == ConversationType.channel) {
      return Text(
        type == ConversationType.group ? 'group' : 'channel',
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    final isOnline = _conversation?.otherUser?.isOnline ?? false;
    return Row(
      children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(color: isOnline ? Colors.green : Colors.grey, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          isOnline ? 'online' : 'offline',
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
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

    final provider = context.read<MessagingProvider>();
    final isBlocked = provider.blockedUserIds.contains(otherUser.id);

    try {
      if (isBlocked) {
        await provider.unblockUser(otherUser.id);
        if (mounted) NotificationService.showSuccess(context, 'User unblocked');
      } else {
        await provider.blockUser(otherUser.id);
        if (mounted) NotificationService.showSuccess(context, 'User blocked');
      }
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Failed to update block status');
    }
  }

  // ============================================================
  // AUDIO RECORDING
  // ============================================================

  void _startRecording() {
    if (_isRecording) return;

    _dismissKeyboard();

    setState(() {
      _isRecording = true;
    });

    _recordAnimationController.repeat(
      reverse: true,
    );
  }

  void _stopRecording() {
    if (!_isRecording) return;

    setState(() {
      _isRecording = false;
    });

    _recordAnimationController.stop();
    _recordAnimationController.value = 1;

    // TODO:
    // Connect to actual audio recording service.
  }

  // ============================================================
  // ATTACHMENTS
  // ============================================================

  void _showAttachmentSheet() {
    _dismissKeyboard();

    final colorScheme =
        Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              20,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius:
              BorderRadius.circular(30),
              border: Border.all(
                color: colorScheme.primary
                    .withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: 0.20),
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
                  alignment:
                  Alignment.centerLeft,
                  child: Text(
                    'SHARE',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                      fontWeight:
                      FontWeight.w800,
                      letterSpacing: 1.5,
                      color:
                      colorScheme.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _AttachmentOption(
                        icon:
                        Icons.image_outlined,
                        label: 'Gallery',
                        onTap: () {
                          Navigator.pop(
                            context,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AttachmentOption(
                        icon:
                        Icons.camera_alt_outlined,
                        label: 'Camera',
                        onTap: () {
                          Navigator.pop(
                            context,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AttachmentOption(
                        icon: Icons
                            .insert_drive_file_outlined,
                        label: 'File',
                        onTap: () {
                          Navigator.pop(
                            context,
                          );
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
                        icon: Icons
                            .location_on_outlined,
                        label: 'Location',
                        onTap: () {
                          Navigator.pop(
                            context,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AttachmentOption(
                        icon: Icons
                            .contact_page_outlined,
                        label: 'Contact',
                        onTap: () {
                          Navigator.pop(
                            context,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AttachmentOption(
                        icon: Icons
                            .currency_exchange_rounded,
                        label: 'Payment',
                        onTap: () {
                          Navigator.pop(
                            context,
                          );

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

  void _showTipSheet() {
    _dismissKeyboard();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final amountController =
    TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final input = double.tryParse(
              amountController.text.replaceAll(
                RegExp(r'[^0-9.]'),
                '',
              ),
            );

            final tokenAmount =
            input == null
                ? 0
                : _isUsdInput
                ? input /
                _selectedToken
                    .usdPrice
                : input;

            final usdValue =
                tokenAmount *
                    _selectedToken.usdPrice;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(
                  sheetContext,
                ).viewInsets.bottom,
              ),
              child: Container(
                margin: const EdgeInsets.all(12),
                padding:
                const EdgeInsets.fromLTRB(
                  18,
                  12,
                  18,
                  22,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius:
                  BorderRadius.circular(30),
                  border: Border.all(
                    color: colorScheme.primary
                        .withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: 0.22),
                      blurRadius: 35,
                      offset:
                      const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    const _SheetHandle(),

                    const SizedBox(height: 18),

                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary
                            .withValues(alpha: 0.10),
                        border: Border.all(
                          color: colorScheme.primary
                              .withValues(alpha: 0.18),
                        ),
                      ),
                      child: Padding(
                        padding:
                        const EdgeInsets.all(
                          16,
                        ),
                        child: SvgPicture.asset(
                          'assets/cowrie_images/cowriesvg.svg',
                          fit: BoxFit.contain,
                          colorFilter: ColorFilter.mode(colorScheme.primary, BlendMode.srcIn),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Tip ${_getDisplayName()}',
                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Send crypto directly to this user',
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: colorScheme
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // TOKEN
                    InkWell(
                      borderRadius:
                      BorderRadius.circular(
                        18,
                      ),
                      onTap: () async {
                        final selected =
                        await _showTokenSelector(
                          context,
                          _selectedToken,
                        );

                        if (selected != null) {
                          setSheetState(() {
                            _selectedToken =
                                selected;
                          });
                        }
                      },
                      child: Container(
                        padding:
                        const EdgeInsets.all(
                          12,
                        ),
                        decoration:
                        BoxDecoration(
                          color: colorScheme
                              .onSurface
                              .withValues(alpha: 0.035),
                          borderRadius:
                          BorderRadius.circular(
                            18,
                          ),
                          border: Border.all(
                            color: colorScheme
                                .outline
                                .withValues(alpha: 0.10),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration:
                              BoxDecoration(
                                shape:
                                BoxShape.circle,
                                color: colorScheme
                                    .primary
                                    .withValues(alpha: 0.08),
                              ),
                              child: _selectedToken
                                  .isCowrie
                                  ? Padding(
                                padding:
                                const EdgeInsets
                                    .all(
                                  8,
                                ),
                                child:
                                Image.asset(
                                  'assets/coins_logo/'
                                      'ic_launcher.png',
                                ),
                              )
                                  : Center(
                                child: Text(
                                  _selectedToken
                                      .symbol
                                      .substring(
                                    0,
                                    1,
                                  ),
                                  style:
                                  TextStyle(
                                    fontWeight:
                                    FontWeight
                                        .w900,
                                    color:
                                    colorScheme
                                        .primary,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  Text(
                                    _selectedToken
                                        .name,
                                    style: theme
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                      fontWeight:
                                      FontWeight
                                          .w800,
                                    ),
                                  ),
                                  const SizedBox(
                                      height: 2),
                                  Text(
                                    '${_selectedToken.symbol} • \$${_selectedToken.usdPrice.toStringAsFixed(4)}',
                                    style: theme
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                      color: colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Icon(
                              Icons
                                  .keyboard_arrow_down_rounded,
                              color: colorScheme
                                  .onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // INPUT MODE
                    Container(
                      padding:
                      const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme
                            .onSurface
                            .withValues(alpha: 0.045),
                        borderRadius:
                        BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TipModeButton(
                              label:
                              _selectedToken
                                  .symbol,
                              selected:
                              !_isUsdInput,
                              onTap: () {
                                setSheetState(() {
                                  _isUsdInput =
                                  false;
                                  amountController
                                      .clear();
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: _TipModeButton(
                              label: 'USD',
                              selected:
                              _isUsdInput,
                              onTap: () {
                                setSheetState(() {
                                  _isUsdInput =
                                  true;
                                  amountController
                                      .clear();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // AMOUNT
                    Container(
                      padding:
                      const EdgeInsets.fromLTRB(
                        16,
                        7,
                        16,
                        7,
                      ),
                      decoration:
                      BoxDecoration(
                        color: colorScheme
                            .onSurface
                            .withValues(alpha: 0.035),
                        borderRadius:
                        BorderRadius.circular(
                          20,
                        ),
                        border: Border.all(
                          color: colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (_isUsdInput)
                            Text(
                              '\$',
                              style: theme
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                fontWeight:
                                FontWeight.w800,
                              ),
                            ),
                          Expanded(
                            child: TextField(
                              controller:
                              amountController,
                              autofocus: true,
                              keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                                decimal: true,
                              ),
                              textAlign:
                              TextAlign.center,
                              onChanged: (_) {
                                setSheetState(
                                      () {},
                                );
                              },
                              style: theme
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                fontWeight:
                                FontWeight.w800,
                              ),
                              decoration:
                              InputDecoration(
                                hintText: '0.00',
                                border:
                                InputBorder.none,
                                hintStyle: theme
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                  color: colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                          ),
                          if (!_isUsdInput)
                            Text(
                              _selectedToken
                                  .symbol,
                              style: theme
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                fontWeight:
                                FontWeight.w800,
                                color: colorScheme
                                    .primary,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    if (input != null &&
                        input > 0)
                      Container(
                        width: double.infinity,
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration:
                        BoxDecoration(
                          color: colorScheme
                              .primary
                              .withValues(alpha: 0.055),
                          borderRadius:
                          BorderRadius.circular(
                            15,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _isUsdInput
                                  ? '${tokenAmount.toStringAsFixed(6)} ${_selectedToken.symbol}'
                                  : '\$${usdValue.toStringAsFixed(2)}',
                              style: theme
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                fontWeight:
                                FontWeight.w800,
                                color: colorScheme
                                    .primary,
                              ),
                            ),
                            const SizedBox(
                                height: 3),
                            Text(
                              _isUsdInput
                                  ? 'Estimated token amount'
                                  : 'Estimated USD value',
                              style: theme
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color: colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed:
                        input == null ||
                            input <= 0
                            ? null
                            : () {
                          Navigator.pop(
                            sheetContext,
                          );

                          // TODO:
                          // Connect wallet.
                        },
                        icon: const Icon(
                          Icons
                              .arrow_forward_rounded,
                        ),
                        label:
                        const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(
      amountController.dispose,
    );
  }

  // ============================================================
  // TOKEN SELECTOR
  // ============================================================

  Future<CryptoToken?> _showTokenSelector(
      BuildContext context,
      CryptoToken current,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return showModalBottomSheet<CryptoToken>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            20,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius:
            BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),

              const SizedBox(height: 18),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select token',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              ...cryptoTokens.map(
                    (token) {
                  final selected =
                      token.symbol ==
                          current.symbol;

                  return ListTile(
                    contentPadding:
                    const EdgeInsets.symmetric(
                      horizontal: 4,
                    ),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        16,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(
                        context,
                        token,
                      );
                    },
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme
                            .primary
                            .withValues(alpha: 0.08),
                      ),
                      child: token.isCowrie
                          ? Padding(
                        padding:
                        const EdgeInsets
                            .all(8),
                        child: Image.asset(
                          'assets/coins_logo/'
                              'ic_launcher.png',
                        ),
                      )
                          : Center(
                        child: Text(
                          token.symbol
                              .substring(
                            0,
                            1,
                          ),
                          style: TextStyle(
                            fontWeight:
                            FontWeight
                                .w900,
                            color:
                            colorScheme
                                .primary,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      token.name,
                      style: const TextStyle(
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${token.symbol} • \$${token.usdPrice.toStringAsFixed(4)}',
                    ),
                    trailing: selected
                        ? Icon(
                      Icons
                          .check_circle_rounded,
                      color: colorScheme
                          .primary,
                    )
                        : null,
                  );
                },
              ),
            ],
          ),
        );
      },
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

    final isDark =
        theme.brightness == Brightness.dark;

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
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor:
          Colors.transparent,
          titleSpacing: 0,

          title: InkWell(
            onTap: _conversation?.type == ConversationType.dm ? _openUserProfile : null,
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getDisplayName(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      _buildSubtitle(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          actions: [
            // ==================================================
            // TIP
            // ==================================================

            Padding(
              padding:
              const EdgeInsets.only(
                right: 3,
              ),
              child: Material(
                color: colorScheme.primary
                    .withValues(alpha: 0.10),
                shape:
                const CircleBorder(),
                child: InkWell(
                  customBorder:
                  const CircleBorder(),
                  onTap: _showTipSheet,
                  child: SizedBox(
                    width: 43,
                    height: 43,
                    child: Padding(
                      padding:
                      const EdgeInsets.all(
                        10,
                      ),
                      child: SvgPicture.asset(
                        'assets/cowrie_images/cowriesvg.svg',
                        fit: BoxFit.contain,
                        colorFilter: ColorFilter.mode(colorScheme.primary, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            PopupMenuButton<String>(
              tooltip: 'More',
              padding: EdgeInsets.zero,
              offset: const Offset(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.1), width: 1.5),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'profile':
                    _openUserProfile();
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
                }
              },
              itemBuilder: (context) {
                final provider = context.read<MessagingProvider>();
                final isBlocked = _conversation?.otherUser != null && 
                                 provider.blockedUserIds.contains(_conversation!.otherUser!.id);
                
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
                          isBlocked ? Icons.block_flipped : Icons.block_rounded,
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
            margin: const EdgeInsets.only(
              left: 8,
              right: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              borderRadius:
              BorderRadius.circular(26),
              border: Border.all(
                color: colorScheme.primary
                    .withValues(alpha: isDark ? 0.15 : 0.20),
              ),
              image:
              const DecorationImage(
                image: AssetImage(
                  'assets/cowrie_images/'
                      'real_chat_background.png',
                ),
                fit: BoxFit.cover,
                opacity: 0.9,
              ),
            ),
            child: Column(
              children: [
                // ==================================================
                // MESSAGES
                // ==================================================

                Expanded(
                  child: Consumer<MessagingProvider>(
                    builder: (context, provider, child) {
                      final cid = _conversationId;
                      if (cid == null) {
                        return const Center(child: GriotLoader());
                      }

                      final messages = provider.getMessagesForConversation(cid);
                      final currentUserId = context.watch<UserProvider>().user?.id;

                      if (provider.isLoadingMessages(cid) && messages.isEmpty) {
                        return const Center(child: GriotLoader());
                      }

                      return ListView.builder(
                        controller: scrollController,
                        reverse: true,
                        physics: const BouncingScrollPhysics(),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.senderId == currentUserId;

                          return _MessageBubble(
                            message: message,
                            isMe: isMe,
                            isDark: isDark,
                            colorScheme: colorScheme,
                          );
                        },
                      );
                    },
                  ),
                ),

                // ==================================================
                // COMPOSER
                // ==================================================

                Consumer<MessagingProvider>(
                  builder: (context, provider, child) {
                    final otherUser = _conversation?.otherUser;
                    final isDM = _conversation?.type == ConversationType.dm;
                    
                    if (isDM && otherUser != null) {
                      final isFriend = provider.friends.any((f) => f.id == otherUser.id);
                      if (!isFriend) {
                        return _buildClosedComposer(provider, otherUser);
                      }
                    }

                    return _MessageInput(
                      controller: controller,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                      onSend: _sendMessage,
                      onAttachment: _showAttachmentSheet,
                      isRecording: _isRecording,
                      hasText: _hasText,
                      onStartRecording: _startRecording,
                      onStopRecording: _stopRecording,
                      animation: _recordAnimationController,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClosedComposer(MessagingProvider provider, ChatUser otherUser) {
    final colors = Theme.of(context).colorScheme;
    
    // Requirement 11: Check if blocked
    final isBlocked = provider.blockedUserIds.contains(otherUser.id);
    if (isBlocked) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.95),
          border: Border(top: BorderSide(color: colors.outline.withValues(alpha: 0.1))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_rounded, color: colors.error.withValues(alpha: 0.5), size: 32),
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
    
    // Check for received request
    final receivedReq = provider.receivedRequests.where((r) => 
      r.senderWalletAddress.toLowerCase() == otherUser.walletAddress.toLowerCase() && r.status == RequestStatus.pending
    ).firstOrNull;

    // Check for sent request
    final sentReq = provider.sentRequests.where((r) => 
      r.receiverWalletAddress.toLowerCase() == otherUser.walletAddress.toLowerCase() && r.status == RequestStatus.pending
    ).firstOrNull;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: colors.outline.withValues(alpha: 0.1))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            receivedReq != null ? Icons.waving_hand_rounded : Icons.lock_person_rounded, 
            color: colors.primary.withValues(alpha: 0.5), 
            size: 32
          ),
          const SizedBox(height: 12),
          Text(
            receivedReq != null 
              ? '${otherUser.effectiveDisplayName} wants to chat!' 
              : 'You are not friends yet.',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            receivedReq != null 
              ? 'Accept their request to start messaging.' 
              : 'Connect with this user to start messaging.',
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
                  const Text('Request Pending', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => provider.sendConnectionRequest(otherUser.id),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Connect to Chat'),
              ),
            ),
        ],
      ),
    );
  }
}

// ================================================================
// TOKEN MODEL
// ================================================================

class CryptoToken {
  final String name;
  final String symbol;
  final double usdPrice;
  final String? contractAddress;
  final bool isCowrie;

  const CryptoToken({
    required this.name,
    required this.symbol,
    required this.usdPrice,
    this.contractAddress,
    this.isCowrie = false,
  });
}

// ================================================================
// TOKEN LIST
// ================================================================

const List<CryptoToken> cryptoTokens = [
  CryptoToken(
    name: 'Cowrie',
    symbol: 'COWR',
    usdPrice: 0.10,
    isCowrie: true,
  ),
  CryptoToken(
    name: 'Ethereum',
    symbol: 'ETH',
    usdPrice: 2500.00,
  ),
  CryptoToken(
    name: 'Tether',
    symbol: 'USDT',
    usdPrice: 1.00,
  ),
  CryptoToken(
    name: 'USD Coin',
    symbol: 'USDC',
    usdPrice: 1.00,
  ),
];

// ================================================================
// SHEET HANDLE
// ================================================================

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: colorScheme
            .onSurfaceVariant
            .withValues(alpha: 0.25),
        borderRadius:
        BorderRadius.circular(20),
      ),
    );
  }
}

// ================================================================
// TIP MODE BUTTON
// ================================================================

class _TipModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TipModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration:
        const Duration(milliseconds: 180),
        height: 38,
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : Colors.transparent,
          borderRadius:
          BorderRadius.circular(11),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(
              fontWeight: FontWeight.w800,
              color: selected
                  ? colorScheme.onPrimary
                  : colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// ATTACHMENT OPTION
// ================================================================

class _AttachmentOption
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(18),
        child: Container(
          padding:
          const EdgeInsets.symmetric(
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: colorScheme.primary
                .withValues(alpha: 0.055),
            borderRadius:
            BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.primary
                  .withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: colorScheme.primary,
                size: 24,
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: theme
                    .textTheme
                    .labelSmall
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w700,
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

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isDark;
  final ColorScheme colorScheme;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: isMe ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 5),
            bottomRight: Radius.circular(isMe ? 5 : 18),
          ),
          border: isMe
              ? null
              : Border.all(
                  color: colorScheme.outline.withValues(alpha: isDark ? 0.15 : 0.20),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMessageText(context),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  DateFormat('HH:mm').format(message.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isMe
                            ? colorScheme.onPrimary.withValues(alpha: 0.68)
                            : colorScheme.onSurfaceVariant,
                      ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color = colorScheme.onPrimary.withValues(alpha: 0.68);

    switch (message.status) {
      case MessageStatus.sending:
        icon = Icons.access_time_rounded;
        break;
      case MessageStatus.sent:
        icon = Icons.check_rounded;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all_rounded;
        break;
      case MessageStatus.read:
        icon = Icons.done_all_rounded;
        color = Colors.blueAccent; 
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline_rounded;
        color = colorScheme.error;
        break;
    }

    return Icon(icon, size: 12, color: color);
  }

  Widget _buildMessageText(BuildContext context) {
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
        children.add(TextSpan(
          text: message.text.substring(lastEnd, match.start),
          style: textStyle,
        ));
      }

      final address = match.group(0)!;
      children.add(TextSpan(
        text: address,
        style: textStyle?.copyWith(
          color: isMe ? Colors.white : colorScheme.primary,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
          decorationColor: isMe ? Colors.white.withValues(alpha: 0.5) : colorScheme.primary.withValues(alpha: 0.5),
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            context.push('/wallet/search', extra: address);
          },
      ));

      lastEnd = match.end;
    }

    if (lastEnd < message.text.length) {
      children.add(TextSpan(
        text: message.text.substring(lastEnd),
        style: textStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: children),
    );
  }
}

// ================================================================
// MESSAGE INPUT
// ================================================================

class _MessageInput
    extends StatelessWidget {
  final TextEditingController controller;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  final VoidCallback onSend;
  final VoidCallback onAttachment;

  final bool isRecording;
  final bool hasText;

  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;

  final Animation<double> animation;

  const _MessageInput({
    required this.controller,
    required this.colorScheme,
    required this.textTheme,
    required this.onSend,
    required this.onAttachment,
    required this.isRecording,
    required this.hasText,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        10,
        7,
        10,
        10,
      ),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Row(
            crossAxisAlignment:
            CrossAxisAlignment.end,
            children: [
              // ==================================================
              // ATTACHMENT BUTTON
              // ==================================================

              _ComposerIconButton(
                icon: Icons.add_rounded,
                color: colorScheme.primary
                    .withValues(alpha: 0.12),
                iconColor:
                colorScheme.primary,
                onTap: onAttachment,
              ),

              const SizedBox(width: 8),

              // ==================================================
              // TEXT FIELD
              // ==================================================

              Expanded(
                child: Container(
                  constraints:
                  const BoxConstraints(
                    minHeight: 48,
                  ),
                  decoration:
                  BoxDecoration(
                    color: colorScheme.surface
                        .withValues(alpha: 0.96),
                    borderRadius:
                    BorderRadius.circular(
                      19,
                    ),
                    border: Border.all(
                      color: isRecording
                          ? colorScheme.error
                          .withValues(alpha: 0.45)
                          : colorScheme
                          .outline
                          .withValues(alpha: 0.18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset:
                        const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction:
                    TextInputAction.newline,
                    style:
                    textTheme.bodyMedium,
                    decoration:
                    InputDecoration(
                      hintText: isRecording
                          ? 'Recording audio...'
                          : 'Message...',
                      hintStyle: textTheme
                          .bodyMedium
                          ?.copyWith(
                        color: isRecording
                            ? colorScheme
                            .error
                            : colorScheme
                            .onSurfaceVariant,
                      ),
                      border:
                      InputBorder.none,
                      contentPadding:
                      const EdgeInsets
                          .symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 9),

              // ==================================================
              // FLOATING AUDIO / SEND BUTTON
              // ==================================================

              AnimatedSwitcher(
                duration: const Duration(
                  milliseconds: 220,
                ),
                transitionBuilder:
                    (child, animation) {
                  return ScaleTransition(
                    scale: CurvedAnimation(
                      parent: animation,
                      curve:
                      Curves.easeOutBack,
                    ),
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: hasText
                    ? _FloatingComposerButton(
                  key: const ValueKey(
                    'send',
                  ),
                  icon: Icons
                      .arrow_upward_rounded,
                  background:
                  colorScheme
                      .primary,
                  foreground:
                  colorScheme
                      .onPrimary,
                  onTap: onSend,
                )
                    : GestureDetector(
                  key: const ValueKey(
                    'audio',
                  ),
                  onLongPressStart:
                      (_) {
                    onStartRecording();
                  },
                  onLongPressEnd:
                      (_) {
                    onStopRecording();
                  },
                  child:
                  Transform.scale(
                    scale: isRecording
                        ? animation.value
                        : 1,
                    child:
                    _FloatingComposerButton(
                      icon: isRecording
                          ? Icons
                          .mic_rounded
                          : Icons
                          .mic_none_rounded,
                      background:
                      isRecording
                          ? colorScheme
                          .error
                          : colorScheme
                          .primary,
                      foreground:
                      isRecording
                          ? colorScheme
                          .onError
                          : colorScheme
                          .onPrimary,
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ================================================================
// FLOATING COMPOSER BUTTON
// ================================================================

class _FloatingComposerButton
    extends StatelessWidget {
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
      shadowColor:
      background.withValues(alpha: 0.35),
      child: InkWell(
        customBorder:
        const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Icon(
            icon,
            color: foreground,
            size: 23,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// COMPOSER ICON BUTTON
// ================================================================

class _ComposerIconButton
    extends StatelessWidget {
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
      borderRadius:
      BorderRadius.circular(17),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(17),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: iconColor,
            size: 25,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// MESSAGE MODEL (OBSOLETE - REMOVE IF NOT USED ELSEWHERE)
// ================================================================
