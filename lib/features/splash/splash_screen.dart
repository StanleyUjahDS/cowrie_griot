import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/core/ui/scaffolds/gradient_scaffold.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
  });

  @override
  State<SplashScreen> createState() =>
      _SplashScreenState();
}

class _SplashScreenState
    extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(
      const Duration(seconds: 2),
          () {
        if (mounted) {
          context.go('/welcome_one');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return GradientScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // ==================================================
                  // LOGO
                  // ==================================================

                  Image.asset(
                    'assets/cowrie_images/cowrie_stack.png',
                    width:
                    MediaQuery.of(context).size.width *
                        0.8,
                    fit: BoxFit.contain,
                  ),

                  // ==================================================
                  // BRAND
                  // ==================================================

                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      'Griot',
                      style: textTheme.displayLarge,
                    ),
                  ),

                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      'By Cowrie',
                      style: textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.start,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // DESCRIPTION
                  // ==================================================

                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      'The first web3 super app to connect with others, earn, and tell your stories without censorship.',
                      textAlign: TextAlign.justify,
                      style: textTheme.bodyLarge,
                    ),
                  ),

                  const Spacer(),

                  // ==================================================
                  // LOADER
                  // ==================================================

                  CircularProgressIndicator(
                    color: colorScheme.primary,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Loading...',
                    style:
                    textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}