import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/services/auth_storage_service.dart';

import 'api_exception.dart';
import 'api_config.dart';

class ApiClient {
  final http.Client _client;
  final AuthStorageService _authStorageService;

  ApiClient({
    http.Client? client,
    AuthStorageService? authStorageService,
  })  : _client = client ?? http.Client(),
        _authStorageService =
            authStorageService ?? AuthStorageService();

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
  // PATCH
  // ============================================================

  Future<dynamic> patch(
      String url, {
        Map<String, dynamic>? body,
        Map<String, String>? headers,
      }) async {
    return _request(
      method: 'PATCH',
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
    bool isRetry = false,
  }) async {
    final uri = Uri.parse(url);

    debugPrint(
      'API REQUEST METHOD: $method',
    );

    debugPrint(
      'API REQUEST URL: $url',
    );

    debugPrint(
      'API REQUEST URI: $uri',
    );

    // ==========================================================
    // GET CURRENT ACCESS TOKEN
    // ==========================================================
    //
    // IMPORTANT:
    //
    // We read the token for EVERY request.
    //
    // This means that when /auth/refresh rotates the access
    // token, the very next request automatically uses the
    // newly saved token.
    //
    // ==========================================================

    final accessToken =
    await _authStorageService.getAccessToken();

    // ==========================================================
    // REQUEST HEADERS
    // ==========================================================

    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };

    // ==========================================================
    // ATTACH AUTHORIZATION HEADER
    // ==========================================================

    if (accessToken != null &&
        accessToken.isNotEmpty) {
      requestHeaders['Authorization'] =
      'Bearer $accessToken';

      debugPrint(
        'API AUTHORIZATION: Bearer token attached',
      );
    } else {
      debugPrint(
        'API AUTHORIZATION: No access token',
      );
    }

    // ==========================================================
    // HTTP REQUEST
    // ==========================================================

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

        case 'PATCH':
          response = await _client.patch(
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
    // DEBUG RESPONSE
    // ==========================================================

    debugPrint(
      'API RESPONSE STATUS: ${response.statusCode}',
    );

    debugPrint(
      'API RESPONSE URL: $url',
    );

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
    // 401 AUTH REFRESH
    // ==========================================================

    if (response.statusCode == 401 &&
        !isRetry &&
        url != ApiConfig.authRefresh) {
      final refreshToken =
          await _authStorageService.getRefreshToken();

      if (refreshToken != null &&
          refreshToken.isNotEmpty) {
        debugPrint('API 401: Attempting token refresh...');

        try {
          final refreshResponse = await _client.post(
            Uri.parse(ApiConfig.authRefresh),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'refreshToken': refreshToken,
            }),
          );

          if (refreshResponse.statusCode == 200) {
            final refreshData =
                jsonDecode(refreshResponse.body);

            final newData =
                refreshData['data'] ?? refreshData;

            await _authStorageService.saveSession(
              accessToken: newData['accessToken'],
              refreshToken: newData['refreshToken'],
            );

            debugPrint(
              'API 401: Refresh success, retrying original request...',
            );

            return await _request(
              method: method,
              url: url,
              body: body,
              headers: headers,
              isRetry: true,
            );
          } else {
            debugPrint(
              'API 401: Refresh failed with status ${refreshResponse.statusCode}',
            );
          }
        } catch (e) {
          debugPrint('API 401: Refresh error: $e');
        }
      }
    }

    // ==========================================================
    // SERVER ERROR
    // ==========================================================

    String message = 'Request failed.';

    if (data is Map<String, dynamic>) {
      final serverMessage =
      data['message'];

      if (serverMessage is String &&
          serverMessage.isNotEmpty) {
        message = serverMessage;
      }
    }

    debugPrint(
      'API ERROR: $message',
    );

    debugPrint(
      'API ERROR STATUS: ${response.statusCode}',
    );

    throw ApiException(
      message: message,
      statusCode: response.statusCode,
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