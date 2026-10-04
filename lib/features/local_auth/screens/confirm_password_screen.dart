import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '/core/services/notification_service.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';
import '../services/local_auth_service.dart';
import '../providers/app_lock_provider.dart';

class VerifyPassword extends StatefulWidget {
  final String input;
  final Future<void> Function(BuildContext)? onSuccess;
  final bool setupBiometrics;

  const VerifyPassword({
    super.key,
    required this.input,
    this.onSuccess,
    this.setupBiometrics = false,
  });

  @override
  State<VerifyPassword> createState() => _VerifyPasswordState();
}

class _VerifyPasswordState extends State<VerifyPassword> {
  String confirminput = '';
  bool _loading = false;
  int? _pressedIndex;

  final List<String> keys = [
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

  void _onKeyTap(String key, int index) {
    if (_loading) return;
    setState(() => _pressedIndex = index);
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted && _pressedIndex == index) {
        setState(() => _pressedIndex = null);
      }
    });

    var nextInput = confirminput;
    if (key == '⌫') {
      if (nextInput.isNotEmpty) {
        nextInput = nextInput.substring(0, nextInput.length - 1);
      }
    } else if (key.isNotEmpty && nextInput.length < 6) {
      nextInput += key;
    }

    setState(() {
      confirminput = nextInput;
    });

    if (nextInput.length == 6) {
      _onContinue(nextInput);
    }
  }

  Future<void> _onContinue([String? value]) async {
    if (_loading) return;

    final pin = value ?? confirminput;
    if (pin == widget.input) {
      setState(() => _loading = true);

      try {
        final authService = context.read<LocalAuthService>();
        final lockProvider = context.read<AppLockProvider>();

        await authService.savePin(pin);
        await lockProvider.setEnabled(true);

        if (!mounted) return;
        // Recovery/setup must always pass through the biometric choice before
        // completing the wallet session. Settings-based PIN changes can still
        // use their callback directly without reopening setup.
        if (widget.setupBiometrics || widget.onSuccess == null) {
          context.pushReplacement(
            '/enable_biometrics',
            extra: widget.onSuccess,
          );
        } else {
          await widget.onSuccess!(context);
        }
      } catch (e) {
        if (mounted) {
          NotificationService.showError(context, "Account setup failed: $e");
          setState(() => _loading = false);
        }
      }
    } else {
      NotificationService.showError(context, "Wrong password");
      setState(() => confirminput = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Confirm Password"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    GriotBrandedContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 32,
                      child: Icon(
                        Icons.verified_user_outlined,
                        size: 40,
                        color: colorScheme.primary,
                      ),
                    ),

                    const SizedBox(height: 40),

                    /// ================= PIN DOTS =================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        final filled = index < confirminput.length;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? colorScheme.primary
                                : colorScheme.onSurface.withValues(alpha: 0.15),
                          ),
                        );
                      }),
                    ),

                    // This spacer pushes the keyboard down
                    const SizedBox(height: 80),

                    const SizedBox(height: 60),

                    /// ================= KEYBOARD =================
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: keys.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            mainAxisExtent: 70,
                          ),
                      itemBuilder: (context, index) {
                        final key = keys[index];
                        if (key.isEmpty) return const SizedBox.shrink();

                        final isPressed = _pressedIndex == index;

                        return GestureDetector(
                          onTap: () => _onKeyTap(key, index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isPressed
                                  ? colorScheme.primary.withValues(alpha: 0.1)
                                  : Colors.transparent,
                            ),
                            child: Center(
                              child: key == '⌫'
                                  ? Icon(
                                      Icons.backspace_rounded,
                                      color: colorScheme.onSurface,
                                      size: 22,
                                    )
                                  : Text(
                                      key,
                                      style: textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            /// ================= BUTTON =================
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Text(
                          "Confirm",
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
