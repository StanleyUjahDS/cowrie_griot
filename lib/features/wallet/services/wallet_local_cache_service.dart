import '../../../core/cache/local_json_cache.dart';
import '../models/token_model.dart';

class WalletCacheSnapshot {
  final String address;
  final List<TokenModel> tokens;
  final List<TokenModel> popularAssets;

  const WalletCacheSnapshot({
    required this.address,
    required this.tokens,
    required this.popularAssets,
  });
}

class WalletLocalCacheService {
  static const _key = 'wallet_ui_snapshot_v1';
  final LocalJsonCache _cache;

  const WalletLocalCacheService({LocalJsonCache cache = const LocalJsonCache()})
      : _cache = cache;

  Future<void> save({
    required String address,
    required List<TokenModel> tokens,
    required List<TokenModel> popularAssets,
  }) {
    return _cache.write(_key, {
      'address': address,
      'tokens': tokens.map((token) => token.toJson()).toList(),
      'popularAssets': popularAssets.map((token) => token.toJson()).toList(),
    });
  }

  Future<WalletCacheSnapshot?> load() async {
    final raw = await _cache.read(_key);
    if (raw is! Map) return null;

    final tokens = raw['tokens'];
    final popularAssets = raw['popularAssets'];
    if (tokens is! List || popularAssets is! List) return null;

    return WalletCacheSnapshot(
      address: raw['address']?.toString() ?? '',
      tokens: tokens
          .whereType<Map>()
          .map((json) => TokenModel.fromJson(Map<String, dynamic>.from(json)))
          .toList(),
      popularAssets: popularAssets
          .whereType<Map>()
          .map((json) => TokenModel.fromJson(Map<String, dynamic>.from(json)))
          .toList(),
    );
  }
}
