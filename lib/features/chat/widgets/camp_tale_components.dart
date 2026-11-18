import 'package:flutter/material.dart';

import '../../../core/ui/widgets/griot_branded_container.dart';
import '../../../core/ui/widgets/griot_avatar.dart';
import '../../../core/ui/widgets/griot_plus_badge.dart';
import '../../../core/ui/widgets/griot_pioneer_badge.dart';
import '../../../core/ui/widgets/native_ad.dart';
import '../../../core/theme/app_text.dart';

/// One scroll contract for Camp surfaces. Keeping the parent physics explicit
/// prevents the feed, profile and reader from feeling like three different
/// apps, especially when pulling to refresh or reaching the list edge.
const ScrollPhysics campScrollPhysics = BouncingScrollPhysics(
  parent: AlwaysScrollableScrollPhysics(),
);

/// Shared visual primitives for every Tale surface in Griot Camp.
///
/// Keeping these primitives in one place prevents the public feed, Camp
/// profiles and the dedicated reader from drifting into different card
/// languages as features are added.
class CampTaleCardSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const CampTaleCardSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GriotBrandedContainer(
      margin: margin,
      padding: padding,
      borderRadius: 18,
      blurSigma: 0,
      showShadow: false,
      backgroundColor: colors.surface,
      borderGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors.primary.withValues(alpha: .52),
          colors.outlineVariant.withValues(alpha: .22),
          colors.outlineVariant.withValues(alpha: .14),
          colors.primary.withValues(alpha: .44),
        ],
        stops: const [0, .24, .72, 1],
      ),
      child: child,
    );
  }
}

/// Shared repost/quote attribution treatment used by feed, profile and reader.
/// It follows the familiar social pattern: the current author owns the card,
/// while the original creator and source are shown as a compact quoted block.
class CampTaleReshareCard extends StatelessWidget {
  final String label;
  final String sourceAuthorName;
  final String? sourceAuthorUsername;
  final String? sourceAuthorSubtitle;
  final bool sourceAuthorIsPlus;
  final bool sourceAuthorIsPioneer;
  final String? sourceAuthorAvatarUrl;
  final String sourceText;
  final List<String> sourceMediaUrls;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onSourceTap;
  final Widget Function(BuildContext, List<String>)? mediaBuilder;

  const CampTaleReshareCard({
    super.key,
    this.label = 'Retold from another Tale',
    required this.sourceAuthorName,
    this.sourceAuthorUsername,
    this.sourceAuthorSubtitle,
    this.sourceAuthorIsPlus = false,
    this.sourceAuthorIsPioneer = false,
    this.sourceAuthorAvatarUrl,
    required this.sourceText,
    this.sourceMediaUrls = const [],
    this.onAuthorTap,
    this.onSourceTap,
    this.mediaBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onSourceTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: colors.primary.withValues(alpha: .8),
              width: 3,
            ),
          ),
        ),
        child: GriotBrandedContainer(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          borderRadius: 16,
          backgroundColor: colors.surfaceContainerHighest.withValues(
            alpha: .32,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.repeat_rounded,
                          size: 17,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (onSourceTap != null)
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                      ],
                    ),
                    if (sourceAuthorName.trim().isNotEmpty ||
                        sourceAuthorAvatarUrl != null) ...[
                      const SizedBox(height: 7),
                      InkWell(
                        onTap: onAuthorTap,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              GriotAvatar(
                                radius: 14,
                                avatarUrl: sourceAuthorAvatarUrl,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            sourceAuthorName.trim().isEmpty
                                                ? 'Original creator'
                                                : sourceAuthorName,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: colors.onSurface,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        if (sourceAuthorIsPlus) ...[
                                          const SizedBox(width: 4),
                                          const GriotPlusBadge(
                                            isPlus: true,
                                            compact: true,
                                          ),
                                        ],
                                        if (sourceAuthorIsPioneer) ...[
                                          const SizedBox(width: 3),
                                          const GriotPioneerBadge(
                                            compact: true,
                                          ),
                                        ],
                                      ],
                                    ),
                                    if ((sourceAuthorUsername ?? '')
                                            .trim()
                                            .isNotEmpty ||
                                        (sourceAuthorSubtitle ?? '')
                                            .trim()
                                            .isNotEmpty)
                                      Text(
                                        [
                                          if ((sourceAuthorUsername ?? '')
                                              .trim()
                                              .isNotEmpty)
                                            '@${sourceAuthorUsername!.trim().replaceFirst('@', '')}',
                                          if ((sourceAuthorSubtitle ?? '')
                                              .trim()
                                              .isNotEmpty)
                                            sourceAuthorSubtitle!.trim(),
                                        ].join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          fontSize: 10,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (onAuthorTap != null)
                                Text(
                                  'View profile',
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    CampTaleText(text: sourceText, fontSize: 14),
                    if (sourceMediaUrls.isNotEmpty && mediaBuilder != null) ...[
                      const SizedBox(height: 10),
                      mediaBuilder!(context, sourceMediaUrls),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared AdMob native placement for Camp surfaces.
///
/// The ad itself remains fully owned by Google Mobile Ads/mediation; this
/// widget only supplies the Camp surface, label, spacing and themed chrome so
/// ads read as a natural part of every Camp list instead of a separate UI.
class CampNativeAdCard extends StatelessWidget {
  final Key? adKey;
  final String placement;
  final bool compact;
  final double? height;

  const CampNativeAdCard({
    super.key,
    this.adKey,
    this.placement = 'Camp',
    this.compact = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GriotNativeAd(
      key: adKey,
      // Camp uses the full native layout so body copy and the CTA are not
      // silently removed by the compact factory variant.
      compact: compact,
      height: height ?? (compact ? 250 : 420),
      cardBuilder: (context, ad) => CampTaleCardSurface(
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 15,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Sponsored',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    placement,
                    style: TextStyle(
                      color: colors.onSurfaceVariant.withValues(alpha: .72),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: ad,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact surface for comments and replies. Comments are part of the
/// parent Tale conversation, so they should read as one continuous thread
/// rather than a stack of nested cards.
class CampTaleCommentSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool reply;

  const CampTaleCommentSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 10),
    this.margin,
    this.reply = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(
          alpha: reply ? .16 : .24,
        ),
        borderRadius: BorderRadius.circular(reply ? 14 : 18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .38)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class CampTaleActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  final Color? activeColor;

  const CampTaleActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = active
        ? (activeColor ?? colors.primary)
        : colors.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: color),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.socialAction.copyWith(color: color),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A consistent vertical rail used for linked Tale parts and comment replies.
class CampTaleThreadRail extends StatelessWidget {
  final Widget child;
  final bool isLast;
  final double width;

  const CampTaleThreadRail({
    super.key,
    required this.child,
    required this.isLast,
    this.width = 28,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: (width - 2) / 2,
            top: 13,
            bottom: 0,
            child: Container(
              width: 2,
              color: colors.primary.withValues(alpha: .28),
            ),
          ),
        Positioned(
          left: (width - 10) / 2,
          top: 6,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: width + 8),
          child: child,
        ),
      ],
    );
  }
}

/// The same author header for a Tale, comment or reply; only actions vary.
class CampTaleHeader extends StatelessWidget {
  const CampTaleHeader({
    super.key,
    required this.authorName,
    required this.subtitle,
    this.avatarUrl,
    this.onAuthorTap,
    this.isPlus = false,
    this.isPioneer = false,
    this.badges = const [],
    this.inlineBadges = const [],
    this.attribution,
    required this.menu,
  });
  final String authorName;
  final String subtitle;
  final String? avatarUrl;
  final VoidCallback? onAuthorTap;
  final bool isPlus;
  final bool isPioneer;
  final List<Widget> badges;
  final List<Widget> inlineBadges;
  final Widget? attribution;
  final Widget menu;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          InkWell(
            onTap: onAuthorTap,
            customBorder: const CircleBorder(),
            child: GriotAvatar(radius: 22, avatarUrl: avatarUrl),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onAuthorTap,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.socialName,
                        ),
                      ),
                      if (isPlus) ...[
                        const SizedBox(width: 5),
                        const GriotPlusBadge(isPlus: true, compact: true),
                      ],
                      if (isPioneer) ...[
                        const SizedBox(width: 4),
                        const GriotPioneerBadge(compact: true),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.socialMeta.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (inlineBadges.isNotEmpty) ...[
            const SizedBox(width: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: inlineBadges
                  .map(
                    (badge) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: badge,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          menu,
        ],
      ),
      if (badges.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 54, top: 6),
          child: Wrap(spacing: 4, runSpacing: 4, children: badges),
        ),
      if (attribution != null)
        Padding(
          padding: const EdgeInsets.only(left: 54, top: 4),
          child: attribution,
        ),
    ],
  );
}

/// Expands only overflowing text. Thread membership is controlled separately.
class CampTaleText extends StatefulWidget {
  const CampTaleText({super.key, required this.text, this.fontSize = 16});
  final String text;
  final double fontSize;
  @override
  State<CampTaleText> createState() => _CampTaleTextState();
}

class _CampTaleTextState extends State<CampTaleText> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant CampTaleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(
      AppText.socialBody.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: widget.fontSize,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 6,
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.text,
                style: style,
                maxLines: _expanded ? null : 6,
                overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
                softWrap: true,
              ),
              if (overflows)
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.only(top: 3),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    _expanded ? 'Show less' : 'Show more',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
