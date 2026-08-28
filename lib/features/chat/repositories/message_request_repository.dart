import '../models/message_request.dart';
import '../services/messaging_api_service.dart';
import '../../../core/network/api_client.dart';

class MessageRequestOperations {
  final MessagingApiService _apiService;

  MessageRequestOperations({MessagingApiService? apiService, ApiClient? apiClient})
      : _apiService = apiService ?? MessagingApiService(apiClient: apiClient ?? ApiClient());

  // ==========================================================
  // GET ALL REQUESTS
  // ==========================================================

  Future<List<MessageRequest>> getRequests() async {
    final received = await _apiService.getReceivedRequests();
    final sent = await _apiService.getSentRequests();
    return [...received, ...sent];
  }

  // ==========================================================
  // COMPATIBILITY METHOD
  // ==========================================================

  Future<List<MessageRequest>> getMessageRequests() async {
    return getRequests();
  }

  // ==========================================================
  // GET RECEIVED REQUESTS
  // ==========================================================

  Future<List<MessageRequest>> getReceivedRequests() async {
    return _apiService.getReceivedRequests();
  }

  // ==========================================================
  // GET SENT REQUESTS
  // ==========================================================

  Future<List<MessageRequest>> getSentRequests() async {
    return _apiService.getSentRequests();
  }

  // ==========================================================
  // SEND REQUEST
  // ==========================================================

  Future<MessageRequest> sendRequest({
    required String recipientId,
  }) async {
    return _apiService.sendDirectMessageRequest(recipientId);
  }

  // ==========================================================
  // ACCEPT REQUEST
  // ==========================================================

  Future<void> acceptRequest(String requestId) async {
    await _apiService.acceptRequest(requestId);
  }

  // ==========================================================
  // DECLINE REQUEST
  // ==========================================================

  Future<void> declineRequest(String requestId) async {
    await _apiService.declineRequest(requestId);
  }

  // ==========================================================
  // CANCEL REQUEST (WITHDRAW)
  // ==========================================================

  Future<void> cancelRequest(String requestId) async {
    await _apiService.withdrawRequest(requestId);
  }
}
