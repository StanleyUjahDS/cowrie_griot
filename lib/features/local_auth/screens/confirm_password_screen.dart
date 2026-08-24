import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '/core/ui/scaffolds/gradient_scaffold.dart';
import '/core/services/notification_service.dart';
import '../services/local_auth_service.dart';
import '../providers/app_lock_provider.dart';

class VerifyPassword extends StatefulWidget {
  final String input;
  final Future<void> Function()? onSuccess;
  const VerifyPassword({super.key, required this.input, this.onSuccess});

  @override
  State<VerifyPassword> createState() => _VerifyPasswordState();
}

class _VerifyPasswordState extends State<VerifyPassword> {
  String confirminput = '';
  bool _loading = false;
  int? _pressedIndex;

  final List<String> keys = [
    '1', '2', '3',
    '4', '5', '6',
    '7', '8', '9',
    '', '0', '⌫',
  ];

  void _onKeyTap(String key, int index) async {
    if (_loading) return;
    setState(() => _pressedIndex = index);

    await Future.delayed(const Duration(milliseconds: 120));

    if (!mounted) return;
    setState(() => _pressedIndex = null);

    setState(() {
      if (key == '⌫') {
        if (confirminput.isNotEmpty) {
          confirminput =
              confirminput.substring(0, confirminput.length - 1);
        }
      } else if (key.isNotEmpty && confirminput.length < 6) {
        confirminput += key;
      }
    });

    if (confirminput.length == 6) {
      _onContinue();
    }
  }

  Future<void> _onContinue() async {
    if (_loading) return;

    if (confirminput == widget.input) {
      setState(() => _loading = true);
      
      try {
        final authService = context.read<LocalAuthService>();
        final lockProvider = context.read<AppLockProvider>();

        await authService.savePin(confirminput);
        // Enable app lock by default when setting a new PIN
        await lockProvider.setEnabled(true);

        if (!mounted) return;
        NotificationService.showSuccess(context, "Password confirmed");

        if (widget.onSuccess != null) {
          await widget.onSuccess!();
        } else {
          if (mounted) {
            context.pushReplacement('/enable_biometrics');
          }
        }
      } catch (e) {
        if (mounted) {
          NotificationService.showError(context, "Failed to save password: $e");
          setState(() => _loading = false);
        }
      }
    } else {
      NotificationService.showError(context, "Wrong password");

      setState(() {
        confirminput = '';
      });
    }
  }

  Color _fade(Color color, double opacity) =>
      color.withValues(alpha: opacity);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    return GradientScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,

        appBar: AppBar(
          title: const Text("Confirm Password"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: true,
        ),

        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [

                /// ================= PIN DOTS =================
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    final filled = index < confirminput.length;

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