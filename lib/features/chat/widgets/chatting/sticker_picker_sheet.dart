import 'dart:io';

import 'package:flutter/material.dart';
import '../../../../core/services/notification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../services/sticker_library_service.dart';
import 'sticker_video_editor.dart';

class StickerPickerSheet extends StatefulWidget {
  final Future<void> Function(StickerAsset asset) onSelected;

  const StickerPickerSheet({super.key, required this.onSelected});

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(StickerAsset asset) onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StickerPickerSheet(onSelected: onSelected),
    );
  }

  @override
  State<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<StickerPickerSheet> {
  final _library = StickerLibraryService.instance;
  List<StickerAsset> _assets = const [];
  bool _loading = true;
  bool _deleteMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final assets = await _library.list();
    if (mounted) {
      setState(() {
        _assets = assets;
        _loading = false;
      });
    }
  }

  Future<void> _createSticker() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Create from image'),
              onTap: () => Navigator.pop(sheetContext, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Create from short video'),
              onTap: () => Navigator.pop(sheetContext, 'video'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final picker = ImagePicker();
    final picked = choice == 'video'
        ? await picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(seconds: 30),
          )
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (!mounted || picked == null) return;
    try {
      var sourcePath = picked.path;
      if (choice == 'video') {
        final trimmedPath = await StickerVideoEditor.show(
          context,
          File(picked.path),
        );
        if (!mounted || trimmedPath == null) return;
        sourcePath = trimmedPath;
      } else {
        // Stickers look best when the artwork is framed consistently. Let the
        // user position the subject in a square crop before compression.
        final cropped = await _cropStickerImage(sourcePath);
        if (!mounted || cropped == null) return;
        sourcePath = cropped.path;
      }
      // Animated stickers are stored as lossless animated PNGs so the chat
      // renderer can autoplay them inline without GIF colour banding.
      await _library.add(sourcePath, isVideo: false);
      await _load();
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not save sticker: $error',
        );
      }
    }
  }

  Future<CroppedFile?> _cropStickerImage(String sourcePath) {
    final colors = Theme.of(context).colorScheme;
    return ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressFormat: ImageCompressFormat.png,
      compressQuality: 95,
      maxWidth: 1200,
      maxHeight: 1200,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Frame sticker',
          toolbarColor: colors.surface,
          toolbarWidgetColor: colors.onSurface,
          activeControlsWidgetColor: colors.primary,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Frame sticker',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );
  }

  Future<void> _select(StickerAsset asset) async {
    Navigator.of(context).pop();
    await widget.onSelected(asset);
  }

  Future<void> _delete(StickerAsset asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete sticker?'),
        content: const Text('This removes the sticker from your device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _library.remove(asset);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .48,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Stickers',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _deleteMode ? 'Done' : 'Delete stickers',
                    onPressed: () => setState(() => _deleteMode = !_deleteMode),
                    icon: Icon(
                      _deleteMode
                          ? Icons.done_rounded
                          : Icons.delete_outline_rounded,
                    ),
                  ),
                  IconButton(
                    onPressed: _createSticker,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    tooltip: 'Create sticker',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _assets.isEmpty
                    ? Center(
                        child: Text(
                          'Create a sticker from an image or short video.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                        itemCount: _assets.length,
                        itemBuilder: (context, index) {
                          final asset = _assets[index];
                          return InkWell(
                            onTap: _deleteMode
                                ? () => _delete(asset)
                                : () => _select(asset),
                            onLongPress: () => _delete(asset),
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest
                                        .withValues(alpha: .55),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: colors.outline.withValues(
                                        alpha: .10,
                                      ),
                                    ),
                                  ),
                                  child: asset.isVideo
                                      ? Icon(
                                          Icons.play_circle_fill_rounded,
                                          size: 34,
                                          color: colors.primary,
                                        )
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Image.file(
                                            File(asset.path),
                                            fit: BoxFit.contain,
                                            filterQuality: FilterQuality.medium,
                                          ),
                                        ),
                                ),
                                if (_deleteMode)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Material(
                                      color: colors.error,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () => _delete(asset),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 19,
                                          color: colors.onError,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
