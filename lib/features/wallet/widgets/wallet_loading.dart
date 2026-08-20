import 'package:flutter/material.dart';
import '../../../core/ui/widgets/griot_branded_loading.dart';

class WalletLoading extends StatelessWidget {
  const WalletLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const GriotBrandedLoading(
      title: 'Preparing your wallet',
      message: 'Fetching your balances and tokens from the blockchain...',
      icon: Icons.account_balance_wallet_outlined,
    );
  }
}
