import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

class MiningApiService {
  final ApiClient _apiClient;

  MiningApiService({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  Future<Map<String, dynamic>> getMiningStatus() async {
    final response = await _apiClient.get(ApiConfig.miningStatus);
    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> startMining() async {
    final response = await _apiClient.post(ApiConfig.miningStart);
    return _asMap(_unwrap(response));
  }

  Future<List<Map<String, dynamic>>> getMiningActivities() async {
    final response = await _apiClient.get(ApiConfig.miningActivities);
    final data = response['data'];
    if (data is! List) return [];
    return data.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<List<Map<String, dynamic>>> getMiningHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.miningHistory(
        limit: limit,
        offset: offset,
      ),
    );

    return _asMapList(_unwrap(response));
  }

  dynamic _unwrap(dynamic response) {
    if (response is Map<String, dynamic>) {
      if (response.containsKey('data') && response['data'] is Map) {
        return response['data'];
      }
      if (response.containsKey('mining') && response['mining'] is Map) {
        return response['mining'];
      }
      if (response.containsKey('status') && response['status'] is Map) {
        return response['status'];
      }
    }
    return response;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    return data is Map<String, dynamic>
        ? Map<String, dynamic>.from(data)
        : {};
  }

  List<Map<String, dynamic>> _asMapList(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (data is Map<String, dynamic> && data.containsKey('history')) {
      final history = data['history'];
      if (history is List) {
        return history.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return [];
  }
}
