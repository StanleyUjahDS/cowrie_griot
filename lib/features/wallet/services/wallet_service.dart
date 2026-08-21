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

  // ============================================================
  // CREATE WALLET
  // ============================================================

  Future<WalletData> createWallet() async {
    final WalletData wallet =
    await _cryptoService.createWallet();

    await _storageService.saveWallet(
      wallet,
    );

    return wallet;
  }

  // ============================================================
  // RESTORE WALLET
  // ============================================================

  Future<WalletData> restoreWallet(
      String mnemonic,
      ) async {
    final normalizedMnemonic = mnemonic
        .trim()
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .toLowerCase();

    if (normalizedMnemonic.isEmpty) {
      throw Exception(
        'Recovery phrase cannot be empty.',
      );
    }

    final WalletData wallet =
    await _cryptoService.restoreWallet(
      normalizedMnemonic,
    );

    await _storageService.replaceWallet(
      wallet,
    );

    return wallet;
  }

  // ============================================================
  // HAS WALLET
  // ============================================================

  Future<bool> hasWallet() async {
    final wallet = await _storageService.loadWallet();
    return wallet != null;
  }

  // ============================================================
  // LOAD WALLET
  // ============================================================

  Future<WalletData?> loadWallet() {
    return _storageService.loadWallet();
  }

  // ============================================================
  // GET ADDRESS
  // ============================================================

  Future<String?> getAddress() {
    return _storageService.getAddress();
  }

  // ============================================================
  // GET PUBLIC KEY
  // ============================================================

  Future<String?> getPublicKey() {
    return _storageService.getPublicKey();
  }

  // ============================================================
  // GET PRIVATE KEY
  // ============================================================

  Future<String?> getPrivateKey() {
    return _storageService.getPrivateKey();
  }

  // ============================================================
  // GET MNEMONIC
  // ============================================================

  Future<String?> getMnemonic() {
    return _storageService.getMnemonic();
  }

  // ============================================================
  // SIGN MESSAGE
  // ============================================================

  Future<String?> signMessage(
      String message,
      ) async {
    final String? privateKey =
    await getPrivateKey();

    if (privateKey == null ||
        privateKey.isEmpty) {
      return null;
    }

    final String signature =
    _cryptoService.signMessage(
      privateKey: privateKey,
      message: message,
    );

    if (!signature.startsWith('0x')) {
      throw Exception(
        'Invalid Ethereum signature: '
            'missing 0x prefix.',
      );
    }

    if (signature.length != 132) {
      throw Exception(
        'Invalid Ethereum signature length: '
            '${signature.length}. '
            'Expected 132 characters.',
      );
    }

    return signature;
  }

  // ============================================================
  // SIGN NATIVE TRANSACTION
  // ============================================================

  Future<String?> signNativeTransaction({
    required String to,
    required String valueRaw,
    required int nonce,
    required String gasLimit,
    required String gasPrice,
    required int chainId,
  }) async {
    final String? privateKey = await getPrivateKey();

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
      chainId: chainId,
    );
  }

  // ============================================================
  // VALIDATE ADDRESS
  // ============================================================

  bool isValidAddress(
      String address,
      ) {
    return _cryptoService.isValidAddress(
      address,
    );
  }

  // ============================================================
  // DELETE WALLET
  // ============================================================

  Future<void> clearWallet() {
    return _storageService.clearWallet();
  }
}