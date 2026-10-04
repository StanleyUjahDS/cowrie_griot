import 'package:flutter/material.dart';
import '../../../core/router/app_router.dart';
import '../screens/call_screen.dart';
import '../services/active_call_controller.dart';

/// Mounted above the router, including while the call is minimized.
class ActiveCallHost extends StatefulWidget {
  const ActiveCallHost({
    super.key,
    this.controller,
    this.callBuilder,
    this.backDispatcher,
  });
  final ActiveCallController? controller;
  final Widget Function(CallRequest)? callBuilder;
  final BackButtonDispatcher? backDispatcher;

  @override
  State<ActiveCallHost> createState() => _ActiveCallHostState();
}

class _ActiveCallHostState extends State<ActiveCallHost> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final _owner = widget.controller ?? ActiveCallController.instance;
  late final ChildBackButtonDispatcher _back;

  @override
  void initState() {
    super.initState();
    _back = (widget.backDispatcher ?? AppRouter.router.backButtonDispatcher)
        .createChildBackButtonDispatcher();
    _back.addCallback(_handleBack);
    _owner.addListener(_syncBack);
    _syncBack();
  }

  void _syncBack() {
    if (_owner.request != null && !_owner.minimized) {
      if (_back.parent.hasCallbacks) {
        _back.takePriority();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _back.parent.hasCallbacks) _syncBack();
        });
      }
    } else {
      _back.parent.forget(_back);
    }
  }

  Future<bool> _handleBack() async {
    if (_owner.request == null || _owner.minimized) return false;
    // Guests and other call dialogs close first; the root call minimizes.
    if (_navigatorKey.currentState?.canPop() == true) {
      await _navigatorKey.currentState!.maybePop();
    } else {
      _owner.minimize();
    }
    return true;
  }

  @override
  void dispose() {
    _owner.removeListener(_syncBack);
    _back.removeCallback(_handleBack);
    _back.parent.forget(_back);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _owner,
    builder: (context, _) {
      final owner = _owner;
      final request = owner.request;
      if (request == null) return const SizedBox.shrink();
      return Offstage(
        offstage: owner.minimized,
        child: HeroControllerScope.none(
          child: KeyedSubtree(
            key: ObjectKey(request),
            child: Navigator(
              key: _navigatorKey,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) =>
                    widget.callBuilder?.call(request) ??
                    CallScreen(
                      conversationId: request.conversationId,
                      conversationType: request.conversationType,
                      mode: request.mode,
                      initialCallId: request.callId,
                      initialSession: request.session,
                      initialRoomId: request.roomId,
                      openParticipantsOnLoad: request.openParticipants,
                    ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
