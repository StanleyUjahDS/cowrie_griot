import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/core/theme/app_colors.dart';
import '/core/theme/app_buttons.dart';
import '/core/ui/scaffolds/gradient_scaffold.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return GradientScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,

        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),

        body: SafeArea(
          child: Column(
            children: [
              ///  TOP LEFT SECTION
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Griot',
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'By Cowrie',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.gold,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              ///  SCROLLABLE CENTER CONTENT
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/cowrie_images/wolrd_cowrie.png',
                          height: 150,
                          width: 150,
                        ),

                        const SizedBox(height: 20),

                        /// BUTTON 1
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: AppButtons.primary(context),
                              onPressed: () {
                                context.push('/create_account');
                              },
                              child: Text("Create Account", style:  textTheme.titleSmall),
                            ),
                          ),
                        ),

                        /// BUTTON 2
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: AppButtons.secondary(context),
                              onPressed: () {
                                context.push('/recover_account');
                              },
                              child: Text("Import or Login Account", style:  textTheme.titleSmall),
                            ),
                          ),
                        ),

                        /// DIVIDER
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: const [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text("Or continue with"),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: AppButtons.secondary(context),
                              onPressed: () {
                                context.go('/chat');
                              },
                              child: Text("Hardware Wallet", style:  textTheme.titleSmall),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              /// 🔽 BOTTOM TERMS (FIXED)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'By proceeding you agree to our Terms and Conditions',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: 10),

            ],
          ),
        ),
      ),
    );
  }
}