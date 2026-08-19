// lib/features/local_auth/screens/pin_verification_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:overlay_support/overlay_support.dart';

import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/services/notification_service.dart';
import '../services/local_auth_service.dart';

class PinVerificationScreen extends StatefulWidget {
  final Future<void> Function()? onSuccess;

  const PinVerificationScreen({
    super.key,
    this.onSuccess,
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

  final List<String> _keys = const [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '',
    '0',
    '⌫',
  ];

  @override
  void initState() {
    super.initState();

    _authService =
        LocalAuthService();
  }

  // ============================================================
  // KEY TAP
  // ============================================================

  Future<void> _onKeyTap(
      String key,
      int index,
      ) async {
    if (_loading) {
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
    if (_loading) {
      return;
    }

    setState(() {
      _loading = true;
    });

    final success =
    await _authService
        .authenticateWithPin(_pin);

    if (!mounted) {
      return;
    }

    if (success) {
      NotificationService.showSuccess('Unlocked');

      if (widget.onSuccess != null) {
        await widget.onSuccess!();

        if (!mounted) {
          return;
        }
      }

      if (mounted) {
        context.pop();
      }

      return;
    }

    setState(() {
      _pin = '';
      _loading = false;
    });

    NotificationService.showError('Incorrect PIN');
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
      appBar: AppBar(
        title:
        const Text('Unlock'),
        centerTitle: true,
        automaticallyImplyLeading:
        false,
      ),
      body: SafeArea(
        child: Padding(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 24,
          ),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.end,
            children: [
              const Spacer(),

              Text(
                'Enter your PIN',
                style:
                text.headlineSmall
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              Text(
                'Enter your 6-digit PIN to continue.',
                textAlign:
                TextAlign.center,
                style:
                text.bodyMedium
                    ?.copyWith(
                  color: colors
                      .onSurfaceVariant,
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
                            .withValues(
                          alpha: 0.20,
                        ),
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
                            .withValues(
                          alpha: 0.08,
                        )
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