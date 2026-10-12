import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import '../../../core/ui/widgets/native_ad.dart';

const _feed =
    'https://feeds.gamepix.com/v2/json?sid=7EI8T&pagination=96&page=1&order=quality';

class GameCenterScreen extends StatefulWidget {
  const GameCenterScreen({super.key});
  @override
  State<GameCenterScreen> createState() => _GameCenterScreenState();
}

class _GameCenterScreenState extends State<GameCenterScreen> {
  late Future<List<_Game>> _games;
  final ScrollController _scrollController = ScrollController();
  String _selectedCategory = 'all';
  bool _showScrollToTop = false;

  static const _popularCategories = [
    ('arcade', 'Arcade', Icons.sports_esports_rounded),
    ('puzzle', 'Puzzle', Icons.extension_rounded),
    ('racing', 'Racing', Icons.directions_car_rounded),
    ('sports', 'Sports', Icons.sports_soccer_rounded),
    ('fighting', 'Fighting', Icons.sports_mma_rounded),
    ('strategy', 'Strategy', Icons.psychology_rounded),
    ('adventure', 'Adventure', Icons.explore_rounded),
    ('shooter', 'Shooters', Icons.gps_fixed_rounded),
    ('simulation', 'Simulation', Icons.precision_manufacturing_rounded),
    ('trivia', 'Trivia', Icons.quiz_rounded),
    ('board', 'Board & Scrabble', Icons.grid_4x4_rounded),
    ('card', 'Card games', Icons.style_rounded),
    ('brain', 'Brain games', Icons.lightbulb_rounded),
    ('match-3', 'Match 3', Icons.diamond_rounded),
    ('memory', 'Memory', Icons.psychology_alt_rounded),
    ('platformer', 'Platformers', Icons.directions_run_rounded),
    ('runner', 'Endless runners', Icons.speed_rounded),
    ('io', 'IO games', Icons.public_rounded),
    ('idle', 'Idle & clicker', Icons.touch_app_rounded),
    ('casual', 'Casual', Icons.sentiment_satisfied_alt_rounded),
    ('zombie', 'Zombies', Icons.coronavirus_rounded),
    ('battle', 'Battle', Icons.shield_rounded),
    ('ball', 'Ball games', Icons.sports_basketball_rounded),
    ('farming', 'Farming', Icons.agriculture_rounded),
    ('retro', 'Retro', Icons.videogame_asset_rounded),
    ('jelly', 'Jelly & Match 3', Icons.catching_pokemon_rounded),
    ('breakout', 'Block Breaker & Ball', Icons.local_fire_department_rounded),
  ];

  static const _categoryGroups = <String, Set<String>>{
    'jelly': {'match-3'},
    'breakout': {'ball', 'block', 'arcade'},
    'shooter': {'shooter', 'first-person-shooter'},
    'arcade': {'arcade', 'fun', 'hyper-casual'},
    'casual': {'casual', 'fun', 'hyper-casual'},
    'brain': {'brain', 'math', 'educational', '2048'},
    'ball': {'ball', 'basketball', 'golf'},
  };

  bool _matchesCategory(_Game game, String filter) {
    final group = _categoryGroups[filter];
    return group == null
        ? game.categories.contains(filter)
        : game.categories.any(group.contains);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _games = _load();
  }

  void _onScroll() {
    final shouldShow =
        _scrollController.hasClients && _scrollController.offset > 420;
    if (shouldShow != _showScrollToTop && mounted) {
      setState(() => _showScrollToTop = shouldShow);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<List<_Game>> _load() async {
    final response = await http.get(Uri.parse(_feed));
    if (response.statusCode != 200) throw Exception('Catalog unavailable');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final games = (data['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_Game.fromJson)
        .where((g) => g.title.isNotEmpty && g.url.isNotEmpty)
        .toList();
    // GamePix's quality-ranked feed is the live popularity signal. Sorting by
    // it keeps the first row current instead of relying on a stale hardcoded
    // title list.
    games.sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
    return games;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Center'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _games = _load()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.small(
              heroTag: 'game-center-scroll-to-top',
              tooltip: 'Back to top',
              onPressed: () {
                if (!_scrollController.hasClients) return;
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                );
              },
              child: const Icon(Icons.keyboard_arrow_up_rounded),
            )
          : null,
      body: FutureBuilder<List<_Game>>(
        future: _games,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: FilledButton(
                onPressed: () => setState(() => _games = _load()),
                child: const Text('Try again'),
              ),
            );
          }
          final games = snap.data ?? const <_Game>[];
          final availableCategories = games
              .expand((game) => game.categories)
              .where((category) => category.isNotEmpty)
              .toSet();
          final visibleGames = _selectedCategory == 'all'
              ? games
              : games
                    .where((game) => _matchesCategory(game, _selectedCategory))
                    .toList();
          final gameSlivers = <Widget>[];
          for (var start = 0; start < visibleGames.length; start += 6) {
            final end = (start + 6).clamp(0, visibleGames.length);
            final section = visibleGames.sublist(start, end);
            if (start > 0 || visibleGames.length <= 6) {
              gameSlivers.add(
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: _GameNativeAdCard(),
                  ),
                ),
              );
            }
            gameSlivers.add(
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  start == 0 ? 0 : 8,
                  16,
                  start + 6 >= visibleGames.length ? 24 : 8,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: section.length,
                  itemBuilder: (_, index) {
                    final game = section[index];
                    return _Card(
                      game: game,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => _Player(game: game)),
                      ),
                    );
                  },
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() => _games = _load()),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        colors: [
                          colors.primary.withValues(alpha: .2),
                          colors.secondary.withValues(alpha: .1),
                        ],
                      ),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: .3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sports_esports_rounded,
                          size: 38,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Play, relax, and discover something new.',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: visibleGames.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  10,
                                ),
                                child: Text(
                                  'Featured games',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              SizedBox(
                                height: 188,
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: visibleGames.take(6).length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 12),
                                  itemBuilder: (_, index) {
                                    final game = visibleGames[index];
                                    return _FeaturedGameCard(
                                      game: game,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => _Player(game: game),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      children: [
                        ChoiceChip(
                          selected: _selectedCategory == 'all',
                          label: const Text('Popular'),
                          avatar: const Icon(
                            Icons.local_fire_department_rounded,
                            size: 18,
                          ),
                          onSelected: (_) =>
                              setState(() => _selectedCategory = 'all'),
                        ),
                        ..._popularCategories
                            .where(
                              (item) => (_categoryGroups[item.$1] ?? {item.$1})
                                  .any(availableCategories.contains),
                            )
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: ChoiceChip(
                                  selected: _selectedCategory == item.$1,
                                  label: Text(item.$2),
                                  avatar: Icon(item.$3, size: 18),
                                  onSelected: (_) => setState(
                                    () => _selectedCategory = item.$1,
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      _selectedCategory == 'all'
                          ? 'All games'
                          : '${_selectedCategory[0].toUpperCase()}${_selectedCategory.substring(1)} games',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                ...gameSlivers,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GameNativeAdCard extends StatelessWidget {
  const _GameNativeAdCard();

  @override
  Widget build(BuildContext context) => SizedBox(
    // Give the ad a proper media panel, header, and bottom CTA instead of
    // treating it like a small square floating in an empty card.
    height: 350,
    width: double.infinity,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: const GriotNativeAd(compact: true, height: 350),
    ),
  );
}

class _FeaturedGameCard extends StatelessWidget {
  final _Game game;
  final VoidCallback onTap;

  const _FeaturedGameCard({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 154,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 3,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 108,
                width: double.infinity,
                child: game.image.isEmpty
                    ? Icon(
                        Icons.sports_esports_rounded,
                        size: 42,
                        color: colors.primary,
                      )
                    : Image.network(
                        game.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.sports_esports_rounded,
                          size: 42,
                          color: colors.primary,
                        ),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      game.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final _Game game;
  final VoidCallback onTap;
  const _Card({required this.game, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    elevation: 4,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 140,
            width: double.infinity,
            child: game.image.isEmpty
                ? const Center(
                    child: Icon(Icons.sports_esports_rounded, size: 42),
                  )
                : Image.network(
                    game.image,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.sports_esports_rounded, size: 42),
                    ),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  game.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Player extends StatelessWidget {
  final _Game game;
  const _Player({required this.game});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(game.title)),
    body: InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(game.url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        allowsInlineMediaPlayback: true,
        mediaPlaybackRequiresUserGesture: false,
      ),
    ),
  );
}

class _Game {
  final String title, image, url;
  final Set<String> categories;
  final double qualityScore;
  const _Game({
    required this.title,
    required this.image,
    required this.url,
    required this.categories,
    required this.qualityScore,
  });
  factory _Game.fromJson(Map<String, dynamic> j) {
    final categories = <String>{};
    final primary = j['category']?.toString().trim().toLowerCase();
    if (primary != null && primary.isNotEmpty) categories.add(primary);
    final secondary = j['categories'];
    if (secondary is List) {
      categories.addAll(
        secondary
            .map((value) => value.toString().trim().toLowerCase())
            .where((value) => value.isNotEmpty),
      );
    }
    return _Game(
      title: j['title'] as String? ?? '',
      image: (j['banner_image'] ?? j['image']) as String? ?? '',
      url: j['url'] as String? ?? '',
      categories: categories,
      qualityScore: (j['quality_score'] as num?)?.toDouble() ?? 0,
    );
  }
}
