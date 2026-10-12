import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/messaging_provider.dart';
import 'chatting/tip_sheet.dart';

class ChatDrawer extends StatelessWidget {
  const ChatDrawer({super.key});

  void _openNewChat(BuildContext context) => context.push('/chat/discover');

  void _openFriends(BuildContext context) => context.push('/chat/friends');

  void _openRequests(BuildContext context) => context.push('/chat/requests');

  void _closeAndNavigate(BuildContext context, VoidCallback navigate) {
    // Push the destination while the drawer still covers the shell, then
    // close the drawer through ScaffoldState. Using Navigator.pop() here is
    // unsafe: after the push it can pop the newly pushed page instead of the
    // drawer's LocalHistoryEntry, briefly exposing the chat home.
    navigate();
    Scaffold.of(context).closeDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.78,
      child: Material(
        color: colors.surface,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        child: SafeArea(
          top: true,
          bottom: true,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              border: Border(
                right: BorderSide(
                  color: colors.primary.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Compact branded header that stays below the status bar.
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.primary.withValues(alpha: 0.14),
                          colors.primary.withValues(alpha: 0.04),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: 0.72),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.42),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: SvgPicture.asset(
                            'assets/cowrie_images/cowriesvg.svg',
                            width: 28,
                            height: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Griot',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'DECENTRALIZED NETWORK',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Close menu',
                          onPressed: () => Scaffold.of(context).closeDrawer(),
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            foregroundColor: colors.onSurface,
                            backgroundColor: colors.surface.withValues(
                              alpha: 0.48,
                            ),
                            side: BorderSide(
                              color: colors.onSurface.withValues(alpha: 0.12),
                            ),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),

                // Navigation list
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 18,
                    ),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      const _DrawerSectionLabel(title: 'Connections'),
                      _DrawerTile(
                        icon: Icons.search_rounded,
                        label: 'Discover Users',
                        onTap: () {
                          _closeAndNavigate(
                            context,
                            () => _openNewChat(context),
                          );
                        },
                      ),
                      _DrawerTile(
                        icon: Icons.people_rounded,
                        label: 'My Friends',
                        onTap: () {
                          _closeAndNavigate(
                            context,
                            () => _openFriends(context),
                          );
                        },
                      ),
                      Consumer<MessagingProvider>(
                        builder: (context, provider, _) {
                          final count = provider.pendingRequestCount;
                          return _DrawerTile(
                            icon: Icons.mail_rounded,
                            label: 'Message Requests',
                            onTap: () {
                              _closeAndNavigate(
                                context,
                                () => _openRequests(context),
                              );
                            },
                            badge: count > 0 ? count.toString() : null,
                          );
                        },
                      ),
                      _DrawerTile(
                        icon: Icons.link_rounded,
                        label: 'Create call link',
                        onTap: () => _closeAndNavigate(
                          context,
                          () => context.push('/chat/call-link/create'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _DrawerSectionLabel(title: 'Play'),
                      _DrawerTile(
                        icon: Icons.sports_esports_rounded,
                        label: 'Game Center',
                        badge: 'NEW',
                        isFeatured: true,
                        onTap: () => _closeAndNavigate(
                          context,
                          () => context.push('/games'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _DrawerSectionLabel(title: 'Tools'),
                      _DrawerTile(
                        label: 'Tip Jar',
                        onTap: () {
                          _closeAndNavigate(
                            context,
                            () => TipSheet.show(context, recipients: []),
                          );
                        },
                        customLeading: Icon(
                          Icons.volunteer_activism_outlined,
                          size: 20,
                          color: colors.primary,
                        ),
                      ),

                      const SizedBox(height: 24),
                      const _DrawerSectionLabel(title: 'Creation'),
                      _DrawerTile(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'Create Private Circle',
                        onTap: () {
                          _closeAndNavigate(
                            context,
                            () => context.push('/chat/groups/create'),
                          );
                        },
                        isAction: true,
                      ),
                      _DrawerTile(
                        icon: Icons.sensors_rounded,
                        label: 'Launch Channel',
                        onTap: () {
                          _closeAndNavigate(
                            context,
                            () => context.push('/chat/channels/create'),
                          );
                        },
                        isAction: true,
                      ),
                    ],
                  ),
                ),

                // Footer branded text
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
                  child: Text(
                    'Griot • griot.network',
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
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

class _DrawerSectionLabel extends StatelessWidget {
  final String title;

  const _DrawerSectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: colors.primary.withValues(alpha: 0.5),
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  final Widget? customLeading;
  final bool isAction;
  final bool isFeatured;

  const _DrawerTile({
    this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.customLeading,
    this.isAction = false,
    this.isFeatured = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: isFeatured ? 12 : 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isFeatured
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary.withValues(alpha: 0.22),
                  colors.secondary.withValues(alpha: 0.12),
                ],
              )
            : null,
        color: isFeatured ? null : colors.surface,
        border: Border.all(
          color: colors.primary.withValues(
            alpha: isFeatured ? 0.55 : (isAction ? 0.15 : 0.05),
          ),
          width: isFeatured ? 1.4 : 1.0,
        ),
        boxShadow: isFeatured
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.16),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: ListTile(
        onTap: onTap,
        visualDensity: isFeatured
            ? VisualDensity.standard
            : VisualDensity.compact,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isFeatured ? 7 : 2,
        ),
        leading: Container(
          padding: EdgeInsets.all(isFeatured ? 11 : 8),
          decoration: BoxDecoration(
            color:
                (isFeatured
                        ? colors.primary
                        : (isAction ? colors.primary : colors.onSurface))
                    .withValues(alpha: isFeatured ? 0.22 : 0.05),
            borderRadius: BorderRadius.circular(isFeatured ? 15 : 12),
          ),
          child:
              customLeading ??
              (icon != null
                  ? Icon(
                      icon,
                      color: isFeatured || isAction
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.7),
                      size: isFeatured ? 24 : 18,
                    )
                  : null),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isFeatured || isAction
                ? FontWeight.w900
                : FontWeight.w700,
            fontSize: isFeatured ? 16 : 14,
            color: colors.onSurface,
          ),
        ),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colors.onSurface.withValues(alpha: 0.2),
              ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
// Clean version
