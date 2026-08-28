import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/widgets/onboarding/welcome_page_widget.dart';
import '/widgets/onboarding/animated_progress_bar.dart';
import '/core/ui/scaffolds/gradient_scaffold.dart';

class WelcomePage4 extends StatelessWidget {
  const WelcomePage4({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    const double progress = 1.0;

    return GradientScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,

        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: colorScheme.onSurface),
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),

        body: SafeArea(
          child: WelcomePageWidget(
            order: 4,
            title: "Get Started",
            description: "Begin your journey with Griot by Cowrie — the Web3 super-app for connection, "
                "earning, and freedom. Chat, earn,"
                " and transact seamlessly in one unified ecosystem.",
            imagePath: "assets/cowrie_images/fifth_frame.png",
          

            bottomAction: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    "Skip",
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
          
                Expanded(
                  child: AnimatedProgressBar(
                    value: progress,
                    backgroundColor:
                    colorScheme.onSurface.withValues(alpha: 0.15),
                    valueColor: colorScheme.primary,
                  ),
                ),
                SizedBox(
                  width:12,
                ),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 4,
                  ),
                  child: const Icon(Icons.check),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
