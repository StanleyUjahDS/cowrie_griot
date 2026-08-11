// lib/features/local_auth/services/local_auth_service.dart

import 'pin_service.dart';
import 'biometric_service.dart';

class LocalAuthService {
  final PinService _pinService;
  final BiometricService _biometricService;

  LocalAuthService({
    PinService? pinService,
    BiometricService? biometricService,
  })  : _pinService =
      pinService ?? PinService(),
        _biometricService =
            biometricService ?? BiometricService();

  // ============================================================
  // PIN
  // ============================================================

  Future<void> savePin(String pin) async {
    await _pinService.savePin(pin);
  }

  Future<bool> authenticateWithPin(String pin) async {
    return _pinService.verifyPin(pin);
  }

  Future<bool> hasPin() async {
    return _pinService.hasPin();
  }

  Future<void> deletePin() async {
    await _pinService.deletePin();
  }

  // ============================================================
  // BIOMETRICS
  // ============================================================

  Future<bool> biometricsEnabled() async {
    return _biometricService.isEnabled();
  }

  Future<bool> biometricsAvailable() async {
    return _biometricService.isAvailable();
  }

  Future<bool> authenticateWithBiometrics() async {
    return _biometricService.authenticate();
  }

  Future<bool>
  authenticateWithBiometricsIfEnabled() async {
    final enabled =
    await biometricsEnabled();

    if (!enabled) {
      return false;
    }

    final available =
    await biometricsAvailable();

    if (!available) {
      return false;
    }

    return authenticateWithBiometrics();
  }

  // ============================================================
  // LOCAL AUTH CONFIGURATION
  // ============================================================

  Future<bool> isConfigured() async {
    return hasPin();
  }
}