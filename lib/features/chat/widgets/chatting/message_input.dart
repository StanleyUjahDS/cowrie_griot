import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/services/notification_service.dart';
import 'floating_composer_button.dart';
import 'composer_icon_button.dart';

class MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  final VoidCallback onSend;
  final VoidCallback onAttachment;
  final VoidCallback onCamera;
  final VoidCallback onMicTap;
  final bool hasText;

  const MessageInput({
    super.key,
    required this.controller,
    required this.colorScheme,
    required this.textTheme,
    required this.onSend,
    required this.onAttachment,
    required this.onCamera,
    required this.onMicTap,
    required this.hasText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final textLength = controller.text.length;
    final isLimitExceeded = textLength > 4000;
    final showWarning = textLength > 3500;

    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.6),
                width: 1.5,
              ),
              bottom: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (showWarning)
                Padding(
                  padding: const EdgeInsets.only(right: 60, bottom: 6),
                  child: Text(
                    '$textLength / 4000',
                    style: textTheme.labelSmall?.copyWith(
                      color: isLimitExceeded
                          ? colorScheme.error
                          : colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ComposerIconButton(
                    icon: Icons.add_rounded,
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    iconColor: colorScheme.primary,
                    onTap: onAttachment,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withValues(
                          alpha: 0.04,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isLimitExceeded
                              ? colorScheme.error.withValues(alpha: 0.5)
                              : colorScheme.outline.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              minLines: 1,
                              maxLines: 6,
                              textInputAction: TextInputAction.newline,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Message...',
                                hintStyle: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.4,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          if (!hasText)
                            IconButton(
                              icon: Icon(
                                Icons.camera_alt_outlined,
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                                size: 22,
                              ),
                              onPressed: onCamera,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: hasText
                        ? FloatingComposerButton(
                            key: const ValueKey('send'),
                            icon: Icons.arrow_upward_rounded,
                            background: isLimitExceeded
                                ? colorScheme.outline.withValues(
                                    alpha: 0.2,
                                  )
                                : colorScheme.primary,
                            foreground: colorScheme.onPrimary,
                            onTap: isLimitExceeded
                                ? () {
                                    NotificationService.showError(
                                      context,
                                      'Message is too long',
                                    );
                                  }
                                : onSend,
                          )
                        : FloatingComposerButton(
                            key: const ValueKey('audio'),
                            icon: Icons.mic_rounded,
                            background: colorScheme.surface,
                            foreground: colorScheme.primary,
                            onTap: onMicTap,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
