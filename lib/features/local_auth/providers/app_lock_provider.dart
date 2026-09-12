import 'dart:async';
import 'package:flutter/material.dart';
import '../services/app_lock_service.dart';

class AppLockProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AppLockService _appLockService;

  AppLockProvider({required AppLockService appLockService})
    : _appLockService = appLockService {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  bool _isLocked = false;
  bool _isEnabled = false;
  bool _biometricEnabled = false;
  Duration _autoLockDuration = const Duration(minutes: 5);
  DateTime? _backgroundTimestamp;
  bool _enteredBackground = false;

  bool get isLocked => _isLocked;
  bool get isEnabled => _isEnabled;
  bool get biometricEnabled => _biometricEnabled;
  Duration get autoLockDuration => _autoLockDuration;

  Future<void> _init() async {
    final hasPin = await _appLockService.hasPin();
    _isEnabled = hasPin && await _appLockService.isAppLockEnabled();
    _biometricEnabled = await _appLockService.isBiometricUnlockEnabled();
    _autoLockDuration = await _appLockService.getAutoLockDuration();

    // Cold start: If app lock is enabled, start in locked state
    if (_isEnabled) {
      _isLocked = true;
    } else {
      _isLocked = false;
    }

    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isEnabled) return;

    // `inactive` is also emitted for Face ID, permission dialogs, keyboards,
    // and other temporary system sheets. It must not count as leaving the
    // app. A real background transition is represented by paused/hidden.
    if (state == AppLifecycleState.inactive) {
      _backgroundTimestamp ??= DateTime.now();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _enteredBackground = true;
      _backgroundTimestamp ??= DateTime.now();

      // For a real background transition, lock immediately when configured.
      if (_autoLockDuration == Duration.zero) {
        lock();
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final backgroundTimestamp = _backgroundTimestamp;
      final enteredBackground = _enteredBackground;
      _backgroundTimestamp = null;
      _enteredBackground = false;

      if (enteredBackground &&
          backgroundTimestamp != null &&
          (_autoLockDuration == Duration.zero ||
              DateTime.now().difference(backgroundTimestamp) >=
                  _autoLockDuration)) {
        lock();
      }
    }
  }

  void lock() {
    if (!_isEnabled) return;
    if (_isLocked) return;

    _isLocked = true;
    notifyListeners();
  }

  void unlock() {
    _isLocked = false;
    _backgroundTimestamp = null;
    _enteredBackground = false;
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    await _appLockService.setAppLockEnabled(enabled);
    _isEnabled = enabled;
    if (!enabled) {
      _isLocked = false;
    }
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _appLockService.setBiometricUnlockEnabled(enabled);
    _biometricEnabled = enabled;
    notifyListeners();
  }

  Future<void> setAutoLockDuration(Duration duration) async {
    await _appLockService.setAutoLockDuration(duration);
    _autoLockDuration = duration;
    notifyListeners();
  }

  void reset() {
    _isLocked = false;
    _isEnabled = false;
    _biometricEnabled = false;
    _autoLockDuration = const Duration(minutes: 5);
    _backgroundTimestamp = null;
    _enteredBackground = false;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
