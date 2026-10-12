import 'package:flutter/material.dart';

/// The expanded reaction picker shared by Campfire and messaging surfaces.
/// Keep the library intentionally lightweight while allowing any emoji typed
/// from the keyboard as a custom reaction.
class EmojiReactionPicker extends StatefulWidget {
  const EmojiReactionPicker({super.key});

  static const library = <String>[
    '😀',
    '😃',
    '😄',
    '😁',
    '😂',
    '🤣',
    '😊',
    '😍',
    '🥰',
    '😘',
    '🤩',
    '🥳',
    '😮',
    '😢',
    '😭',
    '😡',
    '🤯',
    '😴',
    '🤔',
    '🙄',
    '😇',
    '😎',
    '🥹',
    '😅',
    '👍',
    '👎',
    '👏',
    '🙏',
    '🙌',
    '🤝',
    '💪',
    '👌',
    '✌️',
    '🤞',
    '👋',
    '🫶',
    '💯',
    '🔥',
    '🎉',
    '❤️',
    '💔',
    '✨',
    '⭐',
    '✅',
    '❌',
    '💡',
    '🎤',
  ];

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => const EmojiReactionPicker(),
    );
  }

  @override
  State<EmojiReactionPicker> createState() => _EmojiReactionPickerState();
}

class _EmojiReactionPickerState extends State<EmojiReactionPicker> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _query.trim();
    final emojis = query.isEmpty
        ? EmojiReactionPicker.library
        : EmojiReactionPicker.library
              .where((emoji) => emoji.contains(query))
              .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'React with an emoji',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search or use your keyboard',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: colors.outlineVariant),
                ),
              ),
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                leading: Text(query, style: const TextStyle(fontSize: 24)),
                title: Text('Use “$query” as your reaction'),
                onTap: () => Navigator.pop(context, query),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 260,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: emojis.length,
                itemBuilder: (_, index) => InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(context, emojis[index]),
                  child: Center(
                    child: Text(
                      emojis[index],
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
