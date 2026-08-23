import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../models/token_model.dart';
import '../providers/token_search_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/wallet_api_service.dart';
import '../widgets/token_icon.dart';
import '../utils/wallet_formatters.dart';

class AssetSearchScreen extends StatelessWidget {
  final String? initialQuery;
  final bool isSelectMode;

  const AssetSearchScreen({
    super.key, 
    this.initialQuery,
    this.isSelectMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.read<WalletProvider>();
    return ChangeNotifierProvider(
      create: (context) => TokenSearchProvider(
        walletApiService: context.read<WalletApiService>(),
      )
        ..setHoldings(walletProvider.tokens)
        ..setWalletMode(!isSelectMode)
        ..updateQuery(initialQuery ?? ''),
      child: _AssetSearchContent(isSelectMode: isSelectMode),
    );
  }
}

class _AssetSearchContent extends StatefulWidget {
  final bool isSelectMode;

  const _AssetSearchContent({required this.isSelectMode});

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

  Future<void> _toggleVisibility(BuildContext context, TokenModel token) async {
    final provider = context.read<WalletProvider>();
    final isHidden = provider.isTokenHidden(token);

    final action = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isHidden ? 'Unhide ${token.symbol}?' : 'Hide ${token.symbol}?'),
        content: Text(isHidden
            ? 'This will make the token visible in your wallet list again.'
            : 'This only removes the token from your wallet list. It does not affect your blockchain balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isHidden ? 'Unhide' : 'Hide'),
          ),
        ],
      ),
    );

    if (action == true) {
      if (isHidden) {
        await provider.showToken(token);
      } else {
        await provider.hideToken(token);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final provider = context.watch<TokenSearchProvider>();

    return GradientScaffold(
      appBar: AppBar(
        title: Text(widget.isSelectMode ? 'Select Asset' : 'Search Assets'),
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
          else if (provider.query.isEmpty && provider.results.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Text(
                      widget.isSelectMode ? 'Popular assets' : 'Your holdings',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: provider.results.length,
                      itemBuilder: (context, index) {
                        final token = provider.results[index];
                        return _TokenSearchResultItem(
                          token: token,
                          isSelectMode: widget.isSelectMode,
                          onLongPress: () => _toggleVisibility(context, token),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          else if (provider.query.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, size: 64, color: colors.onSurfaceVariant.withValues(alpha: 0.2)),
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
                    Icon(Icons.search_off, size: 64, color: colors.onSurfaceVariant.withValues(alpha: 0.2)),
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
                  return _TokenSearchResultItem(
                    token: token,
                    isSelectMode: widget.isSelectMode,
                    onLongPress: () => _toggleVisibility(context, token),
                  );
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
  final bool isSelectMode;
  final VoidCallback? onLongPress;

  const _TokenSearchResultItem({
    required this.token,
    required this.isSelectMode,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    final walletProvider = context.watch<WalletProvider>();

    final isBlocked = token.status == 'blocked';
    final isHidden = walletProvider.isTokenHidden(token);
    final canSwap = context.read<TokenSearchProvider>().canSwap(token);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: InkWell(
        onTap: () {
          if (isSelectMode) {
            if (canSwap) {
              Navigator.pop(context, token);
            }
          } else {
            context.push('/wallet/asset', extra: token);
          }
        },
        onLongPress: isSelectMode ? null : onLongPress,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isBlocked 
              ? colors.error.withValues(alpha: 0.05) 
              : colors.surfaceContainerLow.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isBlocked 
                ? colors.error.withValues(alpha: 0.2) 
                : isHidden
                  ? colors.primary.withValues(alpha: 0.3)
                  : colors.outlineVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TokenIcon(
                    imageUrl: token.imageUrl,
                    symbol: token.symbol,
                    name: token.name,
                    chainName: token.chain,
                    isNative: token.isNative,
                    radius: 20,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                token.name.isEmpty ? token.symbol : token.name,
                                style: text.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (token.status == 'verified' || token.isNative || token.isGriotAsset) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: Colors.green,
                              ),
                            ],
                            if (token.isEcosystem) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.workspace_premium_rounded,
                                size: 16,
                                color: colors.primary,
                              ),
                            ],
                          ],
                        ),
                        if (token.isGriotAsset) ...[
                          const SizedBox(height: 2),
                          Text(
                            "Griot Native Asset",
                            style: text.labelSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          '${token.symbol} • ${token.chain.toUpperCase()}',
                          style: text.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (token.balance > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Holding: ${WalletFormatters.formatBalance(token.balance)}',
                            style: text.labelSmall?.copyWith(
                              color: isHidden ? colors.onSurfaceVariant : colors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isSelectMode && token.balance > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Transform.scale(
                          scale: 0.7,
                          alignment: Alignment.centerRight,
                          child: Switch.adaptive(
                            value: !isHidden,
                            onChanged: (value) async {
                              if (value) {
                                await walletProvider.showToken(token);
                              } else {
                                await walletProvider.hideToken(token);
                              }
                            },
                            activeTrackColor: colors.primary,
                            activeThumbColor: Colors.white,
                          ),
                        ),
                        Text(
                          isHidden ? "HIDDEN" : "VISIBLE",
                          style: text.labelSmall?.copyWith(
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            color: isHidden ? colors.onSurfaceVariant : colors.primary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (!token.isOfficial && !token.isNative && token.contractAddress.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          token.contractAddress,
                          style: text.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Spacer(),
                  _buildLinksRow(token),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinksRow(TokenModel token) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
