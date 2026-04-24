import 'package:flutter/material.dart';
import '../../core/theme/theme_controller.dart';

class ThemeSettingsPage extends StatelessWidget {
  final ThemeController themeController;

  const ThemeSettingsPage({
    super.key,
    required this.themeController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Theme Settings"),
      ),

      body: ListView(
        children: [
          const SizedBox(height: 10),

          //  SYSTEM
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text("System Theme"),
            subtitle: const Text("Follow device settings"),
            trailing: themeController.themeMode == ThemeMode.system
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () {
              themeController.setTheme(ThemeMode.system);
            },
          ),

          //  LIGHT
          ListTile(
            leading: const Icon(Icons.light_mode),
            title: const Text("Light Mode"),
            subtitle: const Text("Always use light theme"),
            trailing: themeController.themeMode == ThemeMode.light
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () {
              themeController.setTheme(ThemeMode.light);
            },
          ),

          //  DARK
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text("Dark Mode"),
            subtitle: const Text("Always use dark theme"),
            trailing: themeController.themeMode == ThemeMode.dark
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () {
              themeController.setTheme(ThemeMode.dark);
            },
          ),

          const SizedBox(height: 20),

          Divider(color: theme.dividerColor),

          const SizedBox(height: 10),

          Center(
            child: Text(
              "Choose appearance for Griot Cowrie",
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}