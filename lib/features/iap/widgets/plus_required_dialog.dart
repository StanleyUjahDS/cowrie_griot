import 'package:flutter/material.dart';

/// Explains why a Plus-only action is unavailable before offering the upgrade.
Future<bool> showPlusRequiredDialog(BuildContext context) async {
  final shouldOpenPlus = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      final textTheme = Theme.of(dialogContext).textTheme;
      return Align(
        alignment: Alignment.bottomCenter,
        child: Dialog(
          alignment: Alignment.bottomCenter,
          insetPadding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
          backgroundColor: colors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(32)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    color: colors.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start your own Campfire',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'A Griot Plus feature',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Bring people together around a topic, story, or idea. Browse and join live Campfires for free.',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _BenefitRow(
              icon: Icons.graphic_eq_rounded,
              text: 'Host voice or video Campfires',
            ),
            _BenefitRow(
              icon: Icons.radio_rounded,
              text: 'Record and share the conversation',
            ),
            _BenefitRow(
              icon: Icons.link_rounded,
              text: 'Invite people with an expiring call link',
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Explore Griot Plus'),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not now'),
              ),
            ),
          ],
            ),
          ),
        ),
      );
    },
  );
  return shouldOpenPlus == true;
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
