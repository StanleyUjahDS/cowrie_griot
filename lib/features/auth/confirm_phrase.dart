import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/core/ui/scaffolds/gradient_scaffold.dart';
import 'package:overlay_support/overlay_support.dart';
import '/core/theme/app_buttons.dart';


class VerifySeed extends StatefulWidget {
  const VerifySeed({super.key});

  @override
  State<VerifySeed> createState() => _VerifySeedState();
}

class _SeedOption {
  final String word;
  final int originalIndex;

  _SeedOption({
    required this.word,
    required this.originalIndex,
  });
}

class _VerifySeedState extends State<VerifySeed> {
  /// ================= DUMMY SEED (FROM PREVIOUS SCREEN) =================
  final List<String> seedPhrase = [
    "apple", "river", "stone", "planet",
    "gold", "shadow", "forest", "dream",
    "ocean", "light", "storm", "flame",
  ];

  List<_SeedOption> options = [];
  List<bool> isSelected = [];

  static const IconData customIcon =
  IconData(0xf53f, fontFamily: 'MaterialIcons');

  @override
  void initState() {
    super.initState();
    _prepareOptions();
  }

  /// ================= BUILD RANDOM OPTIONS =================
  void _prepareOptions() {
    const mandatory = {3, 8};

    List<_SeedOption> selected = mandatory
        .map((i) => _SeedOption(
      word: seedPhrase[i],
      originalIndex: i,
    ))
        .toList();

    List<int> remaining = List.generate(12, (i) => i)
        .where((i) => !mandatory.contains(i))
        .toList()
      ..shuffle();

    while (selected.length < 6) {
      final index = remaining.removeLast();
      selected.add(
        _SeedOption(
          word: seedPhrase[index],
          originalIndex: index,
        ),
      );
    }

    selected.shuffle();

    options = selected;
    isSelected = List.filled(options.length, false);
  }

  /// ================= CHECK SELECTION =================
  Set<int> _selectedIndexes() {
    final set = <int>{};

    for (int i = 0; i < options.length; i++) {
      if (isSelected[i]) {
        set.add(options[i].originalIndex);
      }
    }

    return set;
  }

  bool isSelectionCorrect() {
    final selected = _selectedIndexes();
    return selected.containsAll({3, 8}) && selected.length == 2;
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
          automaticallyImplyLeading: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text(
            "Verify Recovery Phrase",
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const Text(
                  "Select the 4th and 9th word",
                ),

                const SizedBox(height: 10),

                /// ================= OPTIONS =================
                Expanded(
                  child: ListView.builder(
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final item = options[index];
                      final selected = isSelected[index];

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            isSelected[index] = !isSelected[index];
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xffd18d1f)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? Colors.white
                                  : Colors.black26,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.word,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                              Icon(
                                customIcon,
                                size: 18,
                                color: selected
                                    ? Colors.white
                                    : Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                /// ================= BUTTON =================
                 SizedBox(
                   width: double.infinity,
                   height: 50,
                   child: ElevatedButton(
                      style: AppButtons.primary(context),
                      onPressed: () {
                          if (isSelectionCorrect()) {
                            context.push('/set_password');
                          } else {
                            showSimpleNotification(
                              const Text("Incorrect selection. Please try again."),
                              leading: const Icon(Icons.error_outline, color: Colors.red),
                              position: NotificationPosition.top,
                              background: Colors.black87,
                              foreground: Colors.white,
                              duration: const Duration(seconds: 2),
                            );
                          }
                      },
                      child: Text(
                        "Continue", style: textTheme.titleSmall,
                      ),
                    ),
                 ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}