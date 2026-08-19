import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ChainAssets {
  static const String _chainPath = 'assets/chains';
  static const String _legacyLogoPath = 'assets/coins_logo';

  static const Map<String, String> _chainLogos = {
    'ethereum': '$_chainPath/Ethereum.svg',
    'bnb': '$_legacyLogoPath/Ellipse 111-3.png',
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

    if (assetPath.toLowerCase().endsWith('.svg')) {
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

    return Image.asset(
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
