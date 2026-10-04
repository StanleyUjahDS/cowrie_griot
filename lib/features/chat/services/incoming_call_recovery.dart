import 'dart:async';

/// Recovers invitations missed by the socket/push transports while foregrounded.
class IncomingCallRecovery {
  IncomingCallRecovery({
    required this.fetch,
    required this.present,
    required this.onError,
    this.interval = const Duration(seconds: 5),
  });

  final Future<List<Map<String, dynamic>>> Function() fetch;
  final void Function(Map<String, dynamic>) present;
  final void Function(Object) onError;
  final Duration interval;
  final Set<String> _delivered = {};
  Timer? _timer;
  String? _userId;
  bool _foreground = false;
  bool _disposed = false;
  int _generation = 0;
  Object? _inFlight;

  void update({required String? userId, required bool foreground}) {
    if (_disposed) return;
    if (_userId == userId && _foreground == foreground) return;
    if (_userId != userId) _delivered.clear();
    _userId = userId;
    _foreground = foreground;
    _generation++;
    _timer?.cancel();
    _timer = null;
    _inFlight = null;
    if (!foreground || userId == null || userId.isEmpty) return;
    unawaited(recover());
    _timer = Timer.periodic(interval, (_) => unawaited(recover()));
  }

  Future<void> recover() async {
    if (_disposed ||
        !_foreground ||
        _userId == null ||
        _userId!.isEmpty ||
        _inFlight != null) {
      return;
    }
    final generation = _generation;
    final request = Object();
    _inFlight = request;
    try {
      final calls = await fetch();
      if (_disposed || generation != _generation) return;
      for (final call in calls) {
        final id = (call['id'] ?? call['callId'])?.toString();
        final room = call['room_id']?.toString();
        final status = call['status']?.toString().toLowerCase();
        final mine = (call['my_status'] ?? call['myStatus'])
            ?.toString()
            .toLowerCase();
        if (id == null ||
            id.isEmpty ||
            room == null ||
            room.isEmpty ||
            mine != 'invited' ||
            !const {'ringing', 'active'}.contains(status) ||
            _delivered.contains(id)) {
          continue;
        }
        present({
          'type': 'incoming_call',
          'callId': id,
          'roomId': room,
          'conversationId': call['conversation_id']?.toString() ?? '',
          'contextType': call['context_type']?.toString() ?? 'direct',
          'mode': call['mode']?.toString() ?? 'voice',
          'callerName': call['caller_name']?.toString() ?? 'Griot contact',
        });
        _delivered.add(id);
      }
    } catch (error) {
      if (!_disposed && generation == _generation) onError(error);
    } finally {
      if (identical(_inFlight, request)) _inFlight = null;
    }
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    _delivered.clear();
  }
}
