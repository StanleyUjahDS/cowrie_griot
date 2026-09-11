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
          confirminput = confirminput.substring(0, confirminput.length - 1);
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
        await lockProvider.setEnabled(true);

        if (!mounted) return;
        NotificationService.showSuccess(context, "Password confirmed");

        if (widget.onSuccess != null) {
          await widget.onSuccess!(context);
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

                    const SizedBox(height: 24),

                    Text(
                      'Confirm Password',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Please re-enter your 6-digit password to confirm it is correct.',
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
