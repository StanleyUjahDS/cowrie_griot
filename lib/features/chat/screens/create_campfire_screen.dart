import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../services/messaging_api_service.dart';

class CreateCampfireScreen extends StatefulWidget {
  const CreateCampfireScreen({super.key});

  @override
  State<CreateCampfireScreen> createState() => _CreateCampfireScreenState();
}

class _CreateCampfireScreenState extends State<CreateCampfireScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _mode = 'voice';
  bool _recording = false;
  bool _creating = false;
  DateTime? _scheduledAt;

  String _scheduleLabel(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month}/${local.year} at $hour:$minute $period';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _scheduledAt ?? now,
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _scheduledAt == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(_scheduledAt!),
    );
    if (!mounted || time == null) return;
    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!value.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future start time.')),
      );
      return;
    }
    setState(() => _scheduledAt = value);
  }

  Future<void> _create() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a Campfire name first.')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final campfire = await context.read<MessagingApiService>().createCampfire(
            title: _title.text.trim(),
            description: _description.text.trim(),
            mode: _mode,
            regionCode: 'GLOBAL',
            recordingEnabled: _recording,
            scheduledAt: _scheduledAt,
          );
      if (mounted) {
        context.pop(<String, dynamic>{
          'id': campfire['id']?.toString(),
          'mode': campfire['mode']?.toString() ?? _mode,
          'scheduledAt': campfire['scheduled_at'] ?? campfire['scheduledAt'],
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start Campfire: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Create Campfire'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text('Start a conversation', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Bring people together around a topic, story, or idea.'),
            const SizedBox(height: 24),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              decoration: const InputDecoration(labelText: 'Campfire name', hintText: 'What would you like to talk about?', prefixIcon: Icon(Icons.campaign_outlined)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _description,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              decoration: const InputDecoration(labelText: 'Description', hintText: 'Optional context for listeners'),
            ),
            const SizedBox(height: 22),
            Text('Format', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'voice', label: Text('Voice'), icon: Icon(Icons.mic_rounded)),
                ButtonSegment(value: 'video', label: Text('Video'), icon: Icon(Icons.videocam_rounded)),
              ],
              selected: {_mode},
              onSelectionChanged: (value) => setState(() => _mode = value.first),
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _recording,
              onChanged: (value) => setState(() => _recording = value),
              title: const Text('Record this Campfire'),
              subtitle: const Text('Save the conversation for people who cannot join live.'),
              secondary: const Icon(Icons.radio_rounded),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickSchedule,
              icon: Icon(_scheduledAt == null ? Icons.calendar_month_rounded : Icons.event_available_rounded),
              label: Text(_scheduledAt == null ? 'Schedule for later' : 'Starts ${_scheduleLabel(_scheduledAt!)}'),
            ),
            if (_scheduledAt != null)
              TextButton(onPressed: () => setState(() => _scheduledAt = null), child: const Text('Start immediately instead')),
            const SizedBox(height: 28),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _creating ? null : _create,
                icon: _creating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_rounded),
                label: Text(_creating ? 'Starting…' : 'Start Campfire'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
