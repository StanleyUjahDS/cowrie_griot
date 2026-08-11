// lib/features/local_auth/services/pin_service.dart

import 'pin_storage_service.dart';

class PinService {
  final PinStorageService _storage;

  PinService({
    PinStorageService? storage,
  }) : _storage = storage ?? const PinStorageService();

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
}