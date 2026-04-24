import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/core/ui/scaffolds/gradient_scaffold.dart';
import '/core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // ⏱ realistic splash timing
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.go('/welcome_one');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GradientScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // 🧠 Logo
                  Image.asset(
                    'assets/cowrie_images/cowrie_stack.png',
                    width: MediaQuery.of(context).size.width * 0.8,
                    fit: BoxFit.contain,
                  ),

                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      'Griot',
                      style: textTheme.displayLarge,
                    ),
                  ),


                  // 🔥 Brand line (GOLD)
                  Align(
                    alignment: Alignment.topLeft,

                    child: Text(
                      'By Cowrie',
                      style: textTheme.titleSmall?.copyWith(
                        color: AppColors.gold,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.start,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔷 Description
                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      'The first web3 super app to connect with others, earn, and tell your stories without censorship.',
                      textAlign: TextAlign.justify,
                      style: textTheme.bodyLarge,
                    ),
                  ),

                  const Spacer(),

                  // 🔄 Loader
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),

                  Text(
                    'Loading...',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.gold,
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