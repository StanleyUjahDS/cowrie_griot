// lib/features/local_auth/services/pin_storage_service.dart

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/security/encryption_service.dart';

class PinStorageService {
  static const String _pinHashKey = 'wallet_pin_hash';
  static const String _encryptionSaltKey = 'wallet_secret_salt';

  final FlutterSecureStorage _storage;
  final EncryptionService _encryptionService = EncryptionService();

  PinStorageService({
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

  // ============================================================
  // SECRETS
  // ============================================================

  Future<void> saveSecret(String key, String value, {String? pin}) async {
    if (pin != null) {
      final salt = await _getOrGenerateSalt();
      final secretKey = await _encryptionService.deriveKey(pin, salt);
      final encryptedValue = await _encryptionService.encrypt(value, secretKey);
      await _storage.write(
        key: 'secret_$key',
        value: encryptedValue,
      );
    } else {
      await _storage.write(
        key: 'secret_$key',
        value: value,
      );
    }
  }

  Future<String?> getSecret(String key, {String? pin}) async {
    final value = await _storage.read(
      key: 'secret_$key',
    );

    if (value == null) return null;
    if (pin == null) return value;

    try {
      final salt = await _getOrGenerateSalt();
      final secretKey = await _encryptionService.deriveKey(pin, salt);
      return await _encryptionService.decrypt(value, secretKey);
    } catch (_) {
      // Never return ciphertext/plaintext after a failed PIN check.
      return null;
    }
  }

  Future<Uint8List> _getOrGenerateSalt() async {
    final saltBase64 = await _storage.read(key: _encryptionSaltKey);
    if (saltBase64 != null) {
      try {
        return base64.decode(saltBase64);
      } catch (_) {}
    }

    final salt = Uint8List(16);
    final random = math.Random.secure();
    for (var i = 0; i < salt.length; i++) {
      salt[i] = random.nextInt(256);
    }

    await _storage.write(
      key: _encryptionSaltKey,
      value: base64.encode(salt),
    );

    return salt;
  }
}
