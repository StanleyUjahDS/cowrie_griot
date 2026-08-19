import 'package:flutter/material.dart';

class ChainAssets {
  static const String _basePath = 'assets/coins_logo';

  static const Map<String, String> _chainLogos = {
    'ethereum': '$_basePath/Ellipse 111.png',
    'solana': '$_basePath/Ellipse 111-1.png',
    'polygon': '$_basePath/Ellipse 111-2.png',
    'bnb': '$_basePath/Ellipse 111-3.png',
    'bnb chain': '$_basePath/Ellipse 111-3.png',
    'bitcoin': '$_basePath/Ellipse 111-4.png',
  };

  static String normalize(String chainName) {
    final value = chainName.trim().toLowerCase();

    if (value == 'bsc' || value == 'binance smart chain' || value == 'binance') {
      return 'bnb';
    }
    if (value == 'eth') {
      return 'ethereum';
    }
    if (value == 'matic') {
      return 'polygon';
    }

    return value;
  }

  static String getLogo(String chainName) {
    return _chainLogos[normalize(chainName)] ?? '$_basePath/ic_launcher.png';
  }

  static Widget getIcon(String chainName, {double size = 24}) {
    final assetPath = getLogo(chainName);

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
