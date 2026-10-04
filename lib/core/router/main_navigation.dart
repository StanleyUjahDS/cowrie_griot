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
  // ============================================================
  // NAVIGATION
  // ============================================================

  void _goBranch(int index) {
    if (index == widget.navigationShell.currentIndex) {
      // Tap current tab: trigger scroll to top
      NavigationScrollService.instance.scrollToTop(index);
      return;
    }

    // Preserve each tab's existing navigator stack when switching tabs.
    // Resetting to the branch root on every tap recreates the screen and
    // produces the visible loading/flicker users see across the main app.
    widget.navigationShell.goBranch(index, initialLocation: false);
  }

  Widget _icon(IconData icon, bool active, Color primary, Color onPrimary) {
    return Container(
      padding: const EdgeInsets.all(6),
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
        size: 22,
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
    final keepDiscoveryChromeDown = routePath == '/chat' ||
        routePath == '/campfires';
    final shellMediaQuery = keepDiscoveryChromeDown
        ? MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero)
        : MediaQuery.of(context);
    final keyboardInset =
        View.of(context).viewInsets.bottom / View.of(context).devicePixelRatio;

    return MediaQuery(
      data: shellMediaQuery,
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
          child: Transform.translate(
            offset: Offset(0, keyboardInset),
            child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
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
                  child: GNav(
                    selectedIndex: widget.navigationShell.currentIndex,
                    onTabChange: _goBranch,
                    gap: 2,
                    iconSize: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    tabMargin: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 6,
                    ),
                    duration: const Duration(milliseconds: 400),
                    tabBackgroundColor: primary.withValues(alpha: 0.2),
                    textStyle: theme.textTheme.labelMedium?.copyWith(
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
                          active: widget.navigationShell.currentIndex == 0,
                          primary: primary,
                          onPrimary: onPrimary,
                          count: messaging.unreadMessageCount,
                        ),
                      ),
                      GButton(
                        icon: Icons.local_fire_department_outlined,
                        text: 'Campfire',
                        leading: _icon(
                          Icons.local_fire_department_rounded,
                          widget.navigationShell.currentIndex == 1,
                          primary,
                          onPrimary,
                        ),
                      ),
                      GButton(
                        icon: Icons.bolt_outlined,
                        text: 'Miner',
                        leading: _icon(
                          Icons.bolt_rounded,
                          widget.navigationShell.currentIndex == 2,
                          primary,
                          onPrimary,
                        ),
                      ),
                      GButton(
                        icon: Icons.account_balance_wallet_outlined,
                        text: 'Wallet',
                        leading: _icon(
                          Icons.account_balance_wallet_rounded,
                          widget.navigationShell.currentIndex == 3,
                          primary,
                          onPrimary,
                        ),
                      ),
                      GButton(
                        icon: Icons.settings_outlined,
                        text: 'Settings',
                        leading: _icon(
                          Icons.settings_rounded,
                          widget.navigationShell.currentIndex == 4,
                          primary,
                          onPrimary,
                        ),
                      ),
                    ],
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
