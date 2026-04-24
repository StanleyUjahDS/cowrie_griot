import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Griot Wallet"),
        backgroundColor: const Color(0xFF00211A),
      ),
      body: const Center(
        child: Text("Wallet Screen"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/chat');
        },
        child: const Icon(Icons.chat),
      ),
    );
  }
}