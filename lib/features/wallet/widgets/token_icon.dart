import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  static const String _hbadgAsset = 'assets/chains/Hbadger.svg';

  bool get _isHbadg => symbol.trim().toUpperCase() == 'HBADG';

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

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.surfaceContainerHighest,
      child: Text(
        _initials(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          fontSize: radius * (_initials().length > 1 ? 0.48 : 0.65),
        ),
      ),
    );
  }

  Widget _nativeChainImage(BuildContext context) {
    final chainLogo = ChainAssets.getLogo(chainName ?? '');
    if (chainLogo == null) return _initialFallback(context);

    return ClipOval(
      child: SvgPicture.asset(
        chainLogo,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _initialFallback(context),
      ),
    );
  }

  Widget _tokenImage(BuildContext context) {
    // Native assets use the local chain logo as their primary logo.
    if (isNative) {
      return _nativeChainImage(context);
    }

    // HBADG is a canonical local asset.
    if (_isHbadg) {
      return ClipOval(
        child: SvgPicture.asset(
          _hbadgAsset,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _initialFallback(context),
        ),
      );
    }

    // Use the token's own remote logo only when it exists.
    if (imageUrl.trim().isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl.trim(),
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _initialFallback(context),
        ),
      );
    }

    // Never fall back to another token's image.
    return _initialFallback(context);
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
