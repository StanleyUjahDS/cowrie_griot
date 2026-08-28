import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:griot_cowrie/core/network/api_config.dart';
import 'package:griot_cowrie/features/chat/models/chat_message.dart';

class ChatSocketService {
  io.Socket? _socket;
  final _messageController = StreamController<ChatMessage>.broadcast();
  
  Stream<ChatMessage> get messageStream => _messageController.stream;

  void connect(String accessToken) {
    if (_socket?.connected ?? false) return;

    final uri = Uri.parse(ApiConfig.baseUrl).replace(path: '/messages');
    
    _socket = io.io(uri.toString(), io.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': accessToken})
      .enableAutoConnect()
      .build());

    _socket?.onConnect((_) {
      debugPrint('Socket connected: /messages');
    });

    _socket?.onDisconnect((_) {
      debugPrint('Socket disconnected');
    });

    _socket?.on('message_received', (data) {
      try {
        final message = ChatMessage.fromJson(Map<String, dynamic>.from(data));
        _messageController.add(message);
      } catch (e) {
        debugPrint('Error parsing socket message: $e');
      }
    });

    _socket?.connect();
  }

  void joinConversation(String conversationId) {
    _socket?.emit('join_conversation', {'conversationId': conversationId});
  }

  void leaveConversation(String conversationId) {
    _socket?.emit('leave_conversation', {'conversationId': conversationId});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
