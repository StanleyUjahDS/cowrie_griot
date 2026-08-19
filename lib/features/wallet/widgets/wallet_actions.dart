import 'package:flutter/material.dart';
import 'wallet_action_box.dart';

class WalletActions extends StatelessWidget {
  final VoidCallback onSendTap;
  final VoidCallback onReceiveTap;
  final VoidCallback onSwapTap;
  final VoidCallback onBuyTap;

  const WalletActions({
    super.key,
    required this.onSendTap,
    required this.onReceiveTap,
    required this.onSwapTap,
    required this.onBuyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Row(
        children: [
          Expanded(
            child: WalletActionBox(
              icon: Icons.arrow_upward_rounded,
              label: 'Send',
              onTap: onSendTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: WalletActionBox(
              icon: Icons.arrow_downward_rounded,
              label: 'Receive',
              onTap: onReceiveTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: WalletActionBox(
              icon: Icons.swap_horiz_rounded,
              label: 'Swap',
              onTap: onSwapTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: WalletActionBox(
              icon: Icons.shopping_cart_outlined,
              label: 'Buy',
              onTap: onBuyTap,
            ),
          ),
        ],
      ),
    );
  }
}
