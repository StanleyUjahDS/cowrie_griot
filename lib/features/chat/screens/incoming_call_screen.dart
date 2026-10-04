import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';
import '../services/realtime_call_service.dart';

class IncomingCallScreen extends StatelessWidget {
  final String conversationId, conversationType, mode, callId;
  final String callerName;
  final String? callerAvatarUrl;
  final String? callerWalletAddress;
  final String? roomId;

  const IncomingCallScreen({
    super.key,
    required this.conversationId,
    required this.conversationType,
    required this.mode,
    required this.callId,
    this.roomId,
    this.callerName = 'Griot contact',
    this.callerAvatarUrl,
    this.callerWalletAddress,
  });

  String get resolvedCallerName {
    final name = callerName.trim();
    if (name.isNotEmpty && name.toLowerCase() != 'griot contact') return name;
    final wallet = callerWalletAddress?.trim() ?? '';
    if (wallet.length > 6)
      return '${wallet.substring(0, 3)}…${wallet.substring(wallet.length - 3)}';
    return name.isEmpty ? 'Griot user' : name;
  }

  Future<void> _decline(BuildContext context) async {
    try {
      await RealtimeCallService(
        context.read<ApiClient>(),
      ).updateStatus(callId, 'declined');
    } catch (_) {}
    if (context.mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(conversationType == 'space' ? '/campfires' : '/chat');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Incoming call'),
        centerTitle: true,
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GriotBrandedContainer(
            padding: const EdgeInsets.all(28),
            borderRadius: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: colors.primary.withValues(alpha: .14),
                  foregroundColor: colors.primary,
                  backgroundImage:
                      callerAvatarUrl != null && callerAvatarUrl!.isNotEmpty
                      ? NetworkImage(callerAvatarUrl!)
                      : null,
                  child: callerAvatarUrl == null || callerAvatarUrl!.isEmpty
                      ? Icon(
                          mode == 'video'
                              ? Icons.videocam_rounded
                              : Icons.phone_in_talk_rounded,
                          size: 48,
                        )
                      : null,
                ),
                const SizedBox(height: 22),
                Text(
                  resolvedCallerName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  mode == 'video'
                      ? 'Incoming video call'
                      : 'Incoming voice call',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.error,
                      ),
                      onPressed: () => _decline(context),
                      icon: const Icon(Icons.call_end_rounded),
                      label: const Text('Decline'),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: () => context.pushReplacement(
                        '/calls/$conversationId',
                        extra: {
                          'type': conversationType,
                          'mode': mode,
                          'roomId': roomId,
                          'callId': callId,
                        },
                      ),
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('Accept'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
