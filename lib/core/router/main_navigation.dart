import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

class MainNavigationShell extends StatefulWidget {
  final Widget child;
  const MainNavigationShell({super.key, required this.child});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int index = 0;

  final List<String> routes = [
    '/main_navigation/wallet',
    '/main_navigation/p2p',
    '/main_navigation/miner',
    '/main_navigation/chat',
    '/main_navigation/settings',
  ];

  void _onTabChange(int i) {
    setState(() => index = i);
    context.go(routes[i]);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Scaffold(
      body: widget.child,

      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: GNav(
          selectedIndex: index,
          onTabChange: _onTabChange,

          gap: 6,
          iconSize: 22,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          duration: const Duration(milliseconds: 300),

          tabBackgroundColor: primary.withOpacity(0.12),
          activeColor: primary,
          color: textColor,

          tabs: const [
            GButton(
              icon: Icons.account_balance_wallet,
              text: 'Wallet',
            ),
            GButton(
              icon: Icons.people_alt,
              text: 'P2P',
            ),
            GButton(
              icon: Icons.memory,
              text: 'Miner',
            ),
            GButton(
              icon: Icons.chat_bubble_outline,
              text: 'Chat',
            ),
            GButton(
              icon: Icons.settings,
              text: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}