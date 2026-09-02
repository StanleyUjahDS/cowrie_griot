import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/messaging_provider.dart';
import '../services/media_api_service.dart';
import 'chatting/tip_sheet.dart';

class ChatDrawer extends StatelessWidget {
  const ChatDrawer({super.key});

  void _openNewChat(BuildContext context) => context.push('/chat/discover');
  void _openFriends(BuildContext context) => context.push('/chat/friends');
  void _openRequests(BuildContext context) => context.push('/chat/requests');

  void _showCreateChannelSheet(BuildContext context) {
    final controller = TextEditingController();
    final usernameController = TextEditingController();
    File? selectedImage;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Image Picker
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70,
                          );
                          if (picked != null) {
                            setSheetState(
                              () => selectedImage = File(picked.path),
                            );
                          }
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.1),
                            ),
                          ),
                          child: ClipOval(
                            child:
                                selectedImage != null
                                    ? Image.file(selectedImage!, fit: BoxFit.cover)
                                    : Icon(
                                      Icons.add_a_photo_rounded,
                                      color: colors.primary,
                                      size: 28,
                                    ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.sensors_rounded,
                            color: colors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Channel',
                              style: text.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Broadcast stories to the network',
                              style: text.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: 'Enter channel name...',
                        filled: true,
                        fillColor: colors.surfaceContainerLow.withValues(
                          alpha: 0.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: colors.outline.withValues(alpha: 0.1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: colors.outline.withValues(alpha: 0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: colors.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: usernameController,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Choose a unique @username',
                        prefixText: '@',
                        filled: true,
                        fillColor: colors.surfaceContainerLow.withValues(
                          alpha: 0.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: colors.outline.withValues(alpha: 0.1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: colors.outline.withValues(alpha: 0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: colors.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: FilledButton(
                        onPressed: () async {
                          final name = controller.text.trim();
                          final username = usernameController.text.trim().toLowerCase();
                          if (name.isEmpty || username.isEmpty) return;
                          
                          try {
                            final provider = context.read<MessagingProvider>();

                            String? imageUrl;
                            if (selectedImage != null) {
                              final Map<String, dynamic> uploadResult =
                                  await context
                                      .read<MediaApiService>()
                                      .uploadMedia(selectedImage!.path);
                              imageUrl = uploadResult['mediaUrl']?.toString();
                            }

                            final conversation = await provider.createChannel(
                              name: name,
                              username: username,
                            );

                            if (imageUrl != null) {
                              await provider.updateChannel(
                                conversation.id,
                                imageUrl: imageUrl,
                              );
                            }

                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                              // Navigate to the new channel feed
                              context.push('/conversation/${conversation.id}', extra: conversation);
                            }
                          } catch (_) {}
                        },
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 8,
                          shadowColor: colors.primary.withValues(alpha: 0.3),
                        ),
                        child: const Text(
                          'LAUNCH CHANNEL',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.75,
      child: Material(
        color: colors.surface,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
            border: Border(
              right: BorderSide(
                color: colors.primary.withValues(alpha: 0.08),
                width: 1.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 40,
                offset: const Offset(10, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Premium Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 72, 28, 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SvgPicture.asset(
                        'assets/cowrie_images/cowriesvg.svg',
                        width: 36,
                        height: 36,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Griot',
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                      ),
                    ),
                    Text(
                      'Decentralized Social Network',
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Navigation
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _tile(context, Icons.search_rounded, 'Discover', () {
                      Navigator.pop(context);
                      _openNewChat(context);
                    }),
                    _tile(context, Icons.people_rounded, 'Friends', () {
                      Navigator.pop(context);
                      _openFriends(context);
                    }),
                    Consumer<MessagingProvider>(
                      builder: (context, provider, _) {
                        final count = provider.pendingRequestCount;
                        return _tile(
                          context,
                          Icons.mail_rounded,
                          'Requests',
                          () {
                            Navigator.pop(context);
                            _openRequests(context);
                          },
                          badge: count > 0 ? count.toString() : null,
                        );
                      },
                    ),
                    _tile(
                      context,
                      null,
                      'Tip Jar',
                      () {
                        Navigator.pop(context);
                        TipSheet.show(context, recipients: []);
                      },
                      customLeading: SvgPicture.asset(
                        'assets/cowrie_images/cowriesvg.svg',
                        width: 22,
                        height: 22,
                        colorFilter: ColorFilter.mode(
                          colors.onSurface.withValues(alpha: 0.6),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 12,
                      ),
                      child: Divider(height: 1, thickness: 0.5),
                    ),

                    _tile(
                      context,
                      Icons.add_circle_outline_rounded,
                      'Start Group',
                      () {
                        Navigator.pop(context);
                        context.push('/chat/groups/create');
                      },
                      isAction: true,
                    ),
                    _tile(context, Icons.sensors_rounded, 'Launch Channel', () {
                      _showCreateChannelSheet(context);
                    }, isAction: true),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData? icon,
    String label,
    VoidCallback onTap, {
    String? badge,
    Widget? customLeading,
    bool isAction = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        onTap: onTap,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading:
            customLeading ??
            (icon != null
                ? Icon(
                    icon,
                    color: isAction
                        ? colors.primary
                        : colors.onSurface.withValues(alpha: 0.7),
                    size: 22,
                  )
                : null),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isAction ? FontWeight.w800 : FontWeight.w700,
            fontSize: 15,
            color: isAction
                ? colors.primary
                : colors.onSurface.withValues(alpha: 0.9),
          ),
        ),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        hoverColor: colors.primary.withValues(alpha: 0.05),
      ),
    );
  }
}
// Clean version
