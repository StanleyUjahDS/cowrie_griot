// lib/features/local_auth/services/biometric_service.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static const String _enabledKey = 'biometrics_enabled';
  static const String _appLockEnabledKey = 'biometric_unlock_enabled';

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  BiometricService({LocalAuthentication? auth, FlutterSecureStorage? storage})
    : _auth = auth ?? LocalAuthentication(),
      _storage = storage ?? const FlutterSecureStorage();

  // ============================================================
  // AVAILABILITY
  // ============================================================

  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;

      final supported = await _auth.isDeviceSupported();

      final biometrics = await _auth.getAvailableBiometrics();

      return canCheck && supported && biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // ENABLED
  // ============================================================

  Future<bool> isEnabled() async {
    // The app-lock preference is authoritative when present.
    final appLockValue = await _storage.read(key: _appLockEnabledKey);

    if (appLockValue != null) {
      return appLockValue == 'true';
    }

    // Existing installs may only have the original preference.
    final legacyValue = await _storage.read(key: _enabledKey);

    return legacyValue == 'true';
  }

  // ============================================================
  // ENABLE
  // ============================================================

  Future<void> enable() async {
    await _storage.write(key: _enabledKey, value: 'true');
    await _storage.write(key: _appLockEnabledKey, value: 'true');
  }

  // ============================================================
  // DISABLE
  // ============================================================

  Future<void> disable() async {
    await _storage.write(key: _enabledKey, value: 'false');
    await _storage.write(key: _appLockEnabledKey, value: 'false');
  }

  // ============================================================
  // AUTHENTICATE
  // ============================================================

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to unlock your wallet',
        // Keep the operating-system passcode out of this prompt. If a
        // biometric is unavailable or cancelled, the lock screen remains
        // visible and the app PIN is the fallback.
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
