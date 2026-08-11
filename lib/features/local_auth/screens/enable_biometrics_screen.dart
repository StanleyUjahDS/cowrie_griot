import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:overlay_support/overlay_support.dart';

import '/core/network/api_client.dart';
import '/core/ui/scaffolds/gradient_scaffold.dart';

import '/features/auth/services/auth_api_service.dart';
import '/features/auth/services/wallet_auth_service.dart';

import '/features/wallet/services/wallet_crypto_service.dart';
import '/features/wallet/services/wallet_service.dart';
import '/features/wallet/services/wallet_storage_service.dart';

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

  final FlutterSecureStorage _storage =
  const FlutterSecureStorage();

  late final WalletService _walletService;

  late final AuthApiService _authApiService;

  late final WalletAuthService _walletAuthService;

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

    // ----------------------------------------------------------
    // WALLET SERVICE
    // ----------------------------------------------------------

    _walletService = WalletService(
      cryptoService: WalletCryptoService(),
      storageService: WalletStorageService(),
    );

    // ----------------------------------------------------------
    // API SERVICE
    // ----------------------------------------------------------

    _authApiService = AuthApiService(
      apiClient: ApiClient(),
    );

    // ----------------------------------------------------------
    // WALLET AUTH SERVICE
    // ----------------------------------------------------------

    _walletAuthService = WalletAuthService(
      walletService: _walletService,
      authApiService: _authApiService,
    );

    // ----------------------------------------------------------
    // CHECK BIOMETRICS
    // ----------------------------------------------------------

    _checkBiometricsAvailability();
  }

  // ============================================================
  // CHECK BIOMETRICS
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
  // BACKEND WALLET AUTHENTICATION
  // ============================================================
  //
  // This is used regardless of whether the user enables
  // biometrics.
  //
  // WalletAuthService handles:
  //
  // 1. Get wallet address
  // 2. Request backend nonce
  // 3. Sign nonce with wallet private key
  // 4. Verify signature with backend
  // 5. Store authentication state/token
  //
  // ============================================================

  Future<void> _authenticateWalletWithBackend() async {
    await _walletAuthService.authenticateWallet();
  }

  // ============================================================
  // ENABLE BIOMETRICS
  // ============================================================

  Future<void> _enableBiometrics() async {
    if (_authenticating) {
      return;
    }

    setState(() {
      _authenticating = true;
    });

    try {
      // --------------------------------------------------------
      // STEP 1
      // DEVICE BIOMETRIC AUTHENTICATION
      // --------------------------------------------------------

      final authenticated =
      await _auth.authenticate(
        localizedReason:
        'Use biometrics to unlock your wallet',
        options:
        const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      // --------------------------------------------------------
      // BIOMETRIC AUTHENTICATION CANCELLED
      // --------------------------------------------------------

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

      // --------------------------------------------------------
      // STEP 2
      // BACKEND WALLET AUTHENTICATION
      // --------------------------------------------------------
      //
      // The loading spinner remains visible here while:
      //
      // biometric -> nonce -> signature -> backend
      //
      // --------------------------------------------------------

      await _authenticateWalletWithBackend();

      // --------------------------------------------------------
      // STEP 3
      // SAVE BIOMETRIC PREFERENCE
      // --------------------------------------------------------

      await _storage.write(
        key: 'biometrics_enabled',
        value: 'true',
      );

      // --------------------------------------------------------
      // STEP 4
      // COMPLETE
      // --------------------------------------------------------

      if (!mounted) {
        return;
      }

      setState(() {
        _authenticating = false;
      });

      _showSuccess(
        'Biometrics enabled.',
      );

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
  // IMPORTANT:
  //
  // The user can skip biometrics, but they cannot skip
  // backend wallet authentication.
  //
  // Flow:
  //
  // Continue without biometrics
  //          ↓
  // Backend wallet authentication
  //          ↓
  // Save biometrics_enabled = false
  //          ↓
  // Home
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
      // --------------------------------------------------------
      // STEP 1
      // BACKEND WALLET AUTHENTICATION
      // --------------------------------------------------------

      await _authenticateWalletWithBackend();

      // --------------------------------------------------------
      // STEP 2
      // SAVE BIOMETRIC PREFERENCE
      // --------------------------------------------------------

      await _storage.write(
        key: 'biometrics_enabled',
        value: 'false',
      );

      // --------------------------------------------------------
      // STEP 3
      // COMPLETE
      // --------------------------------------------------------

      if (!mounted) {
        return;
      }

      setState(() {
        _authenticating = false;
      });

      _showInfo(
        'Continuing without biometrics.',
      );

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
  // SUCCESS MESSAGE
  // ============================================================

  void _showSuccess(
      String message,
      ) {
    showSimpleNotification(
      Text(message),
      leading: const Icon(
        Icons.check_circle_outline_rounded,
        color: Colors.white,
      ),
      position: NotificationPosition.top,
      background: Colors.black87,
      foreground: Colors.white,
      duration: const Duration(
        seconds: 2,
      ),
    );
  }

  // ============================================================
  // INFO MESSAGE
  // ============================================================

  void _showInfo(
      String message,
      ) {
    showSimpleNotification(
      Text(message),
      leading: const Icon(
        Icons.info_outline_rounded,
        color: Colors.white,
      ),
      position: NotificationPosition.top,
      background: Colors.black87,
      foreground: Colors.white,
      duration: const Duration(
        seconds: 2,
      ),
    );
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  void _showError(
      String message,
      ) {
    showSimpleNotification(
      Text(message),
      leading: const Icon(
        Icons.error_outline_rounded,
        color: Colors.white,
      ),
      position: NotificationPosition.top,
      background: Colors.black87,
      foreground: Colors.white,
      duration: const Duration(
        seconds: 3,
      ),
    );
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
            child: SingleChildScrollView(
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
                      Padding(
                        padding:
                        const EdgeInsets.only(
                          top: 100,
                        ),
                        child:
                        CircularProgressIndicator(
                          color:
                          colorScheme.primary,
                        ),
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
                        screenWidth * 0.45,
                        height:
                        screenWidth * 0.45,
                        decoration:
                        BoxDecoration(
                          shape:
                          BoxShape.circle,
                          color: colorScheme
                              .primary
                              .withValues(
                            alpha:
                            isDark
                                ? 0.14
                                : 0.08,
                          ),
                          border:
                          Border.all(
                            color: colorScheme
                                .primary
                                .withValues(
                              alpha:
                              isDark
                                  ? 0.35
                                  : 0.25,
                            ),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons
                              .fingerprint_rounded,
                          size: 80,
                          color:
                          colorScheme.primary,
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
                                .withValues(
                              alpha: 0.08,
                            ),
                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                            border:
                            Border.all(
                              color: colorScheme
                                  .error
                                  .withValues(
                                alpha: 0.20,
                              ),
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
                      colorScheme.primary,
                      foregroundColor:
                      colorScheme.onPrimary,
                      disabledBackgroundColor:
                      colorScheme.primary
                          .withValues(
                        alpha: 0.65,
                      ),
                      disabledForegroundColor:
                      colorScheme.onPrimary,
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
                    child:
                    _authenticating
                        ? Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child:
                          CircularProgressIndicator(
                            strokeWidth:
                            2.5,
                            color:
                            colorScheme
                                .onPrimary,
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Text(
                          'Authenticating...',
                          style: textTheme
                              .labelLarge
                              ?.copyWith(
                            color:
                            colorScheme
                                .onPrimary,
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),
                      ],
                    )
                        : Text(
                      'Enable',
                      style: textTheme
                          .labelLarge
                          ?.copyWith(
                        color:
                        colorScheme
                            .onPrimary,
                        fontWeight:
                        FontWeight
                            .w600,
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
                            .withValues(
                          alpha: 0.35,
                        ),
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
                    _authenticating
                        ? Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child:
                          CircularProgressIndicator(
                            strokeWidth:
                            2.5,
                            color:
                            colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Text(
                          'Authenticating...',
                          style: textTheme
                              .labelLarge
                              ?.copyWith(
                            color:
                            colorScheme
                                .onSurfaceVariant,
                            fontWeight:
                            FontWeight
                                .w500,
                          ),
                        ),
                      ],
                    )
                        : Text(
                      'Continue without biometrics',
                      textAlign:
                      TextAlign.center,
                      style: textTheme
                          .labelLarge
                          ?.copyWith(
                        fontWeight:
                        FontWeight
                            .w500,
                      ),
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