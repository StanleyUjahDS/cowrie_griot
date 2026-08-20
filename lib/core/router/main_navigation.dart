import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/navigation_scroll_service.dart';

class MainNavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationShell({
    super.key,
    required this.navigationShell,
  });

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _goBranch(int index) {
    if (index == navigationShell.currentIndex) {
      // Tap current tab: trigger scroll to top
      NavigationScrollService.instance.scrollToTop(index);
      return;
    }
    
    navigationShell.goBranch(
      index,
      initialLocation: false, // Default is usually false unless we specifically want to reset
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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ========================================================
          // PAGE
          // ========================================================

          navigationShell,

          // ========================================================
          // FLOATING NAVIGATION
          // ========================================================

          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: 26,
                    sigmaY: 26,
                  ),
                  child: Container(
                    height: 68,
                    decoration: BoxDecoration(
                      color: navigationSurface.withValues(alpha: isDark ? 0.88 : 0.92),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: borderColor,
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: shadowColor,
                          blurRadius: 30,
                          spreadRadius: -8,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 5,
                      ),
                      child: Row(
                        children: [
                          // ==================================================
                          // CHAT
                          // ==================================================

                          _NavigationItem(
                            icon: Icons.chat_bubble_outline_rounded,
                            activeIcon: Icons.chat_bubble_rounded,
                            label: 'Chat',
                            index: 0,
                            currentIndex:
                            navigationShell.currentIndex,
                            primary: primary,
                            activeBackground: activeBackground,
                            inactiveColor: inactiveColor,
                            onTap: _goBranch,
                          ),

                          // ==================================================
                          // MINER
                          // ==================================================

                          _NavigationItem(
                            icon: Icons.bolt_outlined,
                            activeIcon: Icons.bolt_rounded,
                            label: 'Miner',
                            index: 1,
                            currentIndex:
                            navigationShell.currentIndex,
                            primary: primary,
                            activeBackground: activeBackground,
                            inactiveColor: inactiveColor,
                            onTap: _goBranch,
                          ),

                          // ==================================================
                          // WALLET
                          // ==================================================

                          _NavigationItem(
                            icon: Icons.account_balance_wallet_outlined,
                            activeIcon:
                            Icons.account_balance_wallet_rounded,
                            label: 'Wallet',
                            index: 2,
                            currentIndex:
                            navigationShell.currentIndex,
                            primary: primary,
                            activeBackground: activeBackground,
                            inactiveColor: inactiveColor,
                            onTap: _goBranch,
                          ),

                          // ==================================================
                          // P2P
                          // ==================================================

                          _NavigationItem(
                            icon: Icons.swap_horiz_rounded,
                            activeIcon: Icons.swap_horiz_rounded,
                            label: 'P2P',
                            index: 3,
                            currentIndex:
                            navigationShell.currentIndex,
                            primary: primary,
                            activeBackground: activeBackground,
                            inactiveColor: inactiveColor,
                            onTap: _goBranch,
                          ),

                          // ==================================================
                          // SETTINGS
                          // ==================================================

                          _NavigationItem(
                            icon: Icons.settings_outlined,
                            activeIcon: Icons.settings_rounded,
                            label: 'Settings',
                            index: 4,
                            currentIndex:
                            navigationShell.currentIndex,
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
        ],
      ),
    );
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
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 220,
            ),
            curve: Curves.easeOutCubic,
            width: 62,
            height: 56,
            decoration: BoxDecoration(
              color: isActive
                  ? activeBackground
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ==================================================
                // ICON
                // ==================================================

                AnimatedSwitcher(
                  duration: const Duration(
                    milliseconds: 180,
                  ),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: child,
                    );
                  },
                  child: Icon(
                    isActive ? activeIcon : icon,
                    key: ValueKey(isActive),
                    size: isActive ? 23 : 22,
                    color: isActive
                        ? primary
                        : inactiveColor,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                // ==================================================
                // LABEL
                // ==================================================

                AnimatedDefaultTextStyle(
                  duration: const Duration(
                    milliseconds: 180,
                  ),
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1,
                    fontWeight: isActive
                        ? FontWeight.w700
                        : FontWeight.w500,
                    letterSpacing: isActive ? 0.05 : 0,
                    color: isActive
                        ? primary
                        : inactiveColor,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}