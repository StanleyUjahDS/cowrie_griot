import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'api_exception.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({
    http.Client? client,
  }) : _client = client ?? http.Client();

  // ============================================================
  // GET
  // ============================================================

  Future<dynamic> get(
      String url, {
        Map<String, String>? headers,
      }) async {
    return _request(
      method: 'GET',
      url: url,
      headers: headers,
    );
  }

  // ============================================================
  // POST
  // ============================================================

  Future<dynamic> post(
      String url, {
        Map<String, dynamic>? body,
        Map<String, String>? headers,
      }) async {
    return _request(
      method: 'POST',
      url: url,
      body: body,
      headers: headers,
    );
  }

  // ============================================================
  // PUT
  // ============================================================

  Future<dynamic> put(
      String url, {
        Map<String, dynamic>? body,
        Map<String, String>? headers,
      }) async {
    return _request(
      method: 'PUT',
      url: url,
      body: body,
      headers: headers,
    );
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<dynamic> delete(
      String url, {
        Map<String, dynamic>? body,
        Map<String, String>? headers,
      }) async {
    return _request(
      method: 'DELETE',
      url: url,
      body: body,
      headers: headers,
    );
  }

  // ============================================================
  // REQUEST
  // ============================================================

  Future<dynamic> _request({
    required String method,
    required String url,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(url);
    debugPrint('API REQUEST URL: $url');
    debugPrint('API REQUEST URI: $uri');
    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };

    http.Response response;

    try {
      switch (method) {
        case 'GET':
          response = await _client.get(
            uri,
            headers: requestHeaders,
          );
          break;

        case 'POST':
          response = await _client.post(
            uri,
            headers: requestHeaders,
            body: body == null
                ? null
                : jsonEncode(body),
          );
          break;

        case 'PUT':
          response = await _client.put(
            uri,
            headers: requestHeaders,
            body: body == null
                ? null
                : jsonEncode(body),
          );
          break;

        case 'DELETE':
          response = await _client.delete(
            uri,
            headers: requestHeaders,
            body: body == null
                ? null
                : jsonEncode(body),
          );
          break;

        default:
          throw ApiException(
            message:
            'Unsupported HTTP method: $method',
          );
      }
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(
        message:
        'Unable to connect to the server.',
        originalError: error,
      );
    }

    // ==========================================================
    // DECODE RESPONSE
    // ==========================================================

    dynamic data;

    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } catch (error) {
        throw ApiException(
          message:
          'Invalid response from server.',
          statusCode:
          response.statusCode,
          originalError: error,
        );
      }
    }

    // ==========================================================
    // SUCCESS
    // ==========================================================

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return data;
    }

    // ==========================================================
    // SERVER ERROR
    // ==========================================================

    String message = 'Request failed.';

    if (data is Map<String, dynamic>) {
      final serverMessage = data['message'];

      if (serverMessage is String &&
          serverMessage.isNotEmpty) {
        message = serverMessage;
      }
    }

    throw ApiException(
      message: message,
      statusCode:
      response.statusCode,
      data: data,
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _client.close();
  }
}