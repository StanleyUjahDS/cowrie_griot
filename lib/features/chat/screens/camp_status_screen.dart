import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/messaging_api_service.dart';

class CampStatusScreen extends StatefulWidget {
  const CampStatusScreen({super.key, this.profileUserId});

  final String? profileUserId;

  @override
  State<CampStatusScreen> createState() => _CampStatusScreenState();
}

class _CampStatusScreenState extends State<CampStatusScreen> {
  final _controller = TextEditingController();
  late Future<List<Map<String, dynamic>>> _statuses;
  bool _saving = false;

  bool get _isOwn =>
      widget.profileUserId == null || widget.profileUserId == 'me';

  @override
  void initState() {
    super.initState();
    _statuses = _load();
  }

  Future<List<Map<String, dynamic>>> _load() => context
      .read<MessagingApiService>()
      .getCampStatuses(widget.profileUserId ?? 'me');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await context.read<MessagingApiService>().createCampStatus(text: text);
      _controller.clear();
      setState(() => _statuses = _load());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not publish Camp Status: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camp Status'),
        actions: [
          if (_isOwn)
            IconButton(
              tooltip: 'Publish Camp Status',
              onPressed: _saving ? null : _publish,
              icon: const Icon(Icons.send_rounded),
            ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _statuses,
        builder: (context, snapshot) {
          final statuses = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (_isOwn) ...[
                TextField(
                  controller: _controller,
                  maxLength: 500,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'What is happening in your Camp?',
                    hintText: 'Share an update that lasts 24 hours',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _publish,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.publish_rounded),
                  label: const Text('Publish Camp Status'),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                statuses.isEmpty
                    ? 'No active Camp Status'
                    : 'Active Camp Status',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              ...statuses.map(
                (status) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(
                      Icons.circle,
                      color: colors.primary,
                      size: 14,
                    ),
                    title: Text(
                      '${status['text_content'] ?? status['text'] ?? 'Media Camp Status'}',
                    ),
                    subtitle: const Text('Expires after 24 hours'),
                  ),
                ),
              ),
              if (snapshot.hasError)
                const Text('Camp Status could not be loaded right now.'),
            ],
          );
        },
      ),
    );
  }
}
