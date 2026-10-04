import 'package:flutter/material.dart';

/// Consistent confirmation surface used for destructive and financial actions.
Future<bool> showGriotConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final colors = Theme.of(context).colorScheme;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: colors.surfaceContainerHigh,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: .55),
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            message,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            _DialogActionColumn(children: [
              TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
              FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: colors.error,
                      foregroundColor: colors.onError,
                    )
                  : null,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
              ),
            ]),
          ],
        ),
      ) ??
      false;
}

Future<String?> showGriotChoiceDialog(
  BuildContext context, {
  required String title,
  required String message,
  required List<(String, String)> choices,
}) {
  final colors = Theme.of(context).colorScheme;
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: colors.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message, style: TextStyle(color: colors.onSurfaceVariant)),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        _DialogActionColumn(children: [
          TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
          ...choices.map(
          (choice) => FilledButton(
            onPressed: () => Navigator.pop(dialogContext, choice.$2),
            child: Text(choice.$1),
          ),
          ),
        ]),
      ],
    ),
  );
}

class _DialogActionColumn extends StatelessWidget {
  final List<Widget> children;
  const _DialogActionColumn({required this.children});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              children[i],
            ],
          ],
        ),
      );
}
