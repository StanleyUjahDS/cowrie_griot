import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChatHomeScreen extends StatelessWidget {
  const ChatHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Griot Chat"),
        backgroundColor: const Color(0xFF00211A),
      ),
      body: const Center(
        child: Text("Chat Home Screen"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/wallet');
        },
        child: const Icon(Icons.account_balance_wallet),
      ),
    );
  }
}