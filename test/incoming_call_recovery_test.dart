import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:griot_cowrie/features/chat/services/incoming_call_recovery.dart';

Map<String, dynamic> invite(String id, {String status = 'ringing'}) => {
  'id': id,
  'room_id': 'room',
  'conversation_id': 'conversation',
  'my_status': 'invited',
  'status': status,
  'caller_name': 'Caller',
};

void main() {
  testWidgets('recovers a missed event while open without ringing twice', (
    tester,
  ) async {
    var calls = <Map<String, dynamic>>[];
    final shown = <Map<String, dynamic>>[];
    final recovery = IncomingCallRecovery(
      fetch: () async => calls,
      present: shown.add,
      onError: (_) {},
    );
    recovery.update(userId: 'recipient', foreground: true);
    await tester.pump();
    expect(shown, isEmpty);
    calls = [invite('call')];
    await tester.pump(const Duration(seconds: 5));
    expect(shown.single['callId'], 'call');
    expect(shown.single['type'], 'incoming_call');
    await tester.pump(const Duration(seconds: 10));
    expect(shown, hasLength(1));
    recovery.dispose();
  });

  testWidgets(
    'recovers active-call invitations but ignores joined and ended calls',
    (tester) async {
      final shown = <Map<String, dynamic>>[];
      final recovery = IncomingCallRecovery(
        fetch: () async => [
          invite('active', status: 'active'),
          invite('ended', status: 'ended'),
          {...invite('joined'), 'my_status': 'active'},
        ],
        present: shown.add,
        onError: (_) {},
      );
      recovery.update(userId: 'recipient', foreground: true);
      await tester.pump();
      expect(shown.map((call) => call['callId']), ['active']);
      recovery.dispose();
    },
  );

  testWidgets('stops background polling and recovers immediately on resume', (
    tester,
  ) async {
    var requests = 0;
    final recovery = IncomingCallRecovery(
      fetch: () async {
        requests++;
        return [];
      },
      present: (_) {},
      onError: (_) {},
    );
    recovery.update(userId: 'recipient', foreground: true);
    await tester.pump();
    expect(requests, 1);
    recovery.update(userId: 'recipient', foreground: false);
    await tester.pump(const Duration(seconds: 20));
    expect(requests, 1);
    recovery.update(userId: 'recipient', foreground: true);
    await tester.pump();
    expect(requests, 2);
    recovery.update(userId: null, foreground: true);
    await tester.pump(const Duration(seconds: 20));
    expect(requests, 2);
    recovery.dispose();
  });

  testWidgets(
    'discards responses from a previous account without blocking the new account',
    (tester) async {
      final old = Completer<List<Map<String, dynamic>>>();
      var requests = 0;
      final shown = <Map<String, dynamic>>[];
      final recovery = IncomingCallRecovery(
        fetch: () =>
            ++requests == 1 ? old.future : Future.value([invite('new')]),
        present: shown.add,
        onError: (_) {},
      );
      recovery.update(userId: 'old', foreground: true);
      recovery.update(userId: 'new', foreground: true);
      await tester.pump();
      old.complete([invite('old')]);
      await tester.pump();
      expect(shown.map((call) => call['callId']), ['new']);
      recovery.dispose();
    },
  );

  testWidgets('retries failed fetches and does not overlap pending requests', (
    tester,
  ) async {
    var requests = 0;
    var errors = 0;
    final pending = Completer<List<Map<String, dynamic>>>();
    final shown = <Map<String, dynamic>>[];
    final recovery = IncomingCallRecovery(
      fetch: () {
        requests++;
        if (requests == 1) return Future.error(StateError('offline'));
        return pending.future;
      },
      present: shown.add,
      onError: (_) => errors++,
    );
    recovery.update(userId: 'recipient', foreground: true);
    await tester.pump();
    expect(errors, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 10));
    expect(requests, 2);
    pending.complete([invite('retry')]);
    await tester.pump();
    expect(shown.single['callId'], 'retry');
    recovery.dispose();
    await tester.pump(const Duration(seconds: 10));
    expect(requests, 2);
  });
}
