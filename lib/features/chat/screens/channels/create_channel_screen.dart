import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/messaging_provider.dart';
import '../../services/media_api_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/ui/scaffolds/gradient_scaffold.dart';

class CreateChannelScreen extends StatefulWidget {
  const CreateChannelScreen({super.key});

  @override
  State<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends State<CreateChannelScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _channelImage;
  bool _isCreating = false;
  String _visibility = 'public';

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _pickChannelImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _channelImage = File(pickedFile.path));
    }
  }

  Future<void> _createChannel() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();
    
    if (name.isEmpty) {
      NotificationService.showError(context, 'Please enter a channel name');
      return;
    }
    if (username.isEmpty) {
      NotificationService.showError(context, 'Please enter a unique username');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final provider = context.read<MessagingProvider>();
      String? imageUrl;
      
      if (_channelImage != null) {
        final Map<String, dynamic> uploadResult = await context.read<MediaApiService>().uploadMedia(_channelImage!.path);
        imageUrl = uploadResult['mediaUrl']?.toString();
      }

      final conversation = await provider.createChannel(
        name: name,
        username: username,
      );

      if (imageUrl != null || _descriptionController.text.isNotEmpty || _visibility != 'public') {
        await provider.updateChannel(
          conversation.id, 
          name: name,
          imageUrl: imageUrl,
          description: _descriptionController.text.trim(),
          visibility: _visibility,
        );
      }

      if (mounted) {
        NotificationService.showSuccess(context, 'Channel created!');
        context.pushReplacement('/chat/channels/${conversation.id}', extra: conversation);
      }
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Failed to create channel: $e');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Create Channel', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createChannel,
            child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickChannelImage,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                  ),
                  child: ClipOval(
                    child: _channelImage != null
                        ? Image.file(_channelImage!, fit: BoxFit.cover)
                        : Icon(Icons.add_a_photo_rounded, size: 40, color: colors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildLabel('CHANNEL NAME'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g. Crypto Updates',
                filled: true,
                fillColor: colors.surface.withValues(alpha: 0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 24),
            _buildLabel('USERNAME'),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                hintText: 'e.g. crypto_updates',
                prefixText: '@ ',
                filled: true,
                fillColor: colors.surface.withValues(alpha: 0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 24),
            _buildLabel('DESCRIPTION (OPTIONAL)'),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'What will you post about?',
                filled: true,
                fillColor: colors.surface.withValues(alpha: 0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 24),
            _buildLabel('VISIBILITY'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _visibility,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'public', child: Text('Public - Anyone can find and join')),
                    DropdownMenuItem(value: 'private', child: Text('Private - Invite only')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _visibility = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Channels are for one-to-many broadcasting. Only you and designated admins can post.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    );
  }
}
