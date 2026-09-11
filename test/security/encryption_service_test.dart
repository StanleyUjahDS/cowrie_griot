import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:griot_cowrie/core/security/encryption_service.dart';

void main() {
  group('EncryptionService', () {
    late EncryptionService encryptionService;
    final salt = Uint8List.fromList(List.generate(16, (i) => i));
    const pin = '123456';
    const plainText = 'Hello World';

    setUp(() {
      encryptionService = EncryptionService();
    });

    test('deriveKey should produce same key for same PIN and salt', () async {
      final key1 = await encryptionService.deriveKey(pin, salt);
      final key2 = await encryptionService.deriveKey(pin, salt);
      
      final bytes1 = await key1.extractBytes();
      final bytes2 = await key2.extractBytes();

      expect(bytes1, bytes2);
    });

    test('encrypt and decrypt should be lossless', () async {
      final key = await encryptionService.deriveKey(pin, salt);
      final encrypted = await encryptionService.encrypt(plainText, key);
      final decrypted = await encryptionService.decrypt(encrypted, key);

      expect(decrypted, plainText);
      expect(encrypted, isNot(plainText));
    });

    test('decrypt should fail with wrong key', () async {
      final key1 = await encryptionService.deriveKey(pin, salt);
      final key2 = await encryptionService.deriveKey('654321', salt);
      
      final encrypted = await encryptionService.encrypt(plainText, key1);
      
      expect(
        () => encryptionService.decrypt(encrypted, key2),
        throwsException,
      );
    });
  });
}
