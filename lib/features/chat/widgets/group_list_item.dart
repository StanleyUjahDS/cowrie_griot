import 'package:flutter/material.dart';

import '../models/chat_group.dart';

class GroupListItem extends StatelessWidget {
  final ChatGroup group;
  final VoidCallback? onTap;

  const GroupListItem({
    super.key,
    required this.group,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final description = group.description?.trim() ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      leading: CircleAvatar(
        radius: 27,
        backgroundColor:
        colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.groups_rounded,
          size: 27,
          color: colorScheme.primary,
        ),
      ),
      title: Text(
        group.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          description.isNotEmpty
              ? description
              : 'Group conversation',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}