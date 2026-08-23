import 'wallet_crypto_service.dart';
import 'wallet_storage_service.dart';

// ============================================================
// WALLET SERVICE
// ============================================================

class WalletService {
  final WalletCryptoService _cryptoService;
  final WalletStorageService _storageService;

  WalletService({
    required WalletCryptoService cryptoService,
    required WalletStorageService storageService,
  })  : _cryptoService = cryptoService,
        _storageService = storageService;

  WalletCryptoService get crypto => _cryptoService;

  Future<WalletData> createWallet() async {
    final wallet = await _cryptoService.createWallet();
    await _storageService.saveWallet(wallet);
    return wallet;
  }

  Future<WalletData> restoreWallet(String mnemonic) async {
    final normalizedMnemonic = mnemonic
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();

    if (normalizedMnemonic.isEmpty) {
      throw Exception('Recovery phrase cannot be empty.');
    }

    final wallet = await _cryptoService.restoreWallet(normalizedMnemonic);
    await _storageService.replaceWallet(wallet);
    return wallet;
  }

  Future<bool> hasWallet() async {
    final wallet = await _storageService.loadWallet();
    return wallet != null;
  }

  Future<WalletData?> loadWallet() {
    return _storageService.loadWallet();
  }

  Future<String?> getAddress() {
    return _storageService.getAddress();
  }

  Future<String?> getPublicKey() {
    return _storageService.getPublicKey();
  }

  Future<String?> getPrivateKey() {
    return _storageService.getPrivateKey();
  }

  Future<String?> getMnemonic() {
    return _storageService.getMnemonic();
  }

  Future<String?> signMessage(String message) async {
    final privateKey = await getPrivateKey();

    if (privateKey == null || privateKey.isEmpty) {
      return null;
    }

    final signature = _cryptoService.signMessage(
      privateKey: privateKey,
      message: message,
    );

    if (!signature.startsWith('0x')) {
      throw Exception('Invalid Ethereum signature: missing 0x prefix.');
    }

    if (signature.length != 132) {
      throw Exception(
        'Invalid Ethereum signature length: ${signature.length}. Expected 132 characters.',
      );
    }

    return signature;
  }

  // ============================================================
  // SIGN EVM TRANSACTION LOCALLY
  // ============================================================

  Future<String?> signNativeTransaction({
    required String to,
    required String valueRaw,
    required int nonce,
    required String gasLimit,
    String? gasPrice,
    String? maxFeePerGas,
    String? maxPriorityFeePerGas,
    required int chainId,
    String? dataHex,
  }) async {
    final privateKey = await getPrivateKey();

    if (privateKey == null || privateKey.isEmpty) {
      return null;
    }

    return _cryptoService.signNativeTransaction(
      privateKey: privateKey,
      to: to,
      valueRaw: valueRaw,
      nonce: nonce,
      gasLimit: gasLimit,
      gasPrice: gasPrice,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      chainId: chainId,
      dataHex: dataHex,
    );
  }

  bool isValidAddress(String address) {
    return _cryptoService.isValidAddress(address);
  }

  Future<void> clearWallet() {
    return _storageService.clearWallet();
  }

  // ============================================================
  // HIDDEN TOKENS STORAGE DELEGATION
  // ============================================================

  Future<List<String>> getHiddenTokens() {
    return _storageService.getHiddenTokens();
  }

  Future<void> saveHiddenTokens(List<String> keys) {
    return _storageService.saveHiddenTokens(keys);
  }

  // ============================================================
  // FILTERS STORAGE DELEGATION
  // ============================================================

  Future<Map<String, dynamic>> getWalletFilters() {
    return _storageService.getWalletFilters();
  }

  Future<void> saveWalletFilters(Map<String, dynamic> filters) {
    return _storageService.saveWalletFilters(filters);
  }
}
