import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores unfinished chat text locally so leaving a conversation or
/// relaunching the app does not discard what the user was composing.
class ChatDraftStore {
  static const _storageKey = 'griot_chat_drafts_v1';
  static const _maxDraftLength = 4000;

  const ChatDraftStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  Future<Map<String, String>> _read() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return <String, String>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<String?> read(String conversationId) async {
    final value = (await _read())[conversationId];
    return value?.trim().isEmpty == true ? null : value;
  }

  Future<Map<String, String>> readAll() => _read();

  Future<void> write(String conversationId, String text) async {
    if (conversationId.trim().isEmpty) return;
    final drafts = await _read();
    final value = text.trim();
    if (value.isEmpty) {
      drafts.remove(conversationId);
    } else {
      drafts[conversationId] = value.substring(
        0,
        value.length > _maxDraftLength ? _maxDraftLength : value.length,
      );
    }
    if (drafts.isEmpty) {
      await _storage.delete(key: _storageKey);
    } else {
      await _storage.write(key: _storageKey, value: jsonEncode(drafts));
    }
  }

  Future<void> clear(String conversationId) => write(conversationId, '');
}
