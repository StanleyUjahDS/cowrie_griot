import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/core/theme/app_buttons.dart';
import '/core/ui/scaffolds/gradient_scaffold.dart';
import 'package:flutter/services.dart';
import 'package:overlay_support/overlay_support.dart';

class DisplayPhraseScreen extends StatefulWidget {
  const DisplayPhraseScreen({super.key});

  @override
  State<DisplayPhraseScreen> createState() => _DisplayPhraseScreenState();
}

class _DisplayPhraseScreenState extends State<DisplayPhraseScreen> {
  final List<String> seedPhrase = [
    "apple", "river", "stone", "planet",
    "gold", "shadow", "forest", "dream",
    "ocean", "light", "storm", "flame",
  ];
  void _copyPhrase() {
    final phrase = seedPhrase.join(' ');

    Clipboard.setData(ClipboardData(text: phrase));

    showSimpleNotification(
      const Text("Copied to clipboard"),
      leading: const Icon(Icons.check_circle, color: Colors.green),
      position: NotificationPosition.top,
      background: Colors.black87,
      foreground: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final size = MediaQuery.of(context).size;

    return GradientScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,

        appBar: AppBar(
          title: const Text("Your Recovery Phrase"),
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

                          Container(
                            padding: const EdgeInsets.all(16),

                            decoration: BoxDecoration(
                              color: theme.primaryColor.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),

                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: seedPhrase.length,

                              gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 3,
                              ),

                              itemBuilder: (context, index) {
                                final word = seedPhrase[index];

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),

                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.15),
                                    ),
                                  ),

                                  child: Row(
                                    children: [
                                      /// NUMBER
                                      Text(
                                        "${index + 1}.",
                                        style: textTheme.bodySmall
                                      ),

                                      const SizedBox(width: 6),

                                      /// WORD
                                      Expanded(
                                        child: Text(
                                          word,
                                          style: textTheme.bodyMedium,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.all(2),
                            child: ElevatedButton.icon(
                              onPressed: _copyPhrase,
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text("Copy Phrase"),

                              style: ElevatedButton.styleFrom(
                                elevation: 4,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),

                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),

                                ),
                              ),
                            ),
                          ),

                    const SizedBox(height: 16),

                    /// GRID (stays same)
                    Container(
                      // your existing grid code
                    ),
                          Text(
                            "Backup your seed phrase to ensure you do not lose access to your wallet.",
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
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
                      context.push('/create_account/verify_phrase');
                    },
                    child: Text(
                      "Continue",
                      style: textTheme.titleSmall,
                    ),
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