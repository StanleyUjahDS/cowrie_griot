import 'package:flutter/material.dart';

import '../utils/chain_assets.dart';

class TokenIcon extends StatelessWidget {
  final String imageUrl;
  final String symbol;
  final String? name;
  final String? chainName;
  final bool isNative;
  final double radius;

  const TokenIcon({
    super.key,
    this.imageUrl = '',
    this.symbol = '',
    this.name,
    this.chainName,
    this.isNative = false,
    this.radius = 24,
  });

  String _initials() {
    final cleanedName = (name ?? '').trim();
    final cleanedSymbol = symbol.trim();
    final source = cleanedName.isNotEmpty ? cleanedName : cleanedSymbol;

    if (source.isEmpty) return '?';

    final words = source
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.length >= 2) {
      return '${words.first[0]}${words.last[0]}'.toUpperCase();
    }

    final value = words.first.toUpperCase();
    return value.length >= 2 ? value.substring(0, 2) : value;
  }

  Widget _initialFallback(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials = _initials();

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.surfaceContainerHighest,
      child: Text(
        initials,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          fontSize: radius * (initials.length > 1 ? 0.48 : 0.65),
        ),
      ),
    );
  }

  Widget _remoteTokenImage(BuildContext context) {
    final url = imageUrl.trim();

    if (url.isEmpty) {
      return _initialFallback(context);
    }

    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _initialFallback(context),
      ),
    );
  }

  Widget _tokenImage(BuildContext context) {
    // The backend/CoinGecko image is the primary token logo for BOTH
    // native and non-native assets.
    //
    // ChainAssets is intentionally NOT used as the main token image.
    // It is used only for the small chain-identification badge below.
    return _remoteTokenImage(context);
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
          _tokenImage(context),
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
