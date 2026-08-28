import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/navigation_scroll_service.dart';
import '../../features/chat/widgets/chat_drawer.dart';
import '../../features/chat/providers/messaging_provider.dart';

class MainNavigationShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationShell({
    super.key,
    required this.navigationShell,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _goBranch(int index) {
    if (index == widget.navigationShell.currentIndex) {
      // Tap current tab: trigger scroll to top
      NavigationScrollService.instance.scrollToTop(index);
      return;
    }
    
    widget.navigationShell.goBranch(
      index,
      initialLocation: true,
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
    final Color navigationSurface = colorScheme.surface;
    final Color inactiveColor = colorScheme.onSurface.withValues(alpha: 0.55);
    final Color activeBackground = colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.055);
    final Color borderColor = colorScheme.outline.withValues(alpha: isDark ? 0.12 : 0.10);
    final Color shadowColor = colorScheme.shadow.withValues(alpha: isDark ? 0.30 : 0.10);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: widget.navigationShell.currentIndex == 0 ? _buildChatDrawer(context) : null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ========================================================
          // PAGE
          // ========================================================

          widget.navigationShell,

          // ========================================================
          // FLOATING NAVIGATION
          // ========================================================

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: 20,
                        sigmaY: 20,
                      ),
                      child: Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: navigationSurface.withValues(alpha: isDark ? 0.82 : 0.88),
                          borderRadius: BorderRadius.circular(33),
                          border: Border.all(
                            color: borderColor,
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: shadowColor,
                              blurRadius: 20,
                              spreadRadius: -6,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _NavigationItem(
                                icon: Icons.chat_bubble_outline_rounded,
                                activeIcon: Icons.chat_bubble_rounded,
                                label: 'Chat',
                                index: 0,
                                currentIndex: widget.navigationShell.currentIndex,
                                primary: primary,
                                activeBackground: activeBackground,
                                inactiveColor: inactiveColor,
                                onTap: _goBranch,
                              ),
                              Consumer<MessagingProvider>(
                                builder: (context, provider, _) {
                                  return _NavigationItem(
                                    icon: Icons.notifications_none_rounded,
                                    activeIcon: Icons.notifications_rounded,
                                    label: 'Activity',
                                    index: 1,
                                    currentIndex: widget.navigationShell.currentIndex,
                                    primary: primary,
                                    activeBackground: activeBackground,
                                    inactiveColor: inactiveColor,
                                    onTap: _goBranch,
                                    badgeCount: provider.totalUnreadCount,
                                  );
                                },
                              ),
                              _NavigationItem(
                                icon: Icons.bolt_outlined,
                                activeIcon: Icons.bolt_rounded,
                                label: 'Miner',
                                index: 2,
                                currentIndex: widget.navigationShell.currentIndex,
                                primary: primary,
                                activeBackground: activeBackground,
                                inactiveColor: inactiveColor,
                                onTap: _goBranch,
                              ),
                              _NavigationItem(
                                icon: Icons.account_balance_wallet_outlined,
                                activeIcon: Icons.account_balance_wallet_rounded,
                                label: 'Wallet',
                                index: 3,
                                currentIndex: widget.navigationShell.currentIndex,
                                primary: primary,
                                activeBackground: activeBackground,
                                inactiveColor: inactiveColor,
                                onTap: _goBranch,
                              ),
                              _NavigationItem(
                                icon: Icons.settings_outlined,
                                activeIcon: Icons.settings_rounded,
                                label: 'Settings',
                                index: 4,
                                currentIndex: widget.navigationShell.currentIndex,
                                primary: primary,
                                activeBackground: activeBackground,
                                inactiveColor: inactiveColor,
                                onTap: _goBranch,
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
        ],
      ),
    );
  }

  // ============================================================
  // CHAT DRAWER (Moved from ChatHomeScreen)
  // ============================================================

  Widget _buildChatDrawer(BuildContext context) {
    // We'll import these in the file
    return const ChatDrawer();
  }
}

// ==================================================================
// NAVIGATION ITEM
// ==================================================================

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  final int index;
  final int currentIndex;

  final Color primary;
  final Color activeBackground;
  final Color inactiveColor;

  final ValueChanged<int> onTap;
  final int badgeCount;

  const _NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.primary,
    required this.activeBackground,
    required this.inactiveColor,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = currentIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 200,
        ),
        curve: Curves.easeOutCubic,
        width: 68,
        height: 54,
        decoration: BoxDecoration(
          color: isActive
              ? activeBackground
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ==================================================
            // ICON
            // ==================================================

            AnimatedSwitcher(
              duration: const Duration(
                milliseconds: 150,
              ),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isActive ? activeIcon : icon,
                    key: ValueKey(isActive),
                    size: isActive ? 26 : 25,
                    color: isActive
                        ? primary
                        : inactiveColor,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(
              height: 1,
            ),

            // ==================================================
            // LABEL
            // ==================================================

            AnimatedDefaultTextStyle(
              duration: const Duration(
                milliseconds: 150,
              ),
              style: TextStyle(
                fontSize: 10.5,
                height: 1,
                fontWeight: isActive
                    ? FontWeight.w900
                    : FontWeight.w600,
                letterSpacing: isActive ? 0.4 : 0,
                color: isActive
                    ? primary
                    : inactiveColor,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
