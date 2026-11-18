import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_config.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';
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

  Future<void> _showComposer() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          4,
          18,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Camp Status',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Visible in Camp for 24 hours',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                maxLength: 500,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Share what is happening in your Camp…',
                  border: OutlineInputBorder(),
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => _pickMedia(video: false),
                    icon: const Icon(Icons.photo_outlined),
                    label: const Text('Photo'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => _pickMedia(video: true),
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Video'),
                  ),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _styleKey,
                    items: const [
                      DropdownMenuItem(
                        value: 'midnight',
                        child: Text('Midnight'),
                      ),
                      DropdownMenuItem(value: 'ocean', child: Text('Ocean')),
                      DropdownMenuItem(value: 'sunset', child: Text('Sunset')),
                      DropdownMenuItem(value: 'gold', child: Text('Gold')),
                    ],
                    onChanged: (value) =>
                        setSheetState(() => _styleKey = value ?? 'midnight'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _publish(),
                  icon: const Icon(Icons.publish_rounded),
                  label: const Text('Publish Camp Status'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() => _statuses = _load());
  }

  Widget _statusTile(BuildContext context, Map<String, dynamic> status) {
    final colors = Theme.of(context).colorScheme;
    final media = _mediaUrl(status['media_url'] ?? status['mediaUrl']);
    final text = '${status['text_content'] ?? status['text'] ?? ''}'.trim();
    return SizedBox(
      width: 158,
      height: 220,
      child: InkWell(
        onTap: () => _openStatus(status),
        borderRadius: BorderRadius.circular(20),
        child: GriotBrandedContainer(
          padding: EdgeInsets.zero,
          borderRadius: 20,
          backgroundColor: colors.surfaceContainerHighest,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (media != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(media, fit: BoxFit.cover),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primaryContainer,
                        colors.tertiaryContainer,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  alignment: Alignment.center,
                  child: Text(
                    text.isEmpty ? 'Camp Status' : text,
                    maxLines: 7,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: .78),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Text(
                  text.isEmpty ? 'Camp Status' : text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Camp Status'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isOwn)
            IconButton(
              tooltip: 'Publish Camp Status',
              onPressed: _saving ? null : _showComposer,
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
        ],
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _statuses,
        builder: (context, snapshot) {
          final statuses = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              GriotBrandedContainer(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                borderRadius: 22,
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: colors.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Camp updates',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '24h',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_isOwn)
                OutlinedButton.icon(
                  onPressed: _saving ? null : _showComposer,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Share a Camp Status'),
                ),
              const SizedBox(height: 18),
              Text(
                statuses.isEmpty
                    ? 'No active Camp Status'
                    : 'Active Camp Status',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (statuses.isNotEmpty)
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: statuses.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) =>
                        _statusTile(context, statuses[index]),
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
