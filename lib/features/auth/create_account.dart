import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/core/theme/app_buttons.dart';
import '/core/ui/scaffolds/gradient_scaffold.dart';

class CreateAccountScreen extends StatelessWidget {
  const CreateAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context) ;
    final textTheme = theme.textTheme;
    final size = MediaQuery.of(context).size;

    return GradientScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,

        appBar: AppBar(
          title: const Text("Create Account"),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),

        body: SafeArea(
          child: Column(
            children: [
              /// ================= TOP CONTENT =================
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),

                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: size.height * 0.75,
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          /// ================= GLASS WARNING BOX =================
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 18,
                                sigmaY: 18,
                              ),

                              child: Container(
                                padding: EdgeInsets.all(size.height * 0.02),
                                width: double.infinity,
                                height: size.height * 0.25,

                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(16),

                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),

                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,

                                  children: [
                                    Text(
                                      "Write it Down!",
                                      style: textTheme.titleMedium),


                                    SizedBox(height: size.height * 0.01),

                                    Text(
                                      "There is no way to recover your account if you lose your recovery phrase. "
                                          "Make sure to store it in a safe place!",
                                      style: textTheme.bodyMedium),

                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          /// ================= BOTTOM INFO TEXT =================
                          Text(
                            "Backup your seed phrase to ensure you do not lose access to Griot when uninstalled or lost",
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              /// ================= BUTTON =================
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: AppButtons.primary(context),
                    onPressed: () {
                      context.push('/display_phrase');
                    },
                    child: Text("Generate Account",style: textTheme.titleSmall),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}