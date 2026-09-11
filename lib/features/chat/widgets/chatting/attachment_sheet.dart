import 'package:flutter/material.dart';
import '../../../../core/services/notification_service.dart';
import 'attachment_option.dart';

class AttachmentSheet extends StatelessWidget {
  final VoidCallback onImage;
  final VoidCallback onCamera;
  final VoidCallback onVideo;
  final VoidCallback onFile;
  final VoidCallback? onLocation;
  final VoidCallback? onContact;
  final VoidCallback? onTip;

  const AttachmentSheet({
    super.key,
    required this.onImage,
    required this.onCamera,
    required this.onVideo,
    required this.onFile,
    this.onLocation,
    this.onContact,
    this.onTip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 40,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              SizedBox(
                width: 85,
                child: AttachmentOption(
                  icon: Icons.image_rounded,
                  label: 'Gallery',
                  onTap: onImage,
                ),
              ),
              SizedBox(
                width: 85,
                child: AttachmentOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: onCamera,
                ),
              ),
              SizedBox(
                width: 85,
                child: AttachmentOption(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  onTap: onVideo,
                ),
              ),
              SizedBox(
                width: 85,
                child: AttachmentOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'File',
                  onTap: onFile,
                ),
              ),
              SizedBox(
                width: 85,
                child: AttachmentOption(
                  icon: Icons.person_add_rounded,
                  label: 'Contact',
                  onTap: onContact ?? () {
                    NotificationService.showInfo(context, 'Contact sharing coming soon!');
                  },
                ),
              ),
              if (onTip != null)
                SizedBox(
                  width: 85,
                  child: AttachmentOption(
                    icon: Icons.volunteer_activism_rounded,
                    label: 'Payment',
                    onTap: onTip!,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
