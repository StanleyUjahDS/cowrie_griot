import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

class GoldsApiService {
  final ApiClient apiClient;

  GoldsApiService({required this.apiClient});

  Future<List<Map<String, dynamic>>> getCatalog() async {
    final response = await apiClient.get(ApiConfig.goldsCatalog);
    final data = response['data'];
    final packages = data is Map ? data['packages'] : null;
    if (packages is! List) return const [];
    return packages
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<int> getBalance() async {
    final response = await apiClient.get(
      ApiConfig.goldsBalance,
      forceRefresh: true,
    );
    final data = response['data'];
    return data is Map ? (data['balance'] as num?)?.toInt() ?? 0 : 0;
  }

  Future<int> tip({
    required String recipientId,
    required int amount,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await apiClient.post(
      ApiConfig.goldsTips,
      body: {
        'recipientId': recipientId,
        'amount': amount,
        ...?(metadata == null ? null : <String, dynamic>{'metadata': metadata}),
      },
    );
    final data = response['data'];
    if (response['success'] != true || data is! Map) {
      throw StateError(
        response['message']?.toString() ?? 'Unable to send Griot Golds',
      );
    }
    return (data['balance'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> purchasePlus({required String productId}) async {
    final response = await apiClient.post(
      ApiConfig.goldsPlus,
      body: {'productId': productId},
    );
    final data = response['data'];
    if (response['success'] != true || data is! Map) {
      throw StateError(
        response['message']?.toString() ??
            'Unable to activate Griot Plus with Golds',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  Future<int> verifyApplePurchase({
    required String productId,
    required String transactionId,
    required String receipt,
  }) async {
    final response = await apiClient.post(
      ApiConfig.goldsAppleVerify,
      body: {
        'productId': productId,
        'transactionId': transactionId,
        'receipt': receipt,
      },
    );
    final data = response['data'];
    if (response['success'] != true || data is! Map) {
      throw StateError(
        response['message']?.toString() ?? 'Gold purchase verification failed',
      );
    }
    return (data['balance'] as num?)?.toInt() ?? 0;
  }

  Future<int> verifyGooglePurchase({
    required String productId,
    required String purchaseToken,
  }) async {
    final response = await apiClient.post(
      ApiConfig.goldsGoogleVerify,
      body: {'productId': productId, 'purchaseToken': purchaseToken},
    );
    final data = response['data'];
    if (response['success'] != true || data is! Map) {
      throw StateError(
        response['message']?.toString() ?? 'Gold purchase verification failed',
      );
    }
    return (data['balance'] as num?)?.toInt() ?? 0;
  }
}
