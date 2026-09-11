import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../services/navigation_scroll_service.dart';
import '../../features/chat/widgets/chat_drawer.dart';

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

    widget.navigationShell.goBranch(index, initialLocation: true);
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
        size: 20,
        color: active ? onPrimary : primary.withValues(alpha: 0.7),
      ),
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

    // ============================================================
    // COLORS
    // ============================================================

    final Color primary = colorScheme.primary;
    final Color onPrimary = colorScheme.onPrimary;
    final Color navigationSurface = colorScheme.surface;

    return Scaffold(
      key: MainNavigationShell.scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      drawer: ChatDrawer(),
      body: widget.navigationShell,
      bottomNavigationBar: Padding(
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
                      fontSize: 10,
                    ),
                    tabs: [
                      GButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        text: 'Chat',
                        leading: _icon(
                          Icons.chat_bubble_rounded,
                          widget.navigationShell.currentIndex == 0,
                          primary,
                          onPrimary,
                        ),
                      ),
                      GButton(
                        icon: Icons.notifications_none_rounded,
                        text: 'Updates',
                        leading: _icon(
                          Icons.notifications_rounded,
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
    );
  }
}
