import 'package:flutter/material.dart';
import '../../../core/ui/widgets/griot_loader.dart';

class ChatLoading extends StatelessWidget {
  const ChatLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: GriotLoader(),
    );
  }
}
