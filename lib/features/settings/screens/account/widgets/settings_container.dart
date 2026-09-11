import 'package:flutter/material.dart';
import '../../../../../core/ui/widgets/griot_branded_container.dart';

class SettingsContainer extends StatelessWidget {
  final List<Widget> children;

  const SettingsContainer({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return GriotBrandedContainer(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(
        children: children,
      ),
    );
  }
}

// ============================================================
// SETTINGS DIVIDER
// ============================================================

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        left: 70,
        right: 14,
      ),
      child: Divider(
        height: 1,
        thickness: 0.6,
        color: colorScheme.onSurface.withValues(alpha: 0.065),
      ),
    );
  }
}