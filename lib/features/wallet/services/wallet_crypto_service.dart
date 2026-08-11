import 'dart:convert';
import 'dart:typed_data';

import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart' as web3;

class WalletCryptoService {
  // ============================================================
  // EVM DERIVATION PATH
  // ============================================================

  static const String derivationPath = "m/44'/60'/0'/0/0";

  // ============================================================
  // CREATE WALLET
  // ============================================================

  WalletData createWallet() {
    final mnemonicWords = wallet.generateMnemonic(
      strength: 128,
    );

    final mnemonic = mnemonicWords.join(' ');

    return _fromMnemonic(mnemonic);
  }

  // ============================================================
  // RESTORE WALLET
  // ============================================================

  WalletData restoreWallet(String mnemonic) {
    final normalizedMnemonic = mnemonic
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    if (normalizedMnemonic.isEmpty) {
      throw Exception('Mnemonic phrase cannot be empty.');
    }

    final words = normalizedMnemonic.split(' ');

    if (!wallet.validateMnemonic(words)) {
      throw Exception('Invalid mnemonic phrase.');
    }

    return _fromMnemonic(normalizedMnemonic);
  }

  // ============================================================
  // DERIVE WALLET
  // ============================================================

  WalletData _fromMnemonic(String mnemonic) {
    final words = mnemonic.split(' ');

    // ----------------------------------------------------------
    // BIP-39
    // ----------------------------------------------------------

    final seed = wallet.mnemonicToSeed(words);

    // ----------------------------------------------------------
    // BIP-32
    // ----------------------------------------------------------

    final master = wallet.ExtendedPrivateKey.master(
      seed,
      wallet.xprv,
    );

    // ----------------------------------------------------------
    // BIP-44 ETHEREUM
    // m/44'/60'/0'/0/0
    // ----------------------------------------------------------

    final derived = master.forPath(
      derivationPath,
    );

    if (derived is! wallet.ExtendedPrivateKey) {
      throw Exception(
        'Failed to derive Ethereum private key.',
      );
    }

    // ----------------------------------------------------------
    // PRIVATE KEY
    // ----------------------------------------------------------

    final privateKey = wallet.PrivateKey(
      derived.key,
    );

    // ----------------------------------------------------------
    // PUBLIC KEY
    // ----------------------------------------------------------

    final publicKey = wallet.ethereum.createPublicKey(
      privateKey,
    );

    // ----------------------------------------------------------
    // ADDRESS
    // ----------------------------------------------------------

    final address = wallet.ethereum.createAddress(
      publicKey,
    );

    // ----------------------------------------------------------
    // HEX
    // ----------------------------------------------------------

    final privateKeyHex = _bigIntToHex(
      privateKey.value,
    );

    final publicKeyHex = _bytesToHex(
      publicKey.value,
    );

    return WalletData(
      mnemonic: mnemonic,
      privateKey: privateKeyHex,
      publicKey: publicKeyHex,
      address: address,
    );
  }

  // ============================================================
  // SIGN MESSAGE
  // ============================================================
  //
  // Uses Ethereum personal-sign / EIP-191.
  //
  // Backend verification:
  //
  // ethers.verifyMessage(message, signature)
  //
  // ============================================================

  String signMessage({
    required String privateKey,
    required String message,
  }) {
    final normalizedPrivateKey = privateKey
        .trim()
        .replaceFirst(
      RegExp(r'^0x'),
      '',
    );

    if (!RegExp(
      r'^[a-fA-F0-9]{64}$',
    ).hasMatch(normalizedPrivateKey)) {
      throw Exception(
        'Invalid Ethereum private key.',
      );
    }

    final credentials = web3.EthPrivateKey.fromHex(
      normalizedPrivateKey,
    );

    final messageBytes = Uint8List.fromList(
      utf8.encode(message),
    );

    final signature =
    credentials.signPersonalMessageToUint8List(
      messageBytes,
    );

    if (signature.length != 65) {
      throw Exception(
        'Invalid Ethereum signature length: '
            '${signature.length}. Expected 65 bytes.',
      );
    }

    return '0x${_bytesToHex(signature)}';
  }

  // ============================================================
  // VALIDATE ADDRESS
  // ============================================================

  bool isValidAddress(String address) {
    return RegExp(
      r'^0x[a-fA-F0-9]{40}$',
    ).hasMatch(
      address.trim(),
    );
  }

  // ============================================================
  // BIGINT -> HEX
  // ============================================================

  String _bigIntToHex(BigInt value) {
    return value
        .toRadixString(16)
        .padLeft(64, '0');
  }

  // ============================================================
  // BYTES -> HEX
  // ============================================================

  String _bytesToHex(Uint8List bytes) {
    final buffer = StringBuffer();

    for (final byte in bytes) {
      buffer.write(
        byte
            .toRadixString(16)
            .padLeft(2, '0'),
      );
    }

    return buffer.toString();
  }
}

// ============================================================
// WALLET DATA
// ============================================================

class WalletData {
  final String mnemonic;
  final String privateKey;
  final String publicKey;
  final String address;

  WalletData({
    required this.mnemonic,
    required this.privateKey,
    required this.publicKey,
    required this.address,
  });
}