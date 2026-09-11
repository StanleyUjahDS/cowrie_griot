import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/core/services/notification_service.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';

class SetPassword extends StatefulWidget {
  final Future<void> Function(BuildContext)? onSuccess;
  const SetPassword({super.key, this.onSuccess});

  @override
  State<SetPassword> createState() => _SetPasswordState();
}

class _SetPasswordState extends State<SetPassword> {
  String input = '';
  int? _pressedIndex;

  final List<String> keys = [
    '1', '2', '3',
    '4', '5', '6',
    '7', '8', '9',
    '', '0', '⌫',
  ];

  void _onKeyTap(String key, int index) async {
    setState(() => _pressedIndex = index);
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() => _pressedIndex = null);

    setState(() {
      if (key == '⌫') {
        if (input.isNotEmpty) {
          input = input.substring(0, input.length - 1);
        }
      } else if (key.isNotEmpty && input.length < 6) {
        input += key;
      }
    });

    if (input.length == 6) {
      _onContinue();
    }
  }

  void _onContinue() {
    if (input.length == 6) {
      if (mounted) {
        context.pushReplacement('/confirm_password', extra: {
          'pin': input,
          'onSuccess': widget.onSuccess,
        });
      }
    } else {
      NotificationService.showError(context, "Enter a 6-digit PIN");
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
        title: const Text("Create Password"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                        Icons.lock_outline_rounded,
                        size: 40,
                        color: colorScheme.primary,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Secure Your Account',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Set a 6-digit password to secure your account on this device.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 40),

                    /// ================= PIN DOTS =================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        final filled = index < input.length;

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

                    // This spacer will push the keyboard down
                    const SizedBox(height: 80),

                    const SizedBox(height: 60),

                    /// ================= KEYBOARD =================
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: keys.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                  child: Text(
                    "Continue",
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
