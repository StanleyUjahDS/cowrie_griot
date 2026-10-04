import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../iap/providers/iap_provider.dart';
import '../../iap/widgets/plus_required_dialog.dart';

import '../../../core/network/api_client.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';
import '../models/space_model.dart';
import '../providers/messaging_provider.dart';
import '../services/realtime_call_service.dart';
import '../services/messaging_api_service.dart';

/// Home for public Campfires and lightweight status updates.
///
/// Public Campfires are join-and-leave realtime rooms. Direct and group calls
/// remain invitation-based conversation calls.
class SpacesStatusScreen extends StatefulWidget {
  const SpacesStatusScreen({super.key});

  @override
  State<SpacesStatusScreen> createState() => _SpacesStatusScreenState();
}

class _SpacesStatusScreenState extends State<SpacesStatusScreen>
    with WidgetsBindingObserver {
  final List<SpaceModel> _spaces = [];
  final List<SpaceModel> _upcomingSpaces = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _feedScrollController = ScrollController();
  bool _loading = true;
  bool _hasMore = true;
  int _offset = 0;
  int _spacesRequestId = 0;
  int _campfireRevision = 0;
  String _region = 'GLOBAL';
  String? _error;
  String _searchQuery = '';
  late final FocusNode _searchFocusNode;
  Timer? _socketRefreshTimer;
  MessagingProvider? _messagingProvider;

  List<SpaceModel> _parseSpaces(Object? raw) {
    if (raw is! List) return <SpaceModel>[];
    final parsed = <SpaceModel>[];
    for (final value in raw) {
      if (value is! Map) continue;
      try {
        parsed.add(SpaceModel.fromJson(Map<String, dynamic>.from(value)));
      } catch (error) {
        debugPrint('Campfire item skipped: $error');
      }
    }
    return parsed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchFocusNode = FocusNode();
    _feedScrollController.addListener(_onFeedScroll);
    _messagingProvider = context.read<MessagingProvider>();
    _campfireRevision = _messagingProvider!.campfireRevision;
    _messagingProvider!.addListener(_onCampfireSocketEvent);
    _region = 'GLOBAL';
    // Discovery must start from the server so a newly created public
    // Campfire is visible immediately on every device.
    _loadSpaces(forceRefresh: true);
    _loadUpcomingSpaces(forceRefresh: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _feedScrollController.dispose();
    _socketRefreshTimer?.cancel();
    _messagingProvider?.removeListener(_onCampfireSocketEvent);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onCampfireSocketEvent() {
    final revision = _messagingProvider?.campfireRevision ?? _campfireRevision;
    if (!mounted || revision == _campfireRevision) return;
    _campfireRevision = revision;
    // Socket events can arrive in a burst (create + participant update +
    // status update). Coalesce them into one silent refresh and keep the
    // existing list mounted while the request is in flight. This prevents the
    // visible loading/flicker loop that polling caused.
    _socketRefreshTimer?.cancel();
    _socketRefreshTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || _searchQuery.trim().isNotEmpty) return;
      unawaited(_loadSpaces(forceRefresh: true, silent: true));
      unawaited(_loadUpcomingSpaces(forceRefresh: true));
    });
  }

  void _onFeedScroll() {
    if (!_feedScrollController.hasClients || _loading || !_hasMore || _searchQuery.trim().isNotEmpty) {
      return;
    }
    if (_feedScrollController.position.extentAfter < 500) {
      _loadSpaces(nextPage: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadSpaces(forceRefresh: true);
      _loadUpcomingSpaces(forceRefresh: true);
    }
  }

  Future<void> _loadUpcomingSpaces({bool forceRefresh = false}) async {
    try {
      final result = await context
          .read<MessagingApiService>()
          .getUpcomingCampfires(region: _region, forceRefresh: forceRefresh);
      final raw = result['items'] ?? result['spaces'] ?? [];
      if (!mounted || raw is! List) return;
      setState(() {
        _upcomingSpaces
          ..clear()
          ..addAll(
            raw.whereType<Map>().map(
              (item) => SpaceModel.fromJson(Map<String, dynamic>.from(item)),
            ),
          );
      });
    } catch (_) {
      // Upcoming Campfires are supplementary; live discovery remains usable.
    }
  }

  Future<void> _loadSpaces({
    bool nextPage = false,
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    if (!_hasMore && nextPage) return;
    final requestId = ++_spacesRequestId;
    final messagingApi = context.read<MessagingApiService>();
    if (mounted && !silent) setState(() => _loading = true);
    try {
      final result = await messagingApi.getActiveCampfires(
        limit: 20,
        offset: nextPage ? _offset : 0,
        region: _region,
        forceRefresh: forceRefresh,
      );
      var raw =
          result['items'] ??
          result['spaces'] ??
          result['campfires'] ??
          result['data'] ??
          [];
      var items = _parseSpaces(raw);
      var hasMore = result['hasMore'] == true || items.length == 20;

      // If regional filter returned no spaces, fall back to global campfires
      if (items.isEmpty && _region != 'GLOBAL' && !nextPage) {
        try {
          final globalResult = await messagingApi.getActiveCampfires(
            limit: 20,
            offset: 0,
            region: 'GLOBAL',
            forceRefresh: forceRefresh,
          );
          final globalRaw =
              globalResult['items'] ??
              globalResult['spaces'] ??
              globalResult['campfires'] ??
              globalResult['data'] ??
              [];
          if (globalRaw is List) {
            items = _parseSpaces(globalRaw);
            hasMore = globalResult['hasMore'] == true || items.length == 20;
          }
        } catch (_) {}
      }

      if (!mounted || requestId != _spacesRequestId) return;
      setState(() {
        _error = null;
        if (nextPage) {
          _spaces.addAll(items);
        } else {
          // Replace the feed in one rebuild. In particular, silent socket
          // reconciliation must never clear the visible cards while the
          // request is in flight, otherwise avatars/cards visibly flicker.
          _spaces
            ..clear()
            ..addAll(items);
        }
        _offset = _spaces.length;
        _hasMore = hasMore;
        _loading = silent ? _loading : false;
      });
    } catch (_) {
      if (mounted && requestId == _spacesRequestId) {
        setState(() {
          _loading = silent ? _loading : false;
          _error =
              'Campfires could not be loaded. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visibleSpaces = _spaces.where((space) {
      final query = _searchQuery.trim().toLowerCase();
      if (query.isEmpty) return true;
      return space.title.toLowerCase().contains(query) ||
          (space.description?.toLowerCase().contains(query) ?? false) ||
          space.regionCode.toLowerCase().contains(query);
    }).toList();

    return GradientScaffold(
      useSafeArea: false,
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text('Campfires'),
        centerTitle: true,
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'campfire-start-fab',
        onPressed: _showCreateSpace,
        icon: const Icon(Icons.local_fire_department_rounded),
        label: const Text('Start a Campfire'),
      ),
      floatingActionButtonLocation: _CampfireFabLocation(
        keyboardInset: _windowKeyboardInset(context),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _searchFocusNode.unfocus(),
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              _loadSpaces(forceRefresh: true),
              _loadUpcomingSpaces(forceRefresh: true),
            ]);
          },
          child: ListView(
          controller: _feedScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
          children: [
            _searchField(context),
            const SizedBox(height: 16),
            Text(
              'Happening Now',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Campfires happening right now',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            if (_upcomingSpaces.isNotEmpty) ...[
              _upcomingSection(context),
              const SizedBox(height: 22),
            ],
            _spacesSection(context, visibleSpaces),
          ],
          ),
        ),
      ),
    );
  }

  Widget _upcomingSection(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Get these in your calendar',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          'Upcoming Campfires from the community',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        ..._upcomingSpaces.map(
          (space) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GriotBrandedContainer(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              borderRadius: 18,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colors.primary.withValues(alpha: .14),
                    foregroundColor: colors.primary,
                    child: Icon(
                      space.mode == 'video'
                          ? Icons.videocam_rounded
                          : Icons.graphic_eq_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          space.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatScheduledTime(space.scheduledAt),
                          style: TextStyle(color: colors.primary),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Add reminder',
                    onPressed: () => _showReminderInfo(context),
                    icon: const Icon(Icons.event_available_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatScheduledTime(DateTime? value) {
    if (value == null) return 'Upcoming';
    final local = value.toLocal();
    final now = DateTime.now();
    final day = DateUtils.isSameDay(local, now)
        ? 'Today'
        : DateUtils.isSameDay(local, now.add(const Duration(days: 1)))
        ? 'Tomorrow'
        : '${local.day}/${local.month}/${local.year}';
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day at $hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  void _showReminderInfo(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Calendar reminders will be connected in the next update.',
        ),
      ),
    );
  }

  Widget _spacesSection(BuildContext context, List<SpaceModel> visibleSpaces) {
    if (_loading && _spaces.isEmpty) {
      return GriotBrandedContainer(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              'Finding live Campfires…',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Checking ${_region == 'GLOBAL' ? 'the community' : _region} for active conversations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    if (_error != null && _spaces.isEmpty) {
      return GriotBrandedContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Campfires are temporarily unavailable',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _loadSpaces(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (_spaces.isEmpty) {
      final isPlus = context.read<IapProvider>().status.isPlus;
      return _emptyState(
        context,
        icon: Icons.local_fire_department_rounded,
        title: 'No Campfires are live',
        message: isPlus
            ? 'There are no live Campfires in this region yet. Start one and invite people to join the conversation.'
            : 'There are no live Campfires in this region yet. Griot Plus members can start the next one.',
        action: isPlus ? 'Start a Campfire' : 'Get Griot Plus',
      );
    }
    if (visibleSpaces.isEmpty) {
      return _emptyState(
        context,
        icon: Icons.search_off_rounded,
        title: 'No Campfires found',
        message: 'Try another search or browse all Campfires currently live.',
        action: 'Clear search',
        onPressed: () {
          _searchController.clear();
          setState(() => _searchQuery = '');
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Trending',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_spaces.length} live',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Live conversations from the Griot community.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (_loading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 16),
        for (final space in visibleSpaces) _spaceCard(context, space),
        if (_hasMore && _searchQuery.trim().isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: OutlinedButton.icon(
              onPressed: _loading ? null : () => _loadSpaces(nextPage: true),
              icon: const Icon(Icons.expand_more_rounded),
              label: const Text('Load more Campfires'),
            ),
          ),
      ],
    );
  }

  Future<void> _showCreateSpace() async {
    if (!context.read<IapProvider>().status.isPlus) {
      final shouldOpenPlus = await showPlusRequiredDialog(context);
      if (shouldOpenPlus && mounted) {
        context.push('/settings/griot-plus');
      }
      return;
    }
    if (!mounted) return;
    final created = await context.push<Map<String, dynamic>>('/campfires/create');
    if (created != null && mounted) {
      _loadSpaces(forceRefresh: true);
      _loadUpcomingSpaces(forceRefresh: true);
      final campfireId = created['id']?.toString();
      if (campfireId != null && campfireId.isNotEmpty) {
        final scheduledRaw = created['scheduledAt'];
        final scheduledAt = scheduledRaw == null
            ? null
            : DateTime.tryParse(scheduledRaw.toString());
        if (scheduledAt != null && scheduledAt.isAfter(DateTime.now())) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Campfire scheduled for ${_formatScheduledTime(scheduledAt)}.',
              ),
            ),
          );
          return;
        }
        context.push(
          '/calls/$campfireId',
          extra: {
            'type': 'space',
            'mode': created['mode']?.toString() ?? 'voice',
          },
        );
      }
    }
    return;
    /*
    final title = TextEditingController();
    final description = TextEditingController();
    var mode = 'voice';
    var recordSpace = false;
    DateTime? scheduledAt;
    var creating = false;
    final created = await showDialog<bool>(
      context: context,
      // Do not dismiss the creation flow when the user taps outside a field.
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (sheetContext) => Align(
        alignment: Alignment.bottomCenter,
        child: Dialog(
          alignment: Alignment.bottomCenter,
          insetPadding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
          backgroundColor: Theme.of(sheetContext).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .9,
            child: StatefulBuilder(
            builder: (context, setSheetState) {
          final colors = Theme.of(context).colorScheme;
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            minChildSize: 0.45,
            maxChildSize: 0.96,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                // Keep the form and primary action above Griot's persistent
                // bottom navigation as well as the system keyboard.
                MediaQuery.of(context).viewInsets.bottom + 104,
              ),
              child: GriotBrandedContainer(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                borderRadius: 26,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Start a Campfire',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start a public conversation people can join. Your device region is selected automatically; you can change it below.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: title,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Campfire name',
                        hintText: 'What would you like to talk about?',
                        prefixIcon: Icon(Icons.campaign_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: description,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Optional context for listeners',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Campfire options',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: recordSpace,
                      onChanged: (value) =>
                          setSheetState(() => recordSpace = value),
                      title: const Text('Record this Campfire'),
                      subtitle: const Text(
                        'Save the conversation for people who cannot join live.',
                      ),
                      secondary: const Icon(Icons.radio_rounded),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Format',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'voice',
                          label: Text('Voice'),
                          icon: Icon(Icons.mic_rounded),
                        ),
                        ButtonSegment(
                          value: 'video',
                          label: Text('Video'),
                          icon: Icon(Icons.videocam_rounded),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (value) =>
                          setSheetState(() => mode = value.first),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final date = await showDatePicker(
                          context: context,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                          initialDate: scheduledAt ?? now,
                        );
                        if (date == null || !context.mounted) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: scheduledAt == null
                              ? TimeOfDay.now()
                              : TimeOfDay.fromDateTime(scheduledAt!),
                        );
                        if (time == null) return;
                        final selected = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                        if (!selected.isAfter(DateTime.now())) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Choose a future start time.'),
                              ),
                            );
                          }
                          return;
                        }
                        setSheetState(() => scheduledAt = selected);
                      },
                      icon: Icon(
                        scheduledAt == null
                            ? Icons.calendar_month_rounded
                            : Icons.event_available_rounded,
                      ),
                      label: Text(
                        scheduledAt == null
                            ? 'Schedule for later'
                            : 'Starts ${_formatScheduledTime(scheduledAt)}',
                      ),
                    ),
                    if (scheduledAt != null)
                      TextButton(
                        onPressed: () =>
                            setSheetState(() => scheduledAt = null),
                        child: const Text('Start immediately instead'),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: creating
                            ? null
                            : () async {
                                if (title.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Add a Campfire name first.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setSheetState(() => creating = true);
                                try {
                                  await context
                                      .read<MessagingApiService>()
                                      .createCampfire(
                                        title: title.text.trim(),
                                        description: description.text.trim(),
                                        mode: mode,
                                        regionCode: 'GLOBAL',
                                        recordingEnabled: recordSpace,
                                        scheduledAt: scheduledAt,
                                      );
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext, true);
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    setSheetState(() => creating = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Could not start Campfire: $error',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: creating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_rounded),
                        label: Text(creating ? 'Starting…' : 'Start Campfire'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
            },
            ),
          ),
        ),
      ),
    );
    title.dispose();
    description.dispose();
    if (created == true && mounted) {
      _loadSpaces(forceRefresh: true);
      _loadUpcomingSpaces(forceRefresh: true);
    }
  }
  */

  }

  Widget _spaceCard(BuildContext context, SpaceModel space) {
    final colors = Theme.of(context).colorScheme;
    final friends = space.friendsPresent.length;
    final listenerLabel = space.participantCount == 1
        ? '1 listener'
        : '${space.participantCount} listeners';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GriotBrandedContainer(
        padding: EdgeInsets.zero,
        borderRadius: 24,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _joinSpace(context, space),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary,
                      Color.lerp(colors.primary, colors.secondary, .28) ??
                          colors.primary,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      space.mode == 'video'
                          ? Icons.videocam_rounded
                          : Icons.graphic_eq_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'BURNING NOW',
                        style: TextStyle(
                        color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (space.isHost) IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Campfire options',
                      onPressed: () => _showCampfireOptions(context, space),
                      icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                color: colors.primary.withValues(alpha: .12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      space.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 23,
                      ),
                    ),
                    if (space.description?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        space.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: colors.surfaceContainerHighest,
                          child: Icon(
                            space.mode == 'video'
                                ? Icons.videocam_rounded
                                : Icons.graphic_eq_rounded,
                            size: 16,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            space.isHost
                                ? 'You are hosting this Campfire'
                                : 'Hosted by ${space.hostName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Host',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _FriendAvatars(friends: space.friendsPresent),
                        const SizedBox(width: 10),
                        Text(
                          listenerLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (friends > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '· $friends friend${friends == 1 ? '' : 's'} here',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                        const Spacer(),
                        FilledButton(
                          onPressed: () => _joinSpace(context, space),
                          child: const Text('Join'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _joinSpace(BuildContext context, SpaceModel space) async {
    try {
      await context.read<MessagingApiService>().joinCampfire(space.id);
      if (!context.mounted) return;
      context.push(
        '/calls/${space.id}',
        extra: {'type': 'space', 'mode': space.mode},
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not join this Campfire: $error')),
        );
      }
    }
  }

  Future<void> _showCampfireOptions(
    BuildContext context,
    SpaceModel space,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('Share Campfire'),
              onTap: () {
                Navigator.pop(sheetContext);
                _shareCampfire(context, space);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report Campfire'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareCampfire(BuildContext context, SpaceModel space) async {
    try {
      final link = await RealtimeCallService(context.read<ApiClient>())
          .createLink(
            roomId: 'griot-space-${space.id}',
            contextType: 'space',
            conversationId: space.id,
            mode: space.mode,
          );
      await SharePlus.instance.share(
        ShareParams(
          text:
              'Join my ${space.mode == 'video' ? 'video' : 'voice'} Campfire “${space.title}” on Griot:\n$link',
          subject: 'Join a Griot Campfire',
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share this Campfire: $error')),
        );
      }
    }
  }

  Widget _searchField(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: (value) => setState(() => _searchQuery = value),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search for a Campfire',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          tooltip: 'Close search',
          onPressed: () {
            _searchFocusNode.unfocus();
            _searchController.clear();
            setState(() => _searchQuery = '');
          },
          icon: Icon(Icons.close_rounded, color: colors.onSurfaceVariant),
        ),
        filled: true,
        fillColor: colors.surfaceContainerHighest.withValues(alpha: .7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  double _windowKeyboardInset(BuildContext context) {
    final view = View.of(context);
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  Widget _emptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String action,
    VoidCallback? onPressed,
  }) {
    final colors = Theme.of(context).colorScheme;
    return GriotBrandedContainer(
      padding: const EdgeInsets.all(28),
      borderRadius: 24,
      child: Column(
        children: [
          Icon(icon, size: 54, color: colors.primary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          // Campfire creation is available from the single floating action
          // button. Keeping the empty state informational avoids presenting
          // two competing start controls on this screen.
        ],
      ),
    );
  }
}

class _FriendAvatars extends StatelessWidget {
  final List<Map<String, dynamic>> friends;

  const _FriendAvatars({required this.friends});

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.people_alt_outlined,
          size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    final visible = friends.take(3).toList();
    return SizedBox(
      width: 24 + ((visible.length - 1) * 18),
      height: 34,
      child: Stack(
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * 18,
              top: 1,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.surface,
                child: CircleAvatar(
                  radius: 13,
                  child: Text(
                    _initial(visible[index]),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _initial(Map<String, dynamic> friend) {
    final name =
        (friend['displayName'] ??
                friend['display_name'] ??
                friend['username'] ??
                'G')
            .toString()
            .trim();
    return name.isEmpty ? 'G' : name[0].toUpperCase();
  }
}

class _CampfireFabLocation extends FloatingActionButtonLocation {
  final double keyboardInset;

  const _CampfireFabLocation({required this.keyboardInset});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final x =
        geometry.scaffoldSize.width -
        geometry.floatingActionButtonSize.width -
        18;
    final y =
        (geometry.scaffoldSize.height -
                geometry.floatingActionButtonSize.height -
                125 +
                keyboardInset)
            .clamp(0.0, double.infinity)
            .toDouble();
    return Offset(x, y);
  }
}
