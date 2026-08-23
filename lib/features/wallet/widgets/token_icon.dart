import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../utils/chain_assets.dart';
import '../utils/token_assets.dart';

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
    final localLogo = TokenAssets.getLogo(symbol);
    if (localLogo != null) {
      if (localLogo.endsWith('.svg')) {
        return ClipOval(
          child: SvgPicture.asset(
            localLogo,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.contain,
          ),
        );
      } else {
        return ClipOval(
          child: Image.asset(
            localLogo,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.contain,
          ),
        );
      }
    }
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
              right: -2,
              bottom: -2,
              child: Container(
                width: radius * 0.88,
                height: radius * 0.88,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.outlineVariant,
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: ChainAssets.getIcon(
                    chainName!,
                    size: radius * 0.62,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
