import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/shared_content.dart';

/// Bridges Android intents and the iOS Share Extension into Flutter.
class SharedContentService {
  SharedContentService._();

  static final SharedContentService instance = SharedContentService._();

  static const _methodChannel = MethodChannel('griot/share_receiver');
  static const _eventChannel = EventChannel('griot/share_receiver/events');

  Stream<SharedContent> get stream {
    if (!Platform.isAndroid && !Platform.isIOS) return const Stream<SharedContent>.empty();
    return _eventChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map((event) => SharedContent.fromMap(event as Map));
  }

  Future<SharedContent?> getInitial() async {
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    final value = await _methodChannel.invokeMethod<dynamic>('getInitialShare');
    if (value is! Map) return null;
    final content = SharedContent.fromMap(value);
    return content.isSupported ? content : null;
  }
}
