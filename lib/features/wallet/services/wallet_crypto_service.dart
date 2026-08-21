import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart' as web3;

class WalletCryptoService {
  static const String derivationPath = "m/44'/60'/0'/0/0";

  Future<WalletData> createWallet() async {
    return compute(_createWalletIsolate, null);
  }

  Future<WalletData> restoreWallet(String mnemonic) async {
    final normalizedMnemonic = mnemonic
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();

    if (normalizedMnemonic.isEmpty) {
      throw Exception('Mnemonic phrase cannot be empty.');
    }

    return compute(_restoreWalletIsolate, normalizedMnemonic);
  }

  static WalletData _createWalletIsolate(dynamic _) {
    final mnemonicWords = wallet.generateMnemonic(strength: 128);
    final mnemonic = mnemonicWords.join(' ');
    return _fromMnemonic(mnemonic);
  }

  static WalletData _restoreWalletIsolate(String mnemonic) {
    final words = mnemonic.split(' ');

    if (!wallet.validateMnemonic(words)) {
      throw Exception('Invalid mnemonic phrase.');
    }

    return _fromMnemonic(mnemonic);
  }

  static WalletData _fromMnemonic(String mnemonic) {
    final words = mnemonic.split(' ');
    final seed = wallet.mnemonicToSeed(words);

    final master = wallet.ExtendedPrivateKey.master(
      seed,
      wallet.xprv,
    );

    final derived = master.forPath(derivationPath);

    if (derived is! wallet.ExtendedPrivateKey) {
      throw Exception('Failed to derive Ethereum private key.');
    }

    final privateKey = wallet.PrivateKey(derived.key);
    final publicKey = wallet.ethereum.createPublicKey(privateKey);
    final address = wallet.ethereum.createAddress(publicKey);

    return WalletData(
      mnemonic: mnemonic,
      privateKey: _bigIntToHex(privateKey.value),
      publicKey: _bytesToHex(publicKey.value),
      address: address,
    );
  }

  String signMessage({
    required String privateKey,
    required String message,
  }) {
    final normalizedPrivateKey = privateKey
        .trim()
        .replaceFirst(RegExp(r'^0x'), '');

    _validatePrivateKey(normalizedPrivateKey);

    final credentials = web3.EthPrivateKey.fromHex(
      normalizedPrivateKey,
    );

    final messageBytes = Uint8List.fromList(
      utf8.encode(message),
    );

    final signature = credentials.signPersonalMessageToUint8List(
      messageBytes,
    );

    if (signature.length != 65) {
      throw Exception(
        'Invalid Ethereum signature length: ${signature.length}. Expected 65 bytes.',
      );
    }

    return '0x${_bytesToHex(signature)}';
  }

  // ============================================================
  // SIGN EVM TRANSACTION
  // ============================================================

  Future<String> signNativeTransaction({
    required String privateKey,
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
    final normalizedPrivateKey = privateKey
        .trim()
        .replaceFirst(RegExp(r'^0x'), '');

    _validatePrivateKey(normalizedPrivateKey);

    if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(to.trim())) {
      throw Exception('Invalid transaction recipient address.');
    }

    final credentials = web3.EthPrivateKey.fromHex(
      normalizedPrivateKey,
    );

    final transactionData = _hexToBytes(dataHex);

    final transaction = web3.Transaction(
      to: web3.EthereumAddress.fromHex(to),
      value: web3.EtherAmount.inWei(
        BigInt.parse(valueRaw),
      ),
      nonce: nonce,
      gasPrice: gasPrice != null
          ? web3.EtherAmount.inWei(BigInt.parse(gasPrice))
          : null,
      maxFeePerGas: maxFeePerGas != null
          ? web3.EtherAmount.inWei(BigInt.parse(maxFeePerGas))
          : null,
      maxPriorityFeePerGas: maxPriorityFeePerGas != null
          ? web3.EtherAmount.inWei(BigInt.parse(maxPriorityFeePerGas))
          : null,
      maxGas: int.parse(gasLimit),
      data: transactionData,
    );

    final signed = web3.signTransactionRaw(
      transaction,
      credentials,
      chainId: chainId,
    );

    return '0x${_bytesToHex(signed)}';
  }

  bool isValidAddress(String address) {
    return RegExp(
      r'^0x[a-fA-F0-9]{40}$',
    ).hasMatch(address.trim());
  }

  static Uint8List _hexToBytes(String? value) {
    if (value == null || value.trim().isEmpty || value.trim() == '0x') {
      return Uint8List(0);
    }

    var hex = value.trim();
    if (hex.startsWith('0x')) {
      hex = hex.substring(2);
    }

    if (hex.isEmpty) return Uint8List(0);
    if (!RegExp(r'^[a-fA-F0-9]+$').hasMatch(hex)) {
      throw Exception('Invalid transaction data.');
    }
    if (hex.length.isOdd) {
      throw Exception('Invalid transaction data length.');
    }

    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(
        hex.substring(i * 2, i * 2 + 2),
        radix: 16,
      );
    }

    return bytes;
  }

  static void _validatePrivateKey(String privateKey) {
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(privateKey)) {
      throw Exception('Invalid Ethereum private key.');
    }
  }

  static String _bigIntToHex(BigInt value) {
    return value.toRadixString(16).padLeft(64, '0');
  }

  static String _bytesToHex(Uint8List bytes) {
    final buffer = StringBuffer();

    for (final byte in bytes) {
      buffer.write(
        byte.toRadixString(16).padLeft(2, '0'),
      );
    }

    return buffer.toString();
  }
}

class WalletData {
  final String mnemonic;
  final String privateKey;
  final String publicKey;
  final String address;

  const WalletData({
    required this.mnemonic,
    required this.privateKey,
    required this.publicKey,
    required this.address,
  });
}
