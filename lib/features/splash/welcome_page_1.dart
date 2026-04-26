import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/widgets/onboarding/welcome_page_widget.dart';
import '/widgets/onboarding/animated_progress_bar.dart';
import '/core/ui/scaffolds/gradient_scaffold.dart';

class WelcomePage1 extends StatelessWidget {
  const WelcomePage1({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const double progress = 0.2;

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
            order: 1,
            title: "Messaging. Connect. Transact.",
            description: "Private, encrypted 1:1 and group chats where your wallet address"
                " becomes your digital identity. Send crypto or tokens directly in "
                "conversation and access token-gated communities for creators and DAOs.",
            imagePath: "assets/cowrie_images/first_frame.png",
          

            bottomAction: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    "Skip",
                    style: theme.textTheme.titleSmall?.copyWith(
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
                  onPressed: () => context.push('/welcome_two'),
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 4,
                  ),
                  child: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}