import 'package:flutter/material.dart';
import '../../../core/ui/widgets/griot_branded_loading.dart';

class P2PLoading extends StatelessWidget {
  const P2PLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const GriotBrandedLoading(
      title: 'Loading P2P Market',
      message: 'Finding the best local trade offers for you...',
      icon: Icons.swap_horiz_rounded,
    );
  }
}
