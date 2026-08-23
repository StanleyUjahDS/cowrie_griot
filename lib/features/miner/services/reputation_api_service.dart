import '../../../core/network/api_client.dart';
import '../models/reputation_model.dart';

class ReputationApiService {
  final ApiClient _apiClient;

  ReputationApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<ReputationData> getReputation() async {
    final response = await _apiClient.get('/api/reputation/me');
    
    if (response is! Map<String, dynamic>) {
      throw Exception('Invalid response from server.');
    }

    // Support both wrapped and unwrapped response
    final data = (response.containsKey('data') ? response['data'] : response);
    
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid reputation data from server.');
    }
    
    return ReputationData.fromJson(data);
  }
}
