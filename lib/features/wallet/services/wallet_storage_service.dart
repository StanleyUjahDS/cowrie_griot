import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/security/encryption_service.dart';
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

  static const String _encryptionSaltKey =
      'wallet_encryption_salt';

  final EncryptionService _encryptionService = EncryptionService();

  // ============================================================
  // SALT MANAGEMENT
  // ============================================================

  Future<Uint8List> getOrGenerateSalt() async {
    final saltHex = await _storage.read(key: _encryptionSaltKey);
    if (saltHex != null) {
      try {
        return Uint8List.fromList(hex.decode(saltHex));
      } catch (_) {}
    }

    final salt = Uint8List(16);
    final random = Random.secure();
    for (var i = 0; i < salt.length; i++) {
      salt[i] = random.nextInt(256);
    }

    await _storage.write(
      key: _encryptionSaltKey,
      value: hex.encode(salt),
    );

    return salt;
  }

  // ============================================================
  // SAVE WALLET
  // ============================================================

  Future<void> saveWallet(
      WalletData wallet, {
      SecretKey? secretKey,
      }) async {
    String mnemonic = wallet.mnemonic;
    String privateKey = wallet.privateKey;

    if (secretKey != null) {
      mnemonic = await _encryptionService.encrypt(mnemonic, secretKey);
      privateKey = await _encryptionService.encrypt(privateKey, secretKey);
    }

    await _storage.write(
      key: _mnemonicKey,
      value: mnemonic,
    );

    await _storage.write(
      key: _privateKeyKey,
      value: privateKey,
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

  Future<WalletData?> loadWallet({SecretKey? secretKey}) async {
    String? mnemonic = await _storage.read(
      key: _mnemonicKey,
    );

    String? privateKey = await _storage.read(
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

    if (secretKey != null) {
      try {
        mnemonic = await _encryptionService.decrypt(mnemonic, secretKey);
        privateKey = await _encryptionService.decrypt(privateKey, secretKey);
      } catch (e) {
        // If decryption fails, it might be that the data is not encrypted yet
        // or the PIN is wrong. We re-throw to let the caller handle it.
        throw Exception('Failed to decrypt wallet data. Please check your PIN.');
      }
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

  // ============================================================
  // WALLET FILTERS STORAGE
  // ============================================================

  static const String _filtersKey = 'wallet_filters_settings';

  Future<Map<String, dynamic>> getWalletFilters() async {
    final data = await _storage.read(key: _filtersKey);
    if (data == null || data.isEmpty) return {};
    try {
      final map = jsonDecode(data);
      if (map is Map) {
        return Map<String, dynamic>.from(map);
      }
    } catch (_) {}
    return {};
  }

  Future<void> saveWalletFilters(Map<String, dynamic> filters) async {
    await _storage.write(
      key: _filtersKey,
      value: jsonEncode(filters),
    );
  }
}
