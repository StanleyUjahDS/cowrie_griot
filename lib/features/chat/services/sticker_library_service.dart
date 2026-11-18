import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../../core/network/api_config.dart';
import '../../auth/services/auth_storage_service.dart';

class StickerAsset {
  final String id;
  final String path;
  final bool isVideo;
  final DateTime createdAt;

  const StickerAsset({
    required this.id,
    required this.path,
    required this.isVideo,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'isVideo': isVideo,
    'createdAt': createdAt.toIso8601String(),
  };

  factory StickerAsset.fromJson(Map<String, dynamic> json) => StickerAsset(
    id: json['id']?.toString() ?? '',
    path: json['path']?.toString() ?? '',
    isVideo: json['isVideo'] == true,
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
  );
}

/// Stores user-created stickers in the app documents directory. The local
/// file is used for instant reuse; sending still uploads through the normal
/// media pipeline so recipients receive a server-backed message.
class StickerLibraryService {
  StickerLibraryService._();
  static final instance = StickerLibraryService._();

  List<StickerAsset>? _cache;

  Future<Directory> _directory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/griot_stickers');
    if (!directory.existsSync()) await directory.create(recursive: true);
    return directory;
  }

  Future<File> _indexFile() async {
    final directory = await _directory();
    return File('${directory.path}/index.json');
  }

  Future<List<StickerAsset>> list() async {
    if (_cache != null) {
      return List<StickerAsset>.unmodifiable(_cache!);
    }
    final index = await _indexFile();
    if (!index.existsSync()) return _cache = <StickerAsset>[];
    try {
      final raw = jsonDecode(await index.readAsString());
      final assets = <StickerAsset>[];
      if (raw is List) {
        for (final item in raw.whereType<Map>()) {
          final asset = StickerAsset.fromJson(Map<String, dynamic>.from(item));
          if (!File(asset.path).existsSync()) continue;
          // Do not re-encode every sticker when the tray opens. Re-encoding
          // PNG artwork as GIF loses colour depth and makes it look blurry.
          assets.add(asset);
        }
      }
      _cache = assets;
      await _saveIndex();
      return _cache!;
    } catch (_) {
      return _cache = <StickerAsset>[];
    }
  }

  Future<StickerAsset> add(String sourcePath, {required bool isVideo}) async {
    final source = File(sourcePath);
    if (!source.existsSync()) throw Exception('Sticker file is not available.');
    final directory = await _directory();
    final id = 'sticker_${DateTime.now().microsecondsSinceEpoch}';
    final sourceExtension = source.path.contains('.')
        ? source.path.substring(source.path.lastIndexOf('.')).toLowerCase()
        : '';
    final sourceBytes = !isVideo ? await source.readAsBytes() : null;
    final decodedSource = sourceBytes == null
        ? null
        : img.decodeImage(sourceBytes);
    final isAnimatedPng =
        !isVideo &&
        sourceExtension == '.png' &&
        decodedSource?.hasAnimation == true;
    final isGif = !isVideo && sourceExtension == '.gif';
    final extension = isVideo
        ? (sourceExtension.isEmpty ? '.mp4' : sourceExtension)
        : (isGif ? '.gif' : '.png');
    final destination = File('${directory.path}/$id$extension');
    if (isVideo || isGif || isAnimatedPng) {
      // Short videos are duration-limited at capture time. Keep the original
      // codec so stickers remain playable across iOS and Android.
      await source.copy(destination.path);
    } else {
      // Keep still stickers lossless. The cropper has already framed these
      // as squares, so PNG gives much better quality than a GIF palette.
      final decoded = decodedSource;
      if (decoded == null) throw Exception('Sticker image could not be read.');
      final side = decoded.width < decoded.height
          ? decoded.width
          : decoded.height;
      final square = img.copyCrop(
        decoded,
        x: (decoded.width - side) ~/ 2,
        y: (decoded.height - side) ~/ 2,
        width: side,
        height: side,
      );
      await destination.writeAsBytes(img.encodePng(square), flush: true);
    }
    final asset = StickerAsset(
      id: id,
      path: destination.path,
      isVideo: isVideo,
      createdAt: DateTime.now(),
    );
    final assets = await list();
    _cache = [asset, ...assets];
    await _saveIndex();
    return asset;
  }

  /// Downloads a sticker received in chat and adds it to this device's
  /// private sticker collection. The remote message is never modified.
  Future<StickerAsset> addFromUrl(String url, {required bool isVideo}) async {
    final resolved = url.startsWith('http://') || url.startsWith('https://')
        ? url
        : '${ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '')}$url';
    final accessToken = await AuthStorageService().getAccessToken();
    final response = await http.get(
      Uri.parse(resolved),
      headers: accessToken == null || accessToken.isEmpty
          ? null
          : {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Sticker download failed (${response.statusCode}).');
    }
    final temporaryDirectory = await getTemporaryDirectory();
    final uriPath = Uri.parse(resolved).path;
    final responseType = response.headers['content-type']
        ?.split(';')
        .first
        .trim();
    final extension = path.extension(uriPath).isEmpty
        ? (isVideo
              ? '.mp4'
              : responseType == 'image/png'
              ? '.png'
              : '.gif')
        : path.extension(uriPath);
    final temporaryFile = File(
      path.join(
        temporaryDirectory.path,
        'griot_received_sticker_${DateTime.now().microsecondsSinceEpoch}$extension',
      ),
    );
    await temporaryFile.writeAsBytes(response.bodyBytes, flush: true);
    try {
      return await add(temporaryFile.path, isVideo: isVideo);
    } finally {
      if (temporaryFile.existsSync()) await temporaryFile.delete();
    }
  }

  Future<void> remove(StickerAsset asset) async {
    final assets = await list();
    _cache = assets.where((item) => item.id != asset.id).toList();
    final file = File(asset.path);
    if (file.existsSync()) await file.delete();
    await _saveIndex();
  }

  Future<void> _saveIndex() async {
    final index = await _indexFile();
    await index.writeAsString(
      jsonEncode(_cache!.map((item) => item.toJson()).toList()),
    );
  }
}
