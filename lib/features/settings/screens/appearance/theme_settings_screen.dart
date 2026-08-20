import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/core/router/app_router.dart';
import '/core/theme/theme_controller.dart';
import '/core/ui/scaffolds/gradient_scaffold.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({
    super.key,
  });

  // ============================================================
  // THEME MODE LABEL
  // ============================================================

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System default';

      case ThemeMode.light:
        return 'Light';

      case ThemeMode.dark:
        return 'Dark';
    }
  }

  // ============================================================
  // THEME MODE DESCRIPTION
  // ============================================================

  String _themeModeDescription(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Follow your device appearance';

      case ThemeMode.light:
        return 'Always use light appearance';

      case ThemeMode.dark:
        return 'Always use dark appearance';
    }
  }

  // ============================================================
  // THEME MODE ICON
  // ============================================================

  IconData _themeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;

      case ThemeMode.light:
        return Icons.light_mode_rounded;

      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
    }
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(
      BuildContext context,
      String title,
      ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        4,
        8,
        4,
        9,
      ),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ============================================================
  // SETTING CONTAINER
  // ============================================================

  Widget _settingContainer({
    required BuildContext context,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.onSurface.withValues(alpha: 0.035),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: child,
      ),
    );
  }

  // ============================================================
  // THEME MODE TILE
  // ============================================================

  Widget _themeModeTile({
    required BuildContext context,
    required ThemeController controller,
    required ThemeMode mode,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final selected = controller.themeMode == mode;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 5,
      ),
      onTap: () {
        controller.setTheme(mode);
      },
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          _themeModeIcon(mode),
          color: selected
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        _themeModeLabel(mode),
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: selected
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        _themeModeDescription(mode),
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        selected
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant,
      ),
    );
  }

  // ============================================================
  // DIVIDER
  // ============================================================

  Widget _divider(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Divider(
      height: 1,
      indent: 74,
      endIndent: 16,
      color: colorScheme.onSurface.withValues(alpha: 0.07),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final controller = AppRouter.themeController;

    return AnimatedBuilder(
      animation: controller,
      builder: (
          context,
          _,
          ) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return GradientScaffold(
          appBar: AppBar(
            title: const Text(
              'Theme',
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            foregroundColor: colorScheme.onSurface,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              onPressed: () {
                context.pop();
              },
              icon: const Icon(
                Icons.arrow_back_rounded,
              ),
            ),
          ),
          child: SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                18,
                8,
                18,
                30,
              ),
              children: [
                // ==================================================
                // APPEARANCE
                // ==================================================

                _sectionTitle(
                  context,
                  'Appearance',
                ),

                _settingContainer(
                  context: context,
                  child: Column(
                    children: [
                      _themeModeTile(
                        context: context,
                        controller: controller,
                        mode: ThemeMode.system,
                      ),

                      _divider(context),

                      _themeModeTile(
                        context: context,
                        controller: controller,
                        mode: ThemeMode.light,
                      ),

                      _divider(context),

                      _themeModeTile(
                        context: context,
                        controller: controller,
                        mode: ThemeMode.dark,
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                // ==================================================
                // INFORMATION
                // ==================================================

                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: colorScheme.primary,
                        size: 21,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Text(
                          'Theme controls the overall light or dark '
                              'appearance of Griot. Accent colors can be '
                              'changed separately.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}