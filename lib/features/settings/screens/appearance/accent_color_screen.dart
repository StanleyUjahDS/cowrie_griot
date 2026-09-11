import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '/core/router/app_router.dart';
import '/core/theme/app_theme.dart';
import '/core/theme/theme_controller.dart';
import '/core/ui/scaffolds/gradient_scaffold.dart';

class AccentColorScreen extends StatelessWidget {
  const AccentColorScreen({super.key});

  // ============================================================
  // ACCENT LABEL
  // ============================================================

  String _accentLabel(AppThemeStyle style) {
    switch (style) {
      case AppThemeStyle.griot:
        return 'Griot';

      case AppThemeStyle.sky:
        return 'Sky';

      case AppThemeStyle.forest:
        return 'Forest';

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

      case AppThemeStyle.azure:
        return 'Azure';

      case AppThemeStyle.indigo:
        return 'Indigo';

      case AppThemeStyle.aurora:
        return 'Aurora';

      case AppThemeStyle.teal:
        return 'Teal';

      case AppThemeStyle.orange:
        return 'Orange';

      case AppThemeStyle.red:
        return 'Red';

      case AppThemeStyle.cyber:
        return 'Cyber';

      case AppThemeStyle.onyx:
        return 'Onyx';

      case AppThemeStyle.cappuccino:
        return 'Cappuccino';

      case AppThemeStyle.mint:
        return 'Mint';

      case AppThemeStyle.mono:
        return 'Mono';

      case AppThemeStyle.noir:
        return 'Noir';
    }
  }

  // ============================================================
  // ACCENT DESCRIPTION
  // ============================================================

  String _accentDescription(AppThemeStyle style) {
    switch (style) {
      case AppThemeStyle.griot:
        return 'Official Griot sea-green and gold';

      case AppThemeStyle.sky:
        return 'Clean blue inspired by summer skies';

      case AppThemeStyle.forest:
        return 'Natural green with a deep organic feel';

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

      case AppThemeStyle.azure:
        return 'Vibrant and clear azure blue';

      case AppThemeStyle.indigo:
        return 'Deep and classic indigo';

      case AppThemeStyle.aurora:
        return 'Modern energetic purple glow';

      case AppThemeStyle.teal:
        return 'Clean and balanced teal';

      case AppThemeStyle.orange:
        return 'Warm and energetic orange';

      case AppThemeStyle.red:
        return 'Bold and confident red';

      case AppThemeStyle.cyber:
        return 'Futuristic high-contrast neon cyan';

      case AppThemeStyle.onyx:
        return 'Deep OLED-optimized pure black';

      case AppThemeStyle.cappuccino:
        return 'Warm and cozy coffee-inspired neutrals';

      case AppThemeStyle.mint:
        return 'Fresh and modern energetic green';

      case AppThemeStyle.mono:
        return 'High-contrast classic black and white';

      case AppThemeStyle.noir:
        return 'Deep and elegant monochrome night';
    }
  }

  // ============================================================
  // ACCENT COLOR
  // ============================================================

  Color _accentColor(BuildContext context, AppThemeStyle style) {
    return AppTheme.primaryColor(style, Theme.of(context).brightness);
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 9),
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
          border: Border(
            top: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.6),
              width: 1.2,
            ),
            bottom: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.6),
              width: 1.2,
            ),
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
    final accent = _accentColor(context, style);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () {
        controller.setThemeStyle(style);
      },
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: accent.withValues(alpha: 0.20)),
        ),
        child: Center(
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
        ),
      ),
      title: Text(
        _accentLabel(style),
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
        color: selected ? accent : colorScheme.onSurfaceVariant,
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

  Widget _currentAccentCard(BuildContext context, ThemeController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final accent = _accentColor(context, controller.themeStyle);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          top: BorderSide(color: accent.withValues(alpha: 0.6), width: 1.2),
          bottom: BorderSide(color: accent.withValues(alpha: 0.6), width: 1.2),
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
            child: Icon(Icons.color_lens_outlined, color: accent, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current accent',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _accentLabel(controller.themeStyle),
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
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
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
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return GradientScaffold(
          appBar: AppBar(
            title: const Text(
              'Accent Color',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          child: SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
              children:
                  [
                        // ==================================================
                        // ACCENT COLOR
                        // ==================================================

                        _sectionTitle(context, 'Accent Color'),

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
                                style: AppThemeStyle.sky,
                              ),

                              _divider(context),

                              _accentTile(
                                context: context,
                                controller: controller,
                                style: AppThemeStyle.forest,
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
                                style: AppThemeStyle.azure,
                              ),

                              _divider(context),

                              _accentTile(
                                context: context,
                                controller: controller,
                                style: AppThemeStyle.indigo,
                              ),

                              _divider(context),

                              _accentTile(
                                context: context,
                                controller: controller,
                                style: AppThemeStyle.aurora,
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

                              _divider(context),

                              _accentTile(
                                context: context,
                                controller: controller,
                                style: AppThemeStyle.cyber,
                              ),

                              _divider(context),

                              _accentTile(
                                context: context,
                                controller: controller,
                                style: AppThemeStyle.onyx,
                              ),

                              _divider(context),

                              _accentTile(
                                context: context,
                                controller: controller,
                                style: AppThemeStyle.cappuccino,
                              ),

                              _divider(context),

                              _accentTile(
                                context: context,
                                controller: controller,
                                style: AppThemeStyle.mint,
                              ),

                              _divider(context),

                              _accentTile(
                                context: context,
                                controller: controller,
                                style: AppThemeStyle.mono,
                              ),

                              _divider(context),

                              _accentTile(
                                context: context,
                                controller: controller,
                                style: AppThemeStyle.noir,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ==================================================
                        // CURRENT ACCENT
                        // ==================================================
                        _currentAccentCard(context, controller),

                        const SizedBox(height: 12),

                        Center(
                          child: Text(
                            'Your accent color changes the primary color '
                            'used throughout the Griot interface.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ]
                      .animate(interval: 50.ms)
                      .fade(duration: 400.ms)
                      .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
            ),
          ),
        );
      },
    );
  }
}
