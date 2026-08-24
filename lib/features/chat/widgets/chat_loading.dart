import 'package:flutter/material.dart';
import '../../../core/ui/widgets/griot_branded_loading.dart';

class ChatLoading extends StatelessWidget {
  const ChatLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const GriotBrandedLoading(
      title: 'Connecting to Griot',
      message: 'Securely loading your private conversations and requests...',
      icon: Icons.chat_bubble_outline_rounded,
    );
  }
}
