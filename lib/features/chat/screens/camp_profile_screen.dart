import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_avatar.dart';
import '../../../core/ui/widgets/griot_feed_media.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';
import '../../../core/ui/widgets/griot_plus_badge.dart';
import '../../../core/ui/widgets/griot_pioneer_badge.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/navigation_scroll_service.dart';
import '../../auth/auth_controller.dart';
import '../../users/models/user_model.dart';
import '../../users/providers/user_provider.dart';
import '../../users/services/user_api_service.dart';
import '../../golds/services/golds_api_service.dart';
import '../services/messaging_api_service.dart';
import '../models/chat_user.dart';
import '../widgets/camp_tip_sheet.dart';
import '../widgets/camp_tale_components.dart';
import '../widgets/camp_tale_media_gallery.dart';
import '../widgets/chatting/report_content_sheet.dart';
import '../providers/messaging_provider.dart';

/// Public Campside projection of the account identity.
///
/// This is intentionally separate from the normal user profile: account
/// identity and badges are inherited, while Camp-specific content is grouped
/// into Campfires, Tales and Activity tabs.
class CampProfileScreen extends StatefulWidget {
  const CampProfileScreen({
    super.key,
    this.profileUser,
    this.profileIdentifier,
    this.isPublic = false,
  });

  final UserModel? profileUser;
  final String? profileIdentifier;
  final bool isPublic;

  @override
  State<CampProfileScreen> createState() => _CampProfileScreenState();
}

class _CampProfileScreenState extends State<CampProfileScreen>
    with TickerProviderStateMixin {
  static const _taleDraftStorageKey = 'griot_tale_composer_drafts_v2';
  static const _legacyTaleDraftStorageKey = 'griot_tale_composer_draft_v1';
  static const _profilePinsKeyPrefix = 'griot_profile_pins_v1_';
  late final TabController _tabController;
  int _selectedTab = 0;
  String _activityFilter = 'All';
  UserModel? _loadedPublicUser;
  bool _loadingPublicUser = false;
  Map<String, dynamic>? _campProfile;
  bool _loadingCampProfile = false;
  bool _updatingFollow = false;
  int? _campGoldBalance;
  List<Map<String, dynamic>> _campTales = const [];
  List<Map<String, dynamic>> _campfires = const [];
  List<Map<String, dynamic>> _campActivity = const [];
  final Set<String> _profilePinnedTaleIds = <String>{};
  final Set<String> _savedCampContent = <String>{};
  final Set<String> _expandedProfileThreads = <String>{};
  bool _loadingCampContent = false;
  bool _loadingMoreTales = false;
  bool _campTalesHasMore = false;
  int _campTalesOffset = 0;
  bool _loadingMoreCampfires = false;
  bool _campfiresHasMore = false;
  int _campfiresOffset = 0;
  final ScrollController _profileScrollController = ScrollController();
  bool _profileChromeVisible = true;
  bool _profileTabsPinned = false;
  Timer? _profileChromeTimer;
  double _lastProfileOffset = 0;
  late final AnimationController _profileChromeAnimation;
  List<Map<String, dynamic>> _taleDrafts = const [];
  bool _cleanedUnrecordedCampfires = false;

  @override
  void initState() {
    super.initState();
    _profileChromeAnimation =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 280),
          value: 1,
        )..addListener(() {
          if (mounted) setState(() {});
        });
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTab = _tabController.index);
      }
    });
    _profileScrollController.addListener(_onProfileScroll);
    if (widget.isPublic &&
        widget.profileUser == null &&
        widget.profileIdentifier != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPublicUser());
    } else if (widget.isPublic && widget.profileUser != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadCampProfile(userId: widget.profileUser!.id),
      );
    } else if (!widget.isPublic) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCampProfile());
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadCampGoldBalance(),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadTaleDraft());
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _cleanupUnrecordedCampfires(),
      );
    }
  }

  Future<void> _loadTaleDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(_taleDraftStorageKey);
      if (raw == null || raw.isEmpty) {
        final legacy = prefs.getString(_legacyTaleDraftStorageKey);
        if (legacy != null && legacy.isNotEmpty) {
          final legacyDecoded = jsonDecode(legacy);
          if (legacyDecoded is Map) {
            raw = jsonEncode([
              {
                'id': 'legacy-${DateTime.now().microsecondsSinceEpoch}',
                ...Map<String, dynamic>.from(legacyDecoded),
              },
            ]);
            await prefs.setString(_taleDraftStorageKey, raw);
            await prefs.remove(_legacyTaleDraftStorageKey);
          }
        }
      }
      if (raw == null || raw.isEmpty || !mounted) return;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final drafts = decoded
            .whereType<Map>()
            .map((draft) {
              final mapped = Map<String, dynamic>.from(draft);
              mapped['id'] ??= 'draft-${DateTime.now().microsecondsSinceEpoch}';
              mapped['parts'] = (mapped['parts'] as List? ?? const [])
                  .map((part) => part.toString())
                  .where((part) => part.trim().isNotEmpty)
                  .toList(growable: false);
              return mapped;
            })
            .where((draft) => (draft['parts'] as List).isNotEmpty)
            .toList();
        if (drafts.isNotEmpty) setState(() => _taleDrafts = drafts);
      }
    } catch (_) {
      // A corrupt draft should not affect the Camp Profile.
    }
  }

  Future<void> _deleteTale(Map<String, dynamic> tale) async {
    final taleId = tale['id']?.toString();
    if (taleId == null || taleId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Tale?'),
        content: const Text('This Tale and its comments will be removed.'),
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
    try {
      await context.read<MessagingApiService>().deleteTale(taleId);
      if (!mounted) return;
      setState(() {
        _campTales = _campTales
            .where((item) => item['id']?.toString() != taleId)
            .toList(growable: false);
      });
      NotificationService.showInfo(context, 'Tale deleted.');
    } catch (error) {
      if (mounted) {
        NotificationService.showError(context, 'Could not delete Tale: $error');
      }
    }
  }

  Future<void> _cleanupUnrecordedCampfires() async {
    if (_cleanedUnrecordedCampfires || !mounted) return;
    _cleanedUnrecordedCampfires = true;
    try {
      final userId = context.read<UserProvider>().user?.id;
      if (userId == null) return;
      await context.read<MessagingApiService>().deleteUnrecordedCampfires(
        userId,
      );
      await _loadCampContent(userId);
    } catch (_) {
      // Cleanup is best-effort and must not affect the Camp Profile view.
    }
  }

  bool _isCampContentSaved(String type, String? id) =>
      id != null && _savedCampContent.contains('$type:$id');

  Future<void> _toggleCampContentSave({
    required String targetType,
    required String targetId,
  }) async {
    final key = '$targetType:$targetId';
    final wasSaved = _savedCampContent.contains(key);
    try {
      final api = context.read<MessagingApiService>();
      if (wasSaved) {
        await api.unsaveCampContent(targetType: targetType, targetId: targetId);
      } else {
        await api.saveCampContent(targetType: targetType, targetId: targetId);
      }
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          _savedCampContent.remove(key);
        } else {
          _savedCampContent.add(key);
        }
      });
      NotificationService.showSuccess(
        context,
        wasSaved ? 'Removed from your Camp list.' : 'Pinned to your Camp list.',
      );
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not update your Camp list: $error',
        );
      }
    }
  }

  Future<void> _loadCampGoldBalance() async {
    try {
      final balance = await context.read<GoldsApiService>().getBalance();
      if (mounted) setState(() => _campGoldBalance = balance);
    } catch (_) {
      // Keep the Camp Profile usable if Golds are not available yet.
    }
  }

  Future<void> _loadPublicUser() async {
    if (!mounted || _loadingPublicUser) return;
    setState(() => _loadingPublicUser = true);
    try {
      final user = await UserApiService(
        apiClient: context.read<ApiClient>(),
      ).getUserById(widget.profileIdentifier!);
      if (mounted) setState(() => _loadedPublicUser = user);
      await _loadCampProfile(userId: user.id);
    } catch (_) {
      // Keep the profile shell usable if the public identity request fails.
    } finally {
      if (mounted) setState(() => _loadingPublicUser = false);
    }
  }

  Future<void> _loadCampProfile({String? userId}) async {
    final id =
        userId ??
        widget.profileUser?.id ??
        context.read<UserProvider>().user?.id;
    if (!mounted || id == null || _loadingCampProfile) return;
    await _loadProfilePins(id);
    if (!mounted) return;
    setState(() => _loadingCampProfile = true);
    try {
      final data = await MessagingApiService(
        apiClient: context.read<ApiClient>(),
      ).getCampProfile(id);
      if (mounted) setState(() => _campProfile = data);
      await _loadCampContent(id);
    } catch (_) {
      // The identity card remains useful if the Camp summary is unavailable.
    } finally {
      if (mounted) setState(() => _loadingCampProfile = false);
    }
  }

  Future<void> _loadProfilePins(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final pins =
        prefs.getStringList('$_profilePinsKeyPrefix$userId') ?? const [];
    if (!mounted) return;
    setState(() {
      _profilePinnedTaleIds
        ..clear()
        ..addAll(pins.take(2));
    });
  }

  Future<void> _toggleProfilePin(String taleId) async {
    final userId =
        widget.profileUser?.id ??
        _loadedPublicUser?.id ??
        context.read<UserProvider>().user?.id;
    if (widget.isPublic || userId == null || userId.isEmpty) return;
    final alreadyPinned = _profilePinnedTaleIds.contains(taleId);
    if (!alreadyPinned && _profilePinnedTaleIds.length >= 2) {
      NotificationService.showInfo(
        context,
        'You can pin up to 2 Tales on your Camp Profile.',
      );
      return;
    }
    setState(() {
      if (alreadyPinned) {
        _profilePinnedTaleIds.remove(taleId);
      } else {
        _profilePinnedTaleIds.add(taleId);
      }
      _campTales = _sortProfileTales(_campTales);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      '$_profilePinsKeyPrefix$userId',
      _profilePinnedTaleIds.take(2).toList(),
    );
  }

  List<Map<String, dynamic>> _sortProfileTales(
    List<Map<String, dynamic>> tales,
  ) {
    final result = List<Map<String, dynamic>>.from(tales);
    result.sort((a, b) {
      final aId = (a['id'] ?? a['tale_id'] ?? a['taleId'])?.toString();
      final bId = (b['id'] ?? b['tale_id'] ?? b['taleId'])?.toString();
      final aPinned =
          a['isPinned'] == true || _profilePinnedTaleIds.contains(aId);
      final bPinned =
          b['isPinned'] == true || _profilePinnedTaleIds.contains(bId);
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      return 0;
    });
    return result;
  }

  void _onProfileScroll() {
    if (_profileScrollController.hasClients) {
      final position = _profileScrollController.position;
      final offset = position.pixels;
      final delta = offset - _lastProfileOffset;
      // Match the Camp feed: hide while moving down, restore when the user
      // scrolls back up, and ignore tiny physics oscillations.
      if (delta.abs() >= 8) {
        _lastProfileOffset = offset;
        if (delta > 0 && offset > 72 && _profileChromeVisible) {
          _profileChromeTimer?.cancel();
          _setProfileChromeVisible(false);
        } else if (delta < 0 && !_profileChromeVisible) {
          _profileChromeTimer?.cancel();
          _setProfileChromeVisible(true);
        }
      }
      if (offset <= position.minScrollExtent) {
        _profileChromeTimer?.cancel();
        _lastProfileOffset = offset;
        _setProfileChromeVisible(true);
      }
      final tabsPinned = offset > 180;
      if (tabsPinned != _profileTabsPinned && mounted) {
        setState(() => _profileTabsPinned = tabsPinned);
      }
    }
    if (!_profileScrollController.hasClients ||
        _loadingMoreTales ||
        !_campTalesHasMore ||
        _selectedTab != 0) {
      return;
    }
    if (_profileScrollController.position.extentAfter < 420) {
      final userId =
          widget.profileUser?.id ??
          _loadedPublicUser?.id ??
          context.read<UserProvider>().user?.id;
      if (userId != null) _loadCampContent(userId, nextPage: true);
    }
  }

  void _setProfileChromeVisible(bool visible) {
    NavigationScrollService.instance.setNavigationVisible(visible);
    if (!mounted || _profileChromeVisible == visible) return;
    setState(() => _profileChromeVisible = visible);
    if (visible) {
      _profileChromeAnimation.forward();
    } else {
      _profileChromeAnimation.reverse();
    }
  }

  Future<void> _loadCampContent(String userId, {bool nextPage = false}) async {
    if (!mounted || (nextPage ? _loadingMoreTales : _loadingCampContent)) {
      return;
    }
    if (nextPage) {
      if (!_campTalesHasMore) {
        return;
      }
      setState(() => _loadingMoreTales = true);
    } else {
      setState(() {
        _loadingCampContent = true;
        _campTalesOffset = 0;
        _campTalesHasMore = false;
        _campfiresOffset = 0;
        _campfiresHasMore = false;
      });
    }
    setState(() => _loadingCampContent = true);
    try {
      final api = MessagingApiService(apiClient: context.read<ApiClient>());
      final results = nextPage
          ? <Map<String, dynamic>>[
              await api.getCampProfileTales(
                userId,
                limit: 12,
                offset: _campTalesOffset,
              ),
            ]
          : await Future.wait([
              api.getCampProfileTales(userId, limit: 12, offset: 0),
              api.getCampProfileCampfires(userId, limit: 12, offset: 0),
              api.getCampProfileActivity(userId, limit: 20, offset: 0),
            ]);
      if (!mounted) return;
      List<Map<String, dynamic>> items(Map<String, dynamic> data) {
        Object? current = data;
        for (var depth = 0; depth < 5; depth++) {
          if (current is List) {
            return current
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
          }
          if (current is! Map) break;
          final map = Map<String, dynamic>.from(current);
          for (final key in const [
            'items',
            'tales',
            'results',
            'spaces',
            'campfires',
          ]) {
            final value = map[key];
            if (value is List) {
              return value
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();
            }
          }
          current = map['data'];
        }
        return <Map<String, dynamic>>[];
      }

      List<Map<String, dynamic>> groupedTales(Map<String, dynamic> data) {
        final tales = items(data);
        final groups = <String, List<Map<String, dynamic>>>{};
        final standalone = <Map<String, dynamic>>[];
        for (final tale in tales) {
          final threadId = (tale['threadId'] ?? tale['thread_id'])?.toString();
          final count =
              int.tryParse(
                '${tale['threadCount'] ?? tale['thread_count'] ?? 1}',
              ) ??
              1;
          if (threadId == null || threadId.isEmpty || count <= 1) {
            standalone.add(tale);
          } else {
            groups
                .putIfAbsent(threadId, () => <Map<String, dynamic>>[])
                .add(tale);
          }
        }
        for (final parts in groups.values) {
          parts.sort(
            (a, b) =>
                (int.tryParse(
                          '${a['threadPosition'] ?? a['thread_position'] ?? 1}',
                        ) ??
                        1)
                    .compareTo(
                      int.tryParse(
                            '${b['threadPosition'] ?? b['thread_position'] ?? 1}',
                          ) ??
                          1,
                    ),
          );
          final first = Map<String, dynamic>.from(parts.first);
          // Keep Part 1 as the normal profile card. The remaining parts are
          // exposed through the linked Tale action instead of being merged
          // into the primary card body.
          first['content'] =
              '${parts.first['content'] ?? parts.first['text'] ?? ''}'.trim();
          first['threadParts'] = parts
              .map(
                (part) => <String, dynamic>{
                  'id': part['id'],
                  'content': '${part['content'] ?? part['text'] ?? ''}'.trim(),
                  'mediaUrl': part['mediaUrl'] ?? part['media_url'],
                  'mediaUrls': part['mediaUrls'] ?? part['media_urls'],
                  'threadPosition':
                      part['threadPosition'] ?? part['thread_position'] ?? 1,
                },
              )
              .toList(growable: false);
          first['threadPosition'] = 1;
          first['threadCount'] = parts.length;
          standalone.add(first);
        }
        standalone.sort((a, b) {
          final aDate = DateTime.tryParse(
            '${a['createdAt'] ?? a['created_at'] ?? ''}',
          );
          final bDate = DateTime.tryParse(
            '${b['createdAt'] ?? b['created_at'] ?? ''}',
          );
          return (bDate ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
            aDate ?? DateTime.fromMillisecondsSinceEpoch(0),
          );
        });
        return standalone;
      }

      setState(() {
        final incomingTales = groupedTales(results[0]);
        _campTales = _sortProfileTales(
          nextPage ? [..._campTales, ...incomingTales] : incomingTales,
        );
        if (!nextPage) {
          _campfires = items(results[1]);
          _campActivity = items(results[2]);
          _campfiresOffset = _campfires.length;
          _campfiresHasMore =
              results[1]['hasMore'] == true || _campfires.length >= 12;
        }
        _campTalesOffset += items(results[0]).length;
        _campTalesHasMore =
            results[0]['hasMore'] == true || items(results[0]).length >= 12;
        _savedCampContent
          ..clear()
          ..addAll(
            _campActivity
                .where((item) => item['type'] == 'saved')
                .map((item) {
                  final targetType = '${item['summary'] ?? ''}'.toLowerCase();
                  final targetId = item['entity_id']?.toString() ?? '';
                  return '$targetType:$targetId';
                })
                .where((key) => !key.endsWith(':')),
          );
        if (!nextPage) _loadingCampContent = false;
      });
    } catch (_) {
      // Keep the profile usable if one content feed is temporarily unavailable.
    } finally {
      if (mounted) {
        setState(() {
          _loadingCampContent = false;
          _loadingMoreTales = false;
        });
      }
    }
  }

  Future<void> _loadMoreCampfires(String userId) async {
    if (!mounted || _loadingMoreCampfires || !_campfiresHasMore) return;
    setState(() => _loadingMoreCampfires = true);
    try {
      final data = await context
          .read<MessagingApiService>()
          .getCampProfileCampfires(userId, limit: 12, offset: _campfiresOffset);
      final raw = data['items'];
      final incoming = raw is List
          ? raw.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _campfires.addAll(incoming);
        _campfiresOffset += incoming.length;
        _campfiresHasMore = data['hasMore'] == true || incoming.length >= 12;
      });
    } catch (_) {
      // Keep already-loaded Campfires visible when a later page fails.
    } finally {
      if (mounted) setState(() => _loadingMoreCampfires = false);
    }
  }

  @override
  void dispose() {
    _profileChromeTimer?.cancel();
    _profileChromeAnimation.dispose();
    NavigationScrollService.instance.setNavigationVisible(true);
    _tabController.dispose();
    _profileScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final chromeFactor = Curves.easeInOutCubic.transform(
      _profileChromeAnimation.value,
    );
    final user =
        widget.profileUser ??
        _loadedPublicUser ??
        (widget.isPublic ? null : context.watch<UserProvider>().user);
    final name = user?.effectiveName ?? 'Your name';
    final username = user?.formattedUsername ?? '@username';

    return GradientScaffold(
      appBar: AppBar(
        // Match the Camp feed: collapse the toolbar itself, not just its
        // contents, so the profile cards reclaim the space while scrolling.
        toolbarHeight: kToolbarHeight * chromeFactor,
        backgroundColor: colors.surface.withValues(alpha: .82 * chromeFactor),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: AnimatedSlide(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          offset: _profileChromeVisible ? Offset.zero : const Offset(0, -.35),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            opacity: _profileChromeVisible ? 1 : 0,
            child: const Text('Camp Profile'),
          ),
        ),
        centerTitle: true,
        actions: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            opacity: _profileChromeVisible ? 1 : 0,
            child: IgnorePointer(
              ignoring: !_profileChromeVisible,
              child: PopupMenuButton<String>(
                tooltip: 'Camp Profile options',
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (value) {
                  switch (value) {
                    case 'share':
                      _shareCampProfile(user);
                      break;
                    case 'drafts':
                      context.push('/camp/tales/drafts');
                      break;
                    case 'profile':
                      if (user != null) {
                        context.push('/user/profile', extra: user);
                      }
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.ios_share_rounded),
                      title: Text('Share Camp Profile'),
                    ),
                  ),
                  if (!widget.isPublic)
                    const PopupMenuItem(
                      value: 'drafts',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.drafts_outlined),
                        title: Text('Tale drafts'),
                      ),
                    ),
                  if (!widget.isPublic)
                    const PopupMenuItem(
                      value: 'profile',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.person_outline_rounded),
                        title: Text('Personal profile'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: widget.isPublic
          ? null
          : Padding(
              // Keep the profile action just above the bottom navigation. This
              // screen is already inside the shell that owns the persistent
              // nav, so a large extra inset makes the action float too high.
              // The global navigation belongs to the shell rather than
              // this nested Scaffold, so Flutter cannot reserve its
              // height automatically. Keep the action above that
              // overlay and its safe-area inset on every device.
              padding: EdgeInsets.only(
                bottom: 8 + MediaQuery.viewPaddingOf(context).bottom,
                right: 8,
              ),
              child: HeroMode(
                enabled: false,
                child: FloatingActionButton.extended(
                  heroTag: 'camp-profile-tell-tale-action',
                  onPressed: () => context.push('/campfires/tales/create'),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('Tell a Tale'),
                ),
              ),
            ),
      // Keep the primary action available while scrolling, but use the
      // compact form so it never covers a Tale card or its action row.
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) => false,
        child: Stack(
          children: [
            ListView(
              controller: _profileScrollController,
              physics: campScrollPhysics,
              // Keep the final Camp content clear of the extended FAB, including
              // on smaller phones and when the keyboard/safe-area inset changes.
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                // Leave room for the extended Camp action while the final card
                // scrolls above it instead of disappearing underneath the FAB.
                96 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                if (_loadingPublicUser)
                  const LinearProgressIndicator(minHeight: 2),
                _profileCard(context, user, name, username),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  labelColor: colors.primary,
                  unselectedLabelColor: colors.onSurfaceVariant,
                  indicatorColor: colors.primary,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(icon: Icon(Icons.menu_book_rounded), text: 'Tales'),
                    Tab(
                      icon: Icon(Icons.local_fire_department_rounded),
                      text: 'Campfires',
                    ),
                    Tab(icon: Icon(Icons.forum_outlined), text: 'Interactions'),
                  ],
                ),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  reverseDuration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) => ClipRect(
                    child: Stack(
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.hardEdge,
                      children: [...previousChildren, ?currentChild],
                    ),
                  ),
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(.035, 0),
                          end: Offset.zero,
                        ).animate(curved),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_selectedTab),
                    child: _selectedTab == 0
                        ? _talesTab(context)
                        : _selectedTab == 1
                        ? _campfiresTab(context)
                        : _activityTab(context),
                  ),
                ),
              ],
            ),
            if (_profileTabsPinned)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Material(
                  color: colors.surface,
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: false,
                      labelColor: colors.primary,
                      unselectedLabelColor: colors.onSurfaceVariant,
                      indicatorColor: colors.primary,
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(icon: Icon(Icons.menu_book_rounded), text: 'Tales'),
                        Tab(
                          icon: Icon(Icons.local_fire_department_rounded),
                          text: 'Campfires',
                        ),
                        Tab(
                          icon: Icon(Icons.forum_outlined),
                          text: 'Interactions',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _profileCard(
    BuildContext context,
    UserModel? user,
    String name,
    String username,
  ) {
    final colors = Theme.of(context).colorScheme;
    final reputation = user?.reputation;
    final bio = user?.bio?.trim();
    final bannerUrl = _taleMediaUrl(_campProfile?['banner_url']);

    return GriotBrandedContainer(
      padding: EdgeInsets.zero,
      borderRadius: 28,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            InkWell(
              child: Container(
                height: 112,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primaryContainer,
                      colors.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  image: bannerUrl?.isNotEmpty == true
                      ? DecorationImage(
                          image: NetworkImage(bannerUrl!),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: .18),
                            BlendMode.darken,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Column(
                children: [
                  Transform.translate(
                    offset: const Offset(0, -34),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.surface,
                        border: Border.all(color: colors.surface, width: 5),
                      ),
                      child: GriotAvatar(
                        avatarUrl: user?.avatarUrl,
                        radius: 36,
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (user?.isPlus == true) ...[
                              const SizedBox(width: 6),
                              const GriotPlusBadge(isPlus: true, compact: true),
                            ],
                            if (user?.isPioneer == true) ...[
                              const SizedBox(width: 4),
                              const GriotPioneerBadge(compact: true),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          username,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (user?.createdAt != null) ...[
                          const SizedBox(height: 7),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                size: 16,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Joined ${MaterialLocalizations.of(context).formatMonthYear(user!.createdAt!)}',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (reputation != null) ...[
                          const SizedBox(height: 7),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 6,
                            runSpacing: 6,
                            children: [_reputationBadge(context, reputation)],
                          ),
                        ],
                        if (reputation != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            reputation.tierName,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        if (bio != null && bio.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            bio,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _stat(
                        context,
                        'Followers',
                        _campCount('followers'),
                        onTap: () => _openConnections('followers', user),
                      ),
                      _stat(
                        context,
                        'Following',
                        _campCount('following'),
                        onTap: () => _openConnections('following', user),
                      ),
                    ],
                  ),
                  if (!widget.isPublic) ...[
                    const SizedBox(height: 9),
                    _campGoldsCard(context),
                  ],
                  if (widget.isPublic && user != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _updatingFollow ? null : _toggleFollow,
                            icon: Icon(
                              _campProfile?['is_following'] == true
                                  ? Icons.check_rounded
                                  : Icons.person_add_alt_1_rounded,
                            ),
                            label: Text(
                              _campProfile?['is_following'] == true
                                  ? 'Following'
                                  : 'Follow',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _tipCampCreator(user),
                            icon: const Icon(Icons.volunteer_activism_outlined),
                            label: const Text('Tip creator'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _tipCampCreator(UserModel user) {
    // Gold tips are account-to-account and do not require a connected crypto
    // wallet. The chooser only checks a wallet when the user selects Crypto.
    CampTipSheet.show(
      context,
      recipient: ChatUser.fromUserModel(user),
      metadata: {'surface': 'camp_profile'},
    );
  }

  Future<void> _muteCampAuthor(String userId) async {
    try {
      await MessagingApiService(
        apiClient: context.read<ApiClient>(),
      ).muteUser(userId);
      if (mounted) {
        NotificationService.showInfo(
          context,
          'Creator muted. Their Camp content will be hidden from your feed.',
        );
      }
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not mute creator: $error',
        );
      }
    }
  }

  Future<void> _blockCampAuthor(String userId) async {
    try {
      await context.read<MessagingProvider>().blockUser(userId);
      if (mounted) {
        setState(() {
          _campTales = _campTales
              .where((tale) {
                final author = tale['author'] is Map
                    ? Map<String, dynamic>.from(tale['author'] as Map)
                    : const <String, dynamic>{};
                final id =
                    (author['id'] ??
                            author['userId'] ??
                            author['user_id'] ??
                            tale['authorId'] ??
                            tale['author_id'] ??
                            tale['user_id'])
                        ?.toString();
                return id != userId;
              })
              .toList(growable: false);
        });
        NotificationService.showInfo(
          context,
          'Creator blocked. Their Camp content is no longer shown.',
        );
      }
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not block creator: $error',
        );
      }
    }
  }

  Widget _campGoldsCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GriotBrandedContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 18,
      child: InkWell(
        onTap: () => context.push('/settings/griot-golds'),
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            Image.asset(
              'assets/coins_logo/griot_gold_nugget_3d.png',
              width: 42,
              height: 42,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Griot Camp Golds',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Golds for use in Griot Camps',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${_campGoldBalance ?? 0}',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campfiresTab(BuildContext context) {
    if (_loadingCampContent && _campfires.isEmpty) {
      return const _CampProfileLoadingSkeleton(tale: false);
    }
    if (_campfires.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < _campfires.length; index++) ...[
            _campfireCard(context, _campfires[index]),
          ],
          if (_campfiresHasMore)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: _loadingMoreCampfires
                    ? null
                    : () {
                        final userId =
                            widget.profileUser?.id ??
                            _loadedPublicUser?.id ??
                            context.read<UserProvider>().user?.id;
                        if (userId != null) _loadMoreCampfires(userId);
                      },
                icon: _loadingMoreCampfires
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: const Text('Load more Campfires'),
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionCard(
          context,
          icon: Icons.local_fire_department_rounded,
          title: 'Hosted Campfires',
          body: const [
            Text(
              'Live, upcoming and past Campfires appear here. Published recordings are shown only when the host enables them.',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _campfireProfileRow(
          context,
          Icons.podcasts_rounded,
          'Live now',
          'Active Campfires hosted by this profile',
        ),
        _campfireProfileRow(
          context,
          Icons.event_rounded,
          'Upcoming',
          'Scheduled Campfires and shareable invitations',
        ),
        _campfireProfileRow(
          context,
          Icons.history_rounded,
          'Past Campfires',
          'Previous sessions and their public summaries',
        ),
        _campfireProfileRow(
          context,
          Icons.ondemand_video_rounded,
          'Recordings',
          'Only recordings the host has chosen to publish',
        ),
      ],
    );
  }

  Widget _campfireProfileRow(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  Widget _talesTab(BuildContext context) {
    if (_loadingCampContent && _campTales.isEmpty) {
      return const _CampProfileLoadingSkeleton(tale: true);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.isPublic && _taleDrafts.isNotEmpty) ...[
          GriotBrandedContainer(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            borderRadius: 18,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: .35),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.drafts_outlined),
              title: const Text(
                'Tale drafts',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${_taleDrafts.length} saved draft${_taleDrafts.length == 1 ? '' : 's'}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/camp/tales/drafts'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_campTales.isNotEmpty)
          ..._campTales.asMap().entries.expand(
            (entry) => <Widget>[
              if (entry.key > 0) _taleSeparator(context),
              _taleCard(context, entry.value, canDelete: !widget.isPublic),
            ],
          )
        else
          _sectionCard(
            context,
            icon: Icons.menu_book_rounded,
            title: 'Published Tales',
            body: [
              Text(
                'Your public Tales will be collected here for readers to browse.',
              ),
              SizedBox(height: 14),
              _ProfileEmptyRow(
                icon: Icons.auto_stories_rounded,
                title: 'No published Tales yet',
                subtitle:
                    'Tales you publish with text, links or media will appear here.',
              ),
            ],
          ),
        if (_campTalesHasMore)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              onPressed: _loadingMoreTales
                  ? null
                  : () {
                      final userId =
                          widget.profileUser?.id ??
                          _loadedPublicUser?.id ??
                          context.read<UserProvider>().user?.id;
                      if (userId != null) {
                        _loadCampContent(userId, nextPage: true);
                      }
                    },
              icon: _loadingMoreTales
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: const Text('Load more Tales'),
            ),
          ),
      ],
    );
  }

  Widget _activityTab(BuildContext context) {
    final filters = ['All', 'Tales', 'Campfires', 'Comments', 'Saved'];
    final filteredActivity = _campActivity
        .where((item) {
          if (_activityFilter == 'All') return true;
          final type = '${item['type'] ?? ''}'.toLowerCase();
          final filter = _activityFilter.toLowerCase();
          if (filter == 'tales') return type == 'tale' || type == 'post';
          if (filter == 'campfires') {
            return type == 'campfire' || type == 'space';
          }
          if (filter == 'comments') return type == 'comment' || type == 'reply';
          return type == filter;
        })
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Interactions',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            if (!widget.isPublic)
              TextButton.icon(
                onPressed: () => context.push('/camp/tales/bookmarks'),
                icon: const Icon(Icons.bookmark_border_rounded, size: 18),
                label: const Text('Bookmarks'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters
                .map(
                  (filter) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: _activityFilter == filter,
                      onSelected: (_) =>
                          setState(() => _activityFilter = filter),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 10),
        if (filteredActivity.isNotEmpty)
          ...filteredActivity.asMap().entries.expand(
            (entry) => <Widget>[_activityItem(context, entry.value)],
          ),
        if (filteredActivity.isEmpty)
          _sectionCard(
            context,
            icon: Icons.forum_outlined,
            title: _activityFilter == 'All'
                ? 'Recent activity'
                : '$_activityFilter activity',
            body: [
              Text(
                _activityFilter == 'Saved'
                    ? 'Tales and Campfires you pin to your Camp list will be collected here. Private bookmarks are available separately.'
                    : 'Tales, Campfires, comments and replies will appear here as you interact across Griot Camp.',
              ),
              SizedBox(height: 14),
              _ProfileEmptyRow(
                icon: Icons.inbox_rounded,
                title: 'Nothing to show yet',
                subtitle:
                    'Published Tales, Campfires, comments, replies and saved items will be listed here.',
              ),
            ],
          ),
      ],
    );
  }

  Widget _taleSeparator(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: .42),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: .42),
            ),
          ),
        ],
      ),
    );
  }

  String _taleTime(dynamic value) {
    final date = value is DateTime ? value : DateTime.tryParse('$value');
    if (date == null) return '';
    final difference = DateTime.now().difference(date.toLocal());
    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return '${date.day}/${date.month}/${date.year}';
  }

  String? _taleMediaUrl(dynamic value) {
    if (value is Map) {
      value =
          value['url'] ??
          value['mediaUrl'] ??
          value['media_url'] ??
          value['downloadUrl'] ??
          value['download_url'] ??
          value['thumbnailUrl'] ??
          value['thumbnail_url'];
    }
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    // Older Tale records may contain either a media UUID or a relative
    // `/api/media/...` path. Normalize both forms so every gallery item gets
    // a valid absolute URL instead of silently rendering a blank tile.
    final looksLikeId = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(raw);
    if (looksLikeId) return '${ApiConfig.baseUrl}/media/$raw';
    final path = raw.startsWith('/') ? raw : '/$raw';
    return '${ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '')}$path';
  }

  List<String> _taleMediaUrls(Map<String, dynamic> tale) {
    dynamic raw =
        tale['mediaUrls'] ??
        tale['media_urls'] ??
        tale['media'] ??
        tale['attachments'];
    if (raw is Map) {
      raw = raw['items'] ?? raw['media'] ?? raw['attachments'] ?? raw['urls'];
    }
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        raw = const [];
      }
    }
    final urls = raw is List
        ? raw.map(_taleMediaUrl).whereType<String>().toSet().toList()
        : <String>[];
    final single = _taleMediaUrl(tale['mediaUrl'] ?? tale['media_url']);
    return <String>[
      ...?single == null ? null : <String>[single],
      ...urls.where((url) => url != single),
    ];
  }

  Widget _profileThreadParts(
    BuildContext context,
    List<Map<String, dynamic>> parts,
    String threadKey,
  ) {
    final first = parts.first;
    final firstContent = '${first['content'] ?? ''}'.trim();
    final firstMedia = _taleMediaUrls(first);
    final expanded = _expandedProfileThreads.contains(threadKey);
    final visibleParts = expanded
        ? parts.skip(1).toList()
        : const <Map<String, dynamic>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Part 1 is the canonical Tale card and must remain visible when the
        // reader is expanded. Expanding only appends the continuation parts;
        // it must never replace the opening part or its media.
        if (firstContent.isNotEmpty)
          CampTaleText(
            key: ValueKey('text-$threadKey-0'),
            text: firstContent,
            fontSize: 17,
          ),
        if (firstMedia.isNotEmpty) ...[
          const SizedBox(height: 12),
          _campTaleMediaGallery(context, firstMedia),
        ],
        if (expanded) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Reading this Tale',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${parts.length} parts',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        ...visibleParts.asMap().entries.map((entry) {
          final index = entry.key;
          final part = entry.value;
          final partNumber = expanded ? index + 2 : index + 1;
          final partContent = '${part['content'] ?? ''}'.trim();
          final partMedia = _taleMediaUrls(part);
          return CampTaleThreadRail(
            isLast: index == visibleParts.length - 1,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: index == visibleParts.length - 1 ? 0 : 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Part $partNumber of ${parts.length}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (partContent.isNotEmpty)
                    CampTaleText(
                      key: ValueKey('text-$threadKey-$partNumber'),
                      text: partContent,
                      fontSize: partNumber == 1 ? 17 : 15,
                    ),
                  if (partMedia.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _campTaleMediaGallery(context, partMedia),
                  ],
                ],
              ),
            ),
          );
        }),
        if (parts.length > 1) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                if (expanded) {
                  _expandedProfileThreads.remove(threadKey);
                } else {
                  _expandedProfileThreads.add(threadKey);
                }
              }),
              icon: Icon(
                expanded ? Icons.expand_less : Icons.account_tree_outlined,
                size: 18,
              ),
              label: Text(
                expanded
                    ? 'Show fewer parts'
                    : 'View all ${parts.length} parts',
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _taleCard(
    BuildContext context,
    Map<String, dynamic> tale, {
    required bool canDelete,
  }) {
    final colors = Theme.of(context).colorScheme;
    final taleId = (tale['id'] ?? tale['tale_id'] ?? tale['taleId'])
        ?.toString();
    final threadId = (tale['threadId'] ?? tale['thread_id'])?.toString();
    final threadCount =
        int.tryParse('${tale['threadCount'] ?? tale['thread_count'] ?? 1}') ??
        1;
    final retellCount =
        int.tryParse(
          '${tale['retellCount'] ?? tale['retell_count'] ?? tale['repostCount'] ?? tale['repost_count'] ?? 0}',
        ) ??
        0;
    final reshareCount = retellCount + (threadCount > 1 ? threadCount - 1 : 0);
    final threadPosition =
        int.tryParse(
          '${tale['threadPosition'] ?? tale['thread_position'] ?? 1}',
        ) ??
        1;
    final content = '${tale['content'] ?? tale['text'] ?? ''}'.trim();
    final threadParts = tale['threadParts'] is List
        ? (tale['threadParts'] as List)
              .map((part) {
                if (part is Map) {
                  final value = Map<String, dynamic>.from(part);
                  value['content'] =
                      '${value['content'] ?? value['text'] ?? ''}'.trim();
                  return value;
                }
                return <String, dynamic>{'content': '$part'.trim()};
              })
              .where((part) => '${part['content'] ?? ''}'.trim().isNotEmpty)
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final retellSource =
        '${tale['retellSourceContent'] ?? tale['retell_source_content'] ?? ''}'
            .trim();
    final isRetell =
        '${tale['retellSourceId'] ?? tale['retell_of_tale_id'] ?? ''}'
            .trim()
            .isNotEmpty;
    final threadOriginalAuthor =
        '${tale['threadOriginalAuthorName'] ?? tale['thread_original_author_name'] ?? ''}'
            .trim();
    final threadOriginalAuthorId =
        (tale['threadOriginalAuthorId'] ?? tale['thread_original_author_id'])
            ?.toString();
    final threadOriginalAuthorAvatar =
        (tale['threadOriginalAuthorAvatarUrl'] ??
                tale['thread_original_author_avatar_url'])
            ?.toString();
    final comments = tale['comment_count'] ?? tale['commentCount'] ?? 0;
    final viewCount =
        int.tryParse(
          '${tale['viewCount'] ?? tale['view_count'] ?? tale['views'] ?? 0}',
        ) ??
        0;
    final category = '${tale['category'] ?? 'Personal'}';
    final nestedAuthor = tale['author'] is Map
        ? Map<String, dynamic>.from(tale['author'] as Map)
        : const <String, dynamic>{};
    final authorName =
        '${nestedAuthor['displayName'] ?? nestedAuthor['display_name'] ?? tale['display_name'] ?? tale['displayName'] ?? tale['author_name'] ?? tale['username'] ?? 'Griot user'}';
    final authorId =
        (nestedAuthor['id'] ??
                nestedAuthor['userId'] ??
                nestedAuthor['user_id'] ??
                tale['authorId'] ??
                tale['author_id'] ??
                tale['user_id'])
            ?.toString();
    final avatarUrl =
        (nestedAuthor['avatarUrl'] ??
                nestedAuthor['avatar_url'] ??
                tale['avatar_url'] ??
                tale['avatarUrl'])
            ?.toString();
    final authorIsPlus =
        nestedAuthor['isPlus'] == true ||
        nestedAuthor['is_plus'] == true ||
        tale['authorIsPlus'] == true ||
        tale['author_is_plus'] == true;
    final authorIsPioneer =
        nestedAuthor['isPioneer'] == true ||
        nestedAuthor['is_pioneer'] == true ||
        tale['authorIsPioneer'] == true ||
        tale['author_is_pioneer'] == true;
    final mediaUrls = _taleMediaUrls(tale);
    final media = mediaUrls.isNotEmpty;
    final authorUsername =
        '${nestedAuthor['username'] ?? tale['username'] ?? ''}'.trim();
    final createdAt = tale['created_at'] ?? tale['createdAt'];
    final viewerId = context.read<UserProvider>().user?.id;
    final isAuthor =
        canDelete ||
        (authorId != null && viewerId != null && authorId == viewerId);
    final isProfilePinned =
        (tale['isPinned'] == true) ||
        (taleId != null && _profilePinnedTaleIds.contains(taleId));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CampTaleCardSurface(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: taleId == null || taleId.isEmpty
              ? null
              : () => context.push('/tale/$taleId', extra: tale),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CampTaleHeader(
                authorName: authorName,
                avatarUrl: avatarUrl,
                isPlus: authorIsPlus,
                isPioneer: authorIsPioneer,
                inlineBadges: [
                  if (category.trim().isNotEmpty)
                    _campTaleBadge(
                      context,
                      category,
                      colors.surfaceContainerHighest,
                      foreground: colors.onSurfaceVariant,
                    ),
                  if (threadCount > 1)
                    _campTaleBadge(
                      context,
                      'Part $threadPosition/$threadCount',
                      colors.surfaceContainerHighest,
                      foreground: colors.onSurfaceVariant,
                    ),
                  if (isProfilePinned)
                    _campTaleBadge(
                      context,
                      'Pinned',
                      colors.primary.withValues(alpha: .16),
                      foreground: colors.primary,
                    ),
                ],
                subtitle: [
                  if (authorUsername.isNotEmpty) '@$authorUsername',
                  if (createdAt != null) _taleTime(createdAt),
                  if (isRetell && retellSource.isNotEmpty)
                    'Originally by ${_retellAuthorName(tale) ?? 'the original creator'}',
                  if (!isRetell &&
                      threadPosition > 1 &&
                      threadOriginalAuthor.isNotEmpty)
                    'Started by $threadOriginalAuthor',
                ].join(' · '),
                onAuthorTap: authorId == null || authorId.isEmpty
                    ? null
                    : () => _openAuthorCampProfile(authorId),
                menu: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 24,
                  offset: const Offset(0, 42),
                  useRootNavigator: true,
                  tooltip: 'Tale options',
                  onSelected: (value) {
                    if (value == 'pin' && taleId != null) {
                      _toggleProfilePin(taleId);
                    } else if (value == 'copy' && taleId != null) {
                      Clipboard.setData(
                        ClipboardData(
                          text: 'https://griot.network/tale/$taleId',
                        ),
                      );
                      NotificationService.showInfo(
                        context,
                        'Tale link copied.',
                      );
                    } else if (value == 'delete') {
                      _deleteTale(tale);
                    } else if (value == 'retell') {
                      _retellCampTale(tale);
                    } else if (value == 'cotell' &&
                        threadId != null &&
                        threadId.isNotEmpty) {
                      context.push(
                        '/campfires/tales/create',
                        extra: {
                          'initialThreadId': threadId,
                          'composerTitle': 'Co-tell this Tale',
                        },
                      );
                    } else if (value == 'continue' &&
                        threadId != null &&
                        threadId.isNotEmpty) {
                      context.push(
                        '/campfires/tales/create',
                        extra: {
                          'initialThreadId': threadId,
                          'composerTitle': 'Continue this Tale',
                        },
                      );
                    } else if (value == 'mute' && authorId != null) {
                      _muteCampAuthor(authorId);
                    } else if (value == 'block' && authorId != null) {
                      _blockCampAuthor(authorId);
                    } else if (value == 'report' && taleId != null) {
                      ReportContentSheet.show(
                        context: context,
                        targetType: 'tale',
                        targetId: taleId,
                        subjectLabel: 'Tale',
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    if (!widget.isPublic && isAuthor && taleId != null)
                      PopupMenuItem(
                        value: 'pin',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _profilePinnedTaleIds.contains(taleId)
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,
                          ),
                          title: Text(
                            _profilePinnedTaleIds.contains(taleId)
                                ? 'Unpin from profile'
                                : 'Pin to profile',
                          ),
                        ),
                      ),
                    if (taleId != null)
                      const PopupMenuItem(
                        value: 'copy',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.link_rounded),
                          title: Text('Copy Tale link'),
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'retell',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.repeat_rounded),
                        title: Text('Retell'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'cotell',
                      enabled: threadId != null && threadId.isNotEmpty,
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.link_rounded),
                        title: Text('Co-tell'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'continue',
                      enabled: threadId != null && threadId.isNotEmpty,
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.add_link_rounded),
                        title: Text('Continue this Tale'),
                      ),
                    ),
                    if (canDelete)
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Delete Tale'),
                        ),
                      ),
                    if (!isAuthor && authorId != null) ...[
                      const PopupMenuItem(
                        value: 'mute',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.volume_off_outlined),
                          title: Text('Mute this creator'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'block',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.block_outlined),
                          title: Text('Block this creator'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'report',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.flag_outlined),
                          title: Text('Report Tale'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 9),
              if (!isRetell &&
                  threadPosition > 1 &&
                  threadParts.isNotEmpty) ...[
                CampTaleReshareCard(
                  label: 'Co-telling · Original Tale',
                  sourceAuthorName: threadOriginalAuthor,
                  sourceAuthorAvatarUrl: threadOriginalAuthorAvatar,
                  sourceText: '${threadParts.first['content'] ?? ''}'.trim(),
                  sourceMediaUrls: threadParts.first['mediaUrls'] is List
                      ? (threadParts.first['mediaUrls'] as List)
                            .map((value) => value.toString())
                            .toList()
                      : const [],
                  onAuthorTap: threadOriginalAuthorId == null
                      ? null
                      : () => _openAuthorCampProfile(threadOriginalAuthorId),
                  onSourceTap: threadId == null
                      ? null
                      : () => context.push('/tale/$threadId'),
                  mediaBuilder: (context, urls) =>
                      _campTaleMediaGallery(context, urls),
                ),
                const SizedBox(height: 10),
              ],
              if (threadParts.length > 1)
                _profileThreadParts(
                  context,
                  threadParts,
                  threadId ?? taleId ?? 'thread-$createdAt',
                )
              else if (content.isNotEmpty)
                CampTaleText(key: ValueKey('text-$taleId'), text: content),
              if (isRetell) ...[
                if (content.isNotEmpty) const SizedBox(height: 10),
                _retellReferenceCard(context, tale, retellSource),
              ],
              if (content.isEmpty && !isRetell)
                const Text(
                  'Untitled Tale',
                  style: TextStyle(fontSize: 16, height: 1.35),
                ),
              if (threadParts.length <= 1 && media) ...[
                const SizedBox(height: 12),
                _campTaleMediaGallery(context, mediaUrls),
              ],
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: .35),
              ),
              if (viewCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 15,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$viewCount ${viewCount == 1 ? 'view' : 'views'}',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  ...(() {
                    final viewerUpvoted =
                        tale['viewerUpvoted'] == true ||
                        tale['viewer_upvoted'] == true ||
                        (tale['viewerVote'] ?? tale['viewer_vote']) == 1;
                    final viewerDownvoted =
                        tale['viewerDownvoted'] == true ||
                        tale['viewer_downvoted'] == true ||
                        (tale['viewerVote'] ?? tale['viewer_vote']) == -1;
                    return <Widget>[
                      Expanded(
                        child: _campTaleAction(
                          context,
                          icon: viewerUpvoted
                              ? Icons.thumb_up_alt_rounded
                              : Icons.thumb_up_alt_outlined,
                          label:
                              '${tale['likeCount'] ?? tale['upvote_count'] ?? 0}',
                          tooltip: 'Like Tale',
                          active: viewerUpvoted,
                          onTap: taleId == null
                              ? null
                              : () => _voteCampTale(
                                  tale,
                                  viewerUpvoted ? 'remove_up' : 'up',
                                ),
                        ),
                      ),
                      Expanded(
                        child: _campTaleAction(
                          context,
                          icon: viewerDownvoted
                              ? Icons.thumb_down_alt_rounded
                              : Icons.thumb_down_alt_outlined,
                          label:
                              '${tale['downvoteCount'] ?? tale['downvote_count'] ?? 0}',
                          tooltip: 'Dislike Tale',
                          active: viewerDownvoted,
                          activeColor: colors.error,
                          onTap: taleId == null
                              ? null
                              : () => _voteCampTale(
                                  tale,
                                  viewerDownvoted ? 'remove_down' : 'down',
                                ),
                        ),
                      ),
                      Expanded(
                        child: _campTaleAction(
                          context,
                          icon: Icons.repeat_rounded,
                          label: '$reshareCount',
                          tooltip: 'Retell or Co-tell',
                          onTap: taleId == null
                              ? null
                              : () => _showCampTaleActions(tale),
                        ),
                      ),
                      Expanded(
                        child: _campTaleAction(
                          context,
                          icon: Icons.volunteer_activism_outlined,
                          label: '',
                          tooltip: 'Tip creator',
                          onTap: () {
                            final creator =
                                _loadedPublicUser ?? widget.profileUser;
                            if (creator == null) {
                              NotificationService.showInfo(
                                context,
                                'Creator details are still loading.',
                              );
                              return;
                            }
                            _tipCampCreator(creator);
                          },
                        ),
                      ),
                      Expanded(
                        child: _campTaleAction(
                          context,
                          icon: Icons.ios_share_rounded,
                          label: '',
                          tooltip: 'Share Tale',
                          onTap: taleId == null
                              ? null
                              : () => SharePlus.instance.share(
                                  ShareParams(
                                    text:
                                        'Read this Tale on Griot:\nhttps://griot.network/tale/$taleId',
                                  ),
                                ),
                        ),
                      ),
                    ];
                  })(),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: _campTaleAction(
                  context,
                  icon: Icons.forum_outlined,
                  label: '$comments Comments',
                  tooltip: 'Comments',
                  onTap: taleId == null
                      ? null
                      : () => context.push('/tale/$taleId', extra: tale),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAuthorCampProfile(String authorId) {
    final ownId = context.read<UserProvider>().user?.id;
    if (ownId == authorId) {
      context.push('/camp/profile');
    } else {
      context.push('/camp/profile/$authorId');
    }
  }

  Widget _retellReferenceCard(
    BuildContext context,
    Map<String, dynamic> tale,
    String source,
  ) {
    final authorName = _retellAuthorName(tale);
    final authorId = _retellAuthorId(tale);
    final authorAvatar = _retellAuthorAvatar(tale);
    final sourceMap = tale['retellSource'] is Map
        ? Map<String, dynamic>.from(tale['retellSource'] as Map)
        : const <String, dynamic>{};
    final sourceAuthorMap = sourceMap['author'] is Map
        ? Map<String, dynamic>.from(sourceMap['author'] as Map)
        : const <String, dynamic>{};
    final authorUsername =
        '${tale['retellSourceAuthorUsername'] ?? tale['retell_source_author_username'] ?? sourceMap['authorUsername'] ?? sourceAuthorMap['username'] ?? ''}'
            .trim();
    final sourceId =
        '${tale['retellSourceId'] ?? tale['retell_source_id'] ?? ''}'.trim();
    return CampTaleReshareCard(
      sourceTaleId: sourceId.isEmpty ? null : sourceId,
      sourceAuthorName: authorName ?? '',
      sourceAuthorUsername: authorUsername.isEmpty ? null : authorUsername,
      sourceAuthorIsPlus:
          tale['retellSourceAuthorIsPlus'] == true ||
          tale['retell_source_author_is_plus'] == true ||
          sourceMap['authorIsPlus'] == true ||
          sourceAuthorMap['isPlus'] == true ||
          sourceAuthorMap['is_plus'] == true,
      sourceAuthorIsPioneer:
          tale['retellSourceAuthorIsPioneer'] == true ||
          tale['retell_source_author_is_pioneer'] == true ||
          sourceMap['authorIsPioneer'] == true ||
          sourceAuthorMap['isPioneer'] == true ||
          sourceAuthorMap['is_pioneer'] == true,
      sourceAuthorAvatarUrl: authorAvatar,
      sourceText: source.isEmpty ? 'Original Tale' : source,
      sourceMediaUrls: _retellSourceMediaUrls(tale),
      onAuthorTap: authorId == null
          ? null
          : () => _openAuthorCampProfile(authorId),
      onSourceTap: sourceId.isEmpty
          ? null
          : () => context.push('/tale/$sourceId'),
      mediaBuilder: (context, urls) => _campTaleMediaGallery(context, urls),
    );
  }

  List<String> _retellSourceMediaUrls(Map<String, dynamic> tale) {
    final source = tale['retellSource'] is Map
        ? Map<String, dynamic>.from(tale['retellSource'] as Map)
        : const <String, dynamic>{};
    final raw =
        tale['retellSourceMediaUrls'] ??
        tale['retell_source_media_urls'] ??
        source['mediaUrls'] ??
        source['media_urls'];
    final urls = raw is List
        ? raw
              .map((value) => value?.toString().trim())
              .where((value) => value != null && value.isNotEmpty)
              .cast<String>()
              .toList()
        : <String>[];
    final single =
        (tale['retellSourceMediaUrl'] ??
                tale['retell_source_media_url'] ??
                source['mediaUrl'] ??
                source['media_url'])
            ?.toString()
            .trim();
    if (single != null && single.isNotEmpty && !urls.contains(single)) {
      urls.insert(0, single);
    }
    return urls;
  }

  String? _retellAuthorName(Map<String, dynamic> tale) {
    final value =
        tale['retellSourceAuthorName'] ??
        tale['retell_source_author_name'] ??
        (tale['retellSource'] is Map
            ? (tale['retellSource'] as Map)['authorName'] ??
                  (tale['retellSource'] as Map)['author_name']
            : null);
    final name = value?.toString().trim();
    return name == null || name.isEmpty ? null : name;
  }

  String? _retellAuthorId(Map<String, dynamic> tale) {
    final source = tale['retellSource'] is Map
        ? Map<String, dynamic>.from(tale['retellSource'] as Map)
        : const <String, dynamic>{};
    final author = source['author'] is Map
        ? Map<String, dynamic>.from(source['author'] as Map)
        : const <String, dynamic>{};
    final value =
        tale['retellSourceAuthorId'] ??
        tale['retell_source_author_id'] ??
        source['authorId'] ??
        source['author_id'] ??
        author['id'] ??
        author['userId'] ??
        author['user_id'];
    final id = value?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  String? _retellAuthorAvatar(Map<String, dynamic> tale) {
    final source = tale['retellSource'] is Map
        ? Map<String, dynamic>.from(tale['retellSource'] as Map)
        : const <String, dynamic>{};
    final author = source['author'] is Map
        ? Map<String, dynamic>.from(source['author'] as Map)
        : const <String, dynamic>{};
    final value =
        tale['retellSourceAuthorAvatarUrl'] ??
        tale['retell_source_author_avatar_url'] ??
        source['authorAvatarUrl'] ??
        source['author_avatar_url'] ??
        author['avatarUrl'] ??
        author['avatar_url'];
    final avatar = value?.toString().trim();
    return avatar == null || avatar.isEmpty ? null : avatar;
  }

  Widget _campTaleMediaGallery(BuildContext context, List<String> urls) {
    final token = context.read<AuthController>().accessToken;
    return CampTaleMediaGallery(
      urls: urls,
      headers: token == null || token.isEmpty
          ? null
          : <String, String>{'Authorization': 'Bearer $token'},
      onOpen: (index) => _showCampMediaPreview(context, urls, index),
    );
  }

  void _showCampMediaPreview(
    BuildContext context,
    List<String> urls,
    int initialIndex,
  ) {
    if (urls.isEmpty) return;
    final token = context.read<AuthController>().accessToken;
    final headers = token == null || token.isEmpty
        ? null
        : <String, String>{'Authorization': 'Bearer $token'};
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .92),
      builder: (dialogContext) {
        final controller = PageController(initialPage: initialIndex);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(dialogContext).height * .78,
                child: PageView.builder(
                  controller: controller,
                  itemCount: urls.length,
                  itemBuilder: (_, index) => InteractiveViewer(
                    minScale: .8,
                    maxScale: 4,
                    child: Center(
                      child: GriotFeedMedia(
                        url: urls[index],
                        headers: headers,
                        fit: BoxFit.contain,
                        cacheWidth: 1800,
                        cacheHeight: 1800,
                        errorIcon: Icons.broken_image_outlined,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _campTaleAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback? onTap,
    bool active = false,
    Color? activeColor,
  }) {
    return CampTaleActionButton(
      icon: icon,
      label: label,
      tooltip: tooltip,
      onTap: onTap,
      active: active,
      activeColor: activeColor,
    );
  }

  Widget _campTaleBadge(
    BuildContext context,
    String label,
    Color background, {
    Color? foreground,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 94),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground ?? colors.onSurfaceVariant,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }

  Future<void> _showCampTaleActions(Map<String, dynamic> tale) async {
    final retellCount =
        int.tryParse(
          '${tale['retellCount'] ?? tale['retell_count'] ?? tale['repostCount'] ?? tale['repost_count'] ?? 0}',
        ) ??
        0;
    final threadCount =
        int.tryParse('${tale['threadCount'] ?? tale['thread_count'] ?? 1}') ??
        1;
    final coTellCount = threadCount > 1 ? threadCount - 1 : 0;
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.repeat_rounded),
              title: Text('Retell ($retellCount)'),
              onTap: () => Navigator.pop(sheetContext, 'retell'),
            ),
            ListTile(
              enabled: (tale['threadId'] ?? tale['thread_id']) != null,
              leading: const Icon(Icons.link_rounded),
              title: Text('Co-tell ($coTellCount)'),
              onTap: (tale['threadId'] ?? tale['thread_id']) == null
                  ? null
                  : () => Navigator.pop(sheetContext, 'cotell'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    final taleId = tale['id']?.toString();
    if (taleId == null || taleId.isEmpty) return;
    final content = '${tale['content'] ?? tale['text'] ?? ''}';
    if (choice == 'retell') {
      await _retellCampTale(tale);
    } else if (choice == 'cotell') {
      await context.push(
        '/campfires/tales/create',
        extra: {
          'initialThreadId': (tale['threadId'] ?? tale['thread_id']).toString(),
          'initialReferenceText': content,
          'initialReferenceLabel': 'Co-telling this Tale',
          'initialReferenceMediaUrls': _taleMediaUrls(tale),
          'composerTitle': 'Co-tell this Tale',
        },
      );
    }
  }

  Future<void> _retellCampTale(Map<String, dynamic> tale) async {
    final taleId = tale['id']?.toString();
    if (taleId == null || taleId.isEmpty) return;
    await context.push(
      '/campfires/tales/create',
      extra: {
        'initialReferenceText': '${tale['content'] ?? tale['text'] ?? ''}'
            .trim(),
        'initialReferenceLabel':
            'Retelling · ${_retellAuthorName(tale) ?? 'another creator'}',
        'initialReferenceMediaUrls': _taleMediaUrls(tale),
        'composerTitle': 'Retell this Tale',
        'initialRetellOfTaleId': taleId,
      },
    );
    if (mounted) {
      await _loadCampProfile(
        userId: widget.profileUser?.id ?? context.read<UserProvider>().user?.id,
      );
    }
  }

  Future<void> _voteCampTale(Map<String, dynamic> tale, String? vote) async {
    final taleId = tale['id']?.toString();
    if (taleId == null || taleId.isEmpty) return;
    try {
      final result = await context.read<MessagingApiService>().voteOnTale(
        taleId,
        vote: vote,
      );
      if (!mounted) return;
      setState(() {
        final index = _campTales.indexWhere(
          (item) => item['id']?.toString() == taleId,
        );
        if (index == -1) return;
        final updated = Map<String, dynamic>.from(_campTales[index]);
        updated['likeCount'] =
            result['upvoteCount'] ?? result['upvote_count'] ?? 0;
        updated['downvoteCount'] =
            result['downvoteCount'] ?? result['downvote_count'] ?? 0;
        if (result.containsKey('viewerUpvoted') ||
            result.containsKey('viewer_upvoted')) {
          updated['viewerUpvoted'] =
              result['viewerUpvoted'] == true ||
              result['viewer_upvoted'] == true;
        }
        if (result.containsKey('viewerDownvoted') ||
            result.containsKey('viewer_downvoted')) {
          updated['viewerDownvoted'] =
              result['viewerDownvoted'] == true ||
              result['viewer_downvoted'] == true;
        }
        final up =
            updated['viewerUpvoted'] == true ||
            updated['viewer_upvoted'] == true;
        final down =
            updated['viewerDownvoted'] == true ||
            updated['viewer_downvoted'] == true;
        updated['viewerVote'] = up && !down
            ? 1
            : down && !up
            ? -1
            : 0;
        _campTales[index] = updated;
      });
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not update Tale reaction: $error',
        );
      }
    }
  }

  Widget _campfireCard(BuildContext context, Map<String, dynamic> campfire) {
    final status = '${campfire['status'] ?? 'past'}';
    final campfireId =
        (campfire['id'] ?? campfire['space_id'] ?? campfire['spaceId'])
            ?.toString();
    final author = campfire['host'] is Map
        ? Map<String, dynamic>.from(campfire['host'] as Map)
        : campfire['creator'] is Map
        ? Map<String, dynamic>.from(campfire['creator'] as Map)
        : const <String, dynamic>{};
    final authorId =
        (author['id'] ??
                author['userId'] ??
                author['user_id'] ??
                campfire['host_id'] ??
                campfire['hostId'] ??
                campfire['creator_id'] ??
                campfire['creatorId'] ??
                campfire['user_id'])
            ?.toString();
    final viewerId = context.read<UserProvider>().user?.id;
    final isAuthor =
        authorId != null && viewerId != null && authorId == viewerId;
    final saved = _isCampContentSaved('campfire', campfireId);
    return CampTaleCardSurface(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          Icons.local_fire_department_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          '${campfire['title'] ?? 'Campfire'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(status[0].toUpperCase() + status.substring(1)),
        trailing: PopupMenuButton<String>(
          tooltip: 'Campfire options',
          onSelected: (value) {
            if (value == 'save' && campfireId != null) {
              _toggleCampContentSave(
                targetType: 'campfire',
                targetId: campfireId,
              );
            } else if (value == 'copy' && campfireId != null) {
              Clipboard.setData(
                ClipboardData(
                  text: 'https://griot.network/campfires/$campfireId',
                ),
              );
              NotificationService.showInfo(context, 'Campfire link copied.');
            } else if (value == 'mute' && authorId != null) {
              _muteCampAuthor(authorId);
            } else if (value == 'block' && authorId != null) {
              _blockCampAuthor(authorId);
            } else if (value == 'report' && campfireId != null) {
              ReportContentSheet.show(
                context: context,
                targetType: 'campfire',
                targetId: campfireId,
                subjectLabel: 'Campfire',
              );
            }
          },
          itemBuilder: (_) => [
            if (!widget.isPublic && campfireId != null)
              PopupMenuItem(
                value: 'save',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    saved ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  ),
                  title: Text(
                    saved ? 'Unpin from Camp list' : 'Pin to Camp list',
                  ),
                ),
              ),
            if (campfireId != null)
              const PopupMenuItem(
                value: 'copy',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.link_rounded),
                  title: Text('Copy Campfire link'),
                ),
              ),
            if (!isAuthor && authorId != null) ...[
              const PopupMenuItem(
                value: 'mute',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.volume_off_outlined),
                  title: Text('Mute this creator'),
                ),
              ),
              const PopupMenuItem(
                value: 'block',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.block_outlined),
                  title: Text('Block this creator'),
                ),
              ),
              if (campfireId != null)
                const PopupMenuItem(
                  value: 'report',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.flag_outlined),
                    title: Text('Report Campfire'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _activityItem(BuildContext context, Map<String, dynamic> item) {
    final type = '${item['type'] ?? 'activity'}'.toLowerCase();
    final entityId = item['entity_id']?.toString();
    final savedTarget = type == 'saved'
        ? '${item['summary'] ?? ''}'.toLowerCase()
        : type.toLowerCase();
    final isTale = savedTarget == 'tale' || savedTarget == 'post';
    final isCampfire = savedTarget == 'campfire' || savedTarget == 'space';
    final isComment = savedTarget == 'comment' || savedTarget == 'reply';
    final icon = isTale
        ? Icons.menu_book_rounded
        : isCampfire
        ? Icons.local_fire_department_rounded
        : isComment
        ? Icons.chat_bubble_outline_rounded
        : type == 'saved'
        ? Icons.bookmark_border_rounded
        : Icons.forum_outlined;
    final label = isTale
        ? 'Tale'
        : isCampfire
        ? 'Campfire'
        : isComment
        ? 'Comment'
        : type == 'saved'
        ? 'Saved'
        : 'Interaction';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(
          type == 'saved'
              ? 'Saved ${isCampfire ? 'Campfire' : 'Tale'}'
              : '${item['summary'] ?? 'Activity'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(type == 'saved' ? 'Saved to your Camp list' : label),
        trailing: (isTale || isCampfire || isComment) && entityId != null
            ? const Icon(Icons.chevron_right_rounded)
            : null,
        onTap: entityId == null
            ? null
            : isTale
            ? () => context.push('/tale/$entityId')
            : isCampfire
            ? () => context.push('/campfires')
            : isComment
            ? () => context.push('/tale/$entityId')
            : null,
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> body,
  }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...body,
          ],
        ),
      ),
    );
  }

  Widget _reputationBadge(
    BuildContext context,
    UserReputationBadge reputation,
  ) {
    final badgeColor = AppColors.parseHexColor(reputation.badgeColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .35)),
      ),
      child: const Icon(
        Icons.workspace_premium_rounded,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  String _campCount(String key) {
    final value = _campProfile?[key];
    if (value is num) return value.toInt().toString();
    return '0';
  }

  void _openConnections(String type, UserModel? user) {
    final id = user?.id ?? widget.profileIdentifier;
    if (id == null) return;
    context.push('/camp/profile/${Uri.encodeComponent(id)}/$type');
  }

  // Kept for compatibility with older Camp Profile data; editing now lives
  // in the main Account settings screen.
  // ignore: unused_element
  Future<void> _editCampBio() async {
    final controller = TextEditingController(
      text: _campProfile?['camp_bio']?.toString() ?? '',
    );
    final value = await showModalBottomSheet<String?>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * .82,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border(
                      top: BorderSide(color: colors.primary, width: 1.5),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.onSurfaceVariant.withValues(
                              alpha: .25,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.local_fire_department_rounded,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Camp bio',
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Tell people what your Camp Profile is about',
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, _) => TextField(
                          controller: controller,
                          autofocus: true,
                          maxLength: 280,
                          minLines: 4,
                          maxLines: 7,
                          textCapitalization: TextCapitalization.sentences,
                          buildCounter:
                              (
                                _, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) => null,
                          decoration: InputDecoration(
                            hintText:
                                'What should visitors know about this Camp?',
                            filled: true,
                            fillColor: colors.surfaceContainerHighest
                                .withValues(alpha: .45),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            counterText: '${value.text.length}/280',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => Navigator.pop(
                                sheetContext,
                                controller.text.trim(),
                              ),
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text('Save bio'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    controller.dispose();
    if (value == null || !mounted) return;
    try {
      final updated = await MessagingApiService(
        apiClient: context.read<ApiClient>(),
      ).updateCampProfile(bio: value);
      if (mounted) {
        setState(
          () =>
              _campProfile = {...?_campProfile, ...updated, 'camp_bio': value},
        );
      }
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not save Camp Profile bio: $error',
        );
      }
    }
  }

  Future<void> _shareCampProfile(UserModel? user) async {
    final id = user?.id ?? widget.profileIdentifier;
    if (id == null) return;
    final name = user?.effectiveName ?? 'Camp Profile';
    final link =
        'https://griot.network/camp/profile/${Uri.encodeComponent(id)}';
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'View $name on Griot Camp:\n$link',
          subject: 'Griot Camp Profile',
        ),
      );
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not share Camp Profile: $error',
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    final id = _loadedPublicUser?.id ?? widget.profileUser?.id;
    if (id == null || _updatingFollow) return;
    final currentlyFollowing = _campProfile?['is_following'] == true;
    setState(() => _updatingFollow = true);
    try {
      final service = MessagingApiService(apiClient: context.read<ApiClient>());
      if (currentlyFollowing) {
        await service.unfollowCampProfile(id);
      } else {
        await service.followCampProfile(id);
      }
      if (mounted) {
        setState(() {
          _campProfile = {
            ...?_campProfile,
            'is_following': !currentlyFollowing,
            'followers':
                ((_campProfile?['followers'] as num?)?.toInt() ?? 0) +
                (currentlyFollowing ? -1 : 1),
          };
        });
      }
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not update following: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _updatingFollow = false);
    }
  }

  Widget _stat(
    BuildContext context,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: onTap == null ? colors.primary : colors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileEmptyRow extends StatelessWidget {
  const _ProfileEmptyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
    );
  }
}

class _CampProfileLoadingSkeleton extends StatefulWidget {
  const _CampProfileLoadingSkeleton({required this.tale});

  final bool tale;

  @override
  State<_CampProfileLoadingSkeleton> createState() =>
      _CampProfileLoadingSkeletonState();
}

class _CampProfileLoadingSkeletonState
    extends State<_CampProfileLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = (_controller.value * 2) - .5;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.2 + progress, 0),
            end: Alignment(progress + 1.2, 0),
            colors: [
              colors.surfaceContainerHighest.withValues(alpha: .45),
              colors.surfaceContainerHighest.withValues(alpha: .9),
              colors.surfaceContainerHighest.withValues(alpha: .45),
            ],
          ).createShader(bounds),
          child: child,
        );
      },
      child: Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GriotBrandedContainer(
              padding: widget.tale
                  ? const EdgeInsets.fromLTRB(16, 14, 16, 16)
                  : const EdgeInsets.all(14),
              borderRadius: widget.tale ? 24 : 20,
              child: widget.tale
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _CampProfileSkeletonBlock(
                              width: 44,
                              height: 44,
                              radius: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _CampProfileSkeletonBlock(
                                    width: 142,
                                    height: 14,
                                  ),
                                  const SizedBox(height: 7),
                                  _CampProfileSkeletonBlock(
                                    width: 176,
                                    height: 10,
                                  ),
                                ],
                              ),
                            ),
                            _CampProfileSkeletonBlock(
                              width: 58,
                              height: 22,
                              radius: 11,
                            ),
                            const SizedBox(width: 8),
                            _CampProfileSkeletonBlock(
                              width: 22,
                              height: 22,
                              radius: 11,
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        Row(
                          children: [
                            _CampProfileSkeletonBlock(
                              width: 112,
                              height: 11,
                              radius: 6,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CampProfileSkeletonBlock(
                                width: double.infinity,
                                height: 1,
                                radius: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _CampProfileSkeletonBlock(
                          width: double.infinity,
                          height: 15,
                        ),
                        const SizedBox(height: 8),
                        _CampProfileSkeletonBlock(
                          width: double.infinity,
                          height: 15,
                        ),
                        const SizedBox(height: 8),
                        FractionallySizedBox(
                          widthFactor: .72,
                          child: _CampProfileSkeletonBlock(
                            width: double.infinity,
                            height: 15,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _CampProfileSkeletonBlock(
                          width: double.infinity,
                          height: 218,
                          radius: 18,
                        ),
                        const SizedBox(height: 12),
                        _CampProfileSkeletonBlock(
                          width: double.infinity,
                          height: 1,
                          radius: 1,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            5,
                            (_) => const _CampProfileSkeletonBlock(
                              width: 34,
                              height: 18,
                              radius: 9,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        _CampProfileSkeletonBlock(
                          width: 44,
                          height: 44,
                          radius: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _CampProfileSkeletonBlock(
                                width: double.infinity,
                                height: 14,
                              ),
                              const SizedBox(height: 9),
                              _CampProfileSkeletonBlock(width: 180, height: 11),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CampProfileSkeletonBlock extends StatelessWidget {
  const _CampProfileSkeletonBlock({
    required this.width,
    required this.height,
    this.radius = 7,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: SizedBox(width: width, height: height),
  );
}
