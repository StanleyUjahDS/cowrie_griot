import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../models/referral_model.dart';

class ReferralApiService {
  final ApiClient _apiClient;

  ReferralApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<ReferralData> getReferralStatus() async {
    final response = await _apiClient.get(ApiConfig.referralMe);
    
    if (response is! Map<String, dynamic>) {
      throw Exception('Invalid response from server.');
    }

    final data = (response.containsKey('data') ? response['data'] : response);
    
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid referral data from server.');
    }
    
    return ReferralData.fromJson(data);
  }

  Future<void> claimReferral(String referralCode) async {
    final response = await _apiClient.post(
      ApiConfig.referralClaim,
      body: {'referralCode': referralCode},
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Invalid response from server.');
    }

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Unable to claim referral.');
    }
  }
}
