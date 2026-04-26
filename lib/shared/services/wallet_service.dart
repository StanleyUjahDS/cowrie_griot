import 'dart:typed_data';

import 'package:web3dart/web3dart.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:convert/convert.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WalletService {
  static final FlutterSecureStorage _storage = FlutterSecureStorage();

  /// =========================
  /// CREATE NEW WALLET
  /// =========================
  static Future<WalletData> createWallet() async {
    final mnemonic = bip39.generateMnemonic();
    return await _fromMnemonic(mnemonic);
  }

  /// =========================
  /// RESTORE WALLET
  /// =========================
  static Future<WalletData> restoreWallet(String mnemonic) async {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw Exception("Invalid mnemonic phrase");
    }

    return await _fromMnemonic(mnemonic);
  }

  /// =========================
  /// CORE DERIVATION LOGIC
  /// =========================
  static Future<WalletData> _fromMnemonic(String mnemonic) async {
    final seed = bip39.mnemonicToSeed(mnemonic);

    final root = bip32.BIP32.fromSeed(seed);

    final child = root.derivePath("m/44'/60'/0'/0/0");

    if (child.privateKey == null) {
      throw Exception("Failed to derive private key");
    }

    final privateKeyHex = '0x${hex.encode(child.privateKey!)}';

    final ethPrivateKey = EthPrivateKey.fromHex(privateKeyHex);

    final address = ethPrivateKey.address.hexEip55;

    // STORE SECURELY
    await _storage.write(key: 'mnemonic', value: mnemonic);
    await _storage.write(key: 'privateKey', value: privateKeyHex);
    await _storage.write(key: 'address', value: address);

    return WalletData(
      mnemonic: mnemonic,
      privateKey: privateKeyHex,
      address: address,
    );
  }

  /// =========================
  /// LOAD WALLET FROM DEVICE
  /// =========================
  static Future<WalletData?> loadWallet() async {
    final mnemonic = await _storage.read(key: 'mnemonic');
    final privateKey = await _storage.read(key: 'privateKey');
    final address = await _storage.read(key: 'address');

    if (mnemonic == null || privateKey == null || address == null) {
      return null;
    }

    return WalletData(
      mnemonic: mnemonic,
      privateKey: privateKey,
      address: address,
    );
  }

  /// =========================
  /// GET ADDRESS ONLY
  /// =========================
  static Future<String?> getAddress() async {
    return _storage.read(key: 'address');
  }

  /// =========================
  /// SIGN MESSAGE (LOGIN / AUTH)
  /// =========================
  static Future<String?> signMessage(String message) async {
    final wallet = await loadWallet();
    if (wallet == null) return null;

    final credentials = EthPrivateKey.fromHex(wallet.privateKey);

    final Uint8List signature =
    credentials.signPersonalMessageToUint8List(
      Uint8List.fromList(message.codeUnits),
    );

    return hex.encode(signature);
  }

  /// =========================
  /// DELETE WALLET
  /// =========================
  static Future<void> clearWallet() async {
    await _storage.delete(key: 'mnemonic');
    await _storage.delete(key: 'privateKey');
    await _storage.delete(key: 'address');
  }
}

/// =========================
/// WALLET MODEL
/// =========================
class WalletData {
  final String mnemonic;
  final String privateKey;
  final String address;

  WalletData({
    required this.mnemonic,
    required this.privateKey,
    required this.address,
  });
}