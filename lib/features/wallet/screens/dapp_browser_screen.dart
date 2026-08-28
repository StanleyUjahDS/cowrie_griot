import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/wallet_provider.dart';
import '../services/dapp_browser_service.dart';
import '../utils/chain_assets.dart';
import '../utils/dapp_provider_js.dart';

class DAppNetwork {
  final String name;
  final String chainId;
  final String symbol;

  const DAppNetwork({
    required this.name,
    required this.chainId,
    required this.symbol,
  });
}

class DAppBrowserScreen extends StatefulWidget {
  final String initialUrl;

  const DAppBrowserScreen({
    super.key,
    this.initialUrl = 'https://app.uniswap.org',
  });

  @override
  State<DAppBrowserScreen> createState() => _DAppBrowserScreenState();
}

class _DAppBrowserScreenState extends State<DAppBrowserScreen> {
  InAppWebViewController? _webViewController;
  final TextEditingController _urlController = TextEditingController();
  double _progress = 0;
  bool _showDiscovery = true;
  late DAppBrowserService _dAppService;
  String? _iconBase64;
  String? _targetUrl;

  static const List<DAppNetwork> _networks = [
    DAppNetwork(
      name: 'Ethereum',
      chainId: '0x1',
      symbol: 'ETH',
    ),
    DAppNetwork(
      name: 'BNB Chain',
      chainId: '0x38',
      symbol: 'BNB',
    ),
    DAppNetwork(
      name: 'Polygon',
      chainId: '0x89',
      symbol: 'MATIC',
    ),
    DAppNetwork(
      name: 'Arbitrum',
      chainId: '0xa4b1',
      symbol: 'ETH',
    ),
    DAppNetwork(
      name: 'Optimism',
      chainId: '0xa',
      symbol: 'ETH',
    ),
    DAppNetwork(
      name: 'Base',
      chainId: '0x2105',
      symbol: 'ETH',
    ),
  ];

  DAppNetwork _selectedNetwork = _networks[0];

  final List<Map<String, String>> _popularDApps = [
    {
      'name': 'HBADGER',
      'url': 'https://hbadgertoken.com/',
      'icon': 'https://hbadgertoken.com/favicon.ico',
      'desc': 'Ecosystem Token',
    },
    {
      'name': 'Cowrie',
      'url': 'https://cowrieprotocol.com/',
      'icon': 'https://cowrieprotocol.com/favicon.ico',
      'desc': 'Protocol Home',
    },
    {
      'name': 'Uniswap',
      'url': 'https://app.uniswap.org',
      'icon': 'https://cryptologos.cc/logos/uniswap-uni-logo.png',
      'desc': 'DeFi Exchange',
    },
    {
      'name': 'PancakeSwap',
      'url': 'https://pancakeswap.finance',
      'icon': 'https://cryptologos.cc/logos/pancakeswap-cake-logo.png',
      'desc': 'Trade & Earn',
    },
    {
      'name': 'OpenSea',
      'url': 'https://opensea.io',
      'icon': 'https://cryptologos.cc/logos/opensea-os-logo.png',
      'desc': 'NFT Marketplace',
    },
    {
      'name': '1inch',
      'url': 'https://app.1inch.io',
      'icon': 'https://cryptologos.cc/logos/1inch-1inch-logo.png',
      'desc': 'DEX Aggregator',
    },
    {
      'name': 'Aave',
      'url': 'https://app.aave.com',
      'icon': 'https://cryptologos.cc/logos/aave-aave-logo.png',
      'desc': 'Lending Protocol',
    },
    {
      'name': 'Compound',
      'url': 'https://app.compound.finance',
      'icon': 'https://cryptologos.cc/logos/compound-comp-logo.png',
      'desc': 'Earn Interest',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadIcon();
    if (widget.initialUrl != 'https://app.uniswap.org') {
      _showDiscovery = false;
      _urlController.text = widget.initialUrl;
    }
    _dAppService = DAppBrowserService(
      context, 
      getChainId: () => _selectedNetwork.chainId,
      onChainSwitch: (chainId) {
        final network = _networks.firstWhere(
          (n) => n.chainId.toLowerCase() == chainId.toLowerCase(),
          orElse: () => _selectedNetwork,
        );
        setState(() {
          _selectedNetwork = network;
        });
        
        _webViewController?.evaluateJavascript(
          source: "if(window.ethereum) { window.ethereum.chainId = '$chainId'; }"
        );
        _webViewController?.reload();
      },
    );
  }

  Future<void> _loadIcon() async {
    try {
      final data = await rootBundle.loadString('assets/cowrie_images/cowriesvg.svg');
      final base64String = base64Encode(utf8.encode(data));
      if (mounted) {
        setState(() {
          _iconBase64 = 'data:image/svg+xml;base64,$base64String';
        });
      }
    } catch (e) {
      debugPrint('Error loading SVG icon: $e');
      try {
        final bytes = await rootBundle.load('assets/coins_logo/ic_launcher.png');
        final list = bytes.buffer.asUint8List();
        final base64String = base64Encode(list);
        if (mounted) {
          setState(() {
            _iconBase64 = 'data:image/png;base64,$base64String';
          });
        }
      } catch (e2) {
        debugPrint('Error loading fallback PNG icon: $e2');
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadUrl(String url) async {
    String formattedUrl = url;
    if (!url.startsWith('http')) {
      formattedUrl = 'https://$url';
    }

    setState(() {
      _showDiscovery = false;
      _targetUrl = formattedUrl;
      _urlController.text = formattedUrl;
    });
    
    if (_webViewController != null) {
      await _webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(formattedUrl)),
      );
    }
  }

  String _getInjectedJs() {
    final provider = context.read<WalletProvider>();
    final address = provider.wallet?.address ?? '';
    
    return DAppProviderJs.providerJs
        .replaceAll('%ADDRESS%', address)
        .replaceAll('%CHAIN_ID%', _selectedNetwork.chainId)
        .replaceAll('%RPC_URL%', '')
        .replaceAll('%ICON%', _iconBase64 ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leadingWidth: 48,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'Search or enter DApp URL',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
              ),
              style: theme.textTheme.bodyMedium,
              onSubmitted: _loadUrl,
            ),
          ),
        ),
        actions: [
          _buildNetworkSelector(context),
          if (!_showDiscovery)
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () => _webViewController?.reload(),
            ),
          const SizedBox(width: 4),
        ],
        bottom: !_showDiscovery && _progress < 1.0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  minHeight: 2,
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (!_showDiscovery && _iconBase64 != null)
                  InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri(_targetUrl ?? widget.initialUrl),
                    ),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      useShouldOverrideUrlLoading: true,
                      mediaPlaybackRequiresUserGesture: false,
                      allowsInlineMediaPlayback: true,
                      useHybridComposition: true,
                      allowsBackForwardNavigationGestures: true,
                    ),
                    initialUserScripts: UnmodifiableListView<UserScript>([
                      UserScript(
                        source: _getInjectedJs(),
                        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                      ),
                    ]),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                      
                      controller.addJavaScriptHandler(
                        handlerName: 'ethereum_request',
                        callback: (args) async {
                          if (args.isEmpty) return null;
                          final request = Map<String, dynamic>.from(args[0]);
                          return await _dAppService.handleRequest(request);
                        },
                      );
                    },
                    onLoadStart: (controller, url) {
                      setState(() {
                        if (url != null) _urlController.text = url.toString();
                      });
                    },
                    onLoadStop: (controller, url) {
                      setState(() {
                        if (url != null) _urlController.text = url.toString();
                      });
                    },
                    onProgressChanged: (controller, progress) {
                      setState(() {
                        _progress = progress / 100;
                      });
                    },
                    shouldOverrideUrlLoading: (controller, navigationAction) async {
                      final uri = navigationAction.request.url;
                      if (uri != null &&
                          !['http', 'https', 'file', 'chrome', 'data', 'javascript', 'about']
                              .contains(uri.scheme)) {
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                          return NavigationActionPolicy.CANCEL;
                        }
                      }
                      return NavigationActionPolicy.ALLOW;
                    },
                  ),
                if (!_showDiscovery && _iconBase64 == null)
                  const Center(child: CircularProgressIndicator()),
                
                if (_showDiscovery) _buildDiscoveryHome(),
              ],
            ),
          ),
          _buildNavigationToolbar(),
        ],
      ),
    );
  }

  Widget _buildNetworkSelector(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _showNetworkSelection(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChainAssets.getIcon(_selectedNetwork.name, size: 16),
            const SizedBox(width: 6),
            Text(
              _selectedNetwork.symbol,
              style: TextStyle(
                fontSize: 11, 
                fontWeight: FontWeight.w900, 
                color: colors.onSurface,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNetworkSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Switch Network',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: _networks.map((network) => ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedNetwork.chainId == network.chainId
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                          : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: ChainAssets.getIcon(network.name),
                  ),
                  title: Text(
                    network.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Chain ID: ${network.chainId}',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  trailing: _selectedNetwork.chainId == network.chainId
                      ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    final targetChainId = network.chainId;
                    setState(() {
                      _selectedNetwork = network;
                    });
                    Navigator.pop(context);
                    
                    if (!_showDiscovery) {
                      _webViewController?.evaluateJavascript(
                        source: "if(window.ethereum) { window.ethereum.chainId = '$targetChainId'; }"
                      );
                      _webViewController?.reload();
                    }
                  },
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveryHome() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DApp Discovery',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Explore the decentralized web securely.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final dapp = _popularDApps[index];
                  return Material(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _loadUrl(dapp['url']!),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Image.network(dapp['icon']!, errorBuilder: (context, error, stackTrace) => const Icon(Icons.public)),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            dapp['name']!,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            dapp['desc']!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 9,
                              color: colors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: _popularDApps.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationToolbar() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom > 0 
            ? MediaQuery.of(context).padding.bottom 
            : 8,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant, width: 0.5)),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new, 
                size: 20, 
                color: _showDiscovery ? colors.outline : colors.onSurface
              ),
              onPressed: () async {
                if (_showDiscovery) return;
                if (await _webViewController?.canGoBack() ?? false) {
                  await _webViewController?.goBack();
                } else {
                  setState(() {
                    _showDiscovery = true;
                    _urlController.clear();
                  });
                }
              },
            ),
            IconButton(
              icon: Icon(
                Icons.arrow_forward_ios, 
                size: 20, 
                color: _showDiscovery ? colors.outline : colors.onSurface
              ),
              onPressed: () async {
                if (_showDiscovery) return;
                if (await _webViewController?.canGoForward() ?? false) {
                  await _webViewController?.goForward();
                }
              },
            ),
            IconButton(
              icon: Icon(
                Icons.home_rounded, 
                color: _showDiscovery ? colors.primary : colors.onSurface
              ),
              onPressed: () {
                setState(() {
                  _showDiscovery = true;
                  _urlController.clear();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () {
                final url = _urlController.text;
                if (url.isNotEmpty && url.startsWith('http')) {
                  SharePlus.instance.share(ShareParams(text: url));
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () {
                _showBrowserMenu(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBrowserMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Reload'),
              onTap: () {
                Navigator.pop(context);
                _webViewController?.reload();
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('Open in External Browser'),
              onTap: () async {
                Navigator.pop(context);
                final url = await _webViewController?.getUrl();
                if (url != null) {
                  launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy URL'),
              onTap: () async {
                Navigator.pop(context);
                final url = await _webViewController?.getUrl();
                if (url != null) {
                  await Clipboard.setData(ClipboardData(text: url.toString()));
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: Text('Clear History & Cache', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Browser Data?'),
                    content: const Text('This will clear your browsing history, cache, and session data.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true), 
                        child: Text('Clear', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                    ],
                  ),
                );
                
                if (confirmed == true) {
                  await InAppWebViewController.clearAllCache();
                  await _webViewController?.clearHistory();
                  final cookieManager = CookieManager.instance();
                  await cookieManager.deleteAllCookies();
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Browser data cleared')),
                    );
                    setState(() {
                      _showDiscovery = true;
                      _urlController.clear();
                    });
                  }
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
