import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChatScreen extends StatefulWidget {
  final String userId;

  const ChatScreen({
    super.key,
    required this.userId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController controller =
  TextEditingController();

  final ScrollController scrollController =
  ScrollController();

  final List<Message> messages =
  List<Message>.from(mockMessages);

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
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      },
    );
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  void _sendMessage() {
    final text = controller.text.trim();

    if (text.isEmpty) return;

    setState(() {
      messages.add(
        Message(
          text: text,
          isMe: true,
          time: 'now',
        ),
      );

      controller.clear();
    });

    _dismissKeyboard();
    _scrollToBottom();
  }

  // ============================================================
  // PROFILE
  // ============================================================

  void _openUserProfile() {
    context.push('/profile/${widget.userId}');
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
                            .withValues(
                          alpha: 0.10,
                        ),
                        border: Border.all(
                          color: colorScheme.primary
                              .withValues(
                            alpha: 0.18,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding:
                        const EdgeInsets.all(
                          13,
                        ),
                        child: Image.asset(
                          'assets/coins_logo/'
                              'ic_launcher.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Tip ${widget.userId}',
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
                              .withValues(
                            alpha: 0.035,
                          ),
                          borderRadius:
                          BorderRadius.circular(
                            18,
                          ),
                          border: Border.all(
                            color: colorScheme
                                .outline
                                .withValues(
                              alpha: 0.10,
                            ),
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
                                    .withValues(
                                  alpha: 0.08,
                                ),
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
                            .withValues(
                          alpha: 0.045,
                        ),
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
                            .withValues(
                          alpha: 0.035,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          20,
                        ),
                        border: Border.all(
                          color: colorScheme
                              .primary
                              .withValues(
                            alpha: 0.12,
                          ),
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
                                      .withValues(
                                    alpha: 0.35,
                                  ),
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
                              .withValues(
                            alpha: 0.055,
                          ),
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
                          //
                          // Recipient:
                          // widget.userId
                          //
                          // Token:
                          // _selectedToken
                          //
                          // Amount:
                          // tokenAmount
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
                            .withValues(
                          alpha: 0.08,
                        ),
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
            onTap: _openUserProfile,
            borderRadius:
            BorderRadius.circular(20),
            child: Row(
              children: [
                Hero(
                  tag:
                  'user_avatar_${widget.userId}',
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin:
                        Alignment.topLeft,
                        end:
                        Alignment.bottomRight,
                        colors: [
                          colorScheme.primary
                              .withValues(
                            alpha: 0.25,
                          ),
                          colorScheme.primary
                              .withValues(
                            alpha: 0.05,
                          ),
                        ],
                      ),
                      border: Border.all(
                        color: colorScheme
                            .primary
                            .withValues(
                          alpha: 0.20,
                        ),
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/cowrie_images/'
                            'profile_placeholder.png',
                        fit: BoxFit.cover,
                        errorBuilder: (
                            context,
                            error,
                            stackTrace,
                            ) {
                          return Icon(
                            Icons
                                .person_outline_rounded,
                            color:
                            colorScheme.primary,
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userId,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration:
                            const BoxDecoration(
                              color: Colors.green,
                              shape:
                              BoxShape.circle,
                            ),
                          ),
                          const SizedBox(
                              width: 5),
                          Text(
                            'online',
                            style: textTheme
                                .labelSmall
                                ?.copyWith(
                              color: colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
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
                    .withValues(
                  alpha: 0.10,
                ),
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
                        8,
                      ),
                      child: Image.asset(
                        'assets/coins_logo/'
                            'ic_launcher.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            PopupMenuButton<String>(
              tooltip: 'More',
              padding: EdgeInsets.zero,
              offset:
              const Offset(0, 48),
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(
                  17,
                ),
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
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .person_outline_rounded,
                      ),
                      SizedBox(width: 12),
                      Text('View profile'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'search',
                  child: Row(
                    children: [
                      Icon(
                          Icons.search_rounded),
                      SizedBox(width: 12),
                      Text(
                          'Search messages'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'mute',
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .notifications_off_outlined,
                      ),
                      SizedBox(width: 12),
                      Text(
                          'Mute notifications'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings_outlined,
                      ),
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
                        Icons.block_rounded,
                        color:
                        colorScheme.error,
                      ),
                      const SizedBox(
                          width: 12),
                      Text(
                        'Block user',
                        style: TextStyle(
                          color:
                          colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                    .withValues(
                  alpha:
                  isDark ? 0.15 : 0.20,
                ),
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
                  child: ListView.builder(
                    controller:
                    scrollController,
                    physics:
                    const BouncingScrollPhysics(),
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior
                        .onDrag,
                    padding:
                    const EdgeInsets
                        .fromLTRB(
                      12,
                      16,
                      12,
                      16,
                    ),
                    itemCount:
                    messages.length,
                    itemBuilder:
                        (context, index) {
                      return _MessageBubble(
                        message:
                        messages[index],
                        isDark: isDark,
                        colorScheme:
                        colorScheme,
                      );
                    },
                  ),
                ),

                // ==================================================
                // COMPOSER
                // ==================================================

                _MessageInput(
                  controller: controller,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onSend: _sendMessage,
                  onAttachment:
                  _showAttachmentSheet,
                  isRecording:
                  _isRecording,
                  hasText: _hasText,
                  onStartRecording:
                  _startRecording,
                  onStopRecording:
                  _stopRecording,
                  animation:
                  _recordAnimationController,
                ),
              ],
            ),
          ),
        ),
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

class _MessageBubble
    extends StatelessWidget {
  final Message message;
  final bool isDark;
  final ColorScheme colorScheme;

  const _MessageBubble({
    required this.message,
    required this.isDark,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;

    return Align(
      alignment: isMe
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin:
        const EdgeInsets.symmetric(
          vertical: 4,
        ),
        padding:
        const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        constraints: BoxConstraints(
          maxWidth:
          MediaQuery.of(context)
              .size
              .width *
              0.76,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? colorScheme.primary
              : colorScheme.surface,
          borderRadius:
          BorderRadius.only(
            topLeft:
            const Radius.circular(18),
            topRight:
            const Radius.circular(18),
            bottomLeft:
            Radius.circular(
              isMe ? 18 : 5,
            ),
            bottomRight:
            Radius.circular(
              isMe ? 5 : 18,
            ),
          ),
          border: isMe
              ? null
              : Border.all(
            color: colorScheme
                .outline
                .withValues(
              alpha:
              isDark
                  ? 0.15
                  : 0.20,
            ),
          ),
          boxShadow: isMe
              ? [
            BoxShadow(
              color: colorScheme
                  .primary
                  .withValues(
                alpha: 0.12,
              ),
              blurRadius: 12,
              offset:
              const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: isMe
                    ? colorScheme
                    .onPrimary
                    : colorScheme
                    .onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment:
              Alignment.centerRight,
              child: Text(
                message.time,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(
                  color: isMe
                      ? colorScheme
                      .onPrimary
                      .withValues(
                    alpha: 0.68,
                  )
                      : colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
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
                        .withValues(
                      alpha: 0.96,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      19,
                    ),
                    border: Border.all(
                      color: isRecording
                          ? colorScheme.error
                          .withValues(
                        alpha: 0.45,
                      )
                          : colorScheme
                          .outline
                          .withValues(
                        alpha: 0.18,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(
                          alpha: 0.06,
                        ),
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
// MESSAGE MODEL
// ================================================================

class Message {
  final String text;
  final bool isMe;
  final String time;

  const Message({
    required this.text,
    required this.isMe,
    required this.time,
  });
}

// ================================================================
// MOCK MESSAGES
// ================================================================

final List<Message> mockMessages = [
  const Message(
    text: 'Hey 👋',
    isMe: false,
    time: '10:01',
  ),
  const Message(
    text: 'Hello!',
    isMe: true,
    time: '10:02',
  ),
  const Message(
    text: 'How are you?',
    isMe: false,
    time: '10:03',
  ),
  const Message(
    text: "I'm good 👍",
    isMe: true,
    time: '10:04',
  ),
  const Message(
    text: 'What about you?',
    isMe: true,
    time: '10:05',
  ),
];