import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/messaging_provider.dart';

import '/core/services/notification_service.dart';

class ChatDrawer extends StatelessWidget {
  const ChatDrawer({super.key});

  void _openNewChat(BuildContext context) => context.push('/chat/discover');
  void _openFriends(BuildContext context) => context.push('/chat/friends');
  void _openRequests(BuildContext context) => context.push('/chat/requests');

  void _showCreateGroupSheet(BuildContext context) {
    final controller = TextEditingController();
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          padding: EdgeInsets.fromLTRB(28, 20, 28, MediaQuery.of(sheetContext).viewInsets.bottom + 28),
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: colors.onSurfaceVariant.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'New Group',
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a private space for your friends.',
                style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller, 
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  prefixIcon: const Icon(Icons.groups_rounded),
                  filled: true,
                  fillColor: colors.surfaceContainerLow,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    try {
                      await context.read<MessagingProvider>().createGroup(name: name);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } catch (_) {}
                  },
                  child: const Text('Create Group', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateChannelSheet(BuildContext context) {
    final controller = TextEditingController();
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          padding: EdgeInsets.fromLTRB(28, 20, 28, MediaQuery.of(sheetContext).viewInsets.bottom + 28),
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: colors.onSurfaceVariant.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'New Channel',
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Broadcast your stories to the world.',
                style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Channel Name',
                  prefixIcon: const Icon(Icons.campaign_rounded),
                  filled: true,
                  fillColor: colors.surfaceContainerLow,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    try {
                      await context.read<MessagingProvider>().createChannel(name: name);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } catch (_) {}
                  },
                  child: const Text('Create Channel', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.70,
      child: ClipPath(
        clipper: _ModernCowrieClipper(),
        child: Material(
          color: colors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Clean Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SvgPicture.asset(
                      'assets/cowrie_images/cowriesvg.svg',
                      width: 48,
                      height: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Griot',
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                      ),
                    ),
                    Text(
                      'Decentralized Social',
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Simple Navigation
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _tile(context, Icons.search_rounded, 'Discover', () {
                      Navigator.pop(context);
                      _openNewChat(context);
                    }),
                    _tile(context, Icons.people_rounded, 'Friends', () {
                      Navigator.pop(context);
                      _openFriends(context);
                    }),
                    Consumer<MessagingProvider>(
                      builder: (context, provider, _) {
                        final count = provider.pendingRequestCount;
                        return _tile(context, Icons.mail_rounded, 'Requests', () {
                          Navigator.pop(context);
                          _openRequests(context);
                        }, badge: count > 0 ? count.toString() : null);
                      },
                    ),
                    _tile(context, Icons.toll_rounded, 'Tip', () {
                      Navigator.pop(context);
                      NotificationService.showInfo(context, 'Tipping coming soon');
                    }),
                    
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 32, 16, 8),
                      child: Divider(height: 1, thickness: 0.5),
                    ),
                    
                    _tile(context, Icons.add_circle_outline_rounded, 'New Group', () {
                      Navigator.pop(context);
                      _showCreateGroupSheet(context);
                    }),
                    _tile(context, Icons.sensors_rounded, 'New Channel', () {
                      Navigator.pop(context);
                      _showCreateChannelSheet(context);
                    }),
                  ],
                ),
              ),

              // 3. Minimal Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
                child: Text(
                  'GRIOT v1.0',
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, VoidCallback onTap, {String? badge}) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: colors.onSurface.withValues(alpha: 0.6), size: 22),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      trailing: badge != null 
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(10)),
            child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          )
        : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      dense: true,
    );
  }
}

class _ModernCowrieClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final double tip = 100.0; // Sharp/Straight tip length
    
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, tip);
    
    // Very simple, modern concave slit
    path.quadraticBezierTo(
      size.width - 40, size.height * 0.5,
      size.width, size.height - tip
    );
    
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
