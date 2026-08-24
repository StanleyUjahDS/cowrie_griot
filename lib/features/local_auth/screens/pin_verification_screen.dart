// lib/features/local_auth/screens/pin_verification_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/services/notification_service.dart';
import '../services/local_auth_service.dart';

class PinVerificationScreen extends StatefulWidget {
  final Future<void> Function()? onSuccess;
  final bool showAppBar;
  final String? title;
  final String? description;

  const PinVerificationScreen({
    super.key,
    this.onSuccess,
    this.showAppBar = true,
    this.title,
    this.description,
  });

  @override
  State<PinVerificationScreen> createState() =>
      _PinVerificationScreenState();
}

class _PinVerificationScreenState
    extends State<PinVerificationScreen> {
  late final LocalAuthService _authService;

  String _pin = '';
  bool _loading = false;
  int? _pressedIndex;
  int _failedAttempts = 0;
  DateTime? _cooldownUntil;
  Timer? _cooldownTimer;

  final List<String> _keys = const [
    '1', '2', '3',
    '4', '5', '6',
    '7', '8', '9',
    '', '0', '⌫',
  ];

  @override
  void initState() {
    super.initState();
    _authService = LocalAuthService();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  bool get _isCooldownActive {
    if (_cooldownUntil == null) return false;
    return DateTime.now().isBefore(_cooldownUntil!);
  }

  String get _cooldownMessage {
    if (_cooldownUntil == null) return '';
    final remaining = _cooldownUntil!.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return '';
    return 'Try again in ${remaining.inSeconds}s';
  }

  void _startCooldown(int seconds) {
    setState(() {
      _cooldownUntil = DateTime.now().add(Duration(seconds: seconds));
      _pin = '';
    });

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (!_isCooldownActive) {
          timer.cancel();
          setState(() {
            _cooldownUntil = null;
          });
        } else {
          setState(() {});
        }
      }
    });
  }

  // ============================================================
  // KEY TAP
  // ============================================================

  Future<void> _onKeyTap(
      String key,
      int index,
      ) async {
    if (_loading || _isCooldownActive) {
      return;
    }

    setState(() {
      _pressedIndex = index;
    });

    await Future.delayed(
      const Duration(milliseconds: 100),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _pressedIndex = null;
    });

    if (key == '⌫') {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(
            0,
            _pin.length - 1,
          );
        });
      }

      return;
    }

    if (key.isEmpty || _pin.length >= 6) {
      return;
    }

    setState(() {
      _pin += key;
    });

    if (_pin.length == 6) {
      await _verify();
    }
  }

  // ============================================================
  // VERIFY PIN
  // ============================================================

  Future<void> _verify() async {
    if (_loading || _isCooldownActive) {
      return;
    }

    setState(() {
      _loading = true;
    });

    final success = await _authService.authenticateWithPin(_pin);

    if (!mounted) return;

    if (success) {
      setState(() {
        _failedAttempts = 0;
        _loading = false;
      });

      if (widget.onSuccess != null) {
        await widget.onSuccess!();
      } else if (mounted) {
        context.pop();
      }
      return;
    }

    // Handle failure
    setState(() {
      _failedAttempts++;
      _pin = '';
      _loading = false;
    });

    if (_failedAttempts >= 5) {
      // 30 second cooldown after 5 failed attempts
      _startCooldown(30);
      NotificationService.showError(context, 'Too many failed attempts. Wait 30s.');
    } else if (_failedAttempts >= 3) {
      NotificationService.showError(context, 'Incorrect PIN. ${5 - _failedAttempts} attempts remaining.');
    } else {
      NotificationService.showError(context, 'Incorrect PIN');
    }
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

    final colors =
        theme.colorScheme;

    final text =
        theme.textTheme;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(widget.title ?? 'Unlock'),
              centerTitle: true,
              automaticallyImplyLeading: false,
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Spacer(),

              Text(
                widget.title ?? 'Enter your PIN',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              Text(
                _isCooldownActive ? _cooldownMessage : (widget.description ?? 'Enter your 6-digit PIN to continue.'),
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: _isCooldownActive ? colors.error : colors.onSurfaceVariant,
                  fontWeight: _isCooldownActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              Row(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children:
                List.generate(
                  6,
                      (index) {
                    final filled =
                        index < _pin.length;

                    return AnimatedContainer(
                      duration:
                      const Duration(
                        milliseconds: 150,
                      ),
                      margin:
                      const EdgeInsets
                          .symmetric(
                        horizontal: 6,
                      ),
                      width: 14,
                      height: 14,
                      decoration:
                      BoxDecoration(
                        shape:
                        BoxShape.circle,
                        color: filled
                            ? colors
                            .onSurface
                            : colors
                            .onSurface
                            .withValues(alpha: 0.20),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(
                height: 45,
              ),

              GridView.builder(
                shrinkWrap: true,
                physics:
                const NeverScrollableScrollPhysics(),
                itemCount:
                _keys.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 70,
                ),
                itemBuilder:
                    (context, index) {
                  final key =
                  _keys[index];

                  if (key.isEmpty) {
                    return const SizedBox
                        .shrink();
                  }

                  final pressed =
                      _pressedIndex ==
                          index;

                  return GestureDetector(
                    onTap: () =>
                        _onKeyTap(
                          key,
                          index,
                        ),
                    child:
                    AnimatedContainer(
                      duration:
                      const Duration(
                        milliseconds: 100,
                      ),
                      decoration:
                      BoxDecoration(
                        shape:
                        BoxShape.circle,
                        color: pressed
                            ? colors
                            .onSurface
                            .withValues(alpha: 0.08)
                            : Colors
                            .transparent,
                      ),
                      child: Center(
                        child: key == '⌫'
                            ? Icon(
                          Icons
                              .backspace,
                          color: colors
                              .onSurface,
                        )
                            : Text(
                          key,
                          style: text
                              .titleMedium,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(
                height: 30,
              ),

              if (_loading)
                const Padding(
                  padding:
                  EdgeInsets.only(
                    bottom: 20,
                  ),
                  child:
                  GriotLoader(size: 28),
                )
              else
                const SizedBox(
                  height: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}