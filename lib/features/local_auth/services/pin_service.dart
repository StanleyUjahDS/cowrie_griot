// lib/features/local_auth/services/pin_service.dart

import 'pin_storage_service.dart';

class PinService {
  final PinStorageService _storage;

  PinService({
    PinStorageService? storage,
  }) : _storage = storage ?? PinStorageService();

  Future<void> savePin(String pin) {
    return _storage.savePin(pin);
  }

  Future<bool> verifyPin(String pin) {
    return _storage.verifyPin(pin);
  }

  Future<bool> hasPin() {
    return _storage.hasPin();
  }

  Future<void> deletePin() {
    return _storage.deletePin();
  }

  Future<void> saveSecret(String key, String value, {String? pin}) {
    return _storage.saveSecret(key, value, pin: pin);
  }

  Future<String?> getSecret(String key, {String? pin}) {
    return _storage.getSecret(key, pin: pin);
  }
}
