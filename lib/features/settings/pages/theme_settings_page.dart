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
  // THEME STYLE LABEL
  // ============================================================

  String _themeStyleLabel(AppThemeStyle style) {
    switch (style) {
      case AppThemeStyle.griot:
        return 'Griot';

      case AppThemeStyle.ocean:
        return 'Ocean';

      case AppThemeStyle.emerald:
        return 'Emerald';

      case AppThemeStyle.violet:
        return 'Violet';

      case AppThemeStyle.lavender:
        return 'Lavender';

      case AppThemeStyle.rose:
        return 'Rose';

      case AppThemeStyle.gold:
        return 'Gold';

      case AppThemeStyle.midnight:
        return 'Midnight';

      case AppThemeStyle.slate:
        return 'Slate';
    }
  }

  // ============================================================
  // THEME STYLE DESCRIPTION
  // ============================================================

  String _themeStyleDescription(AppThemeStyle style) {
    switch (style) {
      case AppThemeStyle.griot:
        return 'The official Griot sea-green and gold theme';

      case AppThemeStyle.ocean:
        return 'A clean modern blue interface';

      case AppThemeStyle.emerald:
        return 'A fresh and energetic green interface';

      case AppThemeStyle.violet:
        return 'A bold modern purple interface';

      case AppThemeStyle.lavender:
        return 'A soft and elegant lavender interface';

      case AppThemeStyle.rose:
        return 'A soft elegant rose and pink interface';

      case AppThemeStyle.gold:
        return 'A premium black and gold interface';

      case AppThemeStyle.midnight:
        return 'A deep blue midnight interface';

      case AppThemeStyle.slate:
        return 'A neutral modern grey interface';
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
      color: colorScheme.onSurface.withValues(
        alpha: 0.035,
      ),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.onSurface.withValues(
              alpha: 0.08,
            ),
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
        vertical: 4,
      ),
      onTap: () {
        controller.setTheme(mode);
      },
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(
            alpha: 0.12,
          )
              : colorScheme.onSurface.withValues(
            alpha: 0.05,
          ),
          borderRadius: BorderRadius.circular(12),
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
  // THEME STYLE TILE
  // ============================================================

  Widget _themeStyleTile({
    required BuildContext context,
    required ThemeController controller,
    required AppThemeStyle style,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final selected = controller.themeStyle == style;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      onTap: () {
        controller.setThemeStyle(style);
      },
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(
            alpha: selected ? 0.16 : 0.08,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.palette_outlined,
          color: selected
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        _themeStyleLabel(style),
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: selected
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        _themeStyleDescription(style),
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
      color: colorScheme.onSurface.withValues(
        alpha: 0.07,
      ),
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
        final textTheme = theme.textTheme;

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
              padding: const EdgeInsets.fromLTRB(
                18,
                8,
                18,
                30,
              ),
              children: [
                // ==================================================
                // APPEARANCE MODE
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
                // THEME STYLE
                // ==================================================

                _sectionTitle(
                  context,
                  'Theme Style',
                ),

                _settingContainer(
                  context: context,
                  child: Column(
                    children: [
                      // GRIOT
                      _themeStyleTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.griot,
                      ),

                      _divider(context),

                      // OCEAN
                      _themeStyleTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.ocean,
                      ),

                      _divider(context),

                      // EMERALD
                      _themeStyleTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.emerald,
                      ),

                      _divider(context),

                      // VIOLET
                      _themeStyleTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.violet,
                      ),

                      _divider(context),

                      // LAVENDER
                      _themeStyleTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.lavender,
                      ),

                      _divider(context),

                      // ROSE
                      _themeStyleTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.rose,
                      ),

                      _divider(context),

                      // GOLD
                      _themeStyleTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.gold,
                      ),

                      _divider(context),

                      // MIDNIGHT
                      _themeStyleTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.midnight,
                      ),

                      _divider(context),

                      // SLATE
                      _themeStyleTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.slate,
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                // ==================================================
                // CURRENT THEME
                // ==================================================

                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(
                      alpha: 0.07,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.primary.withValues(
                        alpha: 0.14,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        color: colorScheme.primary,
                        size: 21,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Text(
                          'Using '
                              '${_themeStyleLabel(controller.themeStyle)}'
                              ' · '
                              '${_themeModeLabel(controller.themeMode)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
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