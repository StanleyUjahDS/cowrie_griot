import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class ConnectivityService extends ChangeNotifier {
  ConnectivityService._internal();
  static final ConnectivityService instance = ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  bool _isInitialized = false;
  ToastificationItem? _currentToast;

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      // Small delay to prevent flapping during network transitions
      Future.delayed(const Duration(milliseconds: 500), () => _updateConnectionStatus(results));
    });
    
    // Initial check
    _connectivity.checkConnectivity().then(_updateConnectionStatus);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // Filter out results that are effectively 'none' or empty
    final bool online = results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);
    
    if (_isOnline != online) {
      final bool wasInitiallyTrue = _isOnline;
      _isOnline = online;
      notifyListeners();
      
      // Don't show "Back online" banner on first check if we were already assumed online
      if (!online || wasInitiallyTrue) {
        _showConnectivityBanner(online);
      }
    }
  }

  void _showConnectivityBanner(bool online) {
    debugPrint('Connectivity: Showing banner (online: $online)');
    
    // Safety check to ensure we don't try to show UI before the app is ready
    if (WidgetsBinding.instance.lifecycleState == null) {
      debugPrint('Connectivity: Skipping banner, app lifecycle not ready');
      return;
    }

    if (_currentToast != null) {
      toastification.dismiss(_currentToast!);
      _currentToast = null;
    }
    
    try {
      _currentToast = toastification.showCustom(
        autoCloseDuration: online ? const Duration(seconds: 4) : null,
        alignment: Alignment.topCenter,
        builder: (context, holder) {
          return SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: online ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        online 
                          ? 'Back online. Connection restored.' 
                          : 'No internet connection. Please check your network.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (!online)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          toastification.dismiss(holder);
                          _currentToast = null;
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Connectivity: Failed to show toastification: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
