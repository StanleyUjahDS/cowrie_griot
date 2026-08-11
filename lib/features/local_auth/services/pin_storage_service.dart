// lib/features/local_auth/services/pin_storage_service.dart

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinStorageService {
  static const String _pinHashKey = 'wallet_pin_hash';

  final FlutterSecureStorage _storage;

  const PinStorageService({
    FlutterSecureStorage? storage,
  }) : _storage =
      storage ?? const FlutterSecureStorage();

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  Future<void> savePin(String pin) async {
    if (pin.length != 6) {
      throw ArgumentError(
        'PIN must contain exactly 6 digits.',
      );
    }

    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError(
        'PIN must contain digits only.',
      );
    }

    await _storage.write(
      key: _pinHashKey,
      value: _hashPin(pin),
    );
  }

  Future<bool> verifyPin(String pin) async {
    if (pin.length != 6 ||
        !RegExp(r'^\d{6}$').hasMatch(pin)) {
      return false;
    }

    final storedHash = await _storage.read(
      key: _pinHashKey,
    );

    if (storedHash == null ||
        storedHash.isEmpty) {
      return false;
    }

    return _hashPin(pin) == storedHash;
  }

  Future<bool> hasPin() async {
    final storedHash = await _storage.read(
      key: _pinHashKey,
    );

    return storedHash != null &&
        storedHash.isNotEmpty;
  }

  Future<void> deletePin() async {
    await _storage.delete(
      key: _pinHashKey,
    );
  }
}