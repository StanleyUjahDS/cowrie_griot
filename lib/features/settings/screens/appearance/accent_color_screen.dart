import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/core/router/app_router.dart';
import '/core/theme/theme_controller.dart';
import '/core/ui/scaffolds/gradient_scaffold.dart';

class AccentColorScreen extends StatelessWidget {
  const AccentColorScreen({
    super.key,
  });

  // ============================================================
  // ACCENT LABEL
  // ============================================================

  String _accentLabel(AppThemeStyle style) {
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

      case AppThemeStyle.telegram:
        return 'Telegram';

      case AppThemeStyle.signal:
        return 'Signal';

      case AppThemeStyle.discord:
        return 'Discord';

      case AppThemeStyle.teal:
        return 'Teal';

      case AppThemeStyle.orange:
        return 'Orange';

      case AppThemeStyle.red:
        return 'Red';
    }
  }

  // ============================================================
  // ACCENT DESCRIPTION
  // ============================================================

  String _accentDescription(AppThemeStyle style) {
    switch (style) {
      case AppThemeStyle.griot:
        return 'Official Griot sea-green and gold';

      case AppThemeStyle.ocean:
        return 'Clean blue inspired by modern messaging apps';

      case AppThemeStyle.emerald:
        return 'Fresh green inspired by familiar chat apps';

      case AppThemeStyle.violet:
        return 'Modern and expressive purple';

      case AppThemeStyle.lavender:
        return 'Soft and elegant purple';

      case AppThemeStyle.rose:
        return 'Warm and elegant rose pink';

      case AppThemeStyle.gold:
        return 'Premium gold with a refined feel';

      case AppThemeStyle.midnight:
        return 'Cool blue with a deep modern feel';

      case AppThemeStyle.slate:
        return 'Neutral grey for a clean minimal interface';

      case AppThemeStyle.telegram:
        return 'Clean messaging blue';

      case AppThemeStyle.signal:
        return 'Simple and calm blue';

      case AppThemeStyle.discord:
        return 'Modern community-inspired indigo';

      case AppThemeStyle.teal:
        return 'Clean and balanced teal';

      case AppThemeStyle.orange:
        return 'Warm and energetic orange';

      case AppThemeStyle.red:
        return 'Bold and confident red';
    }
  }

  // ============================================================
  // ACCENT COLOR
  // ============================================================

  Color _accentColor(
      AppThemeStyle style,
      ) {
    switch (style) {
      case AppThemeStyle.griot:
        return const Color(0xFFD4A84F);

      case AppThemeStyle.ocean:
        return const Color(0xFF1877F2);

      case AppThemeStyle.emerald:
        return const Color(0xFF25D366);

      case AppThemeStyle.violet:
        return const Color(0xFF8B6CFF);

      case AppThemeStyle.lavender:
        return const Color(0xFFB59CFF);

      case AppThemeStyle.rose:
        return const Color(0xFFFF4F87);

      case AppThemeStyle.gold:
        return const Color(0xFFE2B85B);

      case AppThemeStyle.midnight:
        return const Color(0xFF6D8CFF);

      case AppThemeStyle.slate:
        return const Color(0xFFB0B7C3);

      case AppThemeStyle.telegram:
        return const Color(0xFF229ED9);

      case AppThemeStyle.signal:
        return const Color(0xFF3A76F0);

      case AppThemeStyle.discord:
        return const Color(0xFF5865F2);

      case AppThemeStyle.teal:
        return const Color(0xFF009688);

      case AppThemeStyle.orange:
        return const Color(0xFFFF9800);

      case AppThemeStyle.red:
        return const Color(0xFFE53935);
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
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: child,
      ),
    );
  }

  // ============================================================
  // ACCENT TILE
  // ============================================================

  Widget _accentTile({
    required BuildContext context,
    required ThemeController controller,
    required AppThemeStyle style,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final selected = controller.themeStyle == style;
    final accent = _accentColor(style);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      onTap: () {
        controller.setThemeStyle(style);
      },
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: accent.withValues(alpha: 0.20),
          ),
        ),
        child: Center(
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      title: Text(
        _accentLabel(style),
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: selected
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        _accentDescription(style),
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        selected
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected
            ? accent
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
      indent: 76,
      endIndent: 16,
      color: colorScheme.onSurface.withValues(alpha: 0.07),
    );
  }

  // ============================================================
  // CURRENT ACCENT CARD
  // ============================================================

  Widget _currentAccentCard(
      BuildContext context,
      ThemeController controller,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final accent = _accentColor(
      controller.themeStyle,
    );

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.color_lens_outlined,
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(
            width: 11,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Current accent',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  _accentLabel(
                    controller.themeStyle,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
        ],
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

        return GradientScaffold(
          appBar: AppBar(
            title: const Text(
              'Accent Color',
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
                // ACCENT COLOR
                // ==================================================

                _sectionTitle(
                  context,
                  'Accent Color',
                ),

                _settingContainer(
                  context: context,
                  child: Column(
                    children: [
                      _accentTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.griot,
                      ),

                      _divider(context),

                      _accentTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.ocean,
                      ),

                      _divider(context),

                      _accentTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.emerald,
                      ),

                      _divider(context),

                      _accentTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.violet,
                      ),

                      _divider(context),

                      _accentTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.lavender,
                      ),

                      _divider(context),

                      _accentTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.rose,
                      ),

                      _divider(context),

                      _accentTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.gold,
                      ),

                      _divider(context),

                      _accentTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.midnight,
                      ),

                      _divider(context),

                      _accentTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.slate,
                      ),

                      _divider(context),

                      _accentTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.telegram,
                      ),

                      _divider(context),

                      _accentTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.signal,
                      ),

                      _divider(context),

                      _accentTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.discord,
                      ),

                      _divider(context),

                      _accentTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.teal,
                      ),

                      _divider(context),

                      _accentTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.orange,
                      ),

                      _divider(context),

                      _accentTile(
                        context: context,
                        controller: controller,
                        style: AppThemeStyle.red,
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                // ==================================================
                // CURRENT ACCENT
                // ==================================================

                _currentAccentCard(
                  context,
                  controller,
                ),

                const SizedBox(
                  height: 12,
                ),

                Text(
                  'Your accent color changes the primary color '
                      'used throughout the Griot interface.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
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