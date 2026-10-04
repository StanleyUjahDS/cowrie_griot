import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ChainAssets {
  static const String _chainPath = 'assets/chains';

  static const Map<String, String> _chainLogos = {
    'ethereum': '$_chainPath/Ethereum.svg',
    'bsc': '$_chainPath/Binance.svg',
    'polygon': '$_chainPath/Polygon.svg',
    'arbitrum': '$_chainPath/arbitrum.png',
    'optimism': '$_chainPath/Optimism.svg',
    'base': '$_chainPath/base.png',
    'avalanche': '$_chainPath/Avalanche_AvaxToken 1.svg',
  };

  static String normalize(String chainName) {
    // API responses may identify an asset as `chain:symbol` (for example
    // `ethereum:ETH`) or use a display label.  Resolve the chain portion
    // before looking up the canonical Cowrie chain artwork.
    var value = chainName.trim().toLowerCase();
    if (value.contains(':')) value = value.split(':').first.trim();
    if (value.contains('/')) value = value.split('/').first.trim();
    value = value.replaceAll('_', '-');

    if (value == 'bsc' ||
        value == 'bnb' ||
        value == 'bnb chain' ||
        value == 'binance smart chain' ||
        value == 'binance' ||
        value == 'binance-smart-chain') {
      return 'bsc';
    }

    if (value == 'eth' ||
        value == 'ethereum mainnet' ||
        value == 'ethereum-mainnet') {
      return 'ethereum';
    }
    if (value == 'matic' || value == 'polygon-mainnet') return 'polygon';
    if (value == 'arb' || value == 'arbitrum-one') return 'arbitrum';
    if (value == 'op' || value == 'optimistic-ethereum') return 'optimism';
    if (value == 'avax' || value == 'avalanche-c-chain') return 'avalanche';

    return value;
  }

  static bool isValidEvmAddress(String? value) {
    if (value == null) return false;
    return RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(value);
  }

  static String? getLogo(String chainName) {
    return _chainLogos[normalize(chainName)];
  }

  static Widget getIcon(String chainName, {double size = 24}) {
    final assetPath = getLogo(chainName);

    if (assetPath == null) {
      return Icon(Icons.link_rounded, size: size);
    }

    if (assetPath.endsWith('.svg')) {
      return SvgPicture.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.link_rounded, size: size),
      );
    }
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.link_rounded, size: size),
    );
  }
}
