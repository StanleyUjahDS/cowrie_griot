import 'package:flutter/material.dart';

class FloatingComposerButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const FloatingComposerButton({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: CircleBorder(
        side: BorderSide(
          color: foreground.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Icon(icon, color: foreground, size: 23),
        ),
      ),
    );
  }
}
