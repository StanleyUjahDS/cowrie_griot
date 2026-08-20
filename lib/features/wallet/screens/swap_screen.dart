import 'package:flutter/material.dart';
import '../models/token_model.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';

class SwapScreen extends StatefulWidget {
  final TokenModel? initialFromToken;

  const SwapScreen({
    super.key,
    this.initialFromToken,
  });

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Swap'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: const Center(
        child: Text('Swap Feature Coming Soon'),
      ),
    );
  }
}
