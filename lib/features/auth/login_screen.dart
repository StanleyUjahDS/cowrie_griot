import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00211A),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            context.go('/chat');
          },
          child: const Text("Login / Enter Wallet"),
        ),
      ),
    );
  }
}