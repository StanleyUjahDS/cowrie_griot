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
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(40),
              bottomRight: Radius.circular(40),
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
              // 1. Premium Branded Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 64, 24, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary.withValues(alpha: 0.08),
                      colors.primary.withValues(alpha: 0.02),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: colors.primary.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                ),
                child: Stack(
                  children: [
                    // Branded Background Element
                    Positioned(
                      right: -20,
                      top: -10,
                      child: Opacity(
                        opacity: 0.06,
                        child: Image.asset(
                          'assets/cowrie_images/Cowrie4.png',
                          width: 120,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.15),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: SvgPicture.asset(
                            'assets/cowrie_images/cowriesvg.svg',
                            width: 34,
                            height: 34,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Griot',
                          style: text.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'DECENTRALIZED NETWORK',
                            style: text.labelSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Navigation List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    const _DrawerSectionLabel(title: 'Connections'),
                    _DrawerTile(
                      icon: Icons.search_rounded,
                      label: 'Discover Users',
                      onTap: () {
                        _closeAndNavigate(context, () => _openNewChat(context));
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.people_rounded,
                      label: 'My Friends',
                      onTap: () {
                        _closeAndNavigate(context, () => _openFriends(context));
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
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                child: Text(
                  'v1.0.0 • griot.network',
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

  const _DrawerTile({
    this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.customLeading,
    this.isAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border(
          top: BorderSide(
            color: colors.primary.withValues(alpha: isAction ? 0.15 : 0.05),
            width: 1.0,
          ),
          bottom: BorderSide(
            color: colors.primary.withValues(alpha: isAction ? 0.15 : 0.05),
            width: 1.0,
          ),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isAction ? colors.primary : colors.onSurface).withValues(
              alpha: 0.05,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              customLeading ??
              (icon != null
                  ? Icon(
                      icon,
                      color: isAction
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.7),
                      size: 18,
                    )
                  : null),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isAction ? FontWeight.w900 : FontWeight.w700,
            fontSize: 14,
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
