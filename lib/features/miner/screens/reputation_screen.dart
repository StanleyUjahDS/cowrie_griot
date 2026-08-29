import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/reputation_model.dart';
import '../providers/reputation_provider.dart';
import '../providers/referral_provider.dart';
import '../../users/providers/user_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/services/notification_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReputationScreen extends StatefulWidget {
  const ReputationScreen({super.key});

  @override
  State<ReputationScreen> createState() => _ReputationScreenState();
}

class _ReputationScreenState extends State<ReputationScreen> {
  final GlobalKey _certificateKey = GlobalKey();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ReputationProvider>().loadReputation();
      }
    });
  }

  Future<void> _shareShowcase(ReputationData reputation, String? displayName, String? referralCode) async {
    setState(() => _isGenerating = true);

    try {
      final boundary = _certificateKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Capture boundary not found');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/griot_prestige_passport.png').create();
      await file.writeAsBytes(buffer);

      final shareLink = 'https://griot.network/join?ref=$referralCode';
      final shareText = 'My status on the Griot app: ${reputation.tier.name}! 🦡\n\nJoin the Cowrie Protocol legacy: $shareLink';
      
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: shareText,
        ),
      );
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to generate showcase: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    final user = context.watch<UserProvider>().user;
    final referralProvider = context.watch<ReferralProvider>();
    final referralData = referralProvider.data;

    return Consumer<ReputationProvider>(
      builder: (context, provider, child) {
        final reputation = provider.data;
        
        // Use preferred referral code (Username or Wallet)
        final referralCode = referralData?.referralCode ?? user?.username?.replaceFirst('@', '') ?? user?.walletAddress ?? 'join';

        return GradientScaffold(
          appBar: AppBar(
            title: const Text(
              'Reputation',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            actions: [
              if (reputation != null)
                IconButton(
                  onPressed: _isGenerating ? null : () => _shareShowcase(reputation, user?.displayName, referralCode),
                  icon: _isGenerating 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.share_rounded),
                  tooltip: 'Showcase your rank',
                ),
              IconButton(
                onPressed: () {
                  provider.loadReputation();
                  referralProvider.loadReferralStatus();
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          child: Stack(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeOutQuart,
                child: _buildMainView(context, provider, referralProvider, reputation, user, referralCode, colors, text),
              ),

              // HIDDEN CERTIFICATE DESIGN (Rendered for capture only)
              if (reputation != null)
                Positioned(
                  left: -2000, 
                  child: RepaintBoundary(
                    key: _certificateKey,
                    child: _PrestigePassport(
                      reputation: reputation,
                      displayName: user?.displayName ?? 'Griot User',
                      username: user?.username,
                      avatarUrl: user?.avatarUrl,
                      referralCode: referralCode,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainView(
    BuildContext context, 
    ReputationProvider provider, 
    ReferralProvider referralProvider,
    ReputationData? reputation,
    dynamic user,
    String referralCode,
    ColorScheme colors,
    TextTheme text,
  ) {
    // Priority 1: If we have no data and it's either loading OR it's the very first frame
    if (reputation == null && (provider.isLoading || provider.error == null)) {
      return const Center(
        key: ValueKey('loading'),
        child: GriotLoader(),
      );
    }

    // Priority 2: If we have no data and an error occurred
    if (reputation == null && provider.error != null) {
      return _buildErrorState(colors, text, provider);
    }

    // Priority 3: If we have no data and no error (shouldn't really happen with Priority 1, but for safety)
    if (reputation == null) {
      return _buildEmptyState(colors, text, provider);
    }

    return RefreshIndicator(
      key: const ValueKey('content'),
      onRefresh: () async {
        await Future.wait([
          provider.loadReputation(),
          referralProvider.loadReferralStatus(),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          _buildPrestigeHero(reputation, colors, text),
          const SizedBox(height: 40),
          _buildProgressionCard(reputation, colors, text),
          const SizedBox(height: 32),
          _buildJourneyGuide(context, reputation.tier.name),
          const SizedBox(height: 24),
          _buildFooter(colors, text),
        ].animate(interval: 50.ms).fade(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
      ),
    );
  }

  Widget _buildPrestigeHero(ReputationData reputation, ColorScheme colors, TextTheme text) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 10),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 150, height: 150,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.parseHexColor(reputation.tier.badgeColor).withValues(alpha: 0.05)),
              ).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.3, 1.3), duration: 3.seconds).fadeOut(),
              Container(
                width: 135, height: 135,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.parseHexColor(reputation.tier.badgeColor).withValues(alpha: 0.1))),
              ),
              SizedBox(
                width: 120, height: 120,
                child: CircularProgressIndicator(value: 1.0, strokeWidth: 4, color: colors.onSurface.withValues(alpha: 0.05)),
              ),
              SizedBox(
                width: 120, height: 120,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: reputation.progress),
                  duration: 1800.ms,
                  curve: Curves.elasticOut,
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value, strokeWidth: 6, strokeCap: StrokeCap.round, color: AppColors.parseHexColor(reputation.tier.badgeColor),
                  ),
                ),
              ),
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.parseHexColor(reputation.tier.badgeColor), AppColors.parseHexColor(reputation.tier.badgeColor).withValues(alpha: 0.85)]),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2.5),
                  boxShadow: [BoxShadow(color: AppColors.parseHexColor(reputation.tier.badgeColor).withValues(alpha: 0.5), blurRadius: 30)],
                ),
                child: Icon(
                  reputation.tier.name.toLowerCase().contains('ultimate') ? Icons.stars_rounded : Icons.workspace_premium_rounded,
                  size: 46, color: Colors.white,
                ),
              ).animate(onPlay: (c) => c.repeat()).shimmer(delay: 2.seconds, duration: 2.seconds),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            reputation.tier.name.toUpperCase(),
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 2.0, color: AppColors.parseHexColor(reputation.tier.badgeColor)),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3, end: 0),
          const SizedBox(height: 12),
          Text(
            'Earn trust, grow your legacy.',
            style: text.labelMedium?.copyWith(color: colors.onSurfaceVariant.withValues(alpha: 0.5), letterSpacing: 1.0, fontWeight: FontWeight.w600),
          ).animate().fadeIn(delay: 800.ms),
        ],
      ),
    );
  }

  Widget _buildProgressionCard(ReputationData reputation, ColorScheme colors, TextTheme text) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [colors.surfaceContainerLow, colors.surfaceContainerLow.withValues(alpha: 0.8)]),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.parseHexColor(reputation.tier.badgeColor).withValues(alpha: 0.1), width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            bottom: -40,
            child: Opacity(
              opacity: 0.05,
              child: Image.asset(
                'assets/cowrie_images/Cowrie7.png',
                width: 160,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('PROGRESSION', style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant.withValues(alpha: 0.6), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    if (reputation.nextTier != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('NEXT: ${reputation.nextTier!.name.toUpperCase()}', style: text.labelSmall?.copyWith(color: colors.primary, fontWeight: FontWeight.w900, fontSize: 9)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: reputation.progress),
                    duration: 1500.ms,
                    curve: Curves.fastOutSlowIn,
                    builder: (context, value, _) => LinearProgressIndicator(value: value, minHeight: 10, backgroundColor: colors.surface, color: AppColors.parseHexColor(reputation.tier.badgeColor)),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    reputation.nextTier == null ? 'ULTIMATE RANK ACHIEVED' : '${(reputation.progress * 100).toInt()}% TOWARDS NEXT RANK',
                    style: text.labelSmall?.copyWith(color: AppColors.parseHexColor(reputation.tier.badgeColor).withValues(alpha: 0.7), fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildFooter(ColorScheme colors, TextTheme text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: colors.onSurfaceVariant, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text('Higher tiers unlock exclusive benefits and mining boosts within the network.', style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant, fontSize: 11))),
        ],
      ),
    ).animate().fadeIn(delay: 1200.ms);
  }

  Widget _buildErrorState(ColorScheme colors, TextTheme text, ReputationProvider provider) {
    return SizedBox(height: 400, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline_rounded, size: 48, color: colors.error),
      const SizedBox(height: 16),
      Text('Unable to load reputation', style: text.titleMedium),
      const SizedBox(height: 24),
      FilledButton(onPressed: provider.loadReputation, child: const Text('Retry')),
    ])));
  }

  Widget _buildEmptyState(ColorScheme colors, TextTheme text, ReputationProvider provider) {
    return SizedBox(height: 400, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.sentiment_dissatisfied_rounded, size: 48, color: colors.onSurfaceVariant),
      const SizedBox(height: 16),
      Text('No reputation data found', style: text.titleMedium),
      const SizedBox(height: 24),
      FilledButton(onPressed: provider.loadReputation, child: const Text('Refresh Status')),
    ])));
  }

  Widget _buildJourneyGuide(BuildContext context, String currentTierName) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    final tiers = [
      {'name': 'Initiate Badger', 'desc': 'Your journey begins here.', 'color': '#64748B'},
      {'name': 'Seeker Badger', 'desc': 'You are becoming an active member.', 'color': '#22C55E'},
      {'name': 'Scout Badger', 'desc': 'Your consistency is being recognized.', 'color': '#3B82F6'},
      {'name': 'Explorer Badger', 'desc': 'You are making a meaningful contribution.', 'color': '#A855F7'},
      {'name': 'Builder Badger', 'desc': 'You are becoming a trusted community member.', 'color': '#14B8A6'},
      {'name': 'Guardian Badger', 'desc': 'You demonstrate strong and consistent participation.', 'color': '#F97316'},
      {'name': 'Master Badger', 'desc': 'Your contribution carries significant weight.', 'color': '#EF4444'},
      {'name': 'Champion Badger', 'desc': 'You are among the most experienced members.', 'color': '#4F46E5'},
      {'name': 'Legendary Badger', 'desc': 'Your reputation stands out across the community.', 'color': '#EAB308'},
      {'name': 'Ultimate Badger', 'desc': 'The highest level of Griot recognition.', 'color': '#67E8F9'},
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: colors.surfaceContainerLowest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(32), border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_awesome_motion_rounded, color: colors.primary, size: 20),
            const SizedBox(width: 12),
            Text('BADGER JOURNEY', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: colors.primary)),
          ]),
          const SizedBox(height: 28),
          ...tiers.asMap().entries.map((entry) {
            final index = entry.key; final tier = entry.value;
            final isCurrent = tier['name']!.toLowerCase() == currentTierName.toLowerCase();
            final tierColor = AppColors.parseHexColor(tier['color']);
            return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: isCurrent ? tierColor : tierColor.withValues(alpha: 0.2), border: isCurrent ? Border.all(color: Colors.white, width: 2) : null, boxShadow: isCurrent ? [BoxShadow(color: tierColor.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2)] : null)),
                if (index != tiers.length - 1) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [tierColor.withValues(alpha: isCurrent ? 0.5 : 0.15), AppColors.parseHexColor(tiers[index + 1]['color']!).withValues(alpha: 0.15)])))),
              ]),
              const SizedBox(width: 20),
              Expanded(child: Padding(padding: EdgeInsets.only(bottom: index == tiers.length - 1 ? 0 : 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tier['name']!.toUpperCase(), style: text.labelMedium?.copyWith(fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w800, fontSize: 11, letterSpacing: 0.8, color: isCurrent ? tierColor : colors.onSurface.withValues(alpha: 0.6))),
                if (isCurrent) ...[const SizedBox(height: 4), Text(tier['desc']!, style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.4, fontStyle: FontStyle.italic))],
              ]))),
            ]));
          }),
        ],
      ),
    ).animate().fadeIn(delay: 1.seconds);
  }
}

// ============================================================================
// PRESTIGE PASSPORT (The Shared Certificate)
// ============================================================================

class _PrestigePassport extends StatelessWidget {
  final ReputationData reputation;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String referralCode;

  const _PrestigePassport({
    required this.reputation,
    required this.displayName,
    required this.referralCode,
    this.username,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final tierColor = AppColors.parseHexColor(reputation.tier.badgeColor);
    final link = 'https://griot.network/join?ref=$referralCode';
    
    // Use the actual theme surface colors instead of hardcoded ones
    final cardBg = isDark ? colors.surface : Colors.white;
    final textMain = colors.onSurface;
    final textSub = colors.onSurfaceVariant;
    final chipBg = colors.surfaceContainerHighest.withValues(alpha: 0.5);
    final chipBorder = colors.outlineVariant.withValues(alpha: 0.3);

    return Theme(
      data: theme,
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(54),
        child: Container(
          width: 420,
          height: 740,
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(54),
            border: Border.all(
              color: isDark ? tierColor.withValues(alpha: 0.2) : colors.outlineVariant,
              width: 2,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Branded Background Ring (Centered)
              Positioned.fill(
                child: Center(
                  child: Opacity(
                    opacity: isDark ? 0.07 : 0.04,
                    child: Image.asset(
                      'assets/cowrie_images/Cowrie8.png',
                      width: 550,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              
              // Atmospheric Glow
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        tierColor.withValues(alpha: isDark ? 0.15 : 0.1),
                        tierColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              
              Column(
                children: [
                  // 2. Branding
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/cowrie_images/cowriesvg.svg',
                            width: 14,
                            height: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'COWRIE PROTOCOL',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const Spacer(flex: 2),
                  
                  // 3. Central Identity Showcase
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: tierColor.withValues(alpha: isDark ? 0.1 : 0.05), width: 1),
                        ),
                      ),
                      // Main Glowing Sphere
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              tierColor,
                              tierColor.withValues(alpha: 0.8),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tierColor.withValues(alpha: 0.4),
                              blurRadius: 40,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(-4, -4),
                            ),
                          ],
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
                        ),
                        child: Icon(
                          reputation.tier.name.toLowerCase().contains('ultimate') 
                            ? Icons.stars_rounded 
                            : Icons.workspace_premium_rounded,
                          size: 75,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // 4. Rank Typography
                  Text(
                    reputation.tier.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textMain,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PRESTIGE LEVEL ATTAINED',
                    style: TextStyle(
                      color: tierColor.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                    ),
                  ),
                  
                  const Spacer(flex: 3),
                  
                  // 5. Verified Member Chip
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: chipBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: tierColor.withValues(alpha: 0.5), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: tierColor.withValues(alpha: 0.1),
                            backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty) 
                                ? NetworkImage(avatarUrl!) 
                                : null,
                            child: (avatarUrl == null || avatarUrl!.isEmpty) 
                                ? Icon(Icons.person_rounded, color: textSub, size: 36)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  color: textMain,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    username != null ? '@$username' : 'VERIFIED MEMBER',
                                    style: TextStyle(
                                      color: tierColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.verified_rounded, color: tierColor, size: 14),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // 6. Referral Deep Link Footer
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'JOIN THE LEGACY',
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Scan the code to join the Griot app and start your Badger journey with me.',
                              style: TextStyle(
                                color: textSub,
                                fontSize: 10,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: link,
                          version: QrVersions.auto,
                          size: 64.0,
                          gapless: true,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                          // embeddedImage: const AssetImage('assets/coins_logo/ic_launcher.png'),
                          embeddedImageStyle: const QrEmbeddedImageStyle(
                            size: Size(28, 28),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
