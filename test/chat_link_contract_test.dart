import 'package:flutter_test/flutter_test.dart';
import 'package:griot_cowrie/core/services/share_link_service.dart';
import 'package:griot_cowrie/core/ui/screens/public_deep_link_recovery_screen.dart';
import 'package:griot_cowrie/features/chat/models/chat_message.dart';
import 'package:griot_cowrie/features/chat/models/conversation_model.dart';
import 'package:griot_cowrie/features/users/models/user_model.dart';

void main() {
  group('public share-link contract', () {
    final now = DateTime.utc(2026, 9, 14);

    test('profile links remove display-only at signs', () {
      const user = UserModel(
        id: 'user-id',
        walletAddress: '0x1234',
        username: '@Stargie',
      );

      expect(
        ShareLinkService.profile(user),
        'https://griot.network/profile/Stargie',
      );
    });

    test('group and channel links use their matching route type', () {
      final group = Conversation(
        id: 'group-id',
        type: ConversationType.group,
        memberIds: const [],
        username: '@builders',
        updatedAt: now,
        createdAt: now,
      );
      final channel = Conversation(
        id: 'channel-id',
        type: ConversationType.channel,
        memberIds: const [],
        username: 'news',
        updatedAt: now,
        createdAt: now,
      );

      expect(
        ShareLinkService.conversation(group),
        'https://griot.network/group/builders',
      );
      expect(
        ShareLinkService.conversation(channel),
        'https://griot.network/channel/news',
      );
    });

    test('HTTPS and custom-scheme public links are recoverable', () {
      expect(
        PublicDeepLinkRecoveryScreen.supports(
          Uri.parse('https://griot.network/profile/stargie'),
        ),
        isTrue,
      );
      expect(
        PublicDeepLinkRecoveryScreen.supports(
          Uri.parse('griot://profile/stargie'),
        ),
        isTrue,
      );
      expect(
        PublicDeepLinkRecoveryScreen.supports(
          Uri.parse('griot://channel/web3_minds'),
        ),
        isTrue,
      );
    });
  });

  test(
    'message JSON preserves idempotency, reply, and local timestamp data',
    () {
      final message = ChatMessage.fromJson({
        'id': 'server-id',
        'conversation_id': 'conversation-id',
        'sender_id': 'sender-id',
        'content': 'hello',
        'message_type': 'text',
        'client_message_id': 'client_123',
        'reply_to_message_id': 'parent-id',
        'created_at': '2026-09-14T01:30:00.000Z',
      });

      expect(message.clientMessageId, 'client_123');
      expect(message.replyToMessageId, 'parent-id');
      expect(message.createdAt.isUtc, isFalse);
      expect(message.toJson()['clientMessageId'], 'client_123');
      expect(message.toJson()['replyToMessageId'], 'parent-id');
    },
  );
}
