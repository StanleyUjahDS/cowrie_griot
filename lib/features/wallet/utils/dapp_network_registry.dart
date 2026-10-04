class DAppNetwork {
  final String name;
  final String network;
  final String chainId;
  final String symbol;

  const DAppNetwork({
    required this.name,
    required this.network,
    required this.chainId,
    required this.symbol,
  });
}

class DAppNetworkRegistry {
  static const networks = <DAppNetwork>[
    DAppNetwork(
      name: 'Ethereum',
      network: 'ethereum',
      chainId: '0x1',
      symbol: 'ETH',
    ),
    DAppNetwork(
      name: 'BNB Chain',
      network: 'bsc',
      chainId: '0x38',
      symbol: 'BNB',
    ),
    DAppNetwork(
      name: 'Polygon',
      network: 'polygon',
      chainId: '0x89',
      symbol: 'POL',
    ),
    DAppNetwork(
      name: 'Arbitrum',
      network: 'arbitrum',
      chainId: '0xa4b1',
      symbol: 'ETH',
    ),
    DAppNetwork(
      name: 'Optimism',
      network: 'optimism',
      chainId: '0xa',
      symbol: 'ETH',
    ),
    DAppNetwork(
      name: 'Base',
      network: 'base',
      chainId: '0x2105',
      symbol: 'ETH',
    ),
    DAppNetwork(
      name: 'Avalanche',
      network: 'avalanche',
      chainId: '0xa86a',
      symbol: 'AVAX',
    ),
    DAppNetwork(
      name: 'Robinhood Chain',
      network: 'robinhood',
      chainId: '0x1237',
      symbol: 'ETH',
    ),
    DAppNetwork(name: 'Ink', network: 'ink', chainId: '0xdef1', symbol: 'ETH'),
  ];

  static String normalizeChainId(Object? value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    if (raw.isEmpty) throw const FormatException('Chain ID is required');
    final parsed = raw.startsWith('0x')
        ? int.parse(raw.substring(2), radix: 16)
        : int.parse(raw);
    return '0x${parsed.toRadixString(16)}';
  }

  static DAppNetwork? find(Object? chainId) {
    try {
      final normalized = normalizeChainId(chainId);
      for (final network in networks) {
        if (network.chainId == normalized) return network;
      }
    } catch (_) {}
    return null;
  }
}
