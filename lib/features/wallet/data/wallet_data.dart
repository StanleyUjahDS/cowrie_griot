import '../models/wallet_models.dart';

final List<WalletToken> mockTokens = [
  WalletToken(
    name: "Ethereum",
    symbol: "ETH",
    balance: 1.25,
    changePercent: 3.2,
    chain: "Ethereum",
    contractAddress:
    "0x0000000000000000000000000000000000000000",
    imageUrl:
    "https://assets.coingecko.com/coins/images/279/small/ethereum.png",
  ),

  WalletToken(
    name: "USD Coin",
    symbol: "USDC",
    balance: 2500,
    changePercent: -0.3,
    chain: "Ethereum",
    contractAddress:
    "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    imageUrl:
    "https://assets.coingecko.com/coins/images/6319/small/usdc.png",
  ),

  WalletToken(
    name: "Solana",
    symbol: "SOL",
    balance: 12,
    changePercent: 5.1,
    chain: "Solana",
    contractAddress:
    "So11111111111111111111111111111111111111112",
    imageUrl:
    "https://assets.coingecko.com/coins/images/4128/small/solana.png",
  ),
];