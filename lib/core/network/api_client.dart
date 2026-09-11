import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/services/auth_storage_service.dart';

import 'api_exception.dart';
import 'api_config.dart';

class ApiClient {
  final http.Client _client;
  final AuthStorageService _authStorageService;

  // ============================================================
  // REFRESH SYNCHRONIZATION
  // ============================================================

  bool _isRefreshing = false;
  Future<bool>? _refreshFuture;
  void Function(String accessToken)? onAccessTokenRefreshed;

  // Read-through cache for idempotent GET requests. Feature providers still
  // own longer-lived/persistent caches; this prevents duplicate requests
  // while several widgets ask for the same resource during navigation.
  final Map<String, _CachedGet> _getCache = {};
  final Map<String, Future<dynamic>> _getInFlight = {};
  static const Duration _getCacheTtl = Duration(seconds: 20);

  ApiClient({http.Client? client, AuthStorageService? authStorageService})
    : _client = client ?? http.Client(),
      _authStorageService = authStorageService ?? AuthStorageService();

  // ============================================================
  // GET
  // ============================================================

  Future<dynamic> get(
    String url, {
    Map<String, String>? headers,
    bool forceRefresh = false,
    Duration? cacheTtl,
  }) async {
    final key = _cacheKey(url, headers);
    final now = DateTime.now();
    final cached = _getCache[key];
    final ttl = cacheTtl ?? _getCacheTtl;
    if (!forceRefresh && cached != null && now.difference(cached.createdAt) < ttl) {
      return cached.value;
    }
    final pending = _getInFlight[key];
    if (pending != null) return pending;
    final request = _request(method: 'GET', url: url, headers: headers);
    _getInFlight[key] = request;
    try {
      final value = await request;
      _getCache[key] = _CachedGet(value, DateTime.now());
      return value;
    } finally {
      _getInFlight.remove(key);
    }
  }

  String _cacheKey(String url, Map<String, String>? headers) =>
      '$url|${headers?['Authorization'] ?? ''}';

  void invalidateGetCache([String? urlPrefix]) {
    if (urlPrefix == null) {
      _getCache.clear();
      return;
    }
    _getCache.removeWhere((key, _) => key.startsWith(urlPrefix));
  }

  // ============================================================
  // POST
  // ============================================================

  Future<dynamic> post(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final result = await _request(method: 'POST', url: url, body: body, headers: headers);
    invalidateGetCache();
    return result;
  }

  // ============================================================
  // PUT
  // ============================================================

  Future<dynamic> put(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final result = await _request(method: 'PUT', url: url, body: body, headers: headers);
    invalidateGetCache();
    return result;
  }

  // ============================================================
  // PATCH
  // ============================================================

  Future<dynamic> patch(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final result = await _request(method: 'PATCH', url: url, body: body, headers: headers);
    invalidateGetCache();
    return result;
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<dynamic> delete(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final result = await _request(method: 'DELETE', url: url, body: body, headers: headers);
    invalidateGetCache();
    return result;
  }

  // ============================================================
  // UPLOAD (MULTIPART)
  // ============================================================

  Future<dynamic> upload(
    String url, {
    required String fileKey,
    required String filePath,
    Map<String, String>? fields,
    Map<String, String>? headers,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse(url);
    final accessToken = await _authStorageService.getAccessToken();

    final request = http.MultipartRequest('POST', uri);

    // Headers
    request.headers['Accept'] = 'application/json';
    if (accessToken != null && accessToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    if (headers != null) {
      request.headers.addAll(headers);
    }

    // Fields
    if (fields != null) {
      request.fields.addAll(fields);
    }

    // File
    final file = await http.MultipartFile.fromPath(fileKey, filePath);
    request.files.add(file);

    try {
      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      dynamic data;
      if (response.body.isNotEmpty) {
        data = jsonDecode(response.body);
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      }

      if (response.statusCode == 401 &&
          !isRetry &&
          url != ApiConfig.authRefresh &&
          url != ApiConfig.authVerify) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          return await upload(
            url,
            fileKey: fileKey,
            filePath: filePath,
            fields: fields,
            headers: headers,
            isRetry: true,
          );
        }
        await _authStorageService.clearSession();
      }

      throw ApiException(
        message: data is Map
            ? (data['message'] ?? 'Upload failed')
            : 'Upload failed',
        statusCode: response.statusCode,
        data: data,
      );
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException(
        message: 'Unable to connect to the server.',
        originalError: error,
      );
    }
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

    if (kDebugMode) {
      debugPrint('API REQUEST METHOD: $method');
      debugPrint('API REQUEST URL: $url');
    }

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

    final accessToken = await _authStorageService.getAccessToken();

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

    final bool isAuthRoute =
        url.contains('/auth/nonce') ||
        url.contains('/auth/verify') ||
        url.contains('/auth/refresh') ||
        url.contains('/auth/login');

    if (accessToken != null && accessToken.isNotEmpty && !isAuthRoute) {
      requestHeaders['Authorization'] = 'Bearer $accessToken';

      if (kDebugMode) {
        debugPrint('API AUTHORIZATION: Bearer token attached');
      }
    } else {
      if (kDebugMode) {
        if (isAuthRoute) {
          debugPrint(
            'API AUTHORIZATION: Not required for public auth endpoint',
          );
        } else {
          debugPrint(
            'API AUTHORIZATION: No access token (Protected route might fail)',
          );
        }
      }
    }

    // ==========================================================
    // HTTP REQUEST
    // ==========================================================

    http.Response response;

    try {
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: requestHeaders);
          break;

        case 'POST':
          response = await _client.post(
            uri,
            headers: requestHeaders,
            body: body == null ? null : jsonEncode(body),
          );
          break;

        case 'PUT':
          response = await _client.put(
            uri,
            headers: requestHeaders,
            body: body == null ? null : jsonEncode(body),
          );
          break;

        case 'PATCH':
          response = await _client.patch(
            uri,
            headers: requestHeaders,
            body: body == null ? null : jsonEncode(body),
          );
          break;

        case 'DELETE':
          response = await _client.delete(
            uri,
            headers: requestHeaders,
            body: body == null ? null : jsonEncode(body),
          );
          break;

        default:
          throw ApiException(message: 'Unsupported HTTP method: $method');
      }
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(
        message: 'Unable to connect to the server.',
        originalError: error,
      );
    }

    // ==========================================================
    // DEBUG RESPONSE
    // ==========================================================

    if (kDebugMode) {
      debugPrint('API RESPONSE STATUS: ${response.statusCode}');
      debugPrint('API RESPONSE URL: $url');
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
          message: 'Invalid response from server.',
          statusCode: response.statusCode,
          originalError: error,
        );
      }
    }

    // ==========================================================
    // SUCCESS
    // ==========================================================

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    // ==========================================================
    // 401 AUTH REFRESH
    // ==========================================================

    if (response.statusCode == 401 &&
        !isRetry &&
        url != ApiConfig.authRefresh &&
        url != ApiConfig.authVerify) {
      if (kDebugMode) debugPrint('API 401: Unauthorized for $url');

      final success = await _refreshAccessToken();
      if (success) {
        return await _request(
          method: method,
          url: url,
          body: body,
          headers: headers,
          isRetry: true,
        );
      }

      if (kDebugMode) debugPrint('API 401: Refresh failed, clearing session.');
      await _authStorageService.clearSession();
      throw ApiException(
        message: 'Session expired. Please log in again.',
        statusCode: 401,
      );
    }

    // ==========================================================
    // SERVER ERROR
    // ==========================================================

    String message = 'Request failed.';

    if (data is Map<String, dynamic>) {
      final serverMessage = data['message'];

      if (serverMessage is String && serverMessage.isNotEmpty) {
        message = serverMessage;
      }
    }

    if (kDebugMode) {
      debugPrint('API ERROR: $message');
      debugPrint('API ERROR STATUS: ${response.statusCode}');
    }

    throw ApiException(
      message: message,
      statusCode: response.statusCode,
      data: data,
    );
  }

  // ============================================================
  // TOKEN REFRESH
  // ============================================================

  Future<bool> _refreshAccessToken() async {
    if (_isRefreshing) {
      if (kDebugMode) {
        debugPrint('API 401: Refresh already in progress, waiting...');
      }
      return await _refreshFuture ?? false;
    }

    _isRefreshing = true;
    _refreshFuture = (() async {
      try {
        final refreshToken = await _authStorageService.getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          if (kDebugMode) debugPrint('API 401: No refresh token found.');
          return false;
        }

        final refreshResponse = await _client.post(
          Uri.parse(ApiConfig.authRefresh),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'refreshToken': refreshToken,
            'refresh_token': refreshToken,
          }),
        );

        if (refreshResponse.statusCode != 200) return false;
        final refreshData = jsonDecode(refreshResponse.body);
        final newData = refreshData['data'] ?? refreshData;
        final newAccess = (newData['accessToken'] ?? newData['access_token'])
            ?.toString();
        final newRefresh = (newData['refreshToken'] ?? newData['refresh_token'])
            ?.toString();
        if (newAccess == null ||
            newRefresh == null ||
            newAccess.isEmpty ||
            newRefresh.isEmpty) {
          return false;
        }

        await _authStorageService.saveSession(
          accessToken: newAccess,
          refreshToken: newRefresh,
        );
        onAccessTokenRefreshed?.call(newAccess);
        if (kDebugMode) debugPrint('API 401: Refresh success.');
        return true;
      } catch (error) {
        if (kDebugMode) debugPrint('API 401: Refresh error: $error');
        return false;
      }
    })();

    try {
      return await _refreshFuture!;
    } finally {
      _isRefreshing = false;
      _refreshFuture = null;
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _client.close();
  }
}

class _CachedGet {
  final dynamic value;
  final DateTime createdAt;
  const _CachedGet(this.value, this.createdAt);
}
