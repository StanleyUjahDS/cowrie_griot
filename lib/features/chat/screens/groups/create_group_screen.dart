import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/messaging_provider.dart';
import '../../services/media_api_service.dart';
import '../../../users/models/user_model.dart';
import '../../widgets/friend_selector_sheet.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/ui/scaffolds/gradient_scaffold.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<UserModel> _selectedMembers = [];
  File? _groupImage;
  bool _isCreating = false;
  String _visibility = 'public';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _pickGroupImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _groupImage = File(pickedFile.path));
    }
  }

  void _selectMembers() async {
    final results = await FriendSelectorSheet.show(
      context,
      initialSelectedIds: _selectedMembers.map((m) => m.id).toList(),
      title: 'Select Members',
    );

    if (results != null) {
      setState(() => _selectedMembers = results);
    }
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      NotificationService.showError(context, 'Please enter a group name');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final provider = context.read<MessagingProvider>();
      String? imageUrl;
      
      if (_groupImage != null) {
        final Map<String, dynamic> uploadResult = await context.read<MediaApiService>().uploadMedia(_groupImage!.path);
        imageUrl = uploadResult['mediaUrl']?.toString();
      }

      final conversation = await provider.createGroup(
        name: name,
        memberIds: _selectedMembers.map((m) => m.id).toList(),
        visibility: _visibility,
      );

      if (imageUrl != null) {
        await provider.updateGroup(conversation.id, imageUrl: imageUrl);
      }

      if (mounted) {
        NotificationService.showSuccess(context, 'Group created!');
        context.pushReplacement('/conversation/${conversation.id}', extra: conversation);
      }
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Failed to create group');
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
        title: const Text('New Group', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createGroup,
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
                onTap: _pickGroupImage,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                  ),
                  child: ClipOval(
                    child: _groupImage != null
                        ? Image.file(_groupImage!, fit: BoxFit.cover)
                        : Icon(Icons.add_a_photo_rounded, size: 40, color: colors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text('NAME', style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter group name...',
                filled: true,
                fillColor: colors.surface.withValues(alpha: 0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 24),
            Text('DESCRIPTION (OPTIONAL)', style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'What is this group about?',
                filled: true,
                fillColor: colors.surface.withValues(alpha: 0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 24),
            Text('VISIBILITY', style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
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
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('MEMBERS (${_selectedMembers.length})', style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                TextButton.icon(
                  onPressed: _selectMembers,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Friends'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedMembers.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.people_outline_rounded, color: colors.onSurfaceVariant.withValues(alpha: 0.3), size: 48),
                    const SizedBox(height: 12),
                    Text('No members selected', style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.5))),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedMembers.length,
                itemBuilder: (context, index) {
                  final user = _selectedMembers[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                      child: user.avatarUrl == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(user.displayName ?? user.username ?? 'Griot User', style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red),
                      onPressed: () => setState(() => _selectedMembers.removeAt(index)),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
