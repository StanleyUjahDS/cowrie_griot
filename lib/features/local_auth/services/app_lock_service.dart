// lib/features/local_auth/services/app_lock_service.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppLockService {
  static const String _appLockEnabledKey = 'app_lock_enabled';
  static const String _biometricUnlockEnabledKey =
      'biometric_unlock_enabled';
  static const String _autoLockDurationKey =
      'auto_lock_duration_seconds';

  final FlutterSecureStorage _storage;

  AppLockService({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  // ============================================================
  // APP LOCK
  // ============================================================

  Future<bool> isAppLockEnabled() async {
    final value = await _storage.read(
      key: _appLockEnabledKey,
    );

    return value == 'true';
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    await _storage.write(
      key: _appLockEnabledKey,
      value: enabled.toString(),
    );
  }

  // ============================================================
  // BIOMETRIC UNLOCK
  // ============================================================

  Future<bool> isBiometricUnlockEnabled() async {
    final value = await _storage.read(
      key: _biometricUnlockEnabledKey,
    );

    return value == 'true';
  }

  Future<void> setBiometricUnlockEnabled(
      bool enabled,
      ) async {
    await _storage.write(
      key: _biometricUnlockEnabledKey,
      value: enabled.toString(),
    );
  }

  // ============================================================
  // BIOMETRIC AVAILABILITY
  // ============================================================

  Future<bool> areBiometricsAvailable() async {
    // Keep this service independent from local_auth.
    //
    // The actual biometric availability check is handled
    // by BiometricService.
    //
    // This method exists so SettingsScreen can safely query
    // whether biometric unlock can be enabled.
    return true;
  }

  // ============================================================
  // PIN
  // ============================================================

  Future<bool> hasPin() async {
    const pinHashKey = 'wallet_pin_hash';

    final value = await _storage.read(
      key: pinHashKey,
    );

    return value != null && value.isNotEmpty;
  }

  // ============================================================
  // AUTO LOCK DURATION
  // ============================================================

  Future<Duration> getAutoLockDuration() async {
    final value = await _storage.read(
      key: _autoLockDurationKey,
    );

    if (value == null || value.isEmpty) {
      return const Duration(minutes: 5);
    }

    final seconds = int.tryParse(value);

    if (seconds == null || seconds <= 0) {
      return const Duration(minutes: 5);
    }

    return Duration(seconds: seconds);
  }

  Future<void> setAutoLockDuration(
      Duration duration,
      ) async {
    if (duration <= Duration.zero) {
      throw ArgumentError(
        'Auto-lock duration must be greater than zero.',
      );
    }

    await _storage.write(
      key: _autoLockDurationKey,
      value: duration.inSeconds.toString(),
    );
  }

  // ============================================================
  // RESET
  // ============================================================

  Future<void> reset() async {
    await _storage.delete(
      key: _appLockEnabledKey,
    );

    await _storage.delete(
      key: _biometricUnlockEnabledKey,
    );

    await _storage.delete(
      key: _autoLockDurationKey,
    );
  }
}