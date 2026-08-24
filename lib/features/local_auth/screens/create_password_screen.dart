import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/core/ui/scaffolds/gradient_scaffold.dart';
import '/core/services/notification_service.dart';

class SetPassword extends StatefulWidget {
  final Future<void> Function()? onSuccess;
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

  Color _fade(Color color, double opacity) =>
      color.withValues(alpha: opacity);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return GradientScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,

        appBar: AppBar(
          title: const Text("Create Password"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),

        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                /// ================= PIN DOTS =================
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    final filled = index < input.length;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? colorScheme.onSurface
                            : _fade(colorScheme.onSurface, 0.2),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 40),

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
                              ? _fade(colorScheme.onSurface, 0.08)
                              : Colors.transparent,
                        ),
                        child: Center(
                          child: key == '⌫'
                              ? Icon(
                            Icons.backspace,
                            color: colorScheme.onSurface,
                          )
                              : Text(
                            key,
                            style: textTheme.titleMedium,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                /// ================= BUTTON =================
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: Text(
                      "Continue",
                      style: textTheme.titleSmall,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}