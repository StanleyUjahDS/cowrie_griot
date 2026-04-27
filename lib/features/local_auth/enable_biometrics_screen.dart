import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '/core/theme/app_buttons.dart';


import '/core/ui/scaffolds/gradient_scaffold.dart';

class BiometricsScreen extends StatefulWidget {
  const BiometricsScreen({super.key});

  @override
  State<BiometricsScreen> createState() => _BiometricsScreenState();
}

class _BiometricsScreenState extends State<BiometricsScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _biometricsAvailable = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkBiometricsAvailability();
  }

  Future<void> _checkBiometricsAvailability() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      final biometrics = await _auth.getAvailableBiometrics();

      debugPrint("Available biometrics: $biometrics");

      final available =
          canCheck && isSupported && biometrics.isNotEmpty;

      if (!mounted) return;

      setState(() {
        _biometricsAvailable = available;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Biometrics check error: $e");

      if (!mounted) return;

      setState(() {
        _biometricsAvailable = false;
        _loading = false;
      });
    }
  }

  Future<void> _enableBiometrics() async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Use biometrics to unlock your wallet',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!mounted) return;

      if (!authenticated) return;

      await _storage.write(
        key: 'biometrics_enabled',
        value: 'true',
      );

      showSimpleNotification(
        const Text("Biometrics enabled"),
        leading: const Icon(Icons.check_circle, color: Colors.green),
        background: Colors.black87,
      );

      if (!mounted) return;
      context.go('/main_navigation');
    } catch (e) {
      debugPrint("Biometric error: $e");
      _showMessage('Biometric authentication failed');
    }
  }

  Future<void> _skipBiometrics() async {
    await _storage.write(
      key: 'biometrics_enabled',
      value: 'false',
    );

    if (!mounted) return;

    showSimpleNotification(
      const Text("Biometrics skipped"),
      leading: const Icon(Icons.info_outline, color: Colors.white),
      background: Colors.black87,
    );

    context.go('/chat');
  }

  void _showMessage(String message) {
    showSimpleNotification(
      Text(message),
      leading: const Icon(Icons.error_outline, color: Colors.red),
      background: Colors.black87,
    );
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final screenWidth = MediaQuery.of(context).size.width;

    return GradientScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Enable Biometrics"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              /// CONTENT (SCROLLABLE)
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),

                        if (_loading)
                          const CircularProgressIndicator(color: Colors.white)
                        else ...[
                          Container(
                            width: screenWidth * 0.45,
                            height: screenWidth * 0.45,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.primaryColor.withValues(alpha: 0.5),
                              border: Border.all(
                                color: Colors.white24,
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.fingerprint,
                                size: 80,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          Text(
                            'Enable Biometrics',
                            textAlign: TextAlign.center,
                            style: textTheme.titleLarge
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            'Use Face ID or Fingerprint to unlock your wallet quickly and securely.',
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 40),

                          const Text(
                            'Tap enable to continue securely.',
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 30),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              /// BUTTONS (FIXED AT BOTTOM)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    /// ENABLE BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: AppButtons.primary(context),
                        onPressed: _biometricsAvailable
                            ? _enableBiometrics
                            : () {
                          _showMessage(
                              "Biometrics not available on this device");
                        },
                        child: Text(
                          "Enable",
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    /// SKIP BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: AppButtons.secondary(context),
                        onPressed: _skipBiometrics,
                        child: Text(
                          "Not now",
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }}