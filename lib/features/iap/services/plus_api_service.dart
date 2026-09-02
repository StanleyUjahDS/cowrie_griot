import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../models/plus_status_model.dart';

class PlusApiService {
  final ApiClient apiClient;

  PlusApiService({required this.apiClient});

  Future<PlusStatus> getStatus() async {
    try {
      final response = await apiClient.get(ApiConfig.plusStatus);
      if (response['success'] == true) {
        return PlusStatus.fromJson(response['data']);
      }
      return PlusStatus.none();
    } catch (e) {
      return PlusStatus.none();
    }
  }

  Future<PlusStatus> verifyPurchase({
    required String provider,
    required String productId,
    required String transactionId,
    String? originalTransactionId,
    String? receipt,
    String? purchaseToken,
  }) async {
    final Map<String, dynamic> body = {
      'provider': provider,
      'productId': productId,
      'transactionId': transactionId,
    };

    if (provider == 'apple') {
      body['originalTransactionId'] = originalTransactionId;
      body['receipt'] = receipt;
    } else if (provider == 'google') {
      body['purchaseToken'] = purchaseToken;
    }

    final response = await apiClient.post(ApiConfig.plusVerify, body: body);
    
    if (response['success'] == true) {
      return PlusStatus.fromJson(response['data']);
    } else {
      throw Exception(response['message'] ?? 'Verification failed');
    }
  }
}
