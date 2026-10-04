import 'dart:io';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/messaging_provider.dart';
import '../../models/chat_message.dart';
import '../../models/chat_user.dart';
import '../../models/conversation_model.dart';
import '../../utils/tip_display.dart';
import '../../../users/models/user_model.dart';
import '../../../users/providers/user_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/ui/widgets/griot_loader.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/deep_link_service.dart';
import 'audio_player_widget.dart';
import 'video_player_widget.dart';
import 'fullscreen_media_viewer.dart';
import 'link_preview_widget.dart';
import 'message_status.dart';
import 'report_content_sheet.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isDark;
  final ColorScheme colorScheme;
  final Function(ChatMessage) onReply;
  final Conversation? conversation;
  final ChatUser? sender;
  final VoidCallback? onSenderTap;
  final VoidCallback? onReplyTap;
  final bool isHighlighted;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.colorScheme,
    required this.onReply,
    this.conversation,
    this.sender,
    this.onSenderTap,
    this.onReplyTap,
    this.isHighlighted = false,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return _buildDeletedBubble(context);
    }

    final double topRadius = isFirstInGroup ? 22 : 6;
    final double bottomRadius = isLastInGroup ? 22 : 6;
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(isMe ? 22 : topRadius),
      topRight: Radius.circular(isMe ? topRadius : 22),
      bottomLeft: Radius.circular(isMe ? 22 : bottomRadius),
      bottomRight: Radius.circular(isMe ? bottomRadius : 22),
    );

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: isLastInGroup
              ? (message.reactions.isNotEmpty ? 15.0 : 10.0)
              : (message.reactions.isNotEmpty ? 10.0 : 2.5),
          top: isFirstInGroup ? 4 : 0,
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isMe &&
                  isFirstInGroup &&
                  conversation?.type == ConversationType.group)
                _buildGroupSenderInfo(context),

              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                      minWidth: 60,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerLow,
                      borderRadius: borderRadius,
                      border: isHighlighted
                          ? Border.all(color: colorScheme.secondary, width: 2)
                          : Border.all(
                              color: isMe
                                  ? colorScheme.primary.withValues(alpha: 0.18)
                                  : colorScheme.outline.withValues(
                                      alpha: isDark ? 0.16 : 0.24,
                                    ),
                              width: 0.7,
                            ),
                      boxShadow: [
                        // Keep every bubble lifted from the wallpaper. The
                        // old treatment only shadowed the last bubble in a
                        // group, which made earlier bubbles disappear into
                        // patterned/light backgrounds.
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.30 : 0.14,
                          ),
                          blurRadius: isLastInGroup ? 9 : 6,
                          spreadRadius: isLastInGroup ? 0.4 : 0,
                          offset: Offset(0, isLastInGroup ? 3 : 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.hasReply) _buildReplyHeader(context),
                        _buildMessageText(context),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(message.createdAt),
                              style: TextStyle(
                                color: isMe
                                    ? colorScheme.onPrimary.withValues(
                                        alpha: 0.7,
                                      )
                                    : colorScheme.onSurfaceVariant.withValues(
                                        alpha: 0.6,
                                      ),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              _buildStatusIcon(),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (message.reactions.isNotEmpty)
                    Positioned(
                      bottom: -11,
                      right: isMe ? 12 : null,
                      left: isMe ? null : 12,
                      child: _buildReactions(context),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeletedBubble(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block_rounded,
              size: 14,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Text(
              'This message was deleted',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(BuildContext context) {
    // Keep the parent chat context. The bottom-sheet builder context is
    // disposed as soon as an option closes the sheet and must not be reused
    // for the confirmation dialog or provider actions.
    final parentContext = context;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currentUserId = context.read<UserProvider>().user?.id;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Quick Reactions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '🔥'].map((emoji) {
                  final hasReacted =
                      message.reactions[emoji]?.contains(currentUserId) ??
                      false;
                  return GestureDetector(
                    onTap: () {
                      context.read<MessagingProvider>().toggleReaction(
                        message.id,
                        emoji,
                      );
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: hasReacted
                            ? colorScheme.primary.withValues(alpha: 0.2)
                            : (isMe
                                  ? colorScheme.onPrimary.withValues(alpha: 0.1)
                                  : colorScheme.primary.withValues(
                                      alpha: 0.05,
                                    )),
                        shape: BoxShape.circle,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            _buildOptionTile(
              context,
              icon: Icons.reply_rounded,
              label: 'Reply',
              onTap: () {
                Navigator.pop(context);
                onReply(message);
              },
            ),
            if (isMe)
              _buildOptionTile(
                context,
                icon: Icons.delete_outline_rounded,
                label: conversation?.type == ConversationType.dm
                    ? 'Delete for both of us'
                    : 'Delete for everyone',
                color: colors.error,
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(parentContext, forEveryone: true);
                },
              ),
            _buildOptionTile(
              context,
              icon: Icons.remove_circle_outline_rounded,
              label: 'Delete for me',
              color: colors.error,
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(parentContext, forEveryone: false);
              },
            ),
            _buildOptionTile(
              context,
              icon: Icons.copy_rounded,
              label: 'Copy Text',
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(context);
                NotificationService.showSuccess(context, 'Copied to clipboard');
              },
            ),
            if (!isMe)
              _buildOptionTile(
                context,
                icon: Icons.flag_outlined,
                label: 'Report Message',
                color: colors.error,
                onTap: () {
                  Navigator.pop(context);
                  ReportContentSheet.show(
                    context: context,
                    targetType: 'message',
                    targetId: message.id,
                    subjectLabel: 'message',
                  );
                },
              ),
            if (message.mediaUrl != null &&
                !message.mediaUrl!.startsWith('file')) ...[
              _buildOptionTile(
                context,
                icon: Icons.download_rounded,
                label: 'Save to Device',
                onTap: () async {
                  Navigator.pop(context);
                  await _downloadMedia(context, message.mediaUrl!);
                },
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: color ?? colorScheme.primary),
        title: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _downloadMedia(BuildContext context, String url) async {
    // Show a non-blocking snackbar with progress if possible,
    // but for now a simple loader in the UI is fine.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            GriotLoader(size: 20, strokeWidth: 2, color: colorScheme.primary),
            const SizedBox(width: 16),
            const Text('Downloading media...'),
          ],
        ),
        duration: const Duration(days: 1), // Semi-permanent until dismissed
      ),
    );

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final directory = Platform.isAndroid
          ? await getExternalStorageDirectory() ??
                await getApplicationDocumentsDirectory()
          : await getApplicationDocumentsDirectory();

      final uri = Uri.parse(url);
      String filename = path.basename(uri.path);
      if (filename.isEmpty) {
        final ext = response.headers['content-type']?.split('/').last ?? 'bin';
        filename =
            'griot_download_${DateTime.now().millisecondsSinceEpoch}.$ext';
      }

      final file = File(path.join(directory.path, filename));
      await file.writeAsBytes(response.bodyBytes, flush: true);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      NotificationService.showSuccess(
        context,
        'Media saved to ${Platform.isAndroid ? "Downloads" : "Documents"}',
      );

      // Offer to share it immediately
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Shared from Griot'),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      NotificationService.showError(
        context,
        'Download failed: ${error.toString().split(":").last}',
      );
    }
  }

  void _confirmDelete(BuildContext context, {required bool forEveryone}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          forEveryone
              ? (conversation?.type == ConversationType.dm
                    ? 'Delete for both of us?'
                    : 'Delete for everyone?')
              : 'Delete for me?',
        ),
        content: Text(
          forEveryone
              ? (conversation?.type == ConversationType.dm
                    ? 'This removes the message from both sides of this chat.'
                    : 'This removes the message for everyone in the group.')
              : 'This removes the message only from your chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (context.mounted == false) return;

    if (confirm == true) {
      try {
        final provider = context.read<MessagingProvider>();
        if (forEveryone) {
          await provider.deleteMessage(message.id);
        } else {
          await provider.deleteMessageForMe(message.id);
        }
        if (context.mounted) {
          NotificationService.showSuccess(
            context,
            forEveryone ? 'Message deleted' : 'Message deleted for you',
          );
        }
      } catch (e) {
        if (context.mounted) {
          NotificationService.showError(context, 'Failed to delete message');
        }
      }
    }
  }

  Widget _buildStatusIcon() {
    return GriotMessageStatus(
      status: message.status,
      color: isMe
          ? colorScheme.onPrimary
          : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
    );
  }

  Widget _buildGroupSenderInfo(BuildContext context) {
    final provider = context.watch<MessagingProvider>();

    // 1. Try to find in friends
    final friend = provider.friends.firstWhere(
      (f) => f.id == message.senderId,
      orElse: () => const UserModel(id: '', walletAddress: ''),
    );

    String? name = sender?.effectiveDisplayName;
    if (name == 'Griot User') name = null;
    name ??= friend.id.isNotEmpty
        ? (friend.displayName ?? friend.username)
        : null;

    name ??= message.senderId.length >= 4
        ? 'User ${message.senderId.substring(0, 4)}'
        : 'Group member';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 2),
      child: Semantics(
        button: onSenderTap != null,
        label: 'Open $name profile',
        child: InkWell(
          onTap: onSenderTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Text(
              name,
              style: TextStyle(
                color: _groupSenderColor(context),
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Gives each group member a stable, readable name color. The conversation's
  /// member order is preferred so members receive different palette entries;
  /// the sender ID is the fallback when that list is incomplete. This is only
  /// used for group sender labels; DMs and channels keep their presentation.
  Color _groupSenderColor(BuildContext context) {
    const lightPalette = <Color>[
      Color(0xFFC62828),
      Color(0xFFAD1457),
      Color(0xFF6A1B9A),
      Color(0xFF283593),
      Color(0xFF1565C0),
      Color(0xFF00695C),
      Color(0xFF2E7D32),
      Color(0xFFEF6C00),
      Color(0xFF6D4C41),
    ];
    const darkPalette = <Color>[
      Color(0xFFFF8A80),
      Color(0xFFFF80AB),
      Color(0xFFEA80FC),
      Color(0xFF8C9EFF),
      Color(0xFF82B1FF),
      Color(0xFF84FFFF),
      Color(0xFFB9F6CA),
      Color(0xFFFFD180),
      Color(0xFFFF9E80),
    ];

    final hash = message.senderId.codeUnits.fold<int>(
      0,
      (value, unit) => (value * 31 + unit) & 0x7fffffff,
    );
    final palette = Theme.of(context).brightness == Brightness.dark
        ? darkPalette
        : lightPalette;
    final memberIndex = conversation?.memberIds.indexOf(message.senderId) ?? -1;
    final stableIndex = memberIndex >= 0 ? memberIndex : hash;
    return palette[stableIndex % palette.length];
  }

  Widget _buildReplyHeader(BuildContext context) {
    final provider = context.read<MessagingProvider>();
    final parent = provider
        .getMessagesForConversation(message.conversationId)
        .firstWhere(
          (m) => m.id == message.replyToMessageId,
          orElse: () => ChatMessage(
            id: '',
            conversationId: '',
            senderId: '',
            text: 'Original message not found',
            createdAt: DateTime.now(),
          ),
        );

    return Semantics(
      button: onReplyTap != null,
      label: 'Go to replied message',
      child: InkWell(
        // Keep older, unloaded parents actionable. The screen callback can
        // page backwards until the referenced message is available.
        onTap: onReplyTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isMe
                ? colorScheme.onPrimary.withValues(alpha: 0.12)
                : colorScheme.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: isMe ? colorScheme.onPrimary : colorScheme.primary,
                width: 3.5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                parent.senderId == context.read<UserProvider>().user?.id
                    ? 'You'
                    : 'Friend',
                style: TextStyle(
                  color: isMe
                      ? colorScheme.onPrimary.withValues(alpha: 0.9)
                      : colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                parent.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isMe
                      ? colorScheme.onPrimary.withValues(alpha: 0.75)
                      : colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactions(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: message.reactions.entries.map((entry) {
          final emoji = entry.key;
          final users = entry.value;
          final currentUserId = context.read<UserProvider>().user?.id;
          final hasReacted = users.contains(currentUserId);

          return GestureDetector(
            onTap: () => context.read<MessagingProvider>().toggleReaction(
              message.id,
              emoji,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasReacted
                    ? colorScheme.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 13)),
                  if (users.length > 1) ...[
                    const SizedBox(width: 3),
                    Text(
                      users.length.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageText(BuildContext context) {
    // 1. Handle Failed Status
    if (message.status == MessageStatus.failed &&
        !message.isMedia &&
        !message.isFile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRetryTextOverlay(context),
          Text(
            message.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
          ),
        ],
      );
    }

    // 2. Handle Specific Media Types
    if (message.type == MessageType.image) {
      return _buildImageContent(context);
    }

    if (message.type == MessageType.video) {
      return _buildVideoContent(context);
    }

    if (message.type == MessageType.voice ||
        message.type == MessageType.audio) {
      return _buildAudioContent(context);
    }

    if (message.type == MessageType.file) {
      return _buildFileContent(context);
    }

    if (message.type == MessageType.tip) {
      return _buildTipContent(context);
    }

    if (message.type == MessageType.contact) {
      return _buildContactContent(context);
    }

    if (message.type == MessageType.system && _isCallSystemMessage) {
      return _buildCallSystemContent(context);
    }

    // 3. Handle Regular Text
    final theme = Theme.of(context);

    // Safety check for empty text
    if (message.text.trim().isEmpty) {
      return Text(
        '[Empty Message]',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: (isMe ? colorScheme.onPrimary : colorScheme.onSurface)
              .withValues(alpha: 0.5),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final Color textColor = isMe
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    final textStyle =
        theme.textTheme.bodyMedium?.copyWith(
          color: textColor,
          fontSize: 15,
          height: 1.3,
          fontWeight: FontWeight.w600,
        ) ??
        TextStyle(
          color: textColor,
          fontSize: 15,
          height: 1.3,
          fontWeight: FontWeight.w600,
        );

    final linkRegex = RegExp(r'(https?://[^\s<]+|0x[a-fA-F0-9]{40})');
    final matches = linkRegex.allMatches(message.text);

    if (matches.isEmpty) {
      return Text(message.text, style: textStyle, textAlign: TextAlign.start);
    }

    final children = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        children.add(
          TextSpan(
            text: message.text.substring(lastEnd, match.start),
            style: textStyle,
          ),
        );
      }

      final link = match.group(0)!.replaceFirst(RegExp(r'[.,!?;:]+$'), '');
      final isWalletAddress = link.startsWith('0x');
      final linkEnd = match.start + link.length;

      children.add(
        TextSpan(
          text: link,
          style: textStyle.copyWith(
            color: isMe
                ? colorScheme.onPrimary
                : (colorScheme.primary.computeLuminance() > 0.4
                      ? colorScheme.onSurface
                      : colorScheme.primary),
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            decorationColor: isMe
                ? colorScheme.onPrimary.withValues(alpha: 0.5)
                : colorScheme.primary.withValues(alpha: 0.5),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (isWalletAddress) {
                context.push('/wallet/search', extra: link);
                return;
              }
              final uri = Uri.tryParse(link);
              if (uri != null) {
                final host = uri.host.toLowerCase();
                final path = uri.path;
                final isInternal =
                    host == 'griot.network' || host == 'www.griot.network';
                if (isInternal &&
                    (path.startsWith('/join') ||
                        path.startsWith('/plus') ||
                        path.startsWith('/profile/') ||
                        path.startsWith('/group/') ||
                        path.startsWith('/circle/') ||
                        path.startsWith('/channel/'))) {
                  // Normalize the legacy www host before handing the link to
                  // the app router. This keeps every Griot conversation link
                  // on one canonical in-app destination.
                  final canonicalUri = uri.replace(host: 'griot.network');
                  DeepLinkService.instance.handleUri(canonicalUri);
                } else {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
        ),
      );

      lastEnd = linkEnd;
    }

    if (lastEnd < message.text.length) {
      children.add(
        TextSpan(text: message.text.substring(lastEnd), style: textStyle),
      );
    }

    final String? firstUrl = _extractFirstUrl(message.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(TextSpan(children: children, style: textStyle)),
        if (firstUrl != null && !message.isMedia && !message.isFile)
          LinkPreviewWidget(url: firstUrl, isMe: isMe),
      ],
    );
  }

  bool get _isCallSystemMessage {
    final value = message.text.trim().toLowerCase();
    return value.startsWith('voice call') ||
        value.startsWith('video call') ||
        value.startsWith('missed voice call') ||
        value.startsWith('missed video call');
  }

  Widget _buildCallSystemContent(BuildContext context) {
    final value = message.text.trim();
    final missed = value.toLowerCase().startsWith('missed');
    final video = value.toLowerCase().contains('video');
    final accent = missed ? colorScheme.error : colorScheme.primary;
    return Container(
      constraints: const BoxConstraints(minWidth: 190, maxWidth: 290),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: .14),
            ),
            child: Icon(
              missed
                  ? Icons.call_missed_rounded
                  : video
                      ? Icons.videocam_rounded
                      : Icons.call_rounded,
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  video ? 'Video call' : 'Voice call',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactContent(BuildContext context) {
    var name = 'Contact';
    var phone = '';

    // New messages use structured JSON. Continue accepting the previous
    // newline format so already-sent contact messages still render correctly.
    try {
      final decoded = jsonDecode(message.text);
      if (decoded is Map) {
        name = decoded['name']?.toString().trim() ?? name;
        phone = decoded['phone']?.toString().trim() ?? phone;
      }
    } catch (_) {
      final lines = message.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      name = lines.isNotEmpty ? lines.first : name;
      phone = lines.length > 1 ? lines.sublist(1).join(' ') : phone;
    }

    if (name.isEmpty) name = 'Contact';
    final textColor = isMe ? colorScheme.onPrimary : colorScheme.onSurface;

    return InkWell(
      onTap: phone.isEmpty
          ? null
          : () => launchUrl(Uri(scheme: 'tel', path: phone)),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: isMe
                  ? colorScheme.onPrimary.withValues(alpha: 0.18)
                  : colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(Icons.person_rounded, color: textColor),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (phone.isNotEmpty)
                    Text(
                      phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  if (phone.isNotEmpty)
                    Text(
                      'Tap to call',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _extractFirstUrl(String text) {
    final linkRegex = RegExp(r'https?://[^\s<]+');
    final match = linkRegex.firstMatch(text);
    if (match != null) {
      return match.group(0)!.replaceFirst(RegExp(r'[.,!?;:]+$'), '');
    }
    return null;
  }

  Widget _buildImageContent(BuildContext context) {
    final url = message.mediaUrl;
    if (url == null) return const SizedBox.shrink();

    final isLocal = url.startsWith('/') || url.startsWith('file://');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.status == MessageStatus.failed) _buildRetryOverlay(context),
        GestureDetector(
          onTap: () => FullscreenMediaViewer.show(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: isLocal
                ? Image.file(
                    File(url.replaceFirst('file://', '')),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                  )
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                    placeholder: (context, url) => const Center(
                      child: GriotLoader(size: 24, strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) =>
                        const Center(child: Icon(Icons.error_outline_rounded)),
                  ),
          ),
        ),
        if (message.text.isNotEmpty && !message.text.startsWith('📷')) ...[
          const SizedBox(height: 8),
          Text(
            message.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAudioContent(BuildContext context) {
    final url = message.mediaUrl;
    if (url == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.status == MessageStatus.failed) _buildRetryOverlay(context),
        AudioPlayerWidget(key: ValueKey(url), url: url, isMe: isMe),
        if (message.text.isNotEmpty && !message.text.startsWith('🎤')) ...[
          const SizedBox(height: 4),
          Text(
            message.text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isMe ? colorScheme.onPrimary.withValues(alpha: 0.7) : null,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVideoContent(BuildContext context) {
    final url = message.mediaUrl;
    if (url == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.status == MessageStatus.failed) _buildRetryOverlay(context),
        GestureDetector(
          onTap: () => FullscreenMediaViewer.show(context, url, isVideo: true),
          child: ChatVideoPlayer(key: ValueKey(url), url: url, isMe: isMe),
        ),
        if (message.text.isNotEmpty && !message.text.startsWith('🎬')) ...[
          const SizedBox(height: 8),
          Text(
            message.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFileContent(BuildContext context) {
    final isPdf = message.text.toLowerCase().endsWith('.pdf');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.status == MessageStatus.failed) _buildRetryOverlay(context),
        GestureDetector(
          onTap: () {
            if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) {
              context.push(
                '/viewer',
                extra: {'url': message.mediaUrl, 'title': message.text},
              );
            } else {
              NotificationService.showInfo(
                context,
                'Document is still processing...',
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe
                  ? colorScheme.onPrimary.withValues(alpha: 0.1)
                  : colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.insert_drive_file_rounded,
                  color: isMe ? colorScheme.onPrimary : colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isMe ? colorScheme.onPrimary : null,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isPdf ? 'PDF Document' : 'File',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isMe
                              ? colorScheme.onPrimary.withValues(alpha: 0.7)
                              : colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipContent(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final tipData = message.tipData;

    if (tipData == null) {
      return Text(
        message.text,
        style: textTheme.bodyMedium?.copyWith(
          color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
      );
    }

    final String network =
        tipData['network']?.toString().toUpperCase() ?? 'UNKNOWN';
    final String status =
        tipData['status']?.toString().toUpperCase() ?? 'CONFIRMED';
    final bool isBatch = tipData['isBatch'] == true;
    final String tokenSymbol =
        tipData['tokenSymbol']?.toString().trim().isNotEmpty == true
        ? tipData['tokenSymbol'].toString().toUpperCase()
        : 'TOKEN';
    final String tokenName = tipData['tokenName']?.toString().trim() ?? '';
    final String amountText =
        tipData['amountDisplay']?.toString().trim().isNotEmpty == true
        ? TipDisplay.amount(tipData['amountDisplay'].toString())
        : TipDisplay.amount(message.text);
    final rawNames = tipData['recipientNames'];
    final recipientNames = rawNames is List
        ? rawNames
              .map((name) => TipDisplay.person(displayName: name.toString()))
              .where((name) => name != 'Griot user')
              .toList()
        : const <String>[];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe
            ? colorScheme.onPrimary.withValues(alpha: 0.1)
            : colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? colorScheme.onPrimary.withValues(alpha: 0.2)
              : colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.volunteer_activism_outlined,
                  size: 18,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBatch
                          ? (isMe ? 'Batch Tip Sent' : 'Batch Tip Received')
                          : (isMe ? 'Tip Sent' : 'Tip Received'),
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isMe
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      amountText,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isMe
                            ? colorScheme.onPrimary.withValues(alpha: 0.9)
                            : colorScheme.onSurface.withValues(alpha: 0.9),
                      ),
                    ),
                    if (tokenName.isNotEmpty)
                      Text(
                        '$tokenName · $tokenSymbol',
                        style: textTheme.bodySmall?.copyWith(
                          color:
                              (isMe
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurface)
                                  .withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            color: (isMe ? colorScheme.onPrimary : colorScheme.onSurface)
                .withValues(alpha: 0.1),
            height: 1,
          ),
          const SizedBox(height: 12),
          _buildTipInfoRow(context, 'Network', network, Icons.lan_outlined),
          const SizedBox(height: 6),
          _buildTipInfoRow(
            context,
            'Status',
            status,
            Icons.check_circle_rounded,
            valueColor: AppColors.success,
          ),
          if (isBatch && recipientNames.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildTipInfoRow(
              context,
              'Recipients',
              '${recipientNames.length} people',
              Icons.people_outline_rounded,
            ),
          ],
          if (tipData['transactionHash'] != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  final hash = tipData['transactionHash'].toString();
                  final explorerUrl = _transactionExplorerUrl({
                    'hash': hash,
                    'network': tipData['network'] ?? tipData['chain'],
                    'chainId': tipData['chainId'] ?? tipData['chain_id'],
                    'explorer': tipData['explorer'],
                  });
                  if (explorerUrl == null) {
                    NotificationService.showError(
                      context,
                      'No block explorer link is available for this network',
                    );
                    return;
                  }
                  _openTransactionExplorer(context, explorerUrl);
                },
                icon: Icon(
                  Icons.open_in_new_rounded,
                  size: 14,
                  color: isMe ? colorScheme.onPrimary : colorScheme.primary,
                ),
                label: Text(
                  'View Transaction',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isMe ? colorScheme.onPrimary : colorScheme.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTipInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    final color = isMe ? colorScheme.onPrimary : colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            color: color.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? color,
            fontWeight: FontWeight.w800,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildRetryTextOverlay(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: isMe
                ? colorScheme.onPrimary.withValues(alpha: 0.7)
                : colorScheme.error,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            'Failed',
            style: TextStyle(
              color: isMe
                  ? colorScheme.onPrimary.withValues(alpha: 0.7)
                  : colorScheme.error,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              try {
                final provider = context.read<MessagingProvider>();
                provider.removeMessageLocally(
                  message.conversationId,
                  message.id,
                );
                await provider.sendMessage(
                  message.conversationId,
                  message.text,
                  replyToMessageId: message.replyToMessageId,
                );
              } catch (error) {
                if (context.mounted) {
                  NotificationService.showError(
                    context,
                    error.toString().replaceFirst('Exception: ', ''),
                  );
                }
              }
            },
            child: Text(
              'Retry',
              style: TextStyle(
                color: isMe ? colorScheme.onPrimary : colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryOverlay(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 14),
          const SizedBox(width: 6),
          Text(
            'Failed to send',
            style: TextStyle(
              color: Colors.red.shade300,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              try {
                await context.read<MessagingProvider>().retryMediaMessage(
                  message,
                );
              } catch (error) {
                if (context.mounted) {
                  NotificationService.showError(
                    context,
                    error.toString().replaceFirst('Exception: ', ''),
                  );
                }
              }
            },
            child: Text(
              'Retry',
              style: TextStyle(
                color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _transactionExplorerUrl(Map<String, dynamic> item) {
    final provided = item['explorer']?.toString().trim();
    if (provided != null && provided.isNotEmpty) return provided;
    final hash = (item['hash'] ?? item['transactionHash'] ?? item['txHash'])
        ?.toString()
        .trim();
    if (hash == null || hash.isEmpty) return null;
    final chain = (item['chain'] ?? item['network'] ?? item['chainName'] ?? '')
        .toString()
        .toLowerCase()
        .replaceAll('_', '-')
        .replaceAll(' ', '-');
    final chainId = (item['chainId'] ?? item['chain_id'])?.toString();
    const byId = {
      '1': 'https://etherscan.io/tx/',
      '10': 'https://optimistic.etherscan.io/tx/',
      '56': 'https://bscscan.com/tx/',
      '137': 'https://polygonscan.com/tx/',
      '8453': 'https://basescan.org/tx/',
      '42161': 'https://arbiscan.io/tx/',
      '43114': 'https://snowtrace.io/tx/',
    };
    const byName = {
      'ethereum': 'https://etherscan.io/tx/',
      'eth': 'https://etherscan.io/tx/',
      'polygon': 'https://polygonscan.com/tx/',
      'matic': 'https://polygonscan.com/tx/',
      'bsc': 'https://bscscan.com/tx/',
      'bnb': 'https://bscscan.com/tx/',
      'base': 'https://basescan.org/tx/',
      'arbitrum': 'https://arbiscan.io/tx/',
      'optimism': 'https://optimistic.etherscan.io/tx/',
      'avalanche': 'https://snowtrace.io/tx/',
    };
    final prefix =
        byId[chainId] ??
        byName[chain] ??
        byName.entries
            .where((entry) => chain.contains(entry.key))
            .map((entry) => entry.value)
            .firstOrNull;
    return prefix == null ? null : '$prefix$hash';
  }

  Future<void> _openTransactionExplorer(
    BuildContext context,
    String url,
  ) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        NotificationService.showError(context, 'Could not open block explorer');
      }
    }
  }
}
