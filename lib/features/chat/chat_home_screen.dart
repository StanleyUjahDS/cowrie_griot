import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:griot_cowrie/core/theme/app_theme_extension.dart';

class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({super.key});

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AppThemeExtension>()!;
    final theme2 = Theme.of(context) ;
    final textTheme = theme2.textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        title:  Text("Griot Chat" , style: textTheme.titleLarge,),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(onPressed: () => {}, icon: Icon(Icons.add))
        ],
      ),

      body: const Center(
        child: Text("Chat Home Screen"),
      ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          FloatingActionButton(
            heroTag: "primary_fab",
            backgroundColor: theme.primaryButton.withValues(alpha: 0.95),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
        onPressed: () {
          context.go('/miner');
            },
            child: const Icon(Icons.construction),
          ),

          const SizedBox(height: 12),

          ///  SECONDARY FAB
          FloatingActionButton(
            heroTag: "secondary_fab",
            backgroundColor: theme.secondaryButton.withValues(alpha: 0.95),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),),
            onPressed: () {
              context.go('/wallet');
            },
            child: const Icon(Icons.account_balance_wallet),
          ),
        ],
      ),
    );
  }
}