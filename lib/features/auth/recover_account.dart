import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '/core/theme/app_buttons.dart';
import '/core/ui/scaffolds/gradient_scaffold.dart';
import 'package:overlay_support/overlay_support.dart';

class ImportWalletScreen extends StatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  State<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  final List<TextEditingController> _controllers =
  List.generate(12, (_) => TextEditingController());

  bool hasPasted = false;
  /// ================= PASTE =================
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? "";

    if (!mounted || text.isEmpty) return;

    final words = text.trim().split(RegExp(r'\s+'));

    setState(() {
      hasPasted = true;

      for (int i = 0; i < 12; i++) {
        _controllers[i].text = i < words.length ? words[i] : "";
      }
    });

    if (!mounted) return;

    showSimpleNotification(
      const Text("Seed phrase pasted successfully"),
      leading: const Icon(Icons.check_circle, color: Colors.green),
      position: NotificationPosition.top,
      background: Colors.black87,
      foreground: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }
  /// ================= CLEAR =================
  void _clearAll() {
    if (!mounted) return;

    setState(() {
      hasPasted = false;
      for (final c in _controllers) {
        c.clear();
      }
    });

    showSimpleNotification(
      const Text("All fields cleared"),
      leading: const Icon(Icons.info_outline, color: Colors.blue),
      position: NotificationPosition.top,
      background: Colors.black87,
      foreground: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }
  /// ================= IMPORT =================
  void _importWallet() {
    final phrase = _controllers.map((e) => e.text.trim()).join(" ").trim();

    if (_controllers.any((c) => c.text.trim().isEmpty)) {
      showSimpleNotification(
        const Text("Complete all 12 words"),
        leading: const Icon(Icons.warning_amber, color: Colors.orange),
        position: NotificationPosition.top,
        background: Colors.black87,
        foreground: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    debugPrint("SEED PHRASE: $phrase");

    context.push('/set_password');
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context) ;
    final textTheme = theme.textTheme;

    return GradientScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,

        appBar: AppBar(
          title: const Text("Import Wallet"),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),

        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  "Paste your seed phrase or wallet address",
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium,
                ),

                const SizedBox(height: 12),

                /// ================= GRID =================
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),

                    child: GridView.builder(
                      itemCount: 12,
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 3.5,
                      ),
                      itemBuilder: (context, index) {
                        return Container(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              if (hasPasted)
                                Text(
                                  "${index + 1}.",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),

                              if (hasPasted)
                                const SizedBox(width: 6),

                              Expanded(
                                child: TextField(
                                  controller: _controllers[index],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                /// ================= ACTION BUTTONS =================

                /// CLEAR + PASTE ROW
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _clearAll,
                        icon: const Icon(Icons.clear, size: 18),
                        label: const Text("Clear"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pasteFromClipboard,
                        icon: const Icon(Icons.paste, size: 18),
                        label: const Text("Paste"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                /// IMPORT BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    style: AppButtons.primary(context),
                    onPressed: _importWallet,
                    child: Text("Import Wallet", style: textTheme.titleSmall,),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}