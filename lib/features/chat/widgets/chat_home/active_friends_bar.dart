import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../providers/messaging_provider.dart';
import '../../../../core/theme/app_colors.dart';

class ActiveFriendsBar extends StatelessWidget {
  const ActiveFriendsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    
    // We only want to rebuild when presence or friends change
    return Consumer<MessagingProvider>(
      builder: (context, provider, _) {
        final onlineFriends = provider.friends.where((f) {
          return provider.presenceMap[f.id] == true;
        }).toList();

        if (onlineFriends.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'ACTIVE NOW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: onlineFriends.length,
                itemBuilder: (context, index) {
                  final user = onlineFriends[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: colors.primary.withValues(alpha: 0.1),
                              backgroundImage: user.avatarUrl != null
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              child: user.avatarUrl == null
                                  ? SvgPicture.asset('assets/coins_logo/hbadger_logo.svg', width: 32)
                                  : null,
                            ),
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colors.surface, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 60,
                          child: Text(
                            user.displayName ?? user.username ?? 'User',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Divider(
                height: 1,
                thickness: 0.5,
                color: colors.outline.withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
