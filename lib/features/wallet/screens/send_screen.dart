import 'package:flutter/material.dart';
import '../models/token_model.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';

class SendScreen extends StatefulWidget {
  final TokenModel? initialToken;

  const SendScreen({
    super.key,
    this.initialToken,
  });

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Send'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: const Center(
        child: Text('Send Feature Coming Soon'),
      ),
    );
  }
}
