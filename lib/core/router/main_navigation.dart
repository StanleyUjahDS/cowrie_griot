import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainNavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationShell({
    super.key,
    required this.navigationShell,
  });

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: navigationShell,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _goBranch,
        type: BottomNavigationBarType.fixed,

        // ================= TEXT COLORS =================
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: isDark ? Colors.white : Colors.black,

        // ================= ICON COLORS =================
        selectedIconTheme: IconThemeData(
          color: colorScheme.primary,
          size: 28,
        ),

        unselectedIconTheme: IconThemeData(
          color: isDark ? Colors.white54 : Colors.black,
          size: 24,
        ),

        // ================= BACKGROUND =================
        backgroundColor: isDark
            ? const Color(0xFF0B1F1A)
            : Colors.white,

        elevation: 10,

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.comment_bank),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.construction),
            label: 'Miner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flash_on),
            label: 'P2P',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}