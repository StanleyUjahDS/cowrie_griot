import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';
import '../services/realtime_call_service.dart';

class JoinCallScreen extends StatefulWidget {
  final String invite;
  const JoinCallScreen({super.key, required this.invite});
  @override
  State<JoinCallScreen> createState() => _JoinCallScreenState();
}

class _JoinCallScreenState extends State<JoinCallScreen> {
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    try {
      final session = await RealtimeCallService(
        context.read<ApiClient>(),
      ).resolveLink(widget.invite);
      if (!mounted) return;
      // Public links do not belong to a conversation. Their room id is the
      // stable destination; group/Campfire links continue to use the
      // conversation id so the existing room context is preserved.
      final id = session.conversationId?.isNotEmpty == true
          ? session.conversationId!
          : session.roomId;
      context.pushReplacement(
        '/calls/$id',
        extra: {
          'type': session.contextType,
          'mode': session.mode,
          'session': session,
          'roomId': session.roomId,
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) => GradientScaffold(
    appBar: AppBar(title: const Text('Join Griot call'), centerTitle: true),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GriotBrandedContainer(
          padding: const EdgeInsets.all(28),
          borderRadius: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _error == null ? Icons.link_rounded : Icons.link_off_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                _error == null ? 'Joining Griot call…' : 'Unable to join call',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (_error == null)
                const CircularProgressIndicator()
              else
                Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );
}
