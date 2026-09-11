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
  bool _commentsLocked = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _pickChannelImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
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
        final Map<String, dynamic> uploadResult = await context
            .read<MediaApiService>()
            .uploadMedia(_channelImage!.path);
        imageUrl = uploadResult['mediaUrl']?.toString();
      }

      final conversation = await provider.createChannel(
        name: name,
        username: username,
        description: _descriptionController.text.trim(),
        imageUrl: imageUrl,
        visibility: _visibility,
        commentsLocked: _commentsLocked,
      );

      if (mounted) {
        NotificationService.showSuccess(context, 'Channel created!');
        context.pushReplacement('/conversation/${conversation.id}', extra: conversation);
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to create channel: $e');
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text(
          'New Channel',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isCreating ? null : _createChannel,
              child: Text(
                'Create',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: colors.primary,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickChannelImage,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.15),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _channelImage != null
                            ? Image.file(_channelImage!, fit: BoxFit.cover)
                            : Icon(
                                Icons.add_a_photo_outlined,
                                size: 36,
                                color: colors.primary,
                              ),
                      ),
                    ),
                  ),
                  if (_channelImage != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _pickChannelImage,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: colors.primary,
                          child: Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // 1. Identity Section
            _buildSectionHeader('CHANNEL IDENTITY', colors.primary),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(28),
                border: Border(
                  top: BorderSide(
                    color: colors.primary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  bottom: BorderSide(
                    color: colors.primary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Crypto Updates',
                      filled: true,
                      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: 'e.g. crypto_updates',
                      prefixText: '@',
                      filled: true,
                      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'What will you post about?',
                      filled: true,
                      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 2. Visibility & Permissions
            _buildSectionHeader('VISIBILITY & ACCESS', colors.primary),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(28),
                border: Border(
                  top: BorderSide(
                    color: colors.primary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  bottom: BorderSide(
                    color: colors.primary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _visibility,
                        isExpanded: true,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: colors.primary),
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                        dropdownColor: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        items: const [
                          DropdownMenuItem(
                            value: 'public',
                            child: Text('Public - Anyone can find and join'),
                          ),
                          DropdownMenuItem(
                            value: 'private',
                            child: Text('Private - Invite only'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _visibility = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Lock Comments',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Prevent subscribers from commenting on posts.',
                    ),
                    value: _commentsLocked,
                    onChanged: (val) => setState(() => _commentsLocked = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Channels are for one-to-many broadcasting. Only you and designated admins can post.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: color,
      ),
    );
  }
}
