import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/nft_model.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/services/notification_service.dart';
import '../utils/wallet_formatters.dart';

class NftDetailsScreen extends StatelessWidget {
  final NftModel nft;

  const NftDetailsScreen({
    super.key,
    required this.nft,
  });

  Future<void> _launchUrl(BuildContext context, String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        NotificationService.showError(context, 'Could not launch link');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return GradientScaffold(
      appBar: AppBar(
        title: Text(nft.name.isEmpty ? 'NFT Details' : nft.name),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // NFT Image
              Center(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 400),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: nft.imageUrl != null
                        ? Image.network(
                            nft.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: colors.surfaceContainerHighest,
                              height: 300,
                              child: Icon(Icons.broken_image, size: 64, color: colors.onSurfaceVariant),
                            ),
                          )
                        : Container(
                            color: colors.surfaceContainerHighest,
                            height: 300,
                            child: Icon(Icons.image, size: 64, color: colors.onSurfaceVariant),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Basic Info
              Text(
                nft.collectionName,
                style: text.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                nft.name,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              if (nft.description.isNotEmpty) ...[
                Text(
                  nft.description,
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // Tags
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Tag(label: nft.network.toUpperCase(), color: colors.secondary),
                  _Tag(label: nft.standard, color: colors.tertiary),
                  if (nft.classification.isTradeable)
                    const _Tag(label: 'Tradeable', color: Colors.green),
                  if (nft.classification.isSpam)
                    const _Tag(label: 'Spam', color: Colors.red),
                ],
              ),
              const SizedBox(height: 40),

              // Info Card
              _buildSectionHeader(context, 'Details'),
              const SizedBox(height: 16),
              _buildInfoCard(context),

              const SizedBox(height: 32),

              // External Links
              if (nft.externalLinks.isNotEmpty) ...[
                _buildSectionHeader(context, 'Links'),
                const SizedBox(height: 16),
                _buildLinkCard(context),
                const SizedBox(height: 48),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = Theme.of(context).colorScheme;
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: colors.primary,
        fontWeight: FontWeight.w900,
        fontSize: 11,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _infoRow(context, 'Contract Address', WalletFormatters.shortenAddress(nft.contractAddress), 
            onTap: () {
              Clipboard.setData(ClipboardData(text: nft.contractAddress));
              NotificationService.showSuccess(context, 'Address copied');
            },
            trailing: Icon(Icons.copy_rounded, size: 16, color: colors.primary),
          ),
          const Divider(height: 32),
          _infoRow(context, 'Token ID', nft.tokenId,
            onTap: () {
              Clipboard.setData(ClipboardData(text: nft.tokenId));
              NotificationService.showSuccess(context, 'Token ID copied');
            },
            trailing: Icon(Icons.copy_rounded, size: 16, color: colors.primary),
          ),
          const Divider(height: 32),
          _infoRow(context, 'Standard', nft.standard),
          const Divider(height: 32),
          _infoRow(context, 'Quantity', nft.quantity),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value, {VoidCallback? onTap, Widget? trailing}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final links = nft.externalLinks.entries.toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: List.generate(links.length, (index) {
          final entry = links[index];
          return Column(
            children: [
              ListTile(
                title: Text(entry.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => _launchUrl(context, entry.value),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: index == 0 ? const Radius.circular(20) : Radius.zero,
                    bottom: index == links.length - 1 ? const Radius.circular(20) : Radius.zero,
                  ),
                ),
              ),
              if (index < links.length - 1)
                Divider(height: 1, indent: 16, endIndent: 16, color: colors.outlineVariant.withValues(alpha: 0.2)),
            ],
          );
        }),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
