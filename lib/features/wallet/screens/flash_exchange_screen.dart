import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import 'package:provider/provider.dart';
import '../services/wallet_api_service.dart';
import '../models/token_model.dart';
import '../models/flash_token_result.dart';
import '../providers/wallet_provider.dart';
import '../utils/wallet_formatters.dart';
import '../utils/chain_assets.dart';

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
  String _lastSubmittedMessage = '';
  bool _isDetected = false;
  bool _isResolving = false;
  String? _lookupError;
  FlashTokenResult? _flashResult;
  String _addressKind = '';

  Future<void> _openResolvedLink(String key) async {
    String? url = _flashResult?.token?.externalLinks[key];

    // Fallback generation if no link provided by backend
    if ((url == null || url.isEmpty) && _detectedAddress.isNotEmpty) {
      final chain = _flashResult?.token?.chain ?? 'ethereum';
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
    final c = ChainAssets.normalize(chain);
    if (c == 'bnb') return 'bsc';
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
      _lastSubmittedMessage = raw;
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
      _flashResult = null;
      _lookupError = null;
    });
    _messageController.clear();

    if (_isDetected) {
      try {
        final result = await context.read<WalletApiService>().lookupFlashToken(_detectedAddress);
        if (!mounted) return;
        setState(() {
          _flashResult = result;
          _addressKind = result?.addressType ?? (evmMatch != null ? 'wallet' : 'unknown');
          _isResolving = false;
        });
      } catch (_) {
        if (mounted) {
          setState(() {
            _isResolving = false;
            _lookupError = 'Unable to resolve this address. Please try again.';
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
    final token = _flashResult?.token;
    if (token == null) return;

    final provider = context.read<WalletProvider>();
    final chain = _normalizeForExternalLinks(
      token.rawNetwork.isNotEmpty ? token.rawNetwork : token.chain,
    );

    TokenModel? baseToken;

    try {
      // Always choose the native/stable token from the detected token's chain.
      baseToken = provider.tokens.firstWhere(
        (t) =>
            _normalizeForExternalLinks(
                  t.rawNetwork.isNotEmpty ? t.rawNetwork : t.chain,
                ) == chain &&
            (t.isNative ||
                t.symbol.toUpperCase() == 'USDT' ||
                t.symbol.toUpperCase() == 'USDC' ||
                t.symbol.toUpperCase() == 'BUSD'),
        orElse: () => provider.tokens.firstWhere(
          (t) =>
              _normalizeForExternalLinks(
                    t.rawNetwork.isNotEmpty ? t.rawNetwork : t.chain,
                  ) ==
                  chain &&
              t.isNative,
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
        extra: {'from': baseToken, 'to': token},
      );
    } else {
      context.push(
        '/wallet/swap',
        extra: {'from': token, 'to': baseToken},
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
                    _buildUserMessage(context, _lastSubmittedMessage)
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

    final canBuy = _flashResult?.trading.canBuy ?? false;
    final canSell = _flashResult?.trading.canSell ?? false;
    final token = _flashResult?.token;

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
              border: Border(
                top: BorderSide(
                  color: colors.primary.withValues(alpha: 0.6),
                  width: 1.2,
                ),
                bottom: BorderSide(
                  color: colors.primary.withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
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
                if (_lookupError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _lookupError!,
                    style: text.labelSmall?.copyWith(color: colors.error),
                  ),
                ],
                if (token != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            (token.symbol).substring(0, 1),
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              token.name,
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${token.chain.toUpperCase()} • ${token.symbol}',
                              style: text.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _marketDataRow("Price",
                      WalletFormatters.formatCurrency(token.priceUsd)),
                  _marketDataRow("Market cap",
                      _formatMarketValue(token.marketCapUsd)),
                  _marketDataRow("Liquidity",
                      _formatMarketValue(token.liquidityUsd)),
                  _marketDataRow("24h volume",
                      _formatMarketValue(token.volume24hUsd)),
                  _marketDataRow(
                    "24h change",
                    _formatChange(token.changePercent),
                    valueColor: (token.changePercent ?? 0) >= 0
                        ? Colors.green
                        : Colors.red,
                  ),
                  _marketDataRow(
                    "Buy tax",
                    _formatTax(_flashResult?.security?.buyTaxPercent),
                  ),
                  _marketDataRow(
                    "Sell tax",
                    _formatTax(_flashResult?.security?.sellTaxPercent),
                  ),
                  if (_flashResult?.security == null ||
                      _flashResult?.security?.status == 'unknown')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Security scan unavailable; trade carefully.',
                        style: text.labelSmall?.copyWith(
                          color: Colors.orange.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
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
                        onTap: canBuy
                            ? () => _handleSwapAction(isBuy: true)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        context,
                        icon: Icons.sell_rounded,
                        label: "Sell",
                        onTap: canSell
                            ? () => _handleSwapAction(isBuy: false)
                            : null,
                      ),
                    ],
                  ),
                  if (!canBuy && !canSell && !_isResolving && _flashResult != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _flashResult?.trading.reason ?? "Trading unavailable for this contract.",
                        style: text.labelSmall?.copyWith(
                          color: colors.error,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _actionButton(
                        context,
                        icon: Icons.show_chart_rounded,
                        label: "Chart",
                        compact: true,
                        onTap: () => _openResolvedLink('dexScreener'),
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        context,
                        icon: Icons.open_in_new_rounded,
                        label: "View",
                        compact: true,
                        onTap: () => _openResolvedLink('explorer'),
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        context,
                        icon: Icons.send_rounded,
                        label: "Send",
                        compact: true,
                        onTap: () => context.push(
                          '/wallet/send',
                          extra: _detectedAddress,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      _actionButton(
                        context,
                        icon: Icons.send_rounded,
                        label: "Send",
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

  Widget _marketDataRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.7),
                  fontSize: 13)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: valueColor)),
        ],
      ),
    );
  }

  String _formatMarketValue(dynamic value) {
    if (value == null || value == 0) return "—";
    final num val = value is num ? value : (num.tryParse(value.toString()) ?? 0);
    if (val == 0) return "—";

    if (val >= 1000000000) return "\$${(val / 1000000000).toStringAsFixed(2)}B";
    if (val >= 1000000) return "\$${(val / 1000000).toStringAsFixed(2)}M";
    if (val >= 1000) return "\$${(val / 1000).toStringAsFixed(2)}K";
    return "\$${val.toStringAsFixed(2)}";
  }

  String _formatChange(dynamic value) {
    if (value == null) return "—";
    final num val = value is num ? value : (num.tryParse(value.toString()) ?? 0);
    return "${val >= 0 ? '+' : ''}${val.toStringAsFixed(2)}%";
  }

  String _formatTax(dynamic value) {
    if (value == null) return "—";
    final num tax = value is num ? value : (num.tryParse(value.toString()) ?? 0);
    return tax == 0
        ? '0%'
        : '${tax.toStringAsFixed(tax == tax.roundToDouble() ? 0 : 2)}%';
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
    required VoidCallback? onTap,
    bool primary = false,
    bool compact = false,
  }) {
    final button = compact
        ? OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Icon(icon, size: 18),
          )
        : primary
            ? ElevatedButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 18),
                label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            : OutlinedButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 18),
                label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );

    return Expanded(
      child: SizedBox(
        height: 44,
        child: Tooltip(message: label, child: button),
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
