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
  bool _initialized = false;
  AppLifecycleState? _lastLifecycleState;

  bool get isLocked => _isLocked;
  bool get isEnabled => _isEnabled;
  bool get biometricEnabled => _biometricEnabled;
  Duration get autoLockDuration => _autoLockDuration;
  bool get isInitialized => _initialized;

  Future<void> _init() async {
    try {
      final hasPin = await _appLockService.hasPin();
      _isEnabled = hasPin && await _appLockService.isAppLockEnabled();
      _biometricEnabled = await _appLockService.isBiometricUnlockEnabled();
      _autoLockDuration = await _appLockService.getAutoLockDuration();

      // Cold start: If app lock is enabled, start in locked state.
      _isLocked = _isEnabled;
      _initialized = true;

      // A lifecycle event can arrive before secure-storage initialization
      // finishes. Reconcile it so an immediate lock cannot be skipped during
      // a fast app switch.
      final state = _lastLifecycleState;
      if (_isEnabled &&
          (state == AppLifecycleState.paused ||
              state == AppLifecycleState.hidden)) {
        _enteredBackground = true;
        _backgroundTimestamp ??= DateTime.now();
        if (_autoLockDuration == Duration.zero) {
          _isLocked = true;
        }
      }
    } catch (error) {
      _initialized = true;
      debugPrint('App lock initialization failed: $error');
    }

    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;

    // `inactive` is also emitted for Face ID, permission dialogs, keyboards,
    // and other temporary system sheets. It must not count as leaving the
    // app. Do not record a timestamp here: otherwise a biometric prompt can
    // be measured as background time and lock the app as soon as it closes.
    if (state == AppLifecycleState.inactive) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _enteredBackground = true;
      _backgroundTimestamp ??= DateTime.now();

      if (!_initialized || !_isEnabled) return;

      // Do not build the lock screen while the app is still paused. Native
      // biometric prompts need an active/resumed application, so the
      // immediate-lock case is evaluated in the resumed branch below.
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final backgroundTimestamp = _backgroundTimestamp;
      final enteredBackground = _enteredBackground;
      _backgroundTimestamp = null;
      _enteredBackground = false;

      if (!_initialized || !_isEnabled) return;

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
      _backgroundTimestamp = null;
      _enteredBackground = false;
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
