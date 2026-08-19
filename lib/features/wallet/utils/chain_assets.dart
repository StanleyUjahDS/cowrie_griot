import 'package:flutter/material.dart';

class ChainAssets {
  static const String _basePath = 'assets/coins_logo';

  static const Map<String, String> _chainLogos = {
    'Ethereum': '$_basePath/Ellipse 111.png',
    'Solana': '$_basePath/Ellipse 111-1.png',
    'Polygon': '$_basePath/Ellipse 111-2.png',
    'BNB Chain': '$_basePath/Ellipse 111-3.png',
    'Bitcoin': '$_basePath/Ellipse 111-4.png',
  };

  static String getLogo(String chainName) {
    return _chainLogos[chainName] ?? '$_basePath/ic_launcher.png';
  }

  static Widget getIcon(String chainName, {double size = 24}) {
    final assetPath = getLogo(chainName);
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.help_outline,
        size: size,
      ),
    );
  }
}
