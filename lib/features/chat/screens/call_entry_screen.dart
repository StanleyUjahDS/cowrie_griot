import 'package:flutter/material.dart';
import '../../../core/router/app_router.dart';
import '../services/active_call_controller.dart';

/// Compatibility entry for deep links and native acceptance. The route owns
/// no engine; it transfers the request once to the persistent app host.
class CallEntryScreen extends StatefulWidget {
  const CallEntryScreen({super.key, required this.request});
  final CallRequest request;
  @override
  State<CallEntryScreen> createState() => _CallEntryScreenState();
}

class _CallEntryScreenState extends State<CallEntryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = AppRouter.router;
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(
          widget.request.conversationType == 'space' ? '/campfires' : '/chat',
        );
      }
      ActiveCallController.instance.open(widget.request);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
