// lib/features/settings/screens/account/widgets/profile_avatar.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/ui/widgets/griot_loader.dart';
import '../../../../../core/ui/widgets/griot_avatar.dart';
import '../../../../../core/services/notification_service.dart';

class ProfileAvatar extends StatefulWidget {
  final String? avatarUrl;

  /// Called only after the user confirms the new image.
  ///
  /// The image is NOT uploaded automatically when selected.
  final Future Function(File image)? onImageSelected;

  const ProfileAvatar({
    super.key,
    this.avatarUrl,
    this.onImageSelected,
  });

  @override
  State<ProfileAvatar> createState() =>
      _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  final ImagePicker _picker = ImagePicker();

  File? _pendingImage;

  /// The image currently being displayed locally after
  /// the user confirms the new photo.
  File? _savedLocalImage;

  bool _isPicking = false;
  bool _isSaving = false;

  // ============================================================
  // DEFAULT PROFILE IMAGE
  // ============================================================

  static const String _defaultProfileImage =
      'assets/chains/Hbadger.svg';

  // ============================================================
  // HAS PENDING IMAGE
  // ============================================================

  bool get _hasPendingImage =>
      _pendingImage != null;

  // ============================================================
  // OPEN PROFILE PHOTO OPTIONS
  // ============================================================

  Future<void> _openPhotoOptions() async {
    if (_isPicking || _isSaving) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(
              18,
              12,
              18,
              18,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.10),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ==================================================
                // HANDLE
                // ==================================================

                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.25),
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // TITLE
                // ==================================================

                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorScheme.primary
                            .withValues(alpha: 0.09),
                        borderRadius:
                        BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.account_circle_outlined,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Profile Photo',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ==================================================
                // VIEW PHOTO
                // ==================================================

                _option(
                  context: sheetContext,
                  icon: Icons.visibility_outlined,
                  title: 'View profile photo',
                  subtitle: 'See your current photo',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _viewPhoto();
                  },
                ),

                const SizedBox(height: 8),

                // ==================================================
                // CHANGE PHOTO
                // ==================================================

                _option(
                  context: sheetContext,
                  icon: Icons.photo_library_outlined,
                  title: 'Change profile photo',
                  subtitle: 'Choose a new photo',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage();
                  },
                ),

                if (_hasPendingImage) ...[
                  const SizedBox(height: 8),

                  _option(
                    context: sheetContext,
                    icon: Icons.undo_rounded,
                    title: 'Discard new photo',
                    subtitle: 'Keep your current photo',
                    destructive: true,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _discardPendingImage();
                    },
                  ),
                ],

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // OPTION
  // ============================================================

  Widget _option({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final color = destructive
        ? colorScheme.error
        : colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 10,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(
                        color:
                        colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.65),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // VIEW PHOTO
  // ============================================================

  void _viewPhoto() {
    final image =
        _pendingImage ?? _savedLocalImage;

    final hasUrl =
        widget.avatarUrl != null &&
            widget.avatarUrl!.trim().isNotEmpty;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.90),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius:
                  BorderRadius.circular(22),
                  child: image != null
                      ? Image.file(
                    image,
                    fit: BoxFit.contain,
                  )
                      : hasUrl
                      ? Image.network(
                    widget.avatarUrl!,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (
                        context,
                        error,
                        stackTrace,
                        ) {
                      return SvgPicture.asset(
                        _defaultProfileImage,
                        fit: BoxFit.contain,
                      );
                    },
                  )
                      : SvgPicture.asset(
                    _defaultProfileImage,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // ==================================================
              // CLOSE
              // ==================================================

              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder:
                    const CircleBorder(),
                    onTap: () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> _pickImage() async {
    if (_isPicking || _isSaving) {
      return;
    }

    setState(() {
      _isPicking = true;
    });

    try {
      final XFile? pickedFile =
      await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (pickedFile == null) {
        return;
      }

      final CroppedFile? croppedFile =
      await _cropImage(
        pickedFile.path,
      );

      if (croppedFile == null) {
        return;
      }

      final File image =
      File(croppedFile.path);

      if (!mounted) {
        return;
      }

      // ========================================================
      // KEEP AS PENDING ONLY
      // ========================================================

      setState(() {
        _pendingImage = image;
      });

      await _showPendingImageActions();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  // ============================================================
  // CROP IMAGE
  // ============================================================

  Future<CroppedFile?> _cropImage(
      String imagePath,
      ) async {
    final colorScheme =
        Theme.of(context).colorScheme;

    return ImageCropper().cropImage(
      sourcePath: imagePath,
      compressFormat:
      ImageCompressFormat.jpg,
      compressQuality: 90,
      maxWidth: 1000,
      maxHeight: 1000,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle:
          'Adjust Profile Photo',
          toolbarColor:
          colorScheme.surface,
          toolbarWidgetColor:
          colorScheme.onSurface,
          activeControlsWidgetColor:
          colorScheme.primary,
          initAspectRatio:
          CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title:
          'Adjust Profile Photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );
  }

  // ============================================================
  // PENDING IMAGE ACTIONS
  // ============================================================

  Future<void>
  _showPendingImageActions() async {
    if (!mounted ||
        _pendingImage == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme =
        Theme.of(sheetContext);

        final colorScheme =
            theme.colorScheme;

        return SafeArea(
          child: Container(
            margin:
            const EdgeInsets.all(12),
            padding:
            const EdgeInsets.fromLTRB(
              18,
              12,
              18,
              18,
            ),
            decoration:
            BoxDecoration(
              color:
              colorScheme.surface,
              borderRadius:
              BorderRadius.circular(
                28,
              ),
            ),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration:
                  BoxDecoration(
                    color: colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.25),
                    borderRadius:
                    BorderRadius.circular(
                      20,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                Text(
                  'New Profile Photo',
                  style: theme
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 6,
                ),

                Text(
                  'This photo has not been saved yet.',
                  textAlign:
                  TextAlign.center,
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: colorScheme
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                // ==================================================
                // PREVIEW
                // ==================================================

                Container(
                  width: 110,
                  height: 110,
                  padding:
                  const EdgeInsets.all(3),
                  decoration:
                  BoxDecoration(
                    shape:
                    BoxShape.circle,
                    gradient:
                    LinearGradient(
                      colors: [
                        colorScheme
                            .primary,
                        colorScheme
                            .primary
                            .withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                  child: ClipOval(
                    child:
                    Image.file(
                      _pendingImage!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                // ==================================================
                // SAVE
                // ==================================================

                SizedBox(
                  width:
                  double.infinity,
                  height: 52,
                  child:
                  FilledButton(
                    onPressed:
                    _isSaving
                        ? null
                        : () async {
                      Navigator.pop(
                        sheetContext,
                      );

                      await _savePendingImage();
                    },
                    child: _isSaving
                        ? const GriotLoader(
                            size: 22,
                            strokeWidth: 2.3,
                            color: Colors.white,
                          )
                        : const Text(
                      'Use This Photo',
                      style:
                      TextStyle(
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                // ==================================================
                // DISCARD
                // ==================================================

                SizedBox(
                  width:
                  double.infinity,
                  height: 48,
                  child:
                  TextButton(
                    onPressed: () {
                      Navigator.pop(
                        sheetContext,
                      );

                      _discardPendingImage();
                    },
                    child:
                    const Text(
                      'Discard',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // SAVE PENDING IMAGE
  // ============================================================

  Future<void> _savePendingImage() async {
    final image =
        _pendingImage;

    if (image == null ||
        _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.onImageSelected != null) {
        await widget.onImageSelected!(
          image,
        );
      }

      if (!mounted) {
        return;
      }

      // ========================================================
      // IMPORTANT:
      //
      // Keep the confirmed image locally so it remains visible
      // immediately even before the backend returns the new URL.
      // ========================================================

      setState(() {
        _savedLocalImage = image;
        _pendingImage = null;
      });

      NotificationService.showSuccess(context, 'Profile photo updated');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // DISCARD
  // ============================================================

  void _discardPendingImage() {
    if (!mounted) {
      return;
    }

    setState(() {
      _pendingImage = null;
    });
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(Object error) {
    NotificationService.showError(context, _cleanError(error));
  }

  String _cleanError(Object error) {
    final message =
    error.toString();

    if (message.startsWith(
      'Exception: ',
    )) {
      return message.substring(11);
    }

    return message;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    return Center(
      child: GestureDetector(
        onTap:
        _openPhotoOptions,
        child: Stack(
          alignment:
          Alignment.bottomRight,
          children: [
            // ==================================================
            // AVATAR
            // ==================================================

            Container(
              width: 100,
              height: 100,
              padding:
              const EdgeInsets.all(2),
              decoration:
              BoxDecoration(
                shape:
                BoxShape.circle,
                gradient:
                LinearGradient(
                  begin:
                  Alignment.topLeft,
                  end:
                  Alignment.bottomRight,
                  colors: [
                    colorScheme
                        .primary
                        .withValues(alpha: 0.30),
                    colorScheme
                        .primary
                        .withValues(alpha: 0.08),
                  ],
                ),
              ),
              child: Container(
                decoration:
                BoxDecoration(
                  shape:
                  BoxShape.circle,
                  color:
                  colorScheme.surface,
                ),
                child:
                ClipOval(
                  child: _isPicking
                      ? const Center(
                    child:
                    GriotLoader(
                      size: 28,
                      strokeWidth: 2.5,
                    ),
                  )
                      : _pendingImage != null 
                        ? Image.file(_pendingImage!, fit: BoxFit.cover)
                        : _savedLocalImage != null
                          ? Image.file(_savedLocalImage!, fit: BoxFit.cover)
                          : GriotAvatar(
                              avatarUrl: widget.avatarUrl,
                              radius: 50,
                              backgroundColor: Colors.transparent,
                            ),
                ),
              ),
            ),

            // ==================================================
            // CAMERA BUTTON
            // ==================================================

            Container(
              width: 32,
              height: 32,
              decoration:
              BoxDecoration(
                color:
                colorScheme.primary,
                shape:
                BoxShape.circle,
                border:
                Border.all(
                  color: theme
                      .scaffoldBackgroundColor,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors
                        .black
                        .withValues(alpha: 0.16),
                    blurRadius: 8,
                    offset:
                    const Offset(
                      0,
                      3,
                    ),
                  ),
                ],
              ),
              child: Icon(
                Icons
                    .camera_alt_rounded,
                size: 15,
                color:
                colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}