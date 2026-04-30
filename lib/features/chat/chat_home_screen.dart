import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:griot_cowrie/core/theme/app_theme_extension.dart';

class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({super.key});

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  late List<ChatUser> users;

  @override
  void initState() {
    super.initState();

    users = mockUsers;

    // sort by latest message
    users.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  String formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);

    if (diff.inMinutes < 1) return "now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    return "${diff.inDays}d";
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
    Theme.of(context).extension<AppThemeExtension>()!;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        title: Text(
          "Griot Chat",
          style: textTheme.bodyLarge,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,

        flexibleSpace: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
        ),

        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add),
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            //  SEARCH BAR
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search chat",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
        
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
        
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
        
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
        
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: appTheme.primaryButton.withValues(alpha: 0.95),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            ),
        
            //  CHAT LIST (FIXED)
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
        
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),

                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage:
                        NetworkImage(user.profileUrl),
                      ),

                      title: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: user.isOnline
                                  ? const Color(0xFFFFD700)
                                  : const Color(0xFFC0C0C0),
                              shape: BoxShape.circle,
                            ),
                          ),

                          const SizedBox(width: 6),

                          Expanded(
                            child: Text(
                              user.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      subtitle: Text(
                        user.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            formatTime(user.timestamp),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),

                          const SizedBox(height: 6),

                          if (user.unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                user.unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),

                      onTap: () {
                        context.push('/chat/${user.id}');
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: "primary_fab",
              backgroundColor:
              appTheme.primaryButton.withValues(alpha: 0.95),
              child: const Icon(Icons.account_balance_wallet, color: Colors.white,),

              onPressed: () => context.go('/wallet'),

            ),

            const SizedBox(height: 12),

            FloatingActionButton(
              heroTag: "secondary_fab",
              backgroundColor:
              appTheme.secondaryButton.withValues(alpha: 0.95),
              child: const Icon(Icons.construction, color: Colors.white,),
               onPressed: () => context.go('/miner'),
            ),
          ],
        ),
      ),
    );
  }
}
class ChatUser {
  final String id;
  final String username;
  final String profileUrl;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final bool isOnline;

  ChatUser({
    required this.id,
    required this.username,
    required this.profileUrl,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    required this.isOnline,
  });
}
final List<ChatUser> mockUsers = [
  ChatUser(
    id: "1",
    username: "Ambassador Joe",
    profileUrl: "https://i.pravatar.cc/150?img=1",
    lastMessage: "Hey, how are you?",
    timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
    unreadCount: 2,
    isOnline: true,
  ),
  ChatUser(
    id: "2",
    username: "Qing_Marcel",
    profileUrl: "https://i.pravatar.cc/150?img=2",
    lastMessage: "Let’s meet tomorrow",
    timestamp: DateTime.now().subtract(const Duration(hours: 3)),
    unreadCount: 0,
    isOnline: false,
  ),
  ChatUser(
    id: "3",
    username: "XperXPerience Richie",
    profileUrl: "https://i.pravatar.cc/150?img=3",
    lastMessage: "Got it ",
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
    unreadCount: 5,
    isOnline: true,
  ),
  ChatUser(
    id: "3",
    username: "Josh",
    profileUrl: "https://i.pravatar.cc/150?img=3",
    lastMessage: "Got it ",
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
    unreadCount: 5,
    isOnline: true,
  ),
];