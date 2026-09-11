import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/widgets/onboarding/welcome_page_widget.dart';
import '/widgets/onboarding/animated_progress_bar.dart';

class WelcomePage1 extends StatelessWidget {
  const WelcomePage1({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const double progress = 0.25;

    return Scaffold(
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
          title: "Message. Connect. Transact.",
          description:
              "Encrypted chats where your wallet is your identity. "
              "Send crypto and access token-gated circles seamlessly.",
          imagePath: "assets/cowrie_images/first_frame.png",
          bottomAction: Row(
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
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedProgressBar(
                  value: progress,
                  backgroundColor: colorScheme.onSurface.withValues(alpha: 0.15),
                  valueColor: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
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
    );
  }
}
