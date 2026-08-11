import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final String userId;

  const ChatScreen({
    super.key,
    required this.userId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController controller =
  TextEditingController();

  final ScrollController scrollController =
  ScrollController();

  final List<Message> messages =
  List<Message>.from(mockMessages);

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // SCROLL TO BOTTOM
  // ============================================================

  void _scrollToBottom() {
    Future.delayed(
      const Duration(milliseconds: 100),
          () {
        if (!scrollController.hasClients) return;

        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
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

    _scrollToBottom();
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

    return Scaffold(
      extendBodyBehindAppBar: true,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: Text(
          'Chat ${widget.userId}',
          style: textTheme.titleMedium,
        ),

        backgroundColor:
        Colors.transparent,

        elevation: 0,

        scrolledUnderElevation: 0,

        surfaceTintColor:
        Colors.transparent,

        actions: [
          // ====================================================
          // WALLET / COIN ICON
          // ====================================================

          IconButton(
            tooltip: 'Wallet',
            onPressed: () {},
            icon: Image.asset(
              'assets/coins_logo/ic_launcher.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
          ),

          // ====================================================
          // MORE MENU
          // ====================================================

          PopupMenuButton<String>(
            padding: EdgeInsets.zero,

            offset:
            const Offset(0, 48),

            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(12),
            ),

            onSelected:
                (value) {
              switch (value) {
                case 'settings':
                  break;

                case 'help':
                  break;
              }
            },

            itemBuilder:
                (context) => const [
              PopupMenuItem(
                value: 'settings',
                child:
                Text('Settings'),
              ),

              PopupMenuItem(
                value: 'help',
                child:
                Text('Help'),
              ),
            ],
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SafeArea(
        child: Container(
          margin:
          const EdgeInsets.only(
            left: 8,
            right: 8,
            bottom: 8,
          ),

          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(24),

            border: Border.all(
              color: colorScheme.primary
                  .withValues(
                alpha:
                isDark ? 0.15 : 0.20,
              ),
              width: 1,
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
              // MESSAGE LIST
              // ==================================================

              Expanded(
                child:
                ListView.builder(
                  controller:
                  scrollController,

                  padding:
                  const EdgeInsets
                      .fromLTRB(
                    12,
                    16,
                    12,
                    12,
                  ),

                  itemCount:
                  messages.length,

                  itemBuilder:
                      (context, index) {
                    final message =
                    messages[index];

                    return _MessageBubble(
                      message:
                      message,
                      isDark:
                      isDark,
                      colorScheme:
                      colorScheme,
                    );
                  },
                ),
              ),

              // ==================================================
              // INPUT BAR
              // ==================================================

              _MessageInput(
                controller:
                controller,

                colorScheme:
                colorScheme,

                textTheme:
                textTheme,

                onSend:
                _sendMessage,

                onAttachment:
                    () {},
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
  final Message message;
  final bool isDark;
  final ColorScheme colorScheme;

  const _MessageBubble({
    required this.message,
    required this.isDark,
    required this.colorScheme,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final isMe =
        message.isMe;

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

        constraints:
        BoxConstraints(
          maxWidth:
          MediaQuery.of(context)
              .size
              .width *
              0.75,
        ),

        decoration:
        BoxDecoration(
          // ====================================================
          // SENT MESSAGE = GOLD
          // RECEIVED MESSAGE = THEME SURFACE
          // ====================================================

          color: isMe
              ? colorScheme.primary
              : colorScheme.surface,

          borderRadius:
          BorderRadius.only(
            topLeft:
            const Radius.circular(
              16,
            ),

            topRight:
            const Radius.circular(
              16,
            ),

            bottomLeft:
            Radius.circular(
              isMe ? 16 : 4,
            ),

            bottomRight:
            Radius.circular(
              isMe ? 4 : 16,
            ),
          ),

          border: isMe
              ? null
              : Border.all(
            color:
            colorScheme.outline
                .withValues(
              alpha:
              isDark
                  ? 0.15
                  : 0.20,
            ),
          ),
        ),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            // ==================================================
            // MESSAGE TEXT
            // ==================================================

            Text(
              message.text,

              style:
              Theme.of(context)
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

            const SizedBox(
              height: 4,
            ),

            // ==================================================
            // MESSAGE TIME
            // ==================================================

            Text(
              message.time,

              style:
              Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(
                color: isMe
                    ? colorScheme
                    .onPrimary
                    .withValues(
                  alpha: 0.70,
                )
                    : colorScheme
                    .onSurfaceVariant,
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

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onSend;
  final VoidCallback onAttachment;

  const _MessageInput({
    required this.controller,
    required this.colorScheme,
    required this.textTheme,
    required this.onSend,
    required this.onAttachment,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        10,
        8,
        10,
        10,
      ),

      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.end,

        children: [
          // ====================================================
          // ATTACHMENT BUTTON
          // ====================================================

          Material(
            color:
            colorScheme.primary,

            borderRadius:
            BorderRadius.circular(
              14,
            ),

            child: InkWell(
              borderRadius:
              BorderRadius.circular(
                14,
              ),

              onTap:
              onAttachment,

              child: const SizedBox(
                width: 46,
                height: 46,

                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          // ====================================================
          // TEXT FIELD
          // ====================================================

          Expanded(
            child: Container(
              constraints:
              const BoxConstraints(
                minHeight: 46,
              ),

              decoration:
              BoxDecoration(
                color: colorScheme
                    .surface
                    .withValues(
                  alpha: 0.94,
                ),

                borderRadius:
                BorderRadius.circular(
                  16,
                ),

                border: Border.all(
                  color: colorScheme
                      .outline
                      .withValues(
                    alpha: 0.20,
                  ),
                ),
              ),

              child: TextField(
                controller:
                controller,

                minLines: 1,

                maxLines: 5,

                textInputAction:
                TextInputAction.newline,

                style:
                textTheme.bodyMedium,

                decoration:
                InputDecoration(
                  hintText:
                  'Type a message...',

                  hintStyle:
                  textTheme.bodyMedium
                      ?.copyWith(
                    color: colorScheme
                        .onSurfaceVariant,
                  ),

                  border:
                  InputBorder.none,

                  contentPadding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          // ====================================================
          // SEND BUTTON
          // ====================================================

          Material(
            color:
            colorScheme.primary,

            shape:
            const CircleBorder(),

            child: InkWell(
              customBorder:
              const CircleBorder(),

              onTap:
              onSend,

              child: const SizedBox(
                width: 46,
                height: 46,

                child: Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ),
          ),
        ],
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
  Message(
    text: 'Hey 👋',
    isMe: false,
    time: '10:01',
  ),

  Message(
    text: 'Hello!',
    isMe: true,
    time: '10:02',
  ),

  Message(
    text: 'How are you?',
    isMe: false,
    time: '10:03',
  ),

  Message(
    text: "I'm good 👍",
    isMe: true,
    time: '10:04',
  ),

  Message(
    text: 'What about you?',
    isMe: true,
    time: '10:05',
  ),
];