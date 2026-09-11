import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/messaging_provider.dart';
import '../../services/media_api_service.dart';
import '../../../users/models/user_model.dart';
import '../../../users/providers/user_provider.dart';
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
  final _usernameController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<UserModel> _selectedMembers = [];
  File? _groupImage;
  bool _isCreating = false;
  String _visibility = 'public';
  bool _messagesLocked = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _pickGroupImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() => _groupImage = File(pickedFile.path));
    }
  }

  void _selectMembers() async {
    final currentUserId = context.read<UserProvider>().user?.id;
    final results = await FriendSelectorSheet.show(
      context,
      initialSelectedIds: _selectedMembers.map((m) => m.id).toList(),
      disabledIds: currentUserId != null ? [currentUserId] : [],
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
        final Map<String, dynamic> uploadResult = await context
            .read<MediaApiService>()
            .uploadMedia(_groupImage!.path);
        imageUrl = uploadResult['mediaUrl']?.toString();
      }

      final conversation = await provider.createGroup(
        name: name,
        username: _usernameController.text.trim(),
        description: _descriptionController.text.trim(),
        memberIds: _selectedMembers.map((m) => m.id).toList(),
        visibility: _visibility,
        messagesLocked: _messagesLocked,
      );

      if (imageUrl != null) {
        await provider.updateGroup(conversation.id, imageUrl: imageUrl);
      }

      if (mounted) {
        NotificationService.showSuccess(context, 'Group created!');
        context.pushReplacement(
          '/conversation/${conversation.id}',
          extra: conversation,
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to create group');
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
          'New Circle',
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
                border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isCreating ? null : _createGroup,
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
                    onTap: _pickGroupImage,
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
                        child: _groupImage != null
                            ? Image.file(_groupImage!, fit: BoxFit.cover)
                            : Icon(
                                Icons.add_a_photo_outlined,
                                size: 36,
                                color: colors.primary,
                              ),
                      ),
                    ),
                  ),
                  if (_groupImage != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _pickGroupImage,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: colors.primary,
                          child: Icon(Icons.edit_rounded, size: 16, color: colors.onPrimary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // 1. Identity Section
            _buildSectionHeader(context, 'CIRCLE IDENTITY', colors.primary),
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
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'Enter circle name...',
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
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Username (Optional)',
                      hintText: 'e.g. my-awesome-circle',
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
                      hintText: 'What is this circle about?',
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
            _buildSectionHeader(context, 'VISIBILITY & ACCESS', colors.primary),
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
                            child: Text('Public Circle - Anyone can join'),
                          ),
                          DropdownMenuItem(
                            value: 'private',
                            child: Text('Private Circle - Invite only'),
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
                      'Admins only can send',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Only owners and admins can post messages.',
                    ),
                    value: _messagesLocked,
                    onChanged: (val) => setState(() => _messagesLocked = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 3. Members Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(context, 'MEMBERS (${_selectedMembers.length})', colors.primary),
                TextButton.icon(
                  onPressed: _selectMembers,
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Add Friends', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: _selectedMembers.isEmpty ? const EdgeInsets.all(0) : const EdgeInsets.symmetric(vertical: 8),
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
              child: _selectedMembers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.group_add_outlined,
                          color: colors.primary.withValues(alpha: 0.3),
                          size: 54,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No members yet',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _selectedMembers.length,
                    itemBuilder: (context, index) {
                      final user = _selectedMembers[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundImage: user.avatarUrl != null
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                            child: user.avatarUrl == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            user.displayName ?? user.username ?? 'Griot User',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.remove_circle_outline_rounded,
                              color: colors.error.withValues(alpha: 0.7),
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _selectedMembers.removeAt(index)),
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, Color color) {
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
