import 'package:flutter/material.dart';
import '../utils/chain_assets.dart';

class TokenIcon extends StatelessWidget {
  final String imageUrl;
  final String symbol;
  final String? chainName;
  final double radius;

  const TokenIcon({
    super.key,
    this.imageUrl = '',
    this.symbol = '',
    this.chainName,
    this.radius = 24,
  });

  String _tokenAsset() {
    final key = symbol.trim().toLowerCase();

    const logos = {
      'eth': 'assets/coins_logo/eth.png',
      'ethereum': 'assets/coins_logo/eth.png',
      'bnb': 'assets/coins_logo/bnb.png',
      'usdt': 'assets/coins_logo/usdt.png',
      'usdc': 'assets/coins_logo/usdc.png',
      'matic': 'assets/coins_logo/matic.png',
      'pol': 'assets/coins_logo/matic.png',
      'btc': 'assets/coins_logo/btc.png',
      'bitcoin': 'assets/coins_logo/btc.png',
      'hbadg': 'assets/coins_logo/hbadg.png',
    };

    return logos[key] ?? 'assets/coins_logo/ic_launcher.png';
  }

  Widget _tokenImage(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (imageUrl.trim().isNotEmpty) {
      return Image.network(
        imageUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          _tokenAsset(),
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.token_rounded,
            color: colors.onSurfaceVariant,
            size: radius,
          ),
        ),
      );
    }

    return Image.asset(
      _tokenAsset(),
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.token_rounded,
        color: colors.onSurfaceVariant,
        size: radius,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: colors.surfaceContainerHighest,
            child: ClipOval(child: _tokenImage(context)),
          ),
          if (chainName != null && chainName!.trim().isNotEmpty)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: radius * 0.78,
                height: radius * 0.78,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.outlineVariant,
                    width: 0.7,
                  ),
                ),
                child: ChainAssets.getIcon(
                  chainName!,
                  size: radius * 0.55,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
