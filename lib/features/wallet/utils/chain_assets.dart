import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ChainAssets {
  static const String _basePath = 'assets/chains';

  static const Map<String, String> _chainLogos = {
    'ethereum': '$_basePath/Ethereum.svg',
    'polygon': '$_basePath/Polygon.svg',
    'arbitrum': '$_basePath/Arbitrum.svg',
    'optimism': '$_basePath/Optimism.svg',
    'base': '$_basePath/Base.svg',
    'avalanche': '$_basePath/Avalanche_AvaxToken 1.svg',
  };

  static String normalize(String chainName) {
    final value = chainName.trim().toLowerCase();

    if (value == 'bsc' ||
        value == 'bnb chain' ||
        value == 'binance smart chain' ||
        value == 'binance') {
      return 'bnb';
    }

    if (value == 'eth') return 'ethereum';
    if (value == 'matic' || value == 'matic/polygon') return 'polygon';
    if (value == 'arb') return 'arbitrum';
    if (value == 'op') return 'optimism';
    if (value == 'avax') return 'avalanche';

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
