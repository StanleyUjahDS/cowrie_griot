import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

class ReferralApiService {
  final ApiClient _apiClient;

  ReferralApiService({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  Future<Map<String, dynamic>> getReferralStats() async {
    final response = await _apiClient.get(ApiConfig.referralStats);
    return _asMap(_unwrap(response));
  }

  Future<List<Map<String, dynamic>>> getReferrals({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.referralList(
        limit: limit,
        offset: offset,
      ),
    );

    return _asMapList(_unwrap(response));
  }

  dynamic _unwrap(dynamic response) {
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      return response['data'];
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
    if (data is Map<String, dynamic> && data.containsKey('referrals')) {
      final referrals = data['referrals'];
      if (referrals is List) {
        return referrals.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return [];
  }
}
