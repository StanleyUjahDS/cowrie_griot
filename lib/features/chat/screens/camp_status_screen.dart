import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_config.dart';
import '../services/messaging_api_service.dart';
import '../services/media_api_service.dart';

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
  String _styleKey = 'midnight';

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

  Future<void> _publish({String? mediaPath}) async {
    final text = _controller.text.trim();
    if (text.isEmpty && mediaPath == null || _saving) return;
    setState(() => _saving = true);
    final messaging = context.read<MessagingApiService>();
    final mediaService = context.read<MediaApiService>();
    try {
      String? mediaId;
      if (mediaPath != null) {
        final upload = await mediaService.uploadMedia(mediaPath);
        mediaId = upload['id']?.toString();
      }
      await messaging.createCampStatus(
        text: text,
        mediaId: mediaId,
        styleKey: _styleKey,
      );
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

  Future<void> _pickMedia({required bool video}) async {
    final picked = video
        ? await ImagePicker().pickVideo(source: ImageSource.gallery)
        : await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) await _publish(mediaPath: picked.path);
  }

  String? _mediaUrl(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty || raw == 'null') return null;
    if (raw.startsWith('http')) return raw;
    return '${ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '')}${raw.startsWith('/') ? raw : '/$raw'}';
  }

  Future<void> _openStatus(Map<String, dynamic> status) async {
    final id = status['id']?.toString();
    if (id != null) {
      final messaging = context.read<MessagingApiService>();
      await messaging.viewCampStatus(id);
    }
    if (!mounted) return;
    final media = _mediaUrl(status['media_url'] ?? status['mediaUrl']);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${status['display_name'] ?? 'Camp Status'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (media != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(media, fit: BoxFit.cover),
              ),
              const SizedBox(height: 10),
            ],
            Text('${status['text_content'] ?? status['text'] ?? ''}'),
            const SizedBox(height: 8),
            const Text('This Camp Status expires after 24 hours.'),
          ],
        ),
        actions: [
          if (_isOwn)
            TextButton(
              onPressed: () async {
                if (id != null) {
                  await context.read<MessagingApiService>().deleteCampStatus(
                    id,
                  );
                  if (mounted) setState(() => _statuses = _load());
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Delete'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _pickMedia(video: false),
                      icon: const Icon(Icons.photo_outlined),
                      label: const Text('Photo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : () => _pickMedia(video: true),
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('Video'),
                    ),
                    DropdownButton<String>(
                      value: _styleKey,
                      items: const [
                        DropdownMenuItem(
                          value: 'midnight',
                          child: Text('Midnight'),
                        ),
                        DropdownMenuItem(value: 'ocean', child: Text('Ocean')),
                        DropdownMenuItem(
                          value: 'sunset',
                          child: Text('Sunset'),
                        ),
                        DropdownMenuItem(value: 'gold', child: Text('Gold')),
                      ],
                      onChanged: (value) =>
                          setState(() => _styleKey = value ?? 'midnight'),
                    ),
                  ],
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
                    onTap: () => _openStatus(status),
                    leading: Icon(
                      Icons.circle,
                      color: colors.primary,
                      size: 14,
                    ),
                    title: Text(
                      '${status['text_content'] ?? status['text'] ?? 'Media Camp Status'}',
                    ),
                    subtitle: const Text('Expires after 24 hours'),
                    trailing: const Icon(Icons.play_circle_outline_rounded),
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
