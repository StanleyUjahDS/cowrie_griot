import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ChainAssets {
  static const String _chainPath = 'assets/chains';

  static const Map<String, String> _chainLogos = {
    'ethereum': '$_chainPath/Ethereum.svg',
    'bnb': '$_chainPath/Binance.svg',
    'polygon': '$_chainPath/Polygon.svg',
    'arbitrum': '$_chainPath/Arbitrum.svg',
    'optimism': '$_chainPath/Optimism.svg',
    'base': '$_chainPath/Base.svg',
    'avalanche': '$_chainPath/Avalanche_AvaxToken 1.svg',
  };

  static String normalize(String chainName) {
    final value = chainName.trim().toLowerCase();

    if (value == 'bsc' ||
        value == 'bnb chain' ||
        value == 'binance smart chain' ||
        value == 'binance' ||
        value == 'binance-smart-chain') {
      return 'bnb';
    }

    if (value == 'eth' || value == 'ethereum mainnet') return 'ethereum';
    if (value == 'matic' || value == 'matic/polygon') return 'polygon';
    if (value == 'arb' || value == 'arbitrum-one') return 'arbitrum';
    if (value == 'op' || value == 'optimistic-ethereum') return 'optimism';
    if (value == 'avax' || value == 'avalanche-c-chain') return 'avalanche';

    return value;
  }

  static String? getLogo(String chainName) {
    return _chainLogos[normalize(chainName)];
  }

  static Widget getIcon(String chainName, {double size = 24}) {
    final assetPath = getLogo(chainName);

    if (assetPath == null) {
      return Icon(Icons.link_rounded, size: size);
    }

    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.link_rounded,
        size: size,
      ),
    );
  }
}
