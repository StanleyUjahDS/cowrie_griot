import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/services/notification_service.dart';
import '../models/conversation_model.dart';
import '../models/shared_content.dart';
import '../providers/messaging_provider.dart';
import '../models/chat_message.dart';

class SharedContentScreen extends StatefulWidget {
  final SharedContent content;

  const SharedContentScreen({super.key, required this.content});

  @override
  State<SharedContentScreen> createState() => _SharedContentScreenState();
}

class _SharedContentScreenState extends State<SharedContentScreen> {
  Conversation? _selected;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MessagingProvider>().loadConversations(force: true);
      }
    });
  }

  Future<void> _send() async {
    final conversation = _selected;
    if (conversation == null || _sending) return;

    setState(() => _sending = true);
    final provider = context.read<MessagingProvider>();
    try {
      if (widget.content.hasFile) {
        if (conversation.type == ConversationType.channel) {
          await provider.sendChannelMediaPost(
            conversationId: conversation.id,
            filePath: widget.content.filePath!,
            type: widget.content.isVideo
                ? MessageType.video
                : MessageType.image,
            content: widget.content.displayText,
          );
        } else {
          await provider.sendMediaMessage(
            conversationId: conversation.id,
            filePath: widget.content.filePath!,
            type: widget.content.isVideo
                ? MessageType.video
                : MessageType.image,
            content: widget.content.displayText.isEmpty
                ? null
                : widget.content.displayText,
          );
        }
      } else {
        if (conversation.type == ConversationType.channel) {
          await provider.createChannelPost(
            conversation.id,
            widget.content.displayText,
          );
        } else {
          await provider.sendMessage(
            conversation.id,
            widget.content.displayText,
          );
        }
      }

      if (mounted) {
        NotificationService.showSuccess(context, 'Shared to Griot');
        final tab = switch (conversation.type) {
          ConversationType.dm => 'direct',
          ConversationType.group => 'groups',
          ConversationType.channel => 'channels',
        };
        context.go('/chat?tab=$tab');
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Could not share to Griot: $e');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _conversationTitle(Conversation conversation) {
    return conversation.name ??
        conversation.otherUser?.displayName ??
        conversation.otherUser?.username ??
        (conversation.type == ConversationType.group ? 'Group' : 'Friend');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessagingProvider>();
    final conversations = provider.conversations.toList();
    final content = widget.content;

    return GradientScaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Share to Griot'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selected == null || _sending ? null : _send,
        icon: _sending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send_rounded),
        label: Text(_sending ? 'Sending…' : 'Send'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: _ContentPreview(content: content),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose where to send it',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: provider.isLoadingConversations && conversations.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : conversations.isEmpty
                  ? const Center(child: Text('No friends or groups available'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      itemCount: conversations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        final selected = _selected?.id == conversation.id;
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outlineVariant
                                        .withValues(alpha: 0.45),
                            ),
                          ),
                          leading: CircleAvatar(
                            backgroundImage: conversation.imageUrl != null
                                ? NetworkImage(conversation.imageUrl!)
                                : null,
                            child: conversation.imageUrl == null
                                ? Icon(
                                    conversation.type == ConversationType.group
                                        ? Icons.groups_rounded
                                        : conversation.type ==
                                              ConversationType.channel
                                        ? Icons.campaign_rounded
                                        : Icons.person_rounded,
                                  )
                                : null,
                          ),
                          title: Text(
                            _conversationTitle(conversation),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            conversation.type == ConversationType.group
                                ? 'Group'
                                : conversation.type == ConversationType.channel
                                ? 'Channel'
                                : 'Friend',
                          ),
                          trailing: selected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                          onTap: () => setState(() => _selected = conversation),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentPreview extends StatelessWidget {
  final SharedContent content;

  const _ContentPreview({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                content.isVideo
                    ? Icons.videocam_rounded
                    : content.isImage
                    ? Icons.image_rounded
                    : Icons.link_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Preview',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (content.hasFile && content.isImage) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                File(content.filePath!),
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          if (content.hasFile && content.isVideo)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Video attachment ready to send'),
            ),
          if (content.displayText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              content.displayText,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
