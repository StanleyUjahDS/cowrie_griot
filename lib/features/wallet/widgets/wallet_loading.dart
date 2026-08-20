import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../models/token_model.dart';
import 'token_list_item.dart';

class WalletLoading extends StatelessWidget {
  const WalletLoading({super.key});

  static const _dummyToken = TokenModel(
    name: 'Token Name Loading',
    symbol: 'SYMBOL',
    balance: 0.0000,
    valueUsd: 0.00,
    changePercent: 0.00,
    chain: 'ethereum',
    contractAddress: '0x',
    imageUrl: '',
    hasMarketData: true,
  );

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        padding: const EdgeInsets.only(top: 8),
        itemBuilder: (context, index) {
          return const TokenListItem(token: _dummyToken);
        },
      ),
    );
  }
}
