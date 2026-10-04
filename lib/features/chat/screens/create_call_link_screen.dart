import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_client.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';
import '../../../core/services/notification_service.dart';
import '../services/realtime_call_service.dart';

class CreateCallLinkScreen extends StatefulWidget {
  const CreateCallLinkScreen({super.key});

  @override
  State<CreateCallLinkScreen> createState() => _CreateCallLinkScreenState();
}

class _CreateCallLinkScreenState extends State<CreateCallLinkScreen> {
  String _mode = 'voice';
  String? _link;
  bool _loading = false;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _link = null;
    });
    try {
      const type = 'public';
      final link = await RealtimeCallService(context.read<ApiClient>())
          .createLink(
            roomId: 'griot-public-${DateTime.now().microsecondsSinceEpoch}',
            contextType: type,
            mode: _mode,
          );
      if (mounted) setState(() => _link = link);
    } catch (error) {
      if (mounted) _notice('Could not create call link: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notice(String message) {
    final isError = message.toLowerCase().startsWith('could not');
    if (isError) {
      NotificationService.showError(context, message);
    } else {
      NotificationService.showSuccess(context, message);
    }
  }

  Future<void> _copy() async {
    final link = _link;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) _notice('Call link copied');
  }

  Future<void> _share() async {
    final link = _link;
    if (link == null) return;
    await SharePlus.instance.share(
      ShareParams(text: 'Join my Griot call: $link'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Create call link'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          GriotBrandedContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.link_rounded, color: colors.primary, size: 34),
                const SizedBox(height: 12),
                Text(
                  'Invite people to a call',
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'The link works inside Griot and expires automatically after 2 hours.',
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GriotBrandedContainer(
            padding: const EdgeInsets.all(18),
            borderRadius: 18,
            child: const Text(
              'Anyone with this link can join the call. No conversation or group is required.',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Call type',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'voice',
                label: Text('Voice'),
                icon: Icon(Icons.phone_rounded),
              ),
              ButtonSegment(
                value: 'video',
                label: Text('Video'),
                icon: Icon(Icons.videocam_rounded),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (value) => setState(() {
              _mode = value.first;
              _link = null;
            }),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            // Keep the action tappable so the user gets an explanation when
            // no group has been selected instead of a button that appears
            // broken/disabled.
            onPressed: _loading ? null : _generate,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_link_rounded),
            label: Text(_loading ? 'Creating link…' : 'Create call link'),
          ),
          if (_link != null) ...[
            const SizedBox(height: 24),
            GriotBrandedContainer(
              padding: const EdgeInsets.all(18),
              borderRadius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your link is ready',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(_link!, style: text.bodySmall),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copy,
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copy'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _share,
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
