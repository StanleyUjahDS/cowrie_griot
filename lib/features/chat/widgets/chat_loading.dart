import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../models/chat_user.dart';
import 'chat_list_item.dart';

class ChatLoading extends StatelessWidget {
  const ChatLoading({super.key});

  static final _dummyUser = ChatUser(
    id: 'loading',
    walletAddress: '0x0000...0000',
    displayName: 'User Display Name',
    username: 'username',
    lastMessage: 'This is a long message for loading skeleton',
    timestamp: DateTime.now(),
    unreadCount: 0,
    isOnline: false,
  );

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 116, bottom: 170),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 10,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 80,
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
        ),
        itemBuilder: (context, index) {
          return ChatListItem(
            user: _dummyUser,
            time: '00:00',
          );
        },
      ),
    );
  }
}
