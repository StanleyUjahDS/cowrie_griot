import 'package:flutter/material.dart';

class WalletLoading extends StatelessWidget {
  const WalletLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}
