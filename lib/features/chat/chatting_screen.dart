import 'package:flutter/material.dart';
import 'package:griot_cowrie/core/theme/app_theme_extension.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  const ChatScreen({super.key, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final List<Message> messages = List.from(mockMessages);

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).extension<AppThemeExtension>()!;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        title: Text("Chat ${widget.userId}"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,

        actions: [
          InkWell(
            onTap: () {
            },
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              "assets/coins_logo/ic_launcher.png",
              width: 50,
              height: 50,
              fit: BoxFit.contain,
            ),
          ),

          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.more_vert),


            offset: const Offset(0, 40),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),

            onSelected: (value) {
              if (value == 'settings') {
                // handle settings
              } else if (value == 'help') {
                // handle help
              }
            },

            itemBuilder: (BuildContext context) => const [
              PopupMenuItem(
                value: 'settings',
                child: Text('Settings'),
              ),
              PopupMenuItem(
                value: 'help',
                child: Text('Help'),
              ),
            ],
          ),
        ],
      ),

      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isDark? appTheme.primaryButton.withValues(alpha: 0.12): appTheme.primaryButton.withValues(alpha: 0.8),
              width: 1,
            ),

            image: DecorationImage(
              image: AssetImage(
                "assets/cowrie_images/real_chat_background.png",
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: Column(
            children: [
              //  MESSAGE LIST
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.isMe;

                    return Align(
                      alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.blueAccent
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.text,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              msg.time,
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),

                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ⌨️ INPUT BAR (FIXED)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Row(
                  children: [

                    // ➕ ATTACH BUTTON
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: appTheme.primaryButton.withValues(alpha: 0.95),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {},
                      ),
                    ),

                    const SizedBox(width: 8),

                    //  TEXT FIELD
                    Expanded(
                      child: Container(
                        padding:  EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color:Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: appTheme.primaryButton.withValues(alpha: 0.95),
                          )
                        ),
                        child: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: "Type a message...",
                            border: InputBorder.none,

                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    //  SEND BUTTON
                    Container(
                      height: 44,
                      width: 44,
                      decoration:  BoxDecoration(
                        shape: BoxShape.circle,
                        color: appTheme.primaryButton.withValues(alpha: 0.95),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.send,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          if (controller.text.trim().isEmpty) return;

                          setState(() {
                            messages.add(
                              Message(
                                text: controller.text.trim(),
                                isMe: true,
                                time: "now",
                              ),
                            );
                            controller.clear();
                          });

                          scrollToBottom();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class Message {
  final String text;
  final bool isMe;
  final String time;

  Message({
    required this.text,
    required this.isMe,
    required this.time,
  });
}

final List<Message> mockMessages = [
  Message(text: "Hey 👋", isMe: false, time: "10:01"),
  Message(text: "Hello!", isMe: true, time: "10:02"),
  Message(text: "How are you?", isMe: false, time: "10:03"),
  Message(text: "I'm good 👍", isMe: true, time: "10:04"),
  Message(text: "What about you?", isMe: true, time: "10:05"),
];