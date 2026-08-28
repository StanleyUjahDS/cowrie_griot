import 'package:flutter/material.dart';
import '../models/nft_model.dart';

class NftItem extends StatelessWidget {
  final NftModel nft;
  final VoidCallback onTap;

  const NftItem({
    super.key,
    required this.nft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: nft.imageUrl != null
                  ? Image.network(
                      nft.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: colors.surfaceContainerHighest,
                        child: Icon(Icons.broken_image, color: colors.onSurfaceVariant),
                      ),
                    )
                  : Container(
                      color: colors.surfaceContainerHighest,
                      child: Icon(Icons.image, color: colors.onSurfaceVariant),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nft.collectionName,
                    style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${nft.name} #${nft.tokenId}',
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
