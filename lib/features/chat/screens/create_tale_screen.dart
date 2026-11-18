import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:any_link_preview/any_link_preview.dart';

import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_avatar.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';
import '../../../core/services/notification_service.dart';
import '../services/messaging_api_service.dart';
import '../services/media_api_service.dart';
import '../widgets/chatting/link_preview_widget.dart';
import '../../iap/providers/iap_provider.dart';
import '../../users/providers/user_provider.dart';
import '../../users/models/user_model.dart';
import '../../users/services/user_api_service.dart';

class _TaleMedia {
  _TaleMedia({required this.path});

  final String path;
  String? url;
  String? type;
}

/// Styles mentions and hashtags while a Tale is being composed.
/// The controller still stores plain text, so the API payload is unchanged.
class _MentionTextEditingController extends TextEditingController {
  Color mentionColor = Colors.blue;
  Color hashtagColor = Colors.teal;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final mentionStyle = baseStyle.copyWith(
      color: mentionColor,
      fontWeight: FontWeight.w700,
    );
    final hashtagStyle = baseStyle.copyWith(
      color: hashtagColor,
      fontWeight: FontWeight.w700,
    );
    final spans = <TextSpan>[];
    final tokenRegex = RegExp(
      r'(?<![A-Za-z0-9_.-])(?:@[A-Za-z0-9_.-]+|#[A-Za-z0-9_-]+)',
    );
    var lastEnd = 0;
    for (final match in tokenRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final token = match.group(0)!;
      spans.add(
        TextSpan(
          text: token,
          style: token.startsWith('@') ? mentionStyle : hashtagStyle,
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: text));
    return TextSpan(style: baseStyle, children: spans);
  }
}

class CreateTaleScreen extends StatefulWidget {
  const CreateTaleScreen({
    super.key,
    this.draftId,
    this.initialText,
    this.initialThreadId,
    this.initialRetellOfTaleId,
    this.initialReferenceText,
    this.initialReferenceLabel,
    this.initialReferenceMediaUrls = const [],
    this.composerTitle,
  });

  final String? draftId;
  final String? initialText;
  final String? initialThreadId;
  final String? initialRetellOfTaleId;
  final String? initialReferenceText;
  final String? initialReferenceLabel;
  final List<String> initialReferenceMediaUrls;
  final String? composerTitle;

  @override
  State<CreateTaleScreen> createState() => _CreateTaleScreenState();
}

class _CreateTaleScreenState extends State<CreateTaleScreen>
    with TickerProviderStateMixin {
  static const _draftStorageKey = 'griot_tale_composer_drafts_v2';
  static const _legacyDraftStorageKey = 'griot_tale_composer_draft_v1';
  static const _freePartLimit = 500;
  static const _plusPartLimit = 2000;
  static const _categories = <String>[
    'Personal',
    'Finance',
    'Technology',
    'Health',
    'Education',
    'Lessons',
    'Culture',
    'Community',
    'Ideas',
    'History',
  ];

  final List<TextEditingController> _threadControllers = [
    _MentionTextEditingController(),
  ];
  final List<FocusNode> _threadFocusNodes = [FocusNode()];
  final List<List<_TaleMedia>> _threadMedia = [[]];
  final ImagePicker _imagePicker = ImagePicker();
  String _category = 'Personal';
  String _audience = 'public';
  int _activePartIndex = 0;
  bool _uploadingMedia = false;
  int? _uploadingPartIndex;
  bool _publishing = false;
  Timer? _draftSaveTimer;
  Timer? _mentionSearchTimer;
  Timer? _linkMetadataTimer;
  Metadata? _linkMetadata;
  String? _linkMetadataUrl;
  List<UserModel> _inlineMentionUsers = const [];
  bool _inlineMentionLoading = false;
  int? _inlineMentionPartIndex;
  String _inlineMentionQuery = '';
  bool _restoringDraft = false;
  String? _draftId;
  late final String? _initialThreadId;
  late final String? _initialRetellOfTaleId;

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftId;
    _initialThreadId = widget.initialThreadId;
    _initialRetellOfTaleId = widget.initialRetellOfTaleId;
    if (widget.draftId == null && widget.initialText != null) {
      _threadControllers.first.text = widget.initialText!;
    }
    for (final controller in _threadControllers) {
      controller.addListener(_scheduleDraftSave);
    }
    unawaited(_restoreDraft());
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _mentionSearchTimer?.cancel();
    _linkMetadataTimer?.cancel();
    for (final controller in _threadControllers) {
      controller.removeListener(_scheduleDraftSave);
      controller.dispose();
    }
    for (final focusNode in _threadFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _addThreadSegment() {
    if (_threadControllers.length >= 10) return;
    final controller = _MentionTextEditingController();
    controller.addListener(_scheduleDraftSave);
    setState(() {
      _threadControllers.add(controller);
      _threadFocusNodes.add(FocusNode());
      _threadMedia.add([]);
      _activePartIndex = _threadControllers.length - 1;
    });
  }

  void _removeThreadSegment(int index) {
    if (_threadControllers.length <= 1 ||
        index <= 0 ||
        index >= _threadControllers.length) {
      return;
    }
    final controller = _threadControllers.removeAt(index);
    controller.dispose();
    final focusNode = _threadFocusNodes.removeAt(index);
    focusNode.dispose();
    _threadMedia.removeAt(index);
    if (_activePartIndex >= _threadControllers.length) {
      _activePartIndex = _threadControllers.length - 1;
    }
    setState(() {});
    _scheduleDraftSave();
  }

  Future<void> _restoreDraft() async {
    _restoringDraft = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(_draftStorageKey);
      if (raw == null || raw.isEmpty) {
        final legacy = prefs.getString(_legacyDraftStorageKey);
        if (legacy != null && legacy.isNotEmpty) {
          final legacyDecoded = jsonDecode(legacy);
          if (legacyDecoded is Map) {
            final migrated = {
              'id': 'legacy-${DateTime.now().microsecondsSinceEpoch}',
              ...Map<String, dynamic>.from(legacyDecoded),
            };
            raw = jsonEncode([migrated]);
            await prefs.setString(_draftStorageKey, raw);
            await prefs.remove(_legacyDraftStorageKey);
          }
        }
      }
      if (raw == null || raw.isEmpty || widget.draftId == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final drafts = decoded
          .whereType<Map>()
          .map((draft) => Map<String, dynamic>.from(draft))
          .toList(growable: false);
      final selected = drafts.cast<Map<String, dynamic>?>().firstWhere(
        (draft) => draft?['id']?.toString() == widget.draftId,
        orElse: () => null,
      );
      if (selected == null) return;
      _draftId = selected['id']?.toString();
      final decodedDraft = selected;
      final parts = (decodedDraft['parts'] as List?)
          ?.map((part) => part.toString())
          .where((part) => part.trim().isNotEmpty)
          .take(10)
          .toList();
      if (parts == null || parts.isEmpty || !mounted) return;
      for (final controller in _threadControllers) {
        controller.removeListener(_scheduleDraftSave);
      }
      for (var index = 1; index < parts.length; index++) {
        _threadControllers.add(_MentionTextEditingController());
        _threadFocusNodes.add(FocusNode());
        _threadMedia.add([]);
      }
      for (var index = 0; index < parts.length; index++) {
        _threadControllers[index].text = parts[index];
        _threadControllers[index].addListener(_scheduleDraftSave);
      }
      _audience = decodedDraft['audience']?.toString() == 'following'
          ? 'following'
          : 'public';
      final savedCategory = decodedDraft['category']?.toString();
      if (savedCategory != null && _categories.contains(savedCategory)) {
        _category = savedCategory;
      }
      _activePartIndex = parts.length - 1;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          NotificationService.showInfo(
            context,
            'Your Tale draft was restored.',
          );
        }
      });
    } catch (_) {
      // A corrupt draft should never prevent the composer from opening.
    } finally {
      _restoringDraft = false;
    }
  }

  void _scheduleDraftSave() {
    if (_restoringDraft || !mounted) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_saveDraft()),
    );
  }

  Future<void> _saveDraft() async {
    final parts = _threadControllers
        .map((controller) => controller.text)
        .toList(growable: false);
    final hasText = parts.any((part) => part.trim().isNotEmpty);
    final prefs = await SharedPreferences.getInstance();
    if (!hasText) return;
    _draftId ??= 'draft-${DateTime.now().microsecondsSinceEpoch}';
    final raw = prefs.getString(_draftStorageKey);
    final drafts = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          drafts.addAll(
            decoded.whereType<Map>().map(
              (draft) => Map<String, dynamic>.from(draft),
            ),
          );
        }
      } catch (_) {}
    }
    final payload = <String, dynamic>{
      'id': _draftId,
      'parts': parts,
      'audience': _audience,
      'category': _category,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    final index = drafts.indexWhere((draft) => draft['id'] == _draftId);
    if (index >= 0) {
      drafts[index] = payload;
    } else {
      drafts.insert(0, payload);
    }
    await prefs.setString(_draftStorageKey, jsonEncode(drafts));
  }

  Future<void> _clearDraft() async {
    _draftSaveTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftStorageKey);
    if (raw == null || raw.isEmpty || _draftId == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final drafts = decoded
            .whereType<Map>()
            .map((draft) => Map<String, dynamic>.from(draft))
            .where((draft) => draft['id'] != _draftId)
            .toList();
        if (drafts.isEmpty) {
          await prefs.remove(_draftStorageKey);
        } else {
          await prefs.setString(_draftStorageKey, jsonEncode(drafts));
        }
      }
    } catch (_) {}
  }

  Future<void> _closeComposer() async {
    final hasDraft = _threadControllers.any(
      (controller) => controller.text.trim().isNotEmpty,
    );
    if (!hasDraft) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final action = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .58),
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: GriotBrandedContainer(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            borderRadius: 26,
            blurSigma: 18,
            backgroundColor: colors.surface.withValues(alpha: .96),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: colors.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Leave this Tale?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Keep writing',
                      onPressed: () => Navigator.pop(dialogContext, 'keep'),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Save your progress as a draft or discard what you have written.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(dialogContext, 'save'),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Save to drafts'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(dialogContext, 'discard'),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.error,
                    ),
                    label: Text(
                      'Discard draft',
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == 'keep' || action == null) return;
    if (action == 'save') {
      await _saveDraft();
    } else if (action == 'discard') {
      await _clearDraft();
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _insertToken(String token) {
    final controller =
        _threadControllers[_activePartIndex.clamp(
          0,
          _threadControllers.length - 1,
        )];
    final selection = controller.selection;
    final start = selection.isValid && selection.start >= 0
        ? selection.start
        : controller.text.length;
    final end = selection.isValid && selection.end >= 0 ? selection.end : start;
    controller.value = controller.value.copyWith(
      text:
          '${controller.text.substring(0, start)}$token${controller.text.substring(end)}',
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  void _handleEditorChanged(int index, String text) {
    _scheduleDraftSave();
    if (index == 0) _scheduleLinkMetadata(text);
    if (index >= _threadControllers.length) return;
    final controller = _threadControllers[index];
    final cursor = controller.selection.isValid
        ? controller.selection.baseOffset
        : text.length;
    final beforeCursor = text.substring(0, cursor.clamp(0, text.length));
    final match = RegExp(
      r'(?:^|\s)@([A-Za-z0-9_.-]*)$',
    ).firstMatch(beforeCursor);
    if (match == null) {
      _clearInlineMentionSuggestions();
      return;
    }
    final query = match.group(1) ?? '';
    _mentionSearchTimer?.cancel();
    if (query.isEmpty) {
      _clearInlineMentionSuggestions();
      return;
    }
    setState(() {
      _inlineMentionPartIndex = index;
      _inlineMentionQuery = query;
      _inlineMentionLoading = true;
    });
    _mentionSearchTimer = Timer(const Duration(milliseconds: 280), () async {
      try {
        final response = await context.read<UserApiService>().searchUsers(
          query,
          limit: 8,
        );
        if (!mounted || _inlineMentionQuery != query) return;
        setState(() {
          _inlineMentionUsers = List<UserModel>.from(
            response['users'] as List? ?? const [],
          );
          _inlineMentionLoading = false;
        });
      } catch (_) {
        if (!mounted || _inlineMentionQuery != query) return;
        setState(() {
          _inlineMentionUsers = const [];
          _inlineMentionLoading = false;
        });
      }
    });
  }

  void _scheduleLinkMetadata(String text) {
    final link = _extractUrl(text);
    _linkMetadataTimer?.cancel();
    if (link == null) {
      if (_linkMetadata != null || _linkMetadataUrl != null) {
        setState(() {
          _linkMetadata = null;
          _linkMetadataUrl = null;
        });
      }
      return;
    }
    if (_linkMetadataUrl == link) return;
    _linkMetadataTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final metadata = await AnyLinkPreview.getMetadata(link: link);
        if (!mounted || _extractUrl(_threadControllers.first.text) != link) {
          return;
        }
        setState(() {
          _linkMetadata = metadata;
          _linkMetadataUrl = link;
        });
      } catch (_) {
        // A site that blocks metadata requests must not interrupt composing.
        if (!mounted || _extractUrl(_threadControllers.first.text) != link) {
          return;
        }
        setState(() {
          _linkMetadata = null;
          _linkMetadataUrl = link;
        });
      }
    });
  }

  void _clearInlineMentionSuggestions() {
    if (_inlineMentionPartIndex == null &&
        _inlineMentionUsers.isEmpty &&
        !_inlineMentionLoading) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _inlineMentionPartIndex = null;
      _inlineMentionQuery = '';
      _inlineMentionUsers = const [];
      _inlineMentionLoading = false;
    });
  }

  void _selectInlineMention(UserModel user) {
    final index = _inlineMentionPartIndex;
    final username = user.username?.trim();
    if (index == null || username == null || username.isEmpty) return;
    final controller = _threadControllers[index];
    final cursor = controller.selection.isValid
        ? controller.selection.baseOffset
        : controller.text.length;
    final beforeCursor = controller.text.substring(0, cursor);
    final match = RegExp(r'@([A-Za-z0-9_.-]*)$').firstMatch(beforeCursor);
    if (match == null) return;
    final start = match.start;
    final replacement = '@$username ';
    controller.value = controller.value.copyWith(
      text:
          '${controller.text.substring(0, start)}$replacement${controller.text.substring(cursor)}',
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
    _clearInlineMentionSuggestions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && index < _threadFocusNodes.length) {
        _threadFocusNodes[index].requestFocus();
      }
    });
  }

  Widget _inlineMentionSuggestions(int index, ColorScheme colors) {
    if (_inlineMentionPartIndex != index) return const SizedBox.shrink();
    if (_inlineMentionLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_inlineMentionUsers.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 190),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: .22)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _inlineMentionUsers.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, userIndex) {
          final user = _inlineMentionUsers[userIndex];
          return ListTile(
            dense: true,
            onTap: () => _selectInlineMention(user),
            leading: GriotAvatar(radius: 18, avatarUrl: user.avatarUrl),
            title: Text(
              user.effectiveName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: user.username == null
                ? null
                : Text(user.formattedUsername),
          );
        },
      ),
    );
  }

  Future<void> _chooseToken({required bool mention}) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      shape: _sheetShape(context),
      builder: (_) => _TokenPickerSheet(mention: mention),
    );
    if (!mounted || value == null || value.trim().isEmpty) return;
    _insertToken('${mention ? '@' : '#'}${value.trim()} ');
    final index = _activePartIndex.clamp(0, _threadFocusNodes.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _threadFocusNodes[index].canRequestFocus) {
        _threadFocusNodes[index].requestFocus();
      }
    });
  }

  Future<void> _publish() async {
    final isPlus = context.read<IapProvider>().status.isPlus;
    final maxLength = isPlus ? _plusPartLimit : _freePartLimit;
    final isRetell = _initialRetellOfTaleId?.trim().isNotEmpty == true;
    final segments = _threadControllers
        .map((controller) => controller.text.trim())
        .toList();
    if ((!isRetell && segments.any((segment) => segment.isEmpty)) ||
        (isRetell && segments.skip(1).any((segment) => segment.isEmpty))) {
      _showError('Complete each Tale segment before publishing.');
      return;
    }
    if (segments.any((segment) => segment.length > maxLength)) {
      _showError('Each Tale segment is limited to $maxLength characters.');
      return;
    }
    final link = _extractUrl(segments.first);
    if (link != null) {
      final uri = Uri.tryParse(link);
      if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
        _showError('Add a valid http or https link.');
        return;
      }
    }
    if (_uploadingMedia) {
      _showError('Wait for the image to finish uploading.');
      return;
    }
    setState(() => _publishing = true);
    try {
      String? threadId = _initialThreadId;
      for (var index = 0; index < segments.length; index++) {
        final segment = segments[index];
        final result = await context.read<MessagingApiService>().publishTale(
          category: _category,
          // A retell is a repost, never a quote post. Any text/media belongs
          // to co-tell and must not alter the original Tale presentation.
          content: isRetell ? '' : segment,
          threadId: threadId,
          mediaUrl: isRetell ? null : _threadMedia[index].firstOrNull?.url,
          mediaType: isRetell ? null : _threadMedia[index].firstOrNull?.type,
          mediaUrls: (isRetell ? const <_TaleMedia>[] : _threadMedia[index])
              .map((media) => media.url)
              .whereType<String>()
              .toList(),
          linkUrl: index == 0 ? link : null,
          linkTitle: index == 0 && _linkMetadataUrl == link
              ? _linkMetadata?.title
              : null,
          linkDescription: index == 0 && _linkMetadataUrl == link
              ? _linkMetadata?.desc
              : null,
          linkThumbnailUrl: index == 0 && _linkMetadataUrl == link
              ? _linkMetadata?.image
              : null,
          retellOfTaleId: index == 0 ? _initialRetellOfTaleId : null,
          visibility: _audience,
        );
        threadId =
            result['thread_id']?.toString() ?? result['threadId']?.toString();
      }
      if (mounted) Navigator.of(context).pop(true);
      await _clearDraft();
    } catch (error) {
      if (mounted) _showError('Could not publish Tale: $error');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  String? _extractUrl(String text) {
    final match = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    ).firstMatch(text);
    final value = match?.group(0)?.replaceAll(RegExp(r'[),.!?]+$'), '');
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 95,
    );
    if (picked == null || !mounted) return;
    final partIndex = _activePartIndex.clamp(0, _threadMedia.length - 1);
    final media = _TaleMedia(path: picked.path);
    setState(() {
      _threadMedia[partIndex].add(media);
      _uploadingMedia = true;
      _uploadingPartIndex = partIndex;
    });
    try {
      final result = await context.read<MediaApiService>().uploadMedia(
        picked.path,
        optimizeImages: true,
      );
      if (!mounted) return;
      setState(() {
        media.url = result['mediaUrl']?.toString();
        media.type = result['contentType']?.toString();
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _threadMedia[partIndex].remove(media);
        });
        _showError('Could not attach that image: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingMedia = false;
          _uploadingPartIndex = null;
        });
      }
    }
  }

  Future<void> _showImageSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      shape: _sheetShape(context),
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return GriotBrandedContainer(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          borderRadius: 28,
          blurSigma: 18,
          backgroundColor: colors.surface.withValues(alpha: .94),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add media to this part',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose an existing photo or capture a new one.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _mediaChoiceCard(
                        context,
                        icon: Icons.photo_library_outlined,
                        title: 'Upload media',
                        subtitle: 'From photos',
                        onTap: () =>
                            Navigator.pop(context, ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _mediaChoiceCard(
                        context,
                        icon: Icons.photo_camera_outlined,
                        title: 'Take photo',
                        subtitle: 'Use camera',
                        onTap: () => Navigator.pop(context, ImageSource.camera),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source != null) await _pickImage(source);
  }

  Widget _mediaChoiceCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: GriotBrandedContainer(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 13),
          borderRadius: 18,
          backgroundColor: colors.primaryContainer.withValues(alpha: .32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary, size: 26),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    NotificationService.showError(context, message);
  }

  Widget _mediaPreview(int partIndex, ColorScheme colors) {
    final mediaItems = _threadMedia[partIndex];
    if (mediaItems.isEmpty) return const SizedBox.shrink();
    final uploading = _uploadingMedia && _uploadingPartIndex == partIndex;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: SizedBox(
        height: mediaItems.length == 1 ? 220 : 154,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: mediaItems.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final media = mediaItems[index];
            return AspectRatio(
              aspectRatio: mediaItems.length == 1 ? 1.35 : 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(media.path), fit: BoxFit.cover),
                    if (uploading && index == mediaItems.length - 1)
                      const ColoredBox(
                        color: Colors.black45,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: IconButton.filledTonal(
                        onPressed: () => setState(
                          () => _threadMedia[partIndex].removeAt(index),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _partEditor(
    BuildContext context,
    int index,
    int maxLength,
    ColorScheme colors, {
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    final editorController = _threadControllers[index];
    if (editorController is _MentionTextEditingController) {
      editorController.mentionColor = colors.primary;
      editorController.hashtagColor = colors.tertiary;
    }
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: editorController,
      builder: (context, value, _) {
        final length = value.text.length;
        final overLimit = length > maxLength;
        final nearLimit = length >= (maxLength * .9).round();
        final counterColor = overLimit
            ? colors.error
            : nearLimit
            ? colors.tertiary
            : colors.onSurfaceVariant;
        return Container(
          height: index == 0
              ? (MediaQuery.sizeOf(context).height -
                        MediaQuery.viewInsetsOf(context).bottom)
                    .clamp(230.0, 340.0)
              : 180,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: .28),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: overLimit
                  ? colors.error
                  : colors.primary.withValues(alpha: .12),
              width: overLimit ? 1.6 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                TextField(
                  controller: editorController,
                  focusNode: _threadFocusNodes[index],
                  autofocus: index == 0,
                  enabled: !readOnly,
                  readOnly: readOnly,
                  showCursor: !readOnly,
                  onTap: () {
                    onTap?.call();
                    // Request focus after the tap so the scroll transition
                    // cannot swallow the keyboard interaction.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted &&
                          index < _threadFocusNodes.length &&
                          _threadFocusNodes[index].canRequestFocus) {
                        _threadFocusNodes[index].requestFocus();
                      }
                    });
                  },
                  enableInteractiveSelection: true,
                  onChanged: (value) => _handleEditorChanged(index, value),
                  minLines: index == 0 ? 16 : 8,
                  maxLines: null,
                  maxLength: maxLength,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: index == 0
                        ? 'What do you want to talk about?'
                        : null,
                    hintStyle: TextStyle(
                      color: colors.onSurfaceVariant.withValues(alpha: .72),
                      fontSize: 20,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 38),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: .86),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      child: Text(
                        '$length/$maxLength',
                        style: TextStyle(
                          color: counterColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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

  Widget _partRail(int index, ColorScheme colors) {
    final active = index == _activePartIndex;
    return SizedBox(
      width: 24,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: active ? 22 : 18,
            height: active ? 22 : 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? colors.primary : colors.surfaceContainerHighest,
              border: Border.all(
                color: active
                    ? colors.primary
                    : colors.outlineVariant.withValues(alpha: .8),
                width: active ? 2 : 1.2,
              ),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: active ? colors.onPrimary : colors.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          // This rail lives inside a ListView item with unbounded height;
          // Expanded would therefore leave later thread parts without a
          // layout size and crash RenderSliverList during hit testing.
          SizedBox(
            height: index == 0 ? 240 : 124,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 2,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: active
                      ? colors.primary.withValues(alpha: .55)
                      : colors.outlineVariant.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final user = context.watch<UserProvider>().user;
    final isPlus = context.watch<IapProvider>().status.isPlus;
    final maxLength = isPlus ? _plusPartLimit : _freePartLimit;

    return GradientScaffold(
      useSafeArea: false,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 18,
        leadingWidth: 52,
        leading: IconButton(
          tooltip: 'Close',
          onPressed: _closeComposer,
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(
          widget.composerTitle ?? 'Tell a Tale',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          AnimatedBuilder(
            animation: Listenable.merge(_threadControllers),
            builder: (context, _) {
              final hasInvalidPart = _threadControllers.any(
                (controller) => controller.text.length > maxLength,
              );
              return Padding(
                padding: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
                child: FilledButton(
                  onPressed: _publishing || hasInvalidPart ? null : _publish,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(92, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: const StadiumBorder(),
                  ),
                  child: _publishing
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Publish'),
                ),
              );
            },
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: GriotBrandedContainer(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                borderRadius: 18,
                blurSigma: 10,
                child: Row(
                  children: [
                    Icon(
                      _audience == 'following'
                          ? Icons.people_alt_outlined
                          : Icons.public_rounded,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _audience == 'following'
                            ? 'Followers can read and reply'
                            : 'Everyone can read and reply',
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _publishing
                          ? null
                          : () => _showAudienceMenu(context),
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.initialReferenceText?.trim().isNotEmpty == true)
                      _referenceTaleCard(colors),
                    GriotBrandedContainer(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      borderRadius: 26,
                      blurSigma: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              GriotAvatar(
                                radius: 22,
                                avatarUrl: user?.avatarUrl,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.displayName ??
                                          user?.username ??
                                          'You',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Share something worth remembering',
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: colors.primary,
                                size: 19,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _partEditor(
                            context,
                            0,
                            maxLength,
                            colors,
                            readOnly:
                                _initialRetellOfTaleId?.isNotEmpty == true,
                            onTap: () {
                              if (_activePartIndex != 0) {
                                setState(() => _activePartIndex = 0);
                              }
                            },
                          ),
                          _inlineMentionSuggestions(0, colors),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _threadControllers.first,
                            builder: (context, value, _) {
                              final url = _extractUrl(value.text);
                              if (url == null) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: LinkPreviewWidget(url: url, isMe: false),
                              );
                            },
                          ),
                          if (_threadMedia.first.isNotEmpty)
                            _mediaPreview(0, colors),
                        ],
                      ),
                    ),
                    if (_activePartIndex == 0) _continueTaleButton(colors),
                    for (
                      var index = 0;
                      index < _threadControllers.length;
                      index++
                    )
                      if (index > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _partRail(index, colors),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        12,
                                        12,
                                        10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.surface.withValues(
                                          alpha: .76,
                                        ),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: colors.outlineVariant
                                              .withValues(alpha: .55),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'Part ${index + 1}',
                                                style: TextStyle(
                                                  color: colors.primary,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const Spacer(),
                                              IconButton(
                                                tooltip: 'Remove part',
                                                onPressed: _publishing
                                                    ? null
                                                    : () =>
                                                          _removeThreadSegment(
                                                            index,
                                                          ),
                                                icon: const Icon(
                                                  Icons.close_rounded,
                                                  size: 18,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            ],
                                          ),
                                          _partEditor(
                                            context,
                                            index,
                                            maxLength,
                                            colors,
                                            onTap: () {
                                              if (_activePartIndex != index) {
                                                setState(
                                                  () =>
                                                      _activePartIndex = index,
                                                );
                                              }
                                            },
                                          ),
                                          _inlineMentionSuggestions(
                                            index,
                                            colors,
                                          ),
                                          if (_threadMedia[index].isNotEmpty)
                                            _mediaPreview(index, colors),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_activePartIndex == index)
                                _continueTaleButton(colors),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Container(
                color: colors.surface.withValues(alpha: .9),
                padding: const EdgeInsets.fromLTRB(12, 5, 12, 3),
                child: Row(
                  children: [
                    _ComposerAction(
                      icon: Icons.image_outlined,
                      label: 'Image',
                      onPressed: _publishing || _uploadingMedia
                          ? null
                          : _showImageSourceSheet,
                    ),
                    _ComposerAction(
                      icon: Icons.tag_rounded,
                      label: 'Hashtag',
                      onPressed: _publishing
                          ? null
                          : () => _chooseToken(mention: false),
                    ),
                    _ComposerAction(
                      icon: Icons.alternate_email_rounded,
                      label: 'Mention',
                      onPressed: _publishing
                          ? null
                          : () => _chooseToken(mention: true),
                    ),
                    _ComposerAction(
                      icon: Icons.category_outlined,
                      label: _category,
                      onPressed: _publishing
                          ? null
                          : () => _showCategorySheet(context),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _threadControllers.first,
                      builder: (context, value, _) => Text(
                        '${value.text.length}/$maxLength',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _referenceTaleCard(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GriotBrandedContainer(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        borderRadius: 20,
        backgroundColor: colors.surfaceContainerHighest.withValues(alpha: .55),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_tree_rounded,
                  size: 18,
                  color: colors.primary,
                ),
                const SizedBox(width: 7),
                Text(
                  widget.initialReferenceLabel ?? 'Referenced Tale',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              widget.initialReferenceText!.trim(),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.3),
            ),
            if (widget.initialReferenceMediaUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.initialReferenceMediaUrls.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.network(
                        widget.initialReferenceMediaUrls[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: colors.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAudienceMenu(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      shape: _sheetShape(context),
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return GriotBrandedContainer(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          borderRadius: 28,
          blurSigma: 18,
          backgroundColor: colors.surface.withValues(alpha: .94),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.public_rounded, color: colors.primary),
                  title: const Text('Public'),
                  subtitle: const Text('Anyone on Griot can read this Tale'),
                  trailing: _audience == 'public'
                      ? Icon(Icons.check_rounded, color: colors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, 'public'),
                ),
                ListTile(
                  leading: Icon(
                    Icons.people_alt_outlined,
                    color: colors.primary,
                  ),
                  title: const Text('Followers'),
                  subtitle: const Text(
                    'Only people who follow you can read and reply',
                  ),
                  trailing: _audience == 'following'
                      ? Icon(Icons.check_rounded, color: colors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, 'following'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (mounted && selected != null) {
      setState(() => _audience = selected);
      _scheduleDraftSave();
    }
  }

  void _showCategorySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      shape: _sheetShape(context),
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return GriotBrandedContainer(
          padding: const EdgeInsets.symmetric(vertical: 8),
          borderRadius: 28,
          blurSigma: 18,
          backgroundColor: colors.surface.withValues(alpha: .94),
          child: SafeArea(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final value = _categories[index];
                return ListTile(
                  title: Text(value),
                  trailing: _category == value
                      ? Icon(Icons.check_rounded, color: colors.primary)
                      : null,
                  onTap: () {
                    setState(() => _category = value);
                    _scheduleDraftSave();
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  ShapeBorder _sheetShape(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: colors.primary.withValues(alpha: .24)),
    );
  }

  Widget _continueTaleButton(ColorScheme colors) {
    final canContinue = !_publishing && _threadControllers.length < 10;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 1, 0, 0),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: colors.outlineVariant.withValues(alpha: .5),
              height: 1,
            ),
          ),
          TextButton.icon(
            onPressed: canContinue ? _addThreadSegment : null,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Continue this Tale'),
            style: TextButton.styleFrom(
              foregroundColor: colors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Expanded(
            child: Divider(
              color: colors.outlineVariant.withValues(alpha: .5),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ComposerAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: Icon(icon, color: colors.primary),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TokenPickerSheet extends StatefulWidget {
  final bool mention;

  const _TokenPickerSheet({required this.mention});

  @override
  State<_TokenPickerSheet> createState() => _TokenPickerSheetState();
}

class _TokenPickerSheetState extends State<_TokenPickerSheet> {
  static const _hashtags = <String>[
    'Personal',
    'Finance',
    'Technology',
    'Health',
    'Education',
    'Lessons',
    'Culture',
    'Community',
    'Ideas',
    'History',
    'PublicHealth',
    'Web3',
  ];

  final _controller = TextEditingController();
  Timer? _debounce;
  List<UserModel> _users = const [];
  bool _loading = false;
  String _query = '';
  int _requestVersion = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _query = value.trim().replaceFirst(RegExp(r'^[@#]'), '');
    if (!widget.mention) {
      setState(() {});
      return;
    }
    _debounce?.cancel();
    final query = _query;
    final version = ++_requestVersion;
    if (query.length < 2) {
      setState(() {
        _users = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final response = await context.read<UserApiService>().searchUsers(
          query,
          limit: 12,
        );
        if (!mounted || version != _requestVersion) return;
        setState(() {
          _users = List<UserModel>.from(response['users'] as List? ?? const []);
          _loading = false;
        });
      } catch (_) {
        if (!mounted || version != _requestVersion) return;
        setState(() {
          _users = const [];
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final suggestions = _hashtags
        .where(
          (tag) =>
              _query.isEmpty ||
              tag.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList(growable: false);

    return GriotBrandedContainer(
      padding: EdgeInsets.zero,
      borderRadius: 28,
      blurSigma: 18,
      backgroundColor: colors.surface.withValues(alpha: .94),
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .68,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.mention ? 'Mention someone' : 'Add a hashtag',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    onChanged: _onChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        widget.mention
                            ? Icons.alternate_email_rounded
                            : Icons.tag_rounded,
                      ),
                      hintText: widget.mention
                          ? 'Search by name or username'
                          : 'Search or create a hashtag',
                      filled: true,
                      fillColor: colors.surfaceContainerHighest.withValues(
                        alpha: .55,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: widget.mention
                      ? _buildMentionResults(context)
                      : _buildHashtagResults(context, suggestions),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMentionResults(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_query.length < 2) {
      return const Center(
        child: Text('Type at least two characters to search.'),
      );
    }
    if (_users.isEmpty) {
      return const Center(child: Text('No matching Griot users found.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final user = _users[index];
        return ListTile(
          onTap: () {
            final username = user.username?.trim();
            if (username == null || username.isEmpty) return;
            Navigator.of(context).pop(username);
          },
          leading: GriotAvatar(radius: 22, avatarUrl: user.avatarUrl),
          title: Text(
            user.effectiveName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: user.username == null ? null : Text(user.formattedUsername),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  Widget _buildHashtagResults(BuildContext context, List<String> suggestions) {
    final options = [...suggestions];
    if (_query.isNotEmpty &&
        !options.any((tag) => tag.toLowerCase() == _query.toLowerCase())) {
      options.insert(0, _query);
    }
    if (options.isEmpty) {
      return const Center(child: Text('Type a topic to create a hashtag.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: options.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final tag = options[index];
        return ListTile(
          onTap: () => Navigator.of(context).pop(tag),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.tag_rounded,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text('#$tag'),
          subtitle: index == 0 && _query.isNotEmpty && tag == _query
              ? const Text('Use this hashtag')
              : const Text('Suggested topic'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }
}
