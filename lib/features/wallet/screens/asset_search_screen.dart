import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../models/token_model.dart';
import '../providers/token_search_provider.dart';
import '../services/wallet_api_service.dart';

class AssetSearchScreen extends StatelessWidget {
  const AssetSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TokenSearchProvider(
        walletApiService: context.read<WalletApiService>(),
      ),
      child: const _AssetSearchContent(),
    );
  }
}

class _AssetSearchContent extends StatefulWidget {
  const _AssetSearchContent();

  @override
  State<_AssetSearchContent> createState() => _AssetSearchContentState();
}

class _AssetSearchContentState extends State<_AssetSearchContent> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final provider = context.watch<TokenSearchProvider>();

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Search Assets'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              onChanged: provider.updateQuery,
              decoration: InputDecoration(
                hintText: 'Search by name, symbol, or address',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          provider.clearSearch();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colors.surfaceContainerLow,
              ),
            ),
          ),
          if (provider.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (provider.error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: colors.error),
                      const SizedBox(height: 16),
                      Text(
                        'Unable to complete search',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        provider.error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (provider.query.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, size: 64, color: colors.onSurfaceVariant.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    Text(
                      'Search for tokens or paste an address',
                      style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          else if (provider.results.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off, size: 64, color: colors.onSurfaceVariant.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    Text(
                      'No results found for "${provider.query}"',
                      style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: provider.results.length,
                itemBuilder: (context, index) {
                  final token = provider.results[index];
                  return _TokenSearchResultItem(token: token);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TokenSearchResultItem extends StatelessWidget {
  final TokenModel token;

  const _TokenSearchResultItem({required this.token});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        token.name,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${token.symbol} • ${token.chain.toUpperCase()}',
                        style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: token.status),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      token.contractAddress.isEmpty ? 'Native Asset' : token.contractAddress,
                      style: text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (token.reasons.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...token.reasons.map((reason) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: colors.error),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reason,
                            style: text.bodySmall?.copyWith(color: colors.error, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (context.read<TokenSearchProvider>().canSwap(token))
                  FilledButton.tonal(
                    onPressed: () {
                      // Navigate to swap screen with this token
                      Navigator.pop(context, token);
                    },
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Swap'),
                  )
                else
                  Text(
                    'Swapping unavailable',
                    style: text.labelSmall?.copyWith(color: colors.error.withOpacity(0.7)),
                  ),
                const Spacer(),
                if (token.externalLinks.containsKey('dexScreener'))
                  _LinkButton(
                    icon: Icons.show_chart,
                    tooltip: 'DEX Screener',
                    onPressed: () => _launchUrl(token.externalLinks['dexScreener']!),
                  ),
                if (token.externalLinks.containsKey('explorer'))
                  _LinkButton(
                    icon: Icons.explore_outlined,
                    tooltip: 'Explorer',
                    onPressed: () => _launchUrl(token.externalLinks['explorer']!),
                  ),
                if (token.externalLinks.containsKey('tokenSniffer'))
                  _LinkButton(
                    icon: Icons.security,
                    tooltip: 'TokenSniffer',
                    onPressed: () => _launchUrl(token.externalLinks['tokenSniffer']!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _LinkButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _LinkButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    
    Color backgroundColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'official':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        label = 'Official';
        icon = Icons.verified;
        break;
      case 'verified':
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        label = 'Verified';
        icon = Icons.check_circle_outline;
        break;
      case 'blocked':
        backgroundColor = colors.errorContainer;
        textColor = colors.onErrorContainer;
        label = 'Blocked';
        icon = Icons.block;
        break;
      case 'unknown':
      default:
        backgroundColor = colors.secondaryContainer;
        textColor = colors.onSecondaryContainer;
        label = 'Warning';
        icon = Icons.help_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
