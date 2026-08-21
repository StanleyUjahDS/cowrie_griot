import 'package:flutter_test/flutter_test.dart';
import 'package:griot_cowrie/features/wallet/services/wallet_crypto_service.dart';

void main() {
  late WalletCryptoService cryptoService;

  setUp(() {
    cryptoService = WalletCryptoService();
  });

  group('WalletCryptoService EIP-1559', () {
    const privateKey =
        '0xabc123abc123abc123abc123abc123abc123abc123abc123abc123abc123abc1';
    const to = '0x1234567890123456789012345678901234567890';

    test('should sign EIP-1559 transaction without error', () async {
      final signature = await cryptoService.signNativeTransaction(
        privateKey: privateKey,
        to: to,
        valueRaw: '10000000000000000', // 0.01 ETH
        nonce: 1,
        gasLimit: '21000',
        maxFeePerGas: '30000000000',
        maxPriorityFeePerGas: '1500000000',
        chainId: 1,
      );

      expect(signature, isNotNull);
      expect(signature.startsWith('0x'), isTrue);
    });

    test('should sign legacy transaction without error', () async {
      final signature = await cryptoService.signNativeTransaction(
        privateKey: privateKey,
        to: to,
        valueRaw: '10000000000000000',
        nonce: 1,
        gasLimit: '21000',
        gasPrice: '20000000000',
        chainId: 1,
      );

      expect(signature, isNotNull);
      expect(signature.startsWith('0x'), isTrue);
    });
  });
}
