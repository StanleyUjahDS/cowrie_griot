import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

class MediaApiService {
  final ApiClient _apiClient;

  MediaApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<Map<String, dynamic>> uploadMedia(String filePath, {String? conversationId}) async {
    final file = File(filePath);
    final filename = path.basename(filePath);
    final sizeBytes = await file.length();
    final contentType = _getContentType(filePath);

    // 1. Presign
    final presignResponse = await _apiClient.post(ApiConfig.mediaPresign, body: {
      'filename': filename,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
      ...?conversationId == null ? null : {'conversationId': conversationId},
    });

    final presignData = _getData(presignResponse);
    final mediaId = presignData['id'].toString();
    final uploadUrl = presignData['uploadUrl'].toString();

    // 2. Upload to S3 (Raw PUT)
    final fileBytes = await file.readAsBytes();
    final putResponse = await http.put(
      Uri.parse(uploadUrl),
      body: fileBytes,
      headers: {
        'Content-Type': contentType,
      },
    );

    if (putResponse.statusCode < 200 || putResponse.statusCode >= 300) {
      throw Exception('S3 Upload failed: ${putResponse.statusCode}');
    }

    // 3. Complete
    final completeResponse = await _apiClient.post(ApiConfig.mediaComplete(mediaId));
    final completeData = _getData(completeResponse);

    return {
      'id': mediaId,
      'mediaUrl': completeData['mediaUrl'].toString(),
    };
  }

  String _getContentType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.mp4':
        return 'video/mp4';
      case '.mp3':
        return 'audio/mpeg';
      case '.m4a':
        return 'audio/mp4';
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  dynamic _getData(dynamic response) {
    if (response is Map<String, dynamic>) {
      if (response.containsKey('success')) {
        if (response['success'] == true) {
          return response['data'];
        }
        throw Exception(response['message'] ?? 'Request failed');
      }
    }
    return response;
  }
}
