import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

class ConnectivityService extends ChangeNotifier {
  ConnectivityService._internal();
  static final ConnectivityService instance = ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  OverlaySupportEntry? _overlayEntry;

  void initialize() {
    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    
    // Initial check
    _connectivity.checkConnectivity().then(_updateConnectionStatus);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // If any result is not 'none', we consider it online for interface detection.
    // In a real app, you might want to ping a server to be 100% sure.
    final bool online = !results.contains(ConnectivityResult.none);
    
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
      _showConnectivityBanner(online);
    }
  }

  void _showConnectivityBanner(bool online) {
    _overlayEntry?.dismiss();
    
    _overlayEntry = showOverlayNotification(
      (context) {
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
                ],
              ),
            ),
          ),
        );
      },
      duration: Duration(seconds: online ? 3 : 0), // Persistent if offline
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
