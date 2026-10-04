import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:griot_cowrie/core/network/api_client.dart';
import 'package:griot_cowrie/features/chat/services/messaging_api_service.dart';
import 'package:griot_cowrie/features/chat/services/active_call_controller.dart';
import 'package:griot_cowrie/features/chat/widgets/active_call_host.dart';

class _NoApi extends Fake implements ApiClient {}
class _NoMessaging extends Fake implements MessagingApiService {}

class _Probe extends StatefulWidget {
  const _Probe({required this.onCreate, required this.onDispose});
  final VoidCallback onCreate, onDispose;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  bool muted = false;
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [TextButton(
      onPressed: () => setState(() => muted = !muted),
      child: Text(muted ? 'Muted session' : 'Live session'),
    ), TextButton(onPressed: () => showDialog<void>(context: context,
      useRootNavigator: false,
      builder: (_) => const Dialog(child: Text('Guests panel'))),
      child: const Text('Open guests'))]),
  );
}

void main() {
  test('remote hang-up closes a minimized connecting session once', () async {
    final controller = ActiveCallController();
    controller.open(const CallRequest(conversationId: 'room', conversationType: 'direct', mode: 'voice'));
    controller.minimize();
    final connecting = Completer<void>();
    final events = StreamController<Map<String, dynamic>>();
    var received = 0;
    controller.listen(events.stream, (_) => received++);
    Future<void> end() => controller.end(api: _NoApi(), messaging: _NoMessaging(),
        connecting: connecting.future, callId: () => null, notifyServer: false, timedOut: false);
    final first = end();
    expect(identical(first, end()), isTrue);
    expect(controller.closing, isTrue);
    controller.expand();
    expect(controller.minimized, isTrue);
    expect(controller.open(const CallRequest(conversationId: 'new', conversationType: 'direct', mode: 'video')), isFalse);
    connecting.complete();
    await first;
    events.add({'status': 'ended'});
    await Future<void>.delayed(Duration.zero);
    expect(received, 0);
    expect(controller.request, isNull);
    expect(controller.closing, isFalse);
    await events.close();
    controller.dispose();
  });
  for (final kind in ['direct', 'group', 'space', 'public']) {
    for (final mode in ['voice', 'video']) {
      testWidgets(
        '$kind $mode retains the same call through minimize, app navigation and Return',
        (tester) async {
          final controller = ActiveCallController();
          final dispatcher = RootBackButtonDispatcher();
          dispatcher.addCallback(() async => false);
          final appNavigator = GlobalKey<NavigatorState>();
          var created = 0;
          var disposed = 0;
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: appNavigator,
              home: const Scaffold(body: Text('App home')),
              builder: (context, child) => Stack(
                children: [
                  child!,
                  ActiveCallHost(
                    controller: controller,
                    backDispatcher: dispatcher,
                    callBuilder: (_) => _Probe(
                      onCreate: () => created++,
                      onDispose: () => disposed++,
                    ),
                  ),
                ],
              ),
            ),
          );
          controller.open(
            CallRequest(
              conversationId: 'room',
              conversationType: kind,
              mode: mode,
            ),
          );
          await tester.pumpAndSettle();
          final media = controller.media;
          expect(
            controller.open(
              CallRequest(
                conversationId: 'duplicate',
                conversationType: kind,
                mode: mode,
              ),
            ),
            isFalse,
          );
          expect(controller.request!.conversationId, 'room');
          await tester.tap(find.text('Live session'));
          await tester.pump();
          for (var i = 0; i < 3; i++) {
            controller.minimize();
            await tester.pumpAndSettle();
            expect(find.text('Muted session'), findsNothing);
            appNavigator.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const Scaffold(body: Text('Another app screen')),
              ),
            );
            await tester.pumpAndSettle();
            controller.expand();
            await tester.pumpAndSettle();
            expect(find.text('Muted session'), findsOneWidget);
            expect(identical(controller.media, media), isTrue);
            expect(created, 1);
            expect(disposed, 0);
          }
          // System Back only minimizes the call; it does not pop app navigation.
          await tester.tap(find.text('Open guests'));
          await tester.pumpAndSettle();
          expect(find.text('Guests panel'), findsOneWidget);
          expect(await dispatcher.invokeCallback(Future.value(false)), isTrue);
          await tester.pumpAndSettle();
          expect(find.text('Guests panel'), findsNothing);
          expect(controller.minimized, isFalse);
          expect(disposed, 0);
          expect(await dispatcher.invokeCallback(Future.value(false)), isTrue);
          await tester.pumpAndSettle();
          expect(controller.minimized, isTrue);
          expect(find.text('Another app screen'), findsOneWidget);
          // Terminal events are allowed to close a minimized session.
          expect(controller.beginClose(), isTrue);
          expect(
            controller.open(
              const CallRequest(
                conversationId: 'second',
                conversationType: 'direct',
                mode: 'voice',
              ),
            ),
            isFalse,
          );
          controller.finishClose();
          await tester.pumpAndSettle();
          expect(disposed, 1);
          expect(controller.request, isNull);
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        },
      );
    }
  }
}
