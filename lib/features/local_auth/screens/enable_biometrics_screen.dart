// biometrics_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/services/notification_service.dart';

class BiometricsScreen extends StatefulWidget {
  const BiometricsScreen({
    super.key,
  });

  @override
  State<BiometricsScreen> createState() =>
      _BiometricsScreenState();
}

class _BiometricsScreenState
    extends State<BiometricsScreen> {
  // ============================================================
  // SERVICES
  // ============================================================

  final LocalAuthentication _auth =
  LocalAuthentication();

  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  // ============================================================
  // STATE
  // ============================================================

  bool _biometricsAvailable = false;

  bool _loading = true;

  bool _authenticating = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _checkBiometricsAvailability();
  }

  // ============================================================
  // CHECK BIOMETRICS AVAILABILITY
  // ============================================================

  Future<void> _checkBiometricsAvailability() async {
    try {
      final canCheck =
      await _auth.canCheckBiometrics;

      final isSupported =
      await _auth.isDeviceSupported();

      final availableBiometrics =
      await _auth.getAvailableBiometrics();

      final available =
          canCheck &&
              isSupported &&
              availableBiometrics.isNotEmpty;

      if (!mounted) {
        return;
      }

      setState(() {
        _biometricsAvailable = available;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _biometricsAvailable = false;
        _loading = false;
      });
    }
  }

  // ============================================================
  // ENABLE BIOMETRICS
  // ============================================================
  //
  // IMPORTANT:
  //
  // This screen does NOT:
  //
  // - authenticate the wallet with the backend
  // - request a nonce
  // - sign a backend authentication message
  // - load the current user
  // - load chats
  // - restore the backend session
  //
  // AppStartupService handles application startup after we
  // enter the main application.
  //
  // ============================================================

  Future<void> _enableBiometrics() async {
    if (_authenticating) {
      return;
    }

    setState(() {
      _authenticating = true;
    });

    try {
      // ========================================================
      // DEVICE BIOMETRIC VERIFICATION
      // ========================================================

      final authenticated =
      await _auth.authenticate(
        localizedReason:
        'Use biometrics to unlock your wallet',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      // ========================================================
      // BIOMETRIC AUTHENTICATION CANCELLED
      // ========================================================

      if (!authenticated) {
        if (!mounted) {
          return;
        }

        setState(() {
          _authenticating = false;
        });

        _showInfo(
          'Biometric authentication was cancelled.',
        );

        return;
      }

      // ========================================================
      // SAVE BIOMETRIC PREFERENCE
      // ========================================================

      await _storage.write(
        key: 'biometrics_enabled',
        value: 'true',
      );

      // ========================================================
      // CONTINUE TO APPLICATION
      // ========================================================
      //
      // AppStartupService will now handle:
      //
      // 1. Local user restoration
      // 2. Backend session restoration
      // 3. Wallet authentication if required
      // 4. Current user synchronization
      //
      // ========================================================

      if (!mounted) {
        return;
      }

      context.go('/chat');
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _authenticating = false;
      });

      _showError(
        _getAuthenticationErrorMessage(e),
      );
    }
  }

  // ============================================================
  // CONTINUE WITHOUT BIOMETRICS
  // ============================================================
  //
  // No backend authentication happens here either.
  //
  // We simply record that the user chose not to enable
  // biometrics and enter the application.
  //
  // AppStartupService handles the actual application startup.
  //
  // ============================================================

  Future<void> _continueWithoutBiometrics() async {
    if (_authenticating) {
      return;
    }

    setState(() {
      _authenticating = true;
    });

    try {
      // ========================================================
      // SAVE BIOMETRIC PREFERENCE
      // ========================================================

      await _storage.write(
        key: 'biometrics_enabled',
        value: 'false',
      );

      // ========================================================
      // CONTINUE TO APPLICATION
      // ========================================================

      if (!mounted) {
        return;
      }

      context.go('/chat');
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _authenticating = false;
      });

      _showError(
        _getAuthenticationErrorMessage(e),
      );
    }
  }

  // ============================================================
  // AUTHENTICATION ERROR
  // ============================================================

  String _getAuthenticationErrorMessage(
      Object error,
      ) {
    final message = error
        .toString()
        .replaceFirst(
      'Exception: ',
      '',
    )
        .trim();

    if (message.isEmpty) {
      return 'Authentication failed.';
    }

    return message;
  }

  // ============================================================
  // INFO MESSAGE
  // ============================================================

  void _showInfo(
      String message,
      ) {
    NotificationService.showInfo(context, message);
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  void _showError(
      String message,
      ) {
    NotificationService.showError(context, message);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    final textTheme =
        theme.textTheme;

    final isDark =
        theme.brightness ==
            Brightness.dark;

    final screenWidth =
        MediaQuery.of(context)
            .size
            .width;

    return GradientScaffold(
      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          'Enable Biometrics',
        ),
        centerTitle: true,
        backgroundColor:
        Colors.transparent,
        foregroundColor:
        colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor:
        Colors.transparent,
      ),

      // ========================================================
      // BODY
      // ========================================================

      child: Column(
        children: [
          // ======================================================
          // CONTENT
          // ======================================================

          Expanded(
            child:
            SingleChildScrollView(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints:
                const BoxConstraints(
                  minHeight: 520,
                ),
                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    // ==================================================
                    // INITIAL LOADING
                    // ==================================================

                    if (_loading)
                      const Padding(
                        padding:
                        EdgeInsets.only(
                          top: 100,
                        ),
                        child:
                        GriotLoader(),
                      )

                    // ==================================================
                    // CONTENT
                    // ==================================================

                    else ...[
                      // ================================================
                      // FINGERPRINT ICON
                      // ================================================

                      Container(
                        width:
                        screenWidth *
                            0.45,
                        height:
                        screenWidth *
                            0.45,
                        decoration:
                        BoxDecoration(
                          shape:
                          BoxShape.circle,
                          color: colorScheme
                              .primary
                              .withValues(alpha: isDark ? 0.14 : 0.08),
                          border:
                          Border.all(
                            color: colorScheme
                                .primary
                                .withValues(alpha: isDark ? 0.35 : 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons
                              .fingerprint_rounded,
                          size: 80,
                          color:
                          colorScheme
                              .primary,
                        ),
                      ),

                      const SizedBox(
                        height: 28,
                      ),

                      // ================================================
                      // TITLE
                      // ================================================

                      Text(
                        'Enable Biometrics',
                        textAlign:
                        TextAlign.center,
                        style: textTheme
                            .headlineSmall
                            ?.copyWith(
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      // ================================================
                      // DESCRIPTION
                      // ================================================

                      ConstrainedBox(
                        constraints:
                        const BoxConstraints(
                          maxWidth: 420,
                        ),
                        child: Text(
                          'Use Face ID or Fingerprint '
                              'to unlock your wallet quickly '
                              'and securely.',
                          textAlign:
                          TextAlign.center,
                          style: textTheme
                              .bodyMedium
                              ?.copyWith(
                            color: colorScheme
                                .onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 28,
                      ),

                      // ================================================
                      // AVAILABILITY
                      // ================================================

                      if (!_biometricsAvailable)
                        Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration:
                          BoxDecoration(
                            color: colorScheme
                                .error
                                .withValues(alpha: 0.08),
                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                            border:
                            Border.all(
                              color: colorScheme
                                  .error
                                  .withValues(alpha: 0.20),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons
                                    .fingerprint_outlined,
                                color:
                                colorScheme
                                    .error,
                                size: 20,
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Expanded(
                                child: Text(
                                  'Biometric authentication '
                                      'is not available on this device. '
                                      'You can continue without it.',
                                  style: textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color:
                                    colorScheme
                                        .error,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          'You can enable biometrics now, '
                              'or continue without it.',
                          textAlign:
                          TextAlign.center,
                          style: textTheme
                              .bodySmall
                              ?.copyWith(
                            color: colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ========================================================
          // BOTTOM ACTIONS
          // ========================================================

          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              20,
            ),
            child: Column(
              children: [
                // ==================================================
                // ENABLE BUTTON
                // ==================================================

                SizedBox(
                  width:
                  double.infinity,
                  height: 52,
                  child:
                  ElevatedButton(
                    onPressed:
                    _loading ||
                        _authenticating ||
                        !_biometricsAvailable
                        ? null
                        : _enableBiometrics,
                    style:
                    ElevatedButton
                        .styleFrom(
                      backgroundColor:
                      colorScheme
                          .primary,
                      foregroundColor:
                      colorScheme
                          .onPrimary,
                      disabledBackgroundColor:
                      colorScheme
                          .primary
                          .withValues(alpha: 0.65),
                      disabledForegroundColor:
                      colorScheme
                          .onPrimary,
                      elevation: 0,
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius
                            .circular(
                          16,
                        ),
                      ),
                    ),
                    child: Text(
                      _authenticating
                          ? 'Continuing...'
                          : 'Enable',
                      style: textTheme
                          .labelLarge
                          ?.copyWith(
                        color:
                        colorScheme
                            .onPrimary,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                // ==================================================
                // CONTINUE WITHOUT BIOMETRICS
                // ==================================================

                SizedBox(
                  width:
                  double.infinity,
                  height: 52,
                  child:
                  OutlinedButton(
                    onPressed:
                    _loading ||
                        _authenticating
                        ? null
                        : _continueWithoutBiometrics,
                    style:
                    OutlinedButton
                        .styleFrom(
                      foregroundColor:
                      colorScheme
                          .onSurface,
                      disabledForegroundColor:
                      colorScheme
                          .onSurfaceVariant,
                      side:
                      BorderSide(
                        color: colorScheme
                            .outline
                            .withValues(alpha: 0.35),
                      ),
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius
                            .circular(
                          16,
                        ),
                      ),
                    ),
                    child:
                    const Text(
                      'Continue without biometrics',
                      textAlign:
                      TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}