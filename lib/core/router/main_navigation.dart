import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';
import '../services/navigation_scroll_service.dart';
import '../../features/chat/widgets/chat_drawer.dart';
import '../../features/chat/providers/messaging_provider.dart';

class MainNavigationShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  const MainNavigationShell({super.key, required this.navigationShell});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  String? _lastRoutePath;
  int? _lastNavTapIndex;
  DateTime? _lastNavTapAt;

  void _dismissTransientInput() {
    // A focused field can outlive a child route in the indexed shell. If it
    // does, the platform view-inset remains non-zero and the shell's floating
    // controls stay lifted after the user has left that screen.
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _goBranch(int index) {
    final now = DateTime.now();
    final isDoubleTap =
        _lastNavTapIndex == index &&
        _lastNavTapAt != null &&
        now.difference(_lastNavTapAt!) <= const Duration(milliseconds: 650);
    _lastNavTapIndex = index;
    _lastNavTapAt = now;
    _dismissTransientInput();
    // The global navigation bar remains available while a discovery feed is
    // scrolling; restore it before changing branches so a hidden animation
    // can never make the main navigation feel unresponsive.
    NavigationScrollService.instance.setNavigationVisible(true);
    if (index == widget.navigationShell.currentIndex) {
      // A single tap on the active destination is intentionally a no-op.
      // Return-to-top and refresh are reserved for a deliberate double tap.
      if (!isDoubleTap) return;
      // Emit the signal before changing the branch location so an already
      // mounted screen can react immediately. The post-frame signal below is
      // also needed when goBranch restores a nested route and rebuilds its
      // scroll view; otherwise the first notification can arrive while the
      // controller has no clients and the visible list stays scrolled down.
      NavigationScrollService.instance.scrollToTop(index);
      NavigationScrollService.instance.refreshBranch(index);
      widget.navigationShell.goBranch(index, initialLocation: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        NavigationScrollService.instance.scrollToTop(index);
      });
      return;
    }

    // Main navigation buttons represent the five root destinations. Always
    // enter the selected branch's root so a nested child screen from an
    // earlier visit cannot make the wrong destination appear selected.
    widget.navigationShell.goBranch(index, initialLocation: true);
  }

  Widget _icon(IconData icon, bool active, Color primary, Color onPrimary) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? primary : Colors.transparent,
        border: Border.all(
          color: active ? onPrimary : primary.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Icon(
        icon,
        size: 24,
        color: active ? onPrimary : primary.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _iconWithBadge({
    required IconData icon,
    required bool active,
    required Color primary,
    required Color onPrimary,
    required int count,
  }) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: _icon(icon, active, primary, onPrimary),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final messaging = context.watch<MessagingProvider>();

    // ============================================================
    // COLORS
    // ============================================================

    final Color primary = colorScheme.primary;
    final Color onPrimary = colorScheme.onPrimary;
    final Color navigationSurface = colorScheme.surface;

    final routePath = GoRouterState.of(context).uri.path;
    if (_lastRoutePath != null && _lastRoutePath != routePath) {
      _dismissTransientInput();
      // A stateful shell keeps branch screens mounted. Reset the global
      // navigation chrome when changing branches so a hidden Camp nav bar
      // cannot remain hidden after switching to Chat, Wallet, or Settings.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          NavigationScrollService.instance.setNavigationVisible(true);
        }
      });
    }
    _lastRoutePath = routePath;
    final keepDiscoveryChromeDown =
        routePath == '/chat' || routePath == '/campfires';
    final shellMediaQuery = keepDiscoveryChromeDown
        ? MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero)
        : MediaQuery.of(context);
    return MediaQuery(
      data: shellMediaQuery,
      child: PopScope<void>(
        onPopInvokedWithResult: (didPop, result) {
          // Also clear focus when the platform back action pops a nested
          // screen. This keeps the shell inset and floating actions reset.
          _dismissTransientInput();
        },
        child: Scaffold(
          key: MainNavigationShell.scaffoldKey,
          backgroundColor: theme.scaffoldBackgroundColor,
          // Keep the bottom navigation anchored when a child search field opens
          // the keyboard. The child screen owns the search surface; this shell
          // must not reposition the global navigation controls.
          resizeToAvoidBottomInset: false,
          extendBody: true,
          drawer: ChatDrawer(),
          body: widget.navigationShell,
          bottomNavigationBar: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SizedBox(
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(60),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: navigationSurface.withValues(
                              alpha: isDark ? 0.12 : 0.18,
                            ),
                            borderRadius: BorderRadius.circular(60),
                            border: Border(
                              top: BorderSide(
                                color: primary.withValues(alpha: 0.6),
                                width: 1.0,
                              ),
                              bottom: BorderSide(
                                color: primary.withValues(alpha: 0.6),
                                width: 1.0,
                              ),
                            ),
                          ),
                          // The global bottom navigation is stable by design.
                          // Discovery chrome may collapse while scrolling,
                          // but hiding this bar changes the viewport and makes
                          // every feed jump underneath the user's finger.
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final designWidth = constraints.maxWidth < 400
                                  ? 400.0
                                  : constraints.maxWidth;
                              return FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: designWidth,
                                  child: GNav(
                                    selectedIndex:
                                        widget.navigationShell.currentIndex,
                                    onTabChange: _goBranch,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    gap: 0,
                                    iconSize: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 12,
                                    ),
                                    tabMargin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                      vertical: 4,
                                    ),
                                    duration: const Duration(milliseconds: 400),
                                    tabBackgroundColor: primary.withValues(
                                      alpha: 0.2,
                                    ),
                                    textStyle: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: primary,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                    tabs: [
                                      GButton(
                                        icon: Icons.chat_bubble_outline_rounded,
                                        text: 'Chat',
                                        leading: _iconWithBadge(
                                          icon: Icons.chat_bubble_rounded,
                                          active:
                                              widget
                                                  .navigationShell
                                                  .currentIndex ==
                                              0,
                                          primary: primary,
                                          onPrimary: onPrimary,
                                          count: messaging.unreadMessageCount,
                                        ),
                                      ),
                                      GButton(
                                        icon: Icons.cabin_outlined,
                                        text: 'Camp',
                                        leading: _icon(
                                          Icons.cabin_rounded,
                                          widget.navigationShell.currentIndex ==
                                              1,
                                          primary,
                                          onPrimary,
                                        ),
                                      ),
                                      GButton(
                                        icon: Icons.bolt_outlined,
                                        text: 'Reputation',
                                        leading: _icon(
                                          Icons.bolt_rounded,
                                          widget.navigationShell.currentIndex ==
                                              2,
                                          primary,
                                          onPrimary,
                                        ),
                                      ),
                                      GButton(
                                        icon: Icons
                                            .account_balance_wallet_outlined,
                                        text: 'Wallet',
                                        leading: _icon(
                                          Icons.account_balance_wallet_rounded,
                                          widget.navigationShell.currentIndex ==
                                              3,
                                          primary,
                                          onPrimary,
                                        ),
                                      ),
                                      GButton(
                                        icon: Icons.settings_outlined,
                                        text: 'Settings',
                                        leading: _icon(
                                          Icons.settings_rounded,
                                          widget.navigationShell.currentIndex ==
                                              4,
                                          primary,
                                          onPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
