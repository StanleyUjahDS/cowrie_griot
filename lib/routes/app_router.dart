import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// screens (we will create these next)
import '../features/splash/splash_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',

    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // 🔐 AUTH (placeholder for now)
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text("Login Screen")),
        ),
      ),

      // 💬 CHAT (placeholder)
      GoRoute(
        path: '/chat',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text("Chat Home")),
        ),
      ),

      // 💰 WALLET (placeholder)
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text("Wallet")),
        ),
      ),
    ],
  );
}