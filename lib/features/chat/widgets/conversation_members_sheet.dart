import 'package:flutter/material.dart';

import '../../../core/ui/widgets/griot_plus_badge.dart';
import '../../../core/ui/widgets/griot_pioneer_badge.dart';
import '../../../core/ui/widgets/griot_avatar.dart';

/// Searchable, bounded member directory used by group and channel overviews.
/// The list is rendered in pages so opening an overview never lays out every
/// member at once, even when a conversation has a large audience.
class ConversationMembersSheet extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> members;
  final String? currentUserId;
  final bool canManage;
  final void Function(Map<String, dynamic> member)? onMemberTap;

  const ConversationMembersSheet({
    super.key,
    required this.title,
    required this.members,
    required this.currentUserId,
    this.canManage = false,
    this.onMemberTap,
  });

  @override
  State<ConversationMembersSheet> createState() =>
      _ConversationMembersSheetState();
}

class _ConversationMembersSheetState extends State<ConversationMembersSheet> {
  static const _pageSize = 30;
  final _searchController = TextEditingController();
  String _query = '';
  int _visibleCount = _pageSize;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredMembers {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.members;
    return widget.members.where((member) {
      final name = '${member['display_name'] ?? ''} ${member['username'] ?? ''}'
          .toLowerCase();
      return name.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtered = _filteredMembers;
    final visible = filtered.take(_visibleCount).toList();

    return FractionallySizedBox(
      heightFactor: 0.86,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: colors.primary.withValues(alpha: 0.6)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${widget.title} (${widget.members.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() {
                    _query = value;
                    _visibleCount = _pageSize;
                  }),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search members',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                                _visibleCount = _pageSize;
                              });
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                    filled: true,
                    fillColor: colors.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          _query.isEmpty
                              ? 'No members yet.'
                              : 'No members match “$_query”.',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        itemCount:
                            visible.length +
                            (visible.length < filtered.length ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          if (index == visible.length) {
                            return Center(
                              child: TextButton.icon(
                                onPressed: () =>
                                    setState(() => _visibleCount += _pageSize),
                                icon: const Icon(Icons.expand_more_rounded),
                                label: Text(
                                  'Load more (${filtered.length - visible.length} remaining)',
                                ),
                              ),
                            );
                          }
                          return _memberTile(context, visible[index], colors);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memberTile(
    BuildContext context,
    Map<String, dynamic> member,
    ColorScheme colors,
  ) {
    final userId = member['user_id']?.toString();
    final isMe = userId != null && userId == widget.currentUserId;
    final role = member['role']?.toString() ?? 'member';
    final avatarUrl = member['avatar_url']?.toString();
    final displayName =
        (member['display_name'] ?? member['username'] ?? 'Griot User')
            .toString();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: GriotAvatar(avatarUrl: avatarUrl, radius: 23),
      title: Row(
        children: [
          Flexible(
            child: Text(
              '$displayName${isMe ? ' (You)' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (member['is_plus'] == true || member['isPlus'] == true) ...[
            const SizedBox(width: 6),
            const GriotPlusBadge(isPlus: true, compact: true),
          ],
          if (member['is_pioneer'] == true || member['isPioneer'] == true) ...[
            const SizedBox(width: 4),
            const GriotPioneerBadge(compact: true),
          ],
        ],
      ),
      subtitle: role == 'owner' || role == 'admin'
          ? Text(
              role.toUpperCase(),
              style: TextStyle(
                color: colors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
      trailing: widget.canManage
          ? const Icon(Icons.more_vert_rounded)
          : const Icon(Icons.chevron_right_rounded),
      onTap: widget.onMemberTap == null
          ? null
          : () => widget.onMemberTap!(member),
    );
  }
}
