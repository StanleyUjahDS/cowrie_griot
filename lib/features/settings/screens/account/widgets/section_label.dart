// lib/features/settings/screens/account/widgets/section_label.dart

import 'package:flutter/material.dart';

class SectionLabel extends StatelessWidget {
  final String title;

  const SectionLabel({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        top: 24,
        bottom: 9,
      ),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}