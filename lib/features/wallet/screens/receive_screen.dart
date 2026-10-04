import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/token_model.dart';
import '../providers/wallet_provider.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/banner_ad.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';

class ReceiveScreen extends StatefulWidget {
  final TokenModel? token;

  const ReceiveScreen({super.key, this.token});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveOption {
  final String name;
  final String symbol;
  final String network;
  final String? logo;
  const _ReceiveOption(this.name, this.symbol, this.network, this.logo);
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  late _ReceiveOption _selected;

  static const _options = <_ReceiveOption>[
    _ReceiveOption(
      'Hbadger',
      'HBADG',
      'BNB Smart Chain',
      'assets/coins_logo/hbadger_logo.png',
    ),
    _ReceiveOption('Ethereum', 'ETH', 'Ethereum', 'assets/chains/Ethereum.svg'),
    _ReceiveOption(
      'BNB',
      'BNB',
      'BNB Smart Chain',
      'assets/chains/Binance.svg',
    ),
    _ReceiveOption('Polygon', 'POL', 'Polygon', 'assets/chains/Polygon.svg'),
    _ReceiveOption('Arbitrum', 'ETH', 'Arbitrum', 'assets/chains/arbitrum.png'),
    _ReceiveOption('Optimism', 'ETH', 'Optimism', 'assets/chains/Optimism.svg'),
    _ReceiveOption('Base', 'ETH', 'Base', 'assets/chains/base.png'),
    _ReceiveOption(
      'Avalanche',
      'AVAX',
      'Avalanche',
      'assets/chains/Avalanche_AvaxToken 1.svg',
    ),
    _ReceiveOption('USDT', 'USDT', 'Ethereum', 'assets/coins_logo/usdt.svg'),
    _ReceiveOption('USDC', 'USDC', 'Ethereum', 'assets/coins_logo/usdc.svg'),
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.token;
    _selected = initial == null
        ? _options.first
        : _ReceiveOption(initial.name, initial.symbol, initial.chain, null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return Consumer<WalletProvider>(
      builder: (context, provider, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          switchInCurve: Curves.easeOutQuart,
          child: _buildBody(context, provider, theme, colors, text),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    WalletProvider provider,
    ThemeData theme,
    ColorScheme colors,
    TextTheme text,
  ) {
    if (provider.isLoading && provider.wallet == null) {
      return const GradientScaffold(
        key: ValueKey('loading'),
        useSafeArea: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final address = provider.wallet?.address;
    if (address == null || address.isEmpty) {
      return GradientScaffold(
        key: const ValueKey('error'),
        useSafeArea: true,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            'Receive',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: colors.error),
              const SizedBox(height: 16),
              const Text('No wallet address found'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => provider.loadWallet(force: true),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final symbol = widget.token?.symbol ?? _selected.symbol;
    final network = widget.token?.chain ?? _selected.network;
    final isEvm = _isEvm(network);

    return GradientScaffold(
      key: const ValueKey('content'),
      useSafeArea: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Receive $symbol',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  if (widget.token == null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Networks and assets',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._options.map((option) {
                      final selected =
                          option.symbol == _selected.symbol &&
                          option.network == _selected.network;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => setState(() => _selected = option),
                          child: GriotBrandedContainer(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                if (option.logo != null)
                                  (option.logo!.toLowerCase().endsWith('.svg')
                                      ? SvgPicture.asset(
                                          option.logo!,
                                          width: 38,
                                          height: 38,
                                          errorBuilder: (_, _, _) => Icon(
                                            Icons.currency_exchange,
                                            color: colors.primary,
                                          ),
                                        )
                                      : Image.asset(
                                          option.logo!,
                                          width: 38,
                                          height: 38,
                                          errorBuilder: (_, _, _) => Icon(
                                            Icons.currency_exchange,
                                            color: colors.primary,
                                          ),
                                        ))
                                else
                                  Icon(
                                    Icons.currency_exchange,
                                    size: 38,
                                    color: colors.primary,
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${option.symbol} • ${option.network}',
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Show QR code',
                                      onPressed: () => _showAddressQr(
                                        context,
                                        address,
                                        option.symbol,
                                      ),
                                      icon: Icon(
                                        Icons.qr_code_2_rounded,
                                        color: selected
                                            ? colors.primary
                                            : colors.onSurfaceVariant,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Copy address',
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: address),
                                        );
                                        NotificationService.showSuccess(
                                          context,
                                          'Address copied',
                                        );
                                      },
                                      icon: Icon(
                                        Icons.copy_rounded,
                                        color: selected
                                            ? colors.primary
                                            : colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 16),

                  // Info Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: colors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NETWORK: ${network.toUpperCase()}',
                                style: text.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isEvm
                                    ? 'This address only supports EVM compatible assets. Sending other assets will result in permanent loss.'
                                    : 'Ensure you are sending assets on the correct network (${network.toUpperCase()}). Incorrect network usage may result in loss.',
                                style: text.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant.withValues(
                                    alpha: 0.7,
                                  ),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate(delay: 400.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          const GriotBannerAd(),
        ],
      ),
    );
  }

  void _showAddressQr(BuildContext context, String address, String symbol) {
    final colors = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$symbol receive address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: QrImageView(
                data: address,
                size: 210,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.circle,
                  color: colors.primary,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _formatAddress(address),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: address));
              NotificationService.showSuccess(context, 'Address copied');
              Navigator.pop(dialogContext);
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  bool _isEvm(String network) {
    final n = network.toLowerCase();
    return n == 'ethereum' ||
        n == 'eth' ||
        n == 'base' ||
        n == 'polygon' ||
        n == 'matic' ||
        n == 'arbitrum' ||
        n == 'optimism' ||
        n == 'avalanche' ||
        n == 'bsc' ||
        n == 'binance';
  }

  String _formatAddress(String addr) {
    if (addr.length < 24) return addr;
    return '${addr.substring(0, 12)}...${addr.substring(addr.length - 10)}';
  }
}
