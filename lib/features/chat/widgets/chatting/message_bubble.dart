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
import '../../models/conversation_model.dart';
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

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isDark;
  final ColorScheme colorScheme;
  final Function(ChatMessage) onReply;
  final Conversation? conversation;
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

    final theme = Theme.of(context);

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: isLastInGroup ? 10 : 2.5,
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
                  boxShadow: [
                    if (isLastInGroup)
                      BoxShadow(
                        color: theme.shadowColor,
                        blurRadius: 8,
                        offset: const Offset(0, 3),
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
                    if (message.reactions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildReactions(context),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat('HH:mm').format(message.createdAt),
                          style: TextStyle(
                            color: isMe
                                ? colorScheme.onPrimary.withValues(alpha: 0.7)
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
                label: 'Delete Message',
                color: colors.error,
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context);
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

  void _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text('This action cannot be undone.'),
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
        await context.read<MessagingProvider>().deleteMessage(message.id);
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

    String? name = friend.id.isNotEmpty
        ? (friend.displayName ?? friend.username)
        : null;

    // 2. TODO: In the future, fetch from a member cache if not a friend.
    name ??= 'User ${message.senderId.substring(0, 4)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 2),
      child: Text(
        name,
        style: TextStyle(
          color: colorScheme.primary.computeLuminance() > 0.4
              ? colorScheme.onSurface
              : colorScheme.primary,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
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

    return Container(
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
    );
  }

  Widget _buildReactions(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasReacted
                  ? colorScheme.primary.withValues(alpha: 0.2)
                  : (isMe
                        ? colorScheme.onPrimary.withValues(alpha: 0.1)
                        : colorScheme.primary.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasReacted
                    ? colorScheme.primary.withValues(alpha: 0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 12)),
                if (users.length > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    users.length.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isMe ? colorScheme.onPrimary : colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
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
                        path.startsWith('/group/@') ||
                        path.startsWith('/circle/@') ||
                        path.startsWith('/channel/@'))) {
                  DeepLinkService.instance.handleUri(uri);
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
        AudioPlayerWidget(url: url, isMe: isMe),
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
          child: ChatVideoPlayer(url: url, isMe: isMe),
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

    // Try to get a human-readable amount if decimals are known (usually 18 for native)
    // For now, use the text field which should have been populated in _saveLocalTipMessage
    final String amountText = message.text;

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
                      isBatch ? 'Batch Tip' : 'Tip Sent',
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
          if (tipData['transactionHash'] != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  final hash = tipData['transactionHash'].toString();
                  // TODO: Open explorer
                  Clipboard.setData(ClipboardData(text: hash));
                  NotificationService.showSuccess(
                    context,
                    'Hash copied to clipboard',
                  );
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
}
