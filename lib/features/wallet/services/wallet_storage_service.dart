import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'wallet_crypto_service.dart';

class WalletStorageService {
  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  static const String _mnemonicKey =
      'wallet_mnemonic';

  static const String _privateKeyKey =
      'wallet_private_key';

  static const String _publicKeyKey =
      'wallet_public_key';

  static const String _addressKey =
      'wallet_address';

  // ============================================================
  // SAVE WALLET
  // ============================================================

  Future<void> saveWallet(
      WalletData wallet,
      ) async {
    // Write all wallet values.
    //
    // If a wallet already exists, these writes REPLACE
    // the previous values because the keys are identical.

    await _storage.write(
      key: _mnemonicKey,
      value: wallet.mnemonic,
    );

    await _storage.write(
      key: _privateKeyKey,
      value: wallet.privateKey,
    );

    await _storage.write(
      key: _publicKeyKey,
      value: wallet.publicKey,
    );

    await _storage.write(
      key: _addressKey,
      value: wallet.address,
    );
  }

  // ============================================================
  // LOAD WALLET
  // ============================================================

  Future<WalletData?> loadWallet() async {
    final mnemonic = await _storage.read(
      key: _mnemonicKey,
    );

    final privateKey = await _storage.read(
      key: _privateKeyKey,
    );

    final publicKey = await _storage.read(
      key: _publicKeyKey,
    );

    final address = await _storage.read(
      key: _addressKey,
    );

    if (mnemonic == null ||
        privateKey == null ||
        publicKey == null ||
        address == null) {
      return null;
    }

    return WalletData(
      mnemonic: mnemonic,
      privateKey: privateKey,
      publicKey: publicKey,
      address: address,
    );
  }

  // ============================================================
  // GET ADDRESS
  // ============================================================

  Future<String?> getAddress() {
    return _storage.read(
      key: _addressKey,
    );
  }

  // ============================================================
  // GET PUBLIC KEY
  // ============================================================

  Future<String?> getPublicKey() {
    return _storage.read(
      key: _publicKeyKey,
    );
  }

  // ============================================================
  // GET PRIVATE KEY
  // ============================================================

  Future<String?> getPrivateKey() {
    return _storage.read(
      key: _privateKeyKey,
    );
  }

  // ============================================================
  // GET MNEMONIC
  // ============================================================

  Future<String?> getMnemonic() {
    return _storage.read(
      key: _mnemonicKey,
    );
  }

  // ============================================================
  // CLEAR WALLET
  // ============================================================

  Future<void> clearWallet() async {
    await _storage.delete(
      key: _mnemonicKey,
    );

    await _storage.delete(
      key: _privateKeyKey,
    );

    await _storage.delete(
      key: _publicKeyKey,
    );

    await _storage.delete(
      key: _addressKey,
    );
  }

  // ============================================================
  // REPLACE WALLET
  // ============================================================
  //
  // This makes the intent explicit:
  //
  // OLD WALLET
  //     ↓
  // delete
  //     ↓
  // NEW WALLET
  //     ↓
  // save
  //
  // This is useful specifically for recovery.
  // ============================================================

  Future<void> replaceWallet(
      WalletData wallet,
      ) async {
    await clearWallet();
    await saveWallet(wallet);
  }

  // ============================================================
  // HIDDEN TOKENS STORAGE
  // ============================================================

  static const String _hiddenTokensKey = 'hidden_tokens_list';

  Future<List<String>> getHiddenTokens() async {
    final data = await _storage.read(key: _hiddenTokensKey);
    if (data == null || data.isEmpty) return [];
    try {
      final list = jsonDecode(data);
      if (list is List) {
        return list.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> saveHiddenTokens(List<String> keys) async {
    await _storage.write(
      key: _hiddenTokensKey,
      value: jsonEncode(keys),
    );
  }
}