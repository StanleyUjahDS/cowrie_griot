import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/chat_message.dart';
import 'message_cache_service.dart';
import 'messaging_api_service.dart';

class MessageSyncService {
  final MessageCacheService _cache;
  final MessagingApiService _api;
  final Connectivity _connectivity;
  
  bool _isSyncing = false;
  StreamSubscription? _connectivitySubscription;

  MessageSyncService({
    required MessageCacheService cache,
    required MessagingApiService api,
    Connectivity? connectivity,
  })  : _cache = cache,
        _api = api,
        _connectivity = connectivity ?? Connectivity();

  void initialize() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        retryPendingMessages();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  // ==========================================================
  // SYNC ACTIONS
  // ==========================================================

  Future<void> retryPendingMessages() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pending = await _cache.getPendingMessages();
      if (pending.isEmpty) return;

      debugPrint('Sync: Retrying ${pending.length} pending messages');

      for (final message in pending) {
        try {
          final realMessage = await _api.sendMessage(
            conversationId: message.conversationId,
            content: message.text,
          );

          // Delete the temporary local message
          await _cache.deleteLocalMessage(message.id);
          
          // Save the real server message
          await _cache.saveMessage(realMessage);
          await _cache.markSynced(realMessage.id);
          
        } catch (e) {
          debugPrint('Sync: Failed to send pending message ${message.id}: $e');
          // We keep it in the cache for next retry
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> syncConversation(String conversationId) async {
    try {
      final remoteMessages = await _api.getMessages(conversationId);
      await _cache.saveMessages(remoteMessages);
    } catch (e) {
      debugPrint('Sync: Failed to sync conversation $conversationId: $e');
    }
  }

  Future<void> saveIncomingMessage(ChatMessage message) async {
    await _cache.saveMessage(message);
    await _cache.markSynced(message.id);
    
    // Automatically send delivered receipt if it's not our own message
    // We don't have currentUserId here, so we might need it passed in or handle it elsewhere.
  }

  Future<void> handleReconnect() async {
    await retryPendingMessages();
  }
}
