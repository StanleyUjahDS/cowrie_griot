import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_svg/flutter_svg.dart';
import '../../users/models/user_model.dart';
import '../../users/services/user_api_service.dart';
import '../providers/messaging_provider.dart';
import '../models/conversation_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_loader.dart';

class UserDiscoveryScreen extends StatefulWidget {
  const UserDiscoveryScreen({super.key});

  @override
  State<UserDiscoveryScreen> createState() => _UserDiscoveryScreenState();
}

class _UserDiscoveryScreenState extends State<UserDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  Timer? _searchTimer;

  List<UserModel> _userResults = [];
  bool _isSearching = false;
  String? _error;

  int _usersPage = 0;
  bool _hasMoreUsers = false;
  bool _isLoadingMoreUsers = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _performSearch(_searchController.text.trim());
      }
      setState(() {}); // Rebuild for hint text update
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    final query = value.trim();

    if (query.length < 3) {
      setState(() {
        _userResults = [];
        _isSearching = false;
        _error = null;
      });
      return;
    }

    _searchTimer = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted || query.length < 3) return;

    setState(() {
      _isSearching = true;
      _error = null;
      _usersPage = 0;
      _hasMoreUsers = false;
    });

    try {
      if (_tabController.index == 0) {
        final apiService = context.read<UserApiService>();
        final response = await apiService.searchUsers(
          query,
          limit: 20,
          offset: 0,
        );
        if (!mounted) return;

        final users = response['users'] as List<UserModel>;
        final total = response['total'] as int;

        setState(() {
          _userResults = users;
          _isSearching = false;
          _hasMoreUsers = _userResults.length < total;
          if (_hasMoreUsers) _usersPage = 20;
        });
      } else if (_tabController.index == 1) {
        final provider = context.read<MessagingProvider>();
        await provider.discoverGroups(query, refresh: true);
        if (!mounted) return;
        setState(() {
          _isSearching = false;
        });
      } else if (_tabController.index == 2) {
        final provider = context.read<MessagingProvider>();
        await provider.discoverChannels(query, refresh: true);
        if (!mounted) return;
        setState(() {
          _isSearching = false;
        });
      }
    } catch (e, stack) {
      debugPrint('DISCOVERY SEARCH ERROR: $e');
      debugPrint('$stack');

      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoadingMoreUsers || !_hasMoreUsers) return;

    setState(() => _isLoadingMoreUsers = true);

    try {
      final apiService = context.read<UserApiService>();
      final response = await apiService.searchUsers(
        _searchController.text.trim(),
        limit: 20,
        offset: _usersPage,
      );

      if (!mounted) return;

      final users = response['users'] as List<UserModel>;
      final total = response['total'] as int;

      setState(() {
        _userResults.addAll(users);
        _isLoadingMoreUsers = false;
        _hasMoreUsers = _userResults.length < total;
        if (_hasMoreUsers) _usersPage += 20;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingMoreUsers = false);
    }
  }

  void _showUserProfile(UserModel user) {
    context.push('/user/profile', extra: user);
  }

  void _openConversation(Conversation conversation) {
    context.push('/conversation/${conversation.id}', extra: conversation);
  }

  Future<void> _handleAction(UserModel user) async {
    final provider = context.read<MessagingProvider>();
    final status = _getEffectiveStatus(
      provider.getRelationship(user.id),
      user.relationshipStatus,
    );

    try {
      switch (status) {
        case 'friend':
          _showUserProfile(user);
          break;
        case 'request_received':
          _showUserProfile(user);
          break;
        case 'not_connected':
          await provider.sendConnectionRequest(user.id);
          if (mounted) {
            NotificationService.showSuccess(context, 'Request sent!');
          }
          break;
        case 'blocked':
          await provider.unblockUser(user.id);
          if (mounted) {
            NotificationService.showSuccess(context, 'User unblocked');
          }
          break;
        default:
          _showUserProfile(user);
          break;
      }
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Action failed');
    }
  }

  String _getEffectiveStatus(RelationshipState state, String? initialStatus) {
    switch (state) {
      case RelationshipState.friends:
        return 'friend';
      case RelationshipState.pendingSent:
        return 'request_sent';
      case RelationshipState.pendingReceived:
        return 'request_received';
      case RelationshipState.blocked:
        return 'blocked';
      case RelationshipState.none:
        return initialStatus ?? 'not_connected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text(
          'Discover',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 50,
        leading: Center(
          child: GestureDetector(
            onTap: () => context.go('/chat?tab=direct'),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  top: BorderSide(
                    color: colors.primary.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  bottom: BorderSide(
                    color: colors.primary.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.primary,
          labelColor: colors.onSurface,
          unselectedLabelColor: colors.onSurfaceVariant,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Users'),
            Tab(text: 'Groups'),
            Tab(text: 'Channels'),
          ],
        ),
      ),
      child: Column(
        children: [
          // Premium Floating Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    autofocus: true,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: _tabController.index == 0
                          ? 'Search username or wallet...'
                          : (_tabController.index == 1
                                ? 'Search circle name...'
                                : 'Search channels...'),
                      hintStyle: TextStyle(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: colors.primary,
                        size: 22,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: colors.surface.withValues(alpha: 0.7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: colors.primary.withValues(alpha: 0.1),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: colors.primary.withValues(alpha: 0.05),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: colors.primary.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserResults(),
                _buildGroupResults(),
                _buildChannelResults(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserResults() {
    if (_isSearching) return const Center(child: GriotLoader(size: 44));
    if (_error != null) return _ErrorState(message: _error!);
    if (_searchController.text.isEmpty) {
      return const _InitialState(type: 'Users');
    }
    if (_userResults.isEmpty) {
      return const _EmptySearch(
        title: 'No users found',
        message: 'Try a different username or wallet.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: _userResults.length + (_hasMoreUsers ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _userResults.length) {
          return _buildLoadMoreButton(
            isLoading: _isLoadingMoreUsers,
            onPressed: _loadMoreUsers,
          );
        }

        final user = _userResults[index];
        return _UserResultTile(
              user: user,
              onTap: () => _showUserProfile(user),
              onActionPressed: () => _handleAction(user),
            )
            .animate()
            .fadeIn(delay: (index * 50).ms)
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
      },
    );
  }

  Widget _buildGroupResults() {
    final provider = context.watch<MessagingProvider>();
    if (_isSearching || provider.isSearchingGroups) {
      return const Center(child: GriotLoader(size: 44));
    }
    if (_error != null) return _ErrorState(message: _error!);
    if (_searchController.text.isEmpty) {
      return const _InitialState(type: 'Groups');
    }

    final results = provider.discoveredGroups;
    if (results.isEmpty) {
      return const _EmptySearch(
        title: 'No groups found',
        message: 'Try a different group name or username.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: results.length + (provider.hasMoreGroups ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == results.length) {
          return _buildLoadMoreButton(
            isLoading: provider.isLoadingMoreGroups,
            onPressed: () => provider.discoverGroups(
              _searchController.text.trim(),
              refresh: false,
            ),
          );
        }

        final group = results[index];
        return _ConversationResultTile(
              conversation: group,
              onTap: () => _openConversation(group),
            )
            .animate()
            .fadeIn(delay: (index * 50).ms)
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
      },
    );
  }

  Widget _buildChannelResults() {
    final provider = context.watch<MessagingProvider>();
    if (_isSearching || provider.isSearchingChannels) {
      return const Center(child: GriotLoader(size: 44));
    }
    if (_error != null) return _ErrorState(message: _error!);
    if (_searchController.text.isEmpty) {
      return const _InitialState(type: 'Channels');
    }

    final results = provider.discoveredChannels;
    if (results.isEmpty) {
      return const _EmptySearch(
        title: 'No channels found',
        message: 'Try a different channel name or username.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: results.length + (provider.hasMoreChannels ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == results.length) {
          return _buildLoadMoreButton(
            isLoading: provider.isLoadingMoreChannels,
            onPressed: () => provider.discoverChannels(
              _searchController.text.trim(),
              refresh: false,
            ),
          );
        }

        final channel = results[index];
        return _ConversationResultTile(
              conversation: channel,
              onTap: () => _openConversation(channel),
            )
            .animate()
            .fadeIn(delay: (index * 50).ms)
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
      },
    );
  }

  Widget _buildLoadMoreButton({
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: isLoading
            ? const GriotLoader(size: 32)
            : TextButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'LOAD MORE',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    fontSize: 12,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: colors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _InitialState extends StatelessWidget {
  final String type;
  const _InitialState({required this.type});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_search_rounded,
              size: 64,
              color: colors.primary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Discover $type',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for others across the network',
            style: TextStyle(
              color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'Search Failed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  final String title;
  final String message;

  const _EmptySearch({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_rounded,
              size: 64,
              color: colors.onSurfaceVariant.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserResultTile extends StatefulWidget {
  final UserModel user;
  final VoidCallback onTap;
  final Future<void> Function() onActionPressed;

  const _UserResultTile({
    required this.user,
    required this.onTap,
    required this.onActionPressed,
  });

  @override
  State<_UserResultTile> createState() => _UserResultTileState();
}

class _UserResultTileState extends State<_UserResultTile> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reputation = widget.user.reputation;

    return Consumer<MessagingProvider>(
      builder: (context, messaging, _) {
        final relationship = messaging.getRelationship(widget.user.id);
        final String effectiveStatus = _getEffectiveStatus(
          relationship,
          widget.user.relationshipStatus,
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border(
              top: BorderSide(
                color: colors.primary.withValues(alpha: 0.6),
                width: 1.2,
              ),
              bottom: BorderSide(
                color: colors.primary.withValues(alpha: 0.6),
                width: 1.2,
              ),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _Avatar(user: widget.user, reputation: reputation),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user.effectiveName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.user.username != null &&
                              widget.user.username!.isNotEmpty)
                            Text(
                              widget.user.formattedUsername,
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            _shortenAddress(widget.user.walletAddress),
                            style: TextStyle(
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.4,
                              ),
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Action(
                      status: effectiveStatus,
                      isLoading: _isLoading,
                      onAction: () async {
                        if (_isLoading) return;
                        setState(() => _isLoading = true);
                        try {
                          await widget.onActionPressed();
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getEffectiveStatus(RelationshipState state, String? initialStatus) {
    switch (state) {
      case RelationshipState.friends:
        return 'friend';
      case RelationshipState.pendingSent:
        return 'request_sent';
      case RelationshipState.pendingReceived:
        return 'request_received';
      case RelationshipState.blocked:
        return 'blocked';
      case RelationshipState.none:
        return initialStatus ?? 'not_connected';
    }
  }

  String _shortenAddress(String addr) {
    if (addr.length < 8) return addr;
    return '${addr.substring(0, 3)}...${addr.substring(addr.length - 3)}';
  }
}

class _Avatar extends StatelessWidget {
  final UserModel user;
  final UserReputationBadge? reputation;
  const _Avatar({required this.user, this.reputation});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bool isOnline =
        context.watch<MessagingProvider>().presenceMap[user.id] == true ||
        user.isOnline;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: colors.surfaceContainerHighest,
          backgroundImage: user.avatarUrl != null
              ? NetworkImage(user.avatarUrl!)
              : null,
          child: user.avatarUrl == null
              ? SvgPicture.asset(
                  'assets/coins_logo/hbadger_logo.svg',
                  width: 32,
                  height: 32,
                )
              : null,
        ),
        if (isOnline)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 2),
              ),
            ),
          ),
        if (reputation != null)
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.parseHexColor(reputation!.badgeColor),
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 2),
              ),
              child: Icon(
                reputation!.tierName.toLowerCase().contains('ultimate')
                    ? Icons.stars_rounded
                    : Icons.workspace_premium_rounded,
                size: 10,
                color: colors.onPrimary,
              ),
            ),
          ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final String? status;
  final bool isLoading;
  final VoidCallback onAction;
  const _Action({this.status, required this.onAction, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (status == 'self') return const SizedBox.shrink();

    IconData icon;
    Color color;
    bool filled = false;

    switch (status) {
      case 'friend':
        icon = Icons.chat_bubble_rounded;
        color = colors.primary;
        break;
      case 'request_received':
        icon = Icons.check_circle_rounded;
        color = AppColors.success;
        filled = true;
        break;
      case 'request_sent':
        icon = Icons.hourglass_top_rounded;
        color = colors.onSurfaceVariant.withValues(alpha: 0.5);
        break;
      case 'blocked':
      case 'blocked_by_user':
        icon = Icons.block_rounded;
        color = colors.error;
        break;
      case 'not_connected':
        icon = Icons.person_add_alt_1_rounded;
        color = colors.primary;
        filled = true;
        break;
      default:
        icon = Icons.person_add_alt_1_rounded;
        color = colors.primary;
        filled = true;
    }

    return GestureDetector(
      onTap: isLoading ? null : onAction,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.onPrimary,
                ),
              )
            : Icon(icon, size: 20, color: filled ? colors.onPrimary : color),
      ),
    );
  }
}

class _ConversationResultTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const _ConversationResultTile({
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isChannel = conversation.type == ConversationType.channel;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border(
          top: BorderSide(
            color: colors.primary.withValues(alpha: 0.6),
            width: 1.2,
          ),
          bottom: BorderSide(
            color: colors.primary.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _ConversationAvatar(conversation: conversation),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.name ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (conversation.username != null)
                        Text(
                          '@${conversation.username}',
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        isChannel
                            ? '${conversation.subscriberCount} subscribers'
                            : '${conversation.memberCount} members',
                        style: TextStyle(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isChannel ? Icons.campaign_rounded : Icons.groups_rounded,
                    size: 20,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  final Conversation conversation;
  const _ConversationAvatar({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isChannel = conversation.type == ConversationType.channel;

    return CircleAvatar(
      radius: 28,
      backgroundColor: colors.surfaceContainerHighest,
      backgroundImage: conversation.imageUrl != null
          ? NetworkImage(conversation.imageUrl!)
          : null,
      child: conversation.imageUrl == null
          ? Icon(
              isChannel ? Icons.campaign_rounded : Icons.groups_rounded,
              color: colors.primary.withValues(alpha: 0.5),
              size: 28,
            )
          : null,
    );
  }
}
