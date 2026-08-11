// lib/features/local_auth/services/biometric_service.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static const String _enabledKey =
      'biometrics_enabled';

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  BiometricService({
    LocalAuthentication? auth,
    FlutterSecureStorage? storage,
  })  : _auth =
      auth ?? LocalAuthentication(),
        _storage =
            storage ?? const FlutterSecureStorage();

  // ============================================================
  // AVAILABILITY
  // ============================================================

  Future<bool> isAvailable() async {
    try {
      final canCheck =
      await _auth.canCheckBiometrics;

      final supported =
      await _auth.isDeviceSupported();

      final biometrics =
      await _auth.getAvailableBiometrics();

      return canCheck &&
          supported &&
          biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // ENABLED
  // ============================================================

  Future<bool> isEnabled() async {
    final value =
    await _storage.read(
      key: _enabledKey,
    );

    return value == 'true';
  }

  // ============================================================
  // ENABLE
  // ============================================================

  Future<void> enable() async {
    await _storage.write(
      key: _enabledKey,
      value: 'true',
    );
  }

  // ============================================================
  // DISABLE
  // ============================================================

  Future<void> disable() async {
    await _storage.write(
      key: _enabledKey,
      value: 'false',
    );
  }

  // ============================================================
  // AUTHENTICATE
  // ============================================================

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason:
        'Authenticate to unlock your wallet',
        options:
        const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}