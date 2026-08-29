import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../providers/messaging_provider.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Consumer<MessagingProvider>(
        builder: (context, provider, child) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeOutQuart,
            child: _buildBody(context, provider),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, MessagingProvider provider) {
    final colors = Theme.of(context).colorScheme;
    
    final unreadMessages = provider.conversations.where((c) => c.unreadCount > 0).toList();
    final pendingRequests = provider.receivedRequests.where((r) => r.isPending).toList();

    if (unreadMessages.isEmpty && pendingRequests.isEmpty) {
      return _buildEmptyState(context, key: const ValueKey('empty'));
    }

    return ListView(
      key: const ValueKey('content'),
      padding: const EdgeInsets.all(20),
      children: [
        if (pendingRequests.isNotEmpty) ...[
          _buildSectionHeader(context, 'CONNECTION REQUESTS'),
          ...pendingRequests.asMap().entries.map((entry) {
            final index = entry.key;
            final req = entry.value;
            return _buildActivityTile(
              context,
              icon: Icons.person_add_rounded,
              color: colors.primary,
              title: 'New Connection Request',
              subtitle: '${req.displayName} wants to connect with you.',
              time: req.createdAt,
              onTap: () => context.push('/chat/requests'),
            ).animate().fadeIn(duration: 400.ms, delay: (index * 40).ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad);
          }),
          const SizedBox(height: 32),
        ],

        if (unreadMessages.isNotEmpty) ...[
          _buildSectionHeader(context, 'MESSAGES'),
          ...unreadMessages.asMap().entries.map((entry) {
            final index = entry.key;
            final conv = entry.value;
            return _buildActivityTile(
              context,
              icon: Icons.chat_bubble_rounded,
              color: Colors.blueAccent,
              title: conv.title ?? 'New Message',
              subtitle: conv.lastMessage?.text ?? 'You have a new message.',
              time: conv.updatedAt,
              onTap: () => context.push('/conversation/${conv.id}'),
            ).animate().fadeIn(duration: 400.ms, delay: (index * 40).ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad);
          }),
        ],

        const SizedBox(height: 32),
        _buildSectionHeader(context, 'TIPS & REWARDS'),
        _buildActivityTile(
          context,
          customIcon: SvgPicture.asset(
            'assets/cowrie_images/cowriesvg.svg',
            width: 20, height: 20,
            colorFilter: ColorFilter.mode(Colors.amber, BlendMode.srcIn),
          ),
          color: Colors.amber,
          title: 'Tipping Coming Soon',
          subtitle: 'Your rewards and tips will appear here.',
          time: DateTime.now(),
          onTap: null,
          isPlaceholder: true,
        ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildActivityTile(
    BuildContext context, {
    IconData? icon,
    Widget? customIcon,
    required Color color,
    required String title,
    required String subtitle,
    required DateTime time,
    required VoidCallback? onTap,
    bool isPlaceholder = false,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outline.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: customIcon ?? Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isPlaceholder ? '--' : DateFormat('HH:mm').format(time),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {Key? key}) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded, size: 64, color: colors.primary.withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 24),
          const Text(
            'All Caught Up',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'New requests, tips, and alerts will appear here.',
            style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
