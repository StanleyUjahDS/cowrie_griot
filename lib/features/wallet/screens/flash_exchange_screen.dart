import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import 'package:provider/provider.dart';
import '../services/wallet_api_service.dart';
import '../models/token_model.dart';
import '../providers/wallet_provider.dart';
import '../../../core/ui/widgets/banner_ad.dart';

class FlashExchangeScreen extends StatefulWidget {
  const FlashExchangeScreen({super.key});

  @override
  State<FlashExchangeScreen> createState() => _FlashExchangeScreenState();
}

class _FlashExchangeScreenState extends State<FlashExchangeScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _detectedAddress = "";
  bool _hasUserMessage = false;
  bool _isDetected = false;
  bool _isResolving = false;
  Map<String, dynamic>? _resolvedToken;
  TokenModel? _resolvedTokenModel;
  String _addressKind = '';

  Future<void> _openResolvedLink(String key) async {
    String? url = _resolvedTokenModel?.externalLinks[key];

    // Fallback generation if no link provided by backend
    if ((url == null || url.isEmpty) && _detectedAddress.isNotEmpty) {
      final chain = _resolvedTokenModel?.chain ?? 'ethereum';
      final normalizedChain = _normalizeForExternalLinks(chain);

      if (key == 'explorer') {
        final base = _getExplorerBase(normalizedChain);
        url = '$base$_detectedAddress';
      } else if (key == 'dexScreener') {
        url = 'https://dexscreener.com/$normalizedChain/$_detectedAddress';
      }
    }

    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              key == 'explorer'
                  ? 'No block explorer link is available.'
                  : 'No chart link is available.',
            ),
          ),
        );
      }
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this link.')),
        );
      }
    }
  }

  String _normalizeForExternalLinks(String chain) {
    final c = chain.toLowerCase().trim();
    if (c == 'bnb' || c == 'bsc') return 'bsc';
    if (c == 'eth') return 'ethereum';
    if (c == 'matic') return 'polygon';
    return c;
  }

  String _getExplorerBase(String chain) {
    switch (chain) {
      case 'bsc':
        return 'https://bscscan.com/address/';
      case 'polygon':
        return 'https://polygonscan.com/address/';
      case 'base':
        return 'https://basescan.org/address/';
      case 'arbitrum':
        return 'https://arbiscan.io/address/';
      case 'optimism':
        return 'https://optimistic.etherscan.io/address/';
      case 'avalanche':
        return 'https://snowtrace.io/address/';
      case 'ethereum':
      default:
        return 'https://etherscan.io/address/';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _detectAddress() async {
    final raw = _messageController.text.trim();
    if (raw.isEmpty) return;

    final evmRegex = RegExp(r'0x[a-fA-F0-9]{40}');
    final solanaRegex = RegExp(r'\b[1-9A-HJ-NP-Za-km-z]{32,44}\b');

    final evmMatch = evmRegex.firstMatch(raw);
    final solanaMatch = solanaRegex.firstMatch(raw);

    setState(() {
      if (evmMatch != null) {
        _detectedAddress = evmMatch.group(0)!;
        _isDetected = true;
        _addressKind = 'wallet_or_contract';
      } else if (solanaMatch != null) {
        _detectedAddress = solanaMatch.group(0)!;
        _isDetected = true;
        _addressKind = 'wallet_or_contract';
      } else {
        _detectedAddress = "";
        _isDetected = false;
      }
      _hasUserMessage = true;
      _isResolving = _isDetected;
      _resolvedToken = null;
    });

    if (_isDetected && evmMatch != null) {
      try {
        final matches = await context.read<WalletApiService>().searchAssets(
          query: _detectedAddress,
        );
        if (!mounted) return;
        setState(() {
          _resolvedToken = matches.isNotEmpty
              ? {
                  'name': matches.first.name,
                  'symbol': matches.first.symbol,
                  'network': matches.first.rawNetwork.isNotEmpty
                      ? matches.first.rawNetwork
                      : matches.first.chain,
                  'contractAddress': matches.first.contractAddress,
                  'decimals': matches.first.decimals,
                  'priceUsd': matches.first.priceUsd,
                }
              : null;
          _resolvedTokenModel = matches.isNotEmpty ? matches.first : null;
          _addressKind = matches.isNotEmpty ? 'contract' : 'wallet';
          _isResolving = false;
        });
      } catch (_) {
        if (mounted) {
          setState(() {
            _addressKind = 'wallet';
            _isResolving = false;
          });
        }
      }
    }

    // Auto scroll to bottom to show results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pasteFromClipboard() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboard?.text == null) return;

    final value = clipboard!.text!.trim();
    if (value.isEmpty) return;

    setState(() {
      _messageController.text = value;
    });
  }

  Future<void> _copyAddress() async {
    if (_detectedAddress.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _detectedAddress));
  }

  void _handleSwapAction({required bool isBuy}) {
    if (_resolvedTokenModel == null) return;

    final provider = context.read<WalletProvider>();
    final chain = _resolvedTokenModel!.chain.toLowerCase();

    TokenModel? baseToken;

    try {
      // Always choose the native/stable token from the detected token's chain.
      baseToken = provider.tokens.firstWhere(
        (t) =>
            t.chain.toLowerCase() == chain &&
            (t.isNative ||
                t.symbol.toUpperCase() == 'USDT' ||
                t.symbol.toUpperCase() == 'USDC' ||
                t.symbol.toUpperCase() == 'BUSD'),
        orElse: () => provider.tokens.firstWhere(
          (t) => t.chain.toLowerCase() == chain && t.isNative,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No native token is available on $chain.')),
        );
      }
      return;
    }

    if (isBuy) {
      context.push(
        '/wallet/swap',
        extra: {'from': baseToken, 'to': _resolvedTokenModel},
      );
    } else {
      context.push(
        '/wallet/swap',
        extra: {'from': _resolvedTokenModel, 'to': baseToken},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GradientScaffold(
        useSafeArea: false,
        appBar: AppBar(
          title: const Text('Flash Exchange'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  _buildBotMessage(
                        context,
                        "Welcome to Flash Exchange! Send me a contract address or wallet address to get started.",
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
                  if (_hasUserMessage) ...[
                    const SizedBox(height: 20),
                    _buildUserMessage(context, _messageController.text)
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: 0.05, end: 0),
                    const SizedBox(height: 20),
                    (_isDetected
                            ? _buildDetectedTokenCard(context)
                            : _buildUnsupportedCard(context))
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.05, end: 0),
                  ],
                ],
              ),
            ),
            const GriotBannerAd(),
            _buildInputArea(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBotMessage(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: colors.primary.withValues(alpha: 0.1),
          child: Icon(Icons.flash_on_rounded, size: 18, color: colors.primary),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      ],
    );
  }

  Widget _buildUserMessage(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.onPrimary),
        ),
      ),
    );
  }

  Widget _buildDetectedTokenCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: colors.primary.withValues(alpha: 0.1),
          child: Icon(Icons.flash_on_rounded, size: 18, color: colors.primary),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isResolving
                      ? "Looking up address..."
                      : (_addressKind == 'contract'
                            ? "Token contract detected"
                            : "Wallet address detected"),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _detectedAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            fontFamily: "monospace",
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _copyAddress,
                        child: Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_resolvedToken != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${_resolvedToken!['name'] ?? 'Unknown token'} (${_resolvedToken!['symbol'] ?? '—'})',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Network: ${_resolvedToken!['network'] ?? _resolvedToken!['chain'] ?? 'Unknown'}',
                    style: text.bodySmall,
                  ),
                  if (_resolvedToken!['contractAddress'] != null)
                    Text(
                      'Contract: ${_resolvedToken!['contractAddress']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(fontFamily: 'monospace'),
                    ),
                ],
                const SizedBox(height: 16),
                if (_addressKind == 'contract') ...[
                  Row(
                    children: [
                      _actionButton(
                        context,
                        icon: Icons.shopping_cart_rounded,
                        label: "Buy",
                        primary: true,
                        onTap: () => _handleSwapAction(isBuy: true),
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        context,
                        icon: Icons.sell_rounded,
                        label: "Sell",
                        onTap: () => _handleSwapAction(isBuy: false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _actionButton(
                        context,
                        icon: Icons.show_chart_rounded,
                        label: "Chart",
                        onTap: () => _openResolvedLink('dexScreener'),
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        context,
                        icon: Icons.open_in_new_rounded,
                        label: "View",
                        onTap: () => _openResolvedLink('explorer'),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      _actionButton(
                        context,
                        icon: Icons.send_rounded,
                        label: "Send to",
                        primary: true,
                        onTap: () => context.push(
                          '/wallet/send',
                          extra: _detectedAddress,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        context,
                        icon: Icons.open_in_new_rounded,
                        label: "Explorer",
                        onTap: () => _openResolvedLink('explorer'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnsupportedCard(BuildContext context) {
    return _buildBotMessage(
      context,
      "I couldn't find a supported wallet or contract address in that message.",
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return Expanded(
      child: SizedBox(
        height: 44,
        child: primary
            ? ElevatedButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 18),
                label: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            : OutlinedButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 18),
                label: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: colors.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "Paste address or message...",
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste_rounded),
                      onPressed: _pasteFromClipboard,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: colors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _detectAddress,
                child: const SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(Icons.arrow_upward_rounded, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
