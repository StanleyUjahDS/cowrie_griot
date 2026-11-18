import 'dart:io';
import 'dart:math' as math;
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
import '../../services/messaging_api_service.dart';
import '../../models/chat_message.dart';
import '../../models/chat_user.dart';
import '../../models/conversation_model.dart';
import '../../utils/tip_display.dart';
import '../../../users/models/user_model.dart';
import '../../../users/providers/user_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/ui/widgets/griot_loader.dart';
import '../../../../core/ui/widgets/griot_avatar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/deep_link_service.dart';
import 'audio_player_widget.dart';
import 'video_player_widget.dart';
import 'fullscreen_media_viewer.dart';
import 'link_preview_widget.dart';
import 'report_content_sheet.dart';
import 'reaction_picker.dart';
import '../../services/sticker_library_service.dart';
import '../../../auth/auth_controller.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isDark;
  final ColorScheme colorScheme;
  final Function(ChatMessage) onReply;
  final Conversation? conversation;
  final ChatUser? sender;
  final Map<String, ChatUser>? memberDirectory;
  final VoidCallback? onSenderTap;
  final VoidCallback? onReplyTap;
  final bool isHighlighted;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool canPinMessage;
  final bool isPinned;
  final VoidCallback? onEdit;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.colorScheme,
    required this.onReply,
    this.conversation,
    this.sender,
    this.memberDirectory,
    this.onSenderTap,
    this.onReplyTap,
    this.isHighlighted = false,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.canPinMessage = false,
    this.isPinned = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return _buildDeletedBubble(context);
    }

    // Stickers are intentionally not rendered inside the normal message
    // bubble. This matches the familiar messaging-app treatment: the artwork
    // stays large and clean, while the time/status sits in a small overlay.
    if (message.type == MessageType.sticker) {
      return _buildStickerMessage(context);
    }

    final double topRadius = isFirstInGroup ? 22 : 6;
    final double bottomRadius = isLastInGroup ? 22 : 6;
    // Reserve the avatar column for every incoming message in a group. The
    // avatar and sender label are only painted on the first bubble, but the
    // following bubbles must keep the same left edge instead of jumping under
    // the wallpaper when the group continues.
    final isIncomingGroupMessage =
        !isMe && conversation?.type == ConversationType.group;
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(isMe ? 22 : topRadius),
      topRight: Radius.circular(isMe ? topRadius : 22),
      bottomLeft: Radius.circular(isMe ? 22 : bottomRadius),
      bottomRight: Radius.circular(isMe ? bottomRadius : 22),
    );

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context),
      onDoubleTap: () =>
          context.read<MessagingProvider>().toggleReaction(message.id, '❤️'),
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (!isMe &&
                      isFirstInGroup &&
                      conversation?.type == ConversationType.group)
                    Positioned(
                      // Keep the sender portrait outside the bubble, like
                      // modern group chats. It anchors the message without
                      // stealing horizontal space from the text.
                      left: 2,
                      top: 18,
                      child: _buildGroupSenderAvatar(context),
                    ),
                  Container(
                    margin: EdgeInsets.only(
                      left: isIncomingGroupMessage ? 50 : 0,
                    ),
                    constraints: BoxConstraints(
                      maxWidth:
                          MediaQuery.of(context).size.width * 0.78 -
                          (isIncomingGroupMessage ? 50 : 0),
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
                          color: colorScheme.shadow.withValues(
                            alpha: isDark ? 0.38 : 0.20,
                          ),
                          blurRadius: isLastInGroup ? 14 : 10,
                          spreadRadius: isLastInGroup ? 0.7 : 0.2,
                          offset: Offset(0, isLastInGroup ? 4 : 3),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.only(
                      left: 14,
                      right: 14,
                      top: 10,
                      bottom: 10,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe &&
                            isFirstInGroup &&
                            conversation?.type == ConversationType.group)
                          _buildGroupSenderInfo(context),
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
                              Text(
                                _messageStatusLabel(message.status),
                                style: TextStyle(
                                  color: colorScheme.secondary.withValues(
                                    alpha: 0.82,
                                  ),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
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

    showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Message actions',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => Align(
        alignment: Alignment.centerRight,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: math.min(
                        MediaQuery.sizeOf(context).width * 0.84,
                        360.0,
                      ),
                      child: _buildFloatingReactionTray(
                        context,
                        colors,
                        currentUserId,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: math.min(
                        MediaQuery.sizeOf(context).width * 0.74,
                        300.0,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(24),
                              ),
                              border: Border(
                                left: BorderSide(
                                  color: colors.primary.withValues(alpha: 0.55),
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 24,
                                  offset: const Offset(-8, 0),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Message actions',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Close',
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Offstage(
                                    offstage: true,
                                    child: ExpansionTile(
                                      initiallyExpanded: true,
                                      tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      childrenPadding:
                                          const EdgeInsets.fromLTRB(
                                            14,
                                            0,
                                            14,
                                            12,
                                          ),
                                      backgroundColor: colors
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.92),
                                      collapsedBackgroundColor: colors
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.92),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                        side: BorderSide(
                                          color: colors.outline.withValues(
                                            alpha: 0.28,
                                          ),
                                        ),
                                      ),
                                      collapsedShape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                        side: BorderSide(
                                          color: colors.outline.withValues(
                                            alpha: 0.28,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        'React to message',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      leading: Icon(
                                        Icons.emoji_emotions_outlined,
                                        color: colors.primary,
                                      ),
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children:
                                              ['👍', '❤️', '😂', '😮', '😢', '🔥'].map((
                                                emoji,
                                              ) {
                                                final hasReacted =
                                                    message.reactions[emoji]
                                                        ?.contains(
                                                          currentUserId,
                                                        ) ??
                                                    false;
                                                return Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    onTap: () {
                                                      context
                                                          .read<
                                                            MessagingProvider
                                                          >()
                                                          .toggleReaction(
                                                            message.id,
                                                            emoji,
                                                          );
                                                      Navigator.pop(context);
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: hasReacted
                                                            ? colorScheme
                                                                  .primary
                                                                  .withValues(
                                                                    alpha: 0.2,
                                                                  )
                                                            : (isMe
                                                                  ? colorScheme
                                                                        .onPrimary
                                                                        .withValues(
                                                                          alpha:
                                                                              0.1,
                                                                        )
                                                                  : colorScheme
                                                                        .primary
                                                                        .withValues(
                                                                          alpha:
                                                                              0.05,
                                                                        )),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              14,
                                                            ),
                                                        border: Border.all(
                                                          color: hasReacted
                                                              ? colorScheme
                                                                    .primary
                                                              : colors.outline
                                                                    .withValues(
                                                                      alpha:
                                                                          0.22,
                                                                    ),
                                                        ),
                                                      ),
                                                      child: emoji == '❤️'
                                                          ? const Icon(
                                                              Icons
                                                                  .favorite_rounded,
                                                              color: Colors.red,
                                                              size: 22,
                                                            )
                                                          : Text(
                                                              emoji,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        22,
                                                                  ),
                                                            ),
                                                    ),
                                                  ),
                                                );
                                              }).toList()..add(
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    onTap: () async {
                                                      final customEmoji =
                                                          await _pickCustomReaction(
                                                            context,
                                                          );
                                                      if (context.mounted &&
                                                          customEmoji != null &&
                                                          customEmoji
                                                              .isNotEmpty) {
                                                        await context
                                                            .read<
                                                              MessagingProvider
                                                            >()
                                                            .toggleReaction(
                                                              message.id,
                                                              customEmoji,
                                                            );
                                                        if (context.mounted) {
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                        }
                                                      }
                                                    },
                                                    child: Container(
                                                      width: 44,
                                                      height: 42,
                                                      alignment:
                                                          Alignment.center,
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              14,
                                                            ),
                                                        border: Border.all(
                                                          color: colors.outline
                                                              .withValues(
                                                                alpha: 0.3,
                                                              ),
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        Icons
                                                            .add_reaction_outlined,
                                                        color: colors.primary,
                                                        size: 21,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Divider(
                                    color: colors.outline.withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                                  _buildOptionTile(
                                    context,
                                    icon: Icons.reply_rounded,
                                    label: 'Reply',
                                    onTap: () {
                                      Navigator.pop(context);
                                      onReply(message);
                                    },
                                  ),
                                  _buildOptionTile(
                                    context,
                                    icon: Icons.copy_rounded,
                                    label: 'Copy Text',
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(text: message.text),
                                      );
                                      Navigator.pop(context);
                                      NotificationService.showSuccess(
                                        context,
                                        'Copied to clipboard',
                                      );
                                    },
                                  ),
                                  if (isMe &&
                                      conversation?.type ==
                                          ConversationType.group)
                                    _buildOptionTile(
                                      context,
                                      icon: Icons.done_all_rounded,
                                      label: 'Message info',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _showGroupMessageInfo(parentContext);
                                      },
                                    ),
                                  if (isMe &&
                                      message.isText &&
                                      !message.isDeleted &&
                                      onEdit != null)
                                    _buildOptionTile(
                                      context,
                                      icon: Icons.edit_outlined,
                                      label: 'Edit message',
                                      onTap: () async {
                                        Navigator.pop(context);
                                        onEdit!();
                                      },
                                    ),
                                  if (conversation?.id != null && canPinMessage)
                                    _buildOptionTile(
                                      context,
                                      icon: isPinned
                                          ? Icons.push_pin
                                          : Icons.push_pin_outlined,
                                      label: isPinned
                                          ? 'Unpin message'
                                          : 'Pin message',
                                      onTap: () async {
                                        Navigator.pop(context);
                                        try {
                                          final provider = parentContext
                                              .read<MessagingProvider>();
                                          if (isPinned) {
                                            await provider.unpinMessage(
                                              conversationId: conversation!.id,
                                              messageId: message.id,
                                            );
                                          } else {
                                            await provider.pinMessage(
                                              conversationId: conversation!.id,
                                              messageId: message.id,
                                            );
                                          }
                                          if (parentContext.mounted) {
                                            NotificationService.showSuccess(
                                              parentContext,
                                              isPinned
                                                  ? 'Message unpinned'
                                                  : 'Message pinned',
                                            );
                                          }
                                        } catch (error) {
                                          if (parentContext.mounted) {
                                            NotificationService.showError(
                                              parentContext,
                                              'Could not pin message',
                                            );
                                          }
                                        }
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
                                  if (message.type != MessageType.sticker &&
                                      message.mediaUrl != null &&
                                      !message.mediaUrl!.startsWith(
                                        'file',
                                      )) ...[
                                    _buildOptionTile(
                                      context,
                                      icon: Icons.download_rounded,
                                      label: 'Save to Device',
                                      onTap: () async {
                                        Navigator.pop(context);
                                        await _downloadMedia(
                                          context,
                                          message.mediaUrl!,
                                        );
                                      },
                                    ),
                                  ],
                                  if (isMe)
                                    _buildOptionTile(
                                      context,
                                      icon: Icons.delete_outline_rounded,
                                      label:
                                          conversation?.type ==
                                              ConversationType.dm
                                          ? 'Delete for both of us'
                                          : 'Delete for everyone',
                                      color: colors.error,
                                      onTap: () {
                                        Navigator.pop(context);
                                        _confirmDelete(
                                          parentContext,
                                          forEveryone: true,
                                        );
                                      },
                                    ),
                                  _buildOptionTile(
                                    context,
                                    icon: Icons.remove_circle_outline_rounded,
                                    label: 'Delete for me',
                                    color: colors.error,
                                    onTap: () {
                                      Navigator.pop(context);
                                      _confirmDelete(
                                        parentContext,
                                        forEveryone: false,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
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
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        );
      },
    );
  }

  Future<void> _showGroupMessageInfo(BuildContext context) async {
    List<Map<String, dynamic>> receipts = const [];
    String? loadError;
    try {
      receipts = await context.read<MessagingApiService>().getMessageReceipts(
        message.id,
      );
    } catch (_) {
      loadError = 'Receipt details are temporarily unavailable.';
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message info',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  if (loadError != null)
                    Text(
                      loadError,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    )
                  else if (receipts.isEmpty)
                    Text(
                      'No delivery or read receipts yet.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    )
                  else ...[
                    Builder(
                      builder: (_) {
                        var seen = 0;
                        var delivered = 0;
                        var sent = 0;
                        for (final receipt in receipts) {
                          switch ('${receipt['status'] ?? 'sent'}'
                              .toLowerCase()) {
                            case 'read':
                            case 'seen':
                              seen++;
                              break;
                            case 'delivered':
                              delivered++;
                              break;
                            default:
                              sent++;
                          }
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Seen $seen  ·  Delivered $delivered  ·  Sent $sent',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  ...receipts.map((receipt) {
                    final name =
                        (receipt['display_name'] ??
                                receipt['username'] ??
                                'Group member')
                            .toString();
                    final status = (receipt['status'] ?? 'sent').toString();
                    final normalizedStatus = status.toLowerCase();
                    final isRead =
                        normalizedStatus == 'read' ||
                        normalizedStatus == 'seen';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name),
                      subtitle: Text(
                        isRead
                            ? 'Seen'
                            : status == 'delivered'
                            ? 'Delivered'
                            : 'Sent',
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _pickCustomReaction(BuildContext context) async {
    return EmojiReactionPicker.show(context);
  }

  Widget _buildFloatingReactionTray(
    BuildContext context,
    ColorScheme colors,
    String? currentUserId,
  ) {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];
    return Material(
      color: colors.surfaceContainerHighest,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ...emojis.map(
              (emoji) => InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  context.read<MessagingProvider>().toggleReaction(
                    message.id,
                    emoji,
                  );
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: emoji == '❤️'
                      ? const Icon(
                          Icons.favorite_rounded,
                          color: Colors.red,
                          size: 26,
                        )
                      : Text(emoji, style: const TextStyle(fontSize: 25)),
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () async {
                final emoji = await _pickCustomReaction(context);
                if (!context.mounted || emoji == null || emoji.trim().isEmpty) {
                  return;
                }
                await context.read<MessagingProvider>().toggleReaction(
                  message.id,
                  emoji.trim(),
                );
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.emoji_emotions_outlined,
                  color: colors.onSurfaceVariant,
                  size: 27,
                ),
              ),
            ),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color ?? colorScheme.onSurface, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color ?? colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: (color ?? colorScheme.onSurface).withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadMedia(BuildContext context, String url) async {
    NotificationService.showInfo(context, 'Downloading media...');

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

  String _messageStatusLabel(MessageStatus status) => switch (status) {
    MessageStatus.sending => 'Sending',
    MessageStatus.sent => 'Sent',
    MessageStatus.delivered => 'Delivered',
    MessageStatus.read => 'Seen',
    MessageStatus.failed => 'Failed',
  };

  Widget _buildGroupSenderInfo(BuildContext context) {
    final provider = context.watch<MessagingProvider>();

    // 1. Try to find in friends
    final friend = provider.friends.firstWhere(
      (f) => f.id == message.senderId,
      orElse: () => const UserModel(id: '', walletAddress: ''),
    );

    final directoryMember = memberDirectory?[message.senderId];
    String? name;
    bool usable(String? value) {
      final text = value?.trim() ?? '';
      return text.isNotEmpty &&
          !{
            'griot user',
            'griot contact',
            'participant',
            'caller',
            'user',
          }.contains(text.toLowerCase());
    }

    // Prefer the real display name, then username, across every directory
    // source. Placeholder names must never be shown when a real identity is
    // available in the group member payload.
    for (final candidate in [
      sender?.displayName,
      sender?.username,
      directoryMember?.displayName,
      directoryMember?.username,
      friend.displayName,
      friend.username,
    ]) {
      if (usable(candidate)) {
        name = candidate!.trim();
        if (candidate == sender?.username ||
            candidate == directoryMember?.username ||
            candidate == friend.username) {
          name = name.startsWith('@') ? name : '@$name';
        }
        break;
      }
    }

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

  Widget _buildGroupSenderAvatar(BuildContext context) {
    final provider = context.read<MessagingProvider>();
    final friend = provider.friends.firstWhere(
      (f) => f.id == message.senderId,
      orElse: () => const UserModel(id: '', walletAddress: ''),
    );
    final avatarUrl =
        sender?.profileUrl ??
        memberDirectory?[message.senderId]?.profileUrl ??
        (friend.id.isNotEmpty ? friend.avatarUrl : null);
    final accent = _groupSenderColor(context);
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onSenderTap,
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surface,
          border: Border.all(color: accent.withValues(alpha: 0.8), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.24),
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: GriotAvatar(
          avatarUrl: avatarUrl,
          radius: 20,
          backgroundColor: accent.withValues(alpha: 0.14),
          iconColor: accent,
        ),
      ),
    );
  }

  /// Gives each group member a stable, readable name color. The conversation's
  /// member order is preferred so members receive different palette entries;
  /// the sender ID is the fallback when that list is incomplete. This is only
  /// used for group sender labels; DMs and channels keep their presentation.
  Color _groupSenderColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Keep sender labels distinct without introducing a separate hard-coded
    // colour system that ignores the user's selected app accent.
    final palette =
        <Color>[
              colors.primary,
              colors.secondary,
              colors.tertiary,
              colors.error,
              colors.primaryContainer,
              colors.secondaryContainer,
              colors.tertiaryContainer,
            ]
            .map((color) {
              if (Theme.of(context).brightness == Brightness.dark) {
                return Color.lerp(color, colors.onSurface, 0.12)!;
              }
              return color;
            })
            .toList(growable: false);

    final hash = message.senderId.codeUnits.fold<int>(
      0,
      (value, unit) => (value * 31 + unit) & 0x7fffffff,
    );
    final memberIndex = conversation?.memberIds.indexOf(message.senderId) ?? -1;
    final stableIndex = memberIndex >= 0 ? memberIndex : hash;
    return palette[stableIndex % palette.length];
  }

  Widget _buildReplyHeader(BuildContext context) {
    final provider = context.read<MessagingProvider>();
    final currentUserId = context.read<UserProvider>().user?.id;
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
                _replySenderName(parent.senderId, provider, currentUserId),
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

  String _replySenderName(
    String senderId,
    MessagingProvider provider,
    String? currentUserId,
  ) {
    if (senderId == currentUserId) return 'You';
    if (sender != null && sender!.id == senderId) {
      return sender!.effectiveDisplayName;
    }
    final member = memberDirectory?[senderId];
    if (member != null) return member.effectiveDisplayName;
    for (final friend in provider.friends) {
      if (friend.id == senderId) return friend.effectiveName;
    }
    return 'Griot User';
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
    if (message.type == MessageType.sticker) {
      return _buildStickerContent(context);
    }

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

    final isEmojiOnly = _isEmojiOnly(message.text);
    if (isEmojiOnly) {
      final emojiSize = message.text.runes.length <= 4 ? 50.0 : 36.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            textAlign: TextAlign.start,
            style: TextStyle(fontSize: emojiSize, height: 1.08),
          ),
          if (message.isEdited) _buildEditedLabel(),
        ],
      );
    }

    final textStyle =
        theme.textTheme.bodyMedium?.copyWith(
          color: textColor,
          fontSize: 16,
          height: 1.32,
          fontWeight: FontWeight.w500,
        ) ??
        TextStyle(
          color: textColor,
          fontSize: 16,
          height: 1.32,
          fontWeight: FontWeight.w500,
        );

    final linkRegex = RegExp(r'(https?://[^\s<]+|0x[a-fA-F0-9]{40})');
    final matches = linkRegex.allMatches(message.text);

    if (matches.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_storyReplyData != null) _buildStoryReplyHeader(context),
          Text(
            message.text,
            style: textStyle,
            textAlign: TextAlign.start,
            maxLines: _isLongMessage ? 12 : null,
            overflow: _isLongMessage ? TextOverflow.fade : TextOverflow.clip,
          ),
          if (_isLongMessage) _buildReadMoreButton(context),
          if (message.isEdited) _buildEditedLabel(),
        ],
      );
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
        if (_storyReplyData != null) _buildStoryReplyHeader(context),
        Text.rich(
          TextSpan(children: children, style: textStyle),
          maxLines: _isLongMessage ? 12 : null,
          overflow: _isLongMessage ? TextOverflow.fade : TextOverflow.clip,
        ),
        if (_isLongMessage) _buildReadMoreButton(context),
        if (message.isEdited) _buildEditedLabel(),
        if (firstUrl != null && !message.isMedia && !message.isFile)
          LinkPreviewWidget(url: firstUrl, isMe: isMe),
      ],
    );
  }

  Map<String, dynamic>? get _storyReplyData {
    final raw = message.tipData?['storyReply'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  Widget _buildStoryReplyHeader(BuildContext context) {
    final data = _storyReplyData!;
    final colors = Theme.of(context).colorScheme;
    final preview = data['preview']?.toString().trim();
    final label = data['displayName']?.toString().trim();
    final accent = isMe ? colorScheme.onPrimary : colors.primary;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, size: 16, color: accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Replying to ${label?.isNotEmpty == true ? label : 'a'} status${preview?.isNotEmpty == true ? ': $preview' : ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMe ? colorScheme.onPrimary : colors.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isLongMessage =>
      message.text.length > 900 || message.text.split('\n').length > 14;

  Widget _buildReadMoreButton(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: () => _showFullMessage(context),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.only(top: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: const Text('Read more'),
      ),
    );
  }

  Future<void> _showFullMessage(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Message'),
        content: SingleChildScrollView(
          child: SelectableText(
            message.text,
            style: Theme.of(dialogContext).textTheme.bodyLarge,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerContent(BuildContext context) {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    final accessToken = context.read<AuthController>().accessToken;
    final mediaHeaders = accessToken == null || accessToken.isEmpty
        ? null
        : <String, String>{'Authorization': 'Bearer $accessToken'};
    final extension = path.extension(url.split('?').first).toLowerCase();
    const videoExtensions = {'.mp4', '.mov', '.m4v', '.webm'};
    // The stable `/api/media/<id>` URL is extensionless. Stickers created by
    // Griot are GIFs, so an extensionless sticker must use the animated image
    // loader rather than being mistaken for a video player.
    final isVideo = videoExtensions.contains(extension);
    final child = isVideo
        ? SizedBox(
            width: 164,
            height: 164,
            child: ChatVideoPlayer(
              key: ValueKey(url),
              url: url,
              isMe: isMe,
              loop: true,
              autoPlay: true,
              showControls: false,
              httpHeaders: mediaHeaders,
            ),
          )
        : (url.startsWith('/') || url.startsWith('file://'))
        ? Image.file(
            File(url.replaceFirst('file://', '')),
            width: 164,
            height: 164,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) return child;
              return const Center(child: GriotLoader(size: 24));
            },
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image_outlined),
          )
        : CachedNetworkImage(
            imageUrl: url,
            httpHeaders: mediaHeaders,
            width: 164,
            height: 164,
            fit: BoxFit.cover,
            placeholder: (context, url) => const GriotLoader(size: 24),
            errorWidget: (context, url, error) =>
                const Icon(Icons.broken_image_outlined),
          );
    return Semantics(
      label: 'Sticker',
      image: true,
      child: GestureDetector(
        onTap: () => _showStickerActions(context, url, isVideo),
        child: Container(
          width: 164,
          height: 164,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: .22),
              width: 1.2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> _showStickerActions(
    BuildContext context,
    String url,
    bool isVideo,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              ListTile(
                leading: const Icon(Icons.bookmark_add_outlined),
                title: const Text('Save to my stickers'),
                subtitle: const Text('Keep a local copy for quick reuse'),
                onTap: () => Navigator.pop(sheetContext, 'save'),
              ),
            ListTile(
              leading: const Icon(Icons.fullscreen_rounded),
              title: const Text('View sticker'),
              onTap: () => Navigator.pop(sheetContext, 'view'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'view') {
      FullscreenMediaViewer.show(context, url, isVideo: isVideo);
      return;
    }
    try {
      await StickerLibraryService.instance.addFromUrl(url, isVideo: isVideo);
      if (context.mounted) {
        NotificationService.showSuccess(
          context,
          'Sticker saved to your collection.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        NotificationService.showError(
          context,
          'Could not save sticker: $error',
        );
      }
    }
  }

  Widget _buildStickerMessage(BuildContext context) {
    final sticker = _buildStickerContent(context);
    final statusColor = isMe
        ? colorScheme.onSurface.withValues(alpha: 0.78)
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.78);

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context),
      onDoubleTap: () =>
          context.read<MessagingProvider>().toggleReaction(message.id, '❤️'),
      child: Padding(
        padding: EdgeInsets.only(
          top: isFirstInGroup ? 5 : 1,
          bottom: message.reactions.isNotEmpty ? 16 : 5,
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 72,
                  maxWidth: 184,
                  maxHeight: 184,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    sticker,
                    if (message.status == MessageStatus.sending)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: .42),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(child: GriotLoader(size: 24)),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: 5,
                bottom: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('HH:mm').format(message.createdAt),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 3),
                          Text(
                            _messageStatusLabel(message.status),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (message.reactions.isNotEmpty)
                Positioned(
                  bottom: -10,
                  right: isMe ? 8 : null,
                  left: isMe ? null : 8,
                  child: _buildReactions(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isEmojiOnly(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;
    return RegExp(
      r'^(?:[\u{1F000}-\u{1FAFF}\u{2300}-\u{23FF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}\u{20E3}\u{1F3FB}-\u{1F3FF}]|\s)+$',
      unicode: true,
    ).hasMatch(text);
  }

  Widget _buildEditedLabel() => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Text(
      'edited',
      style: TextStyle(
        fontSize: 10,
        fontStyle: FontStyle.italic,
        color: (isMe ? colorScheme.onPrimary : colorScheme.onSurface)
            .withValues(alpha: 0.62),
      ),
    ),
  );

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
    final accessToken = context.read<AuthController>().accessToken;
    final mediaHeaders = accessToken == null || accessToken.isEmpty
        ? null
        : <String, String>{'Authorization': 'Bearer $accessToken'};

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
                    httpHeaders: mediaHeaders,
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
                  color: colorScheme.tertiary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.volunteer_activism_outlined,
                  size: 18,
                  color: colorScheme.tertiary,
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
