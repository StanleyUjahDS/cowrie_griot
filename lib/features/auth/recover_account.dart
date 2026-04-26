import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/core/theme/app_buttons.dart';
import '/core/ui/scaffolds/gradient_scaffold.dart';

class RecoverAccountScreen extends StatelessWidget {
  const RecoverAccountScreen({super.key});

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
        ),

        body: SafeArea(
          child: Column(
            children: [
              ///  CONTENT
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        "Recover Account",
                        style: textTheme.headlineMedium,
                      ),

                      const SizedBox(height: 12),

                      Text(
                        "Enter your recovery phrase to restore your wallet.",
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium,
                      ),

                      const SizedBox(height: 30),

                      /// 🔑 INPUT FIELD
                      TextField(
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "Enter recovery phrase",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              /// 🔽 ACTION BUTTON
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: AppButtons.primary(context),
                    onPressed: () {
                      // TODO: recover wallet
                    },
                    child: const Text("Recover Wallet"),
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