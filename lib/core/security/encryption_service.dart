import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 10000,
    bits: 256,
  );

  final _aesGcm = AesGcm.with256bits();

  // ============================================================
  // KEY DERIVATION
  // ============================================================

  Future<SecretKey> deriveKey(String pin, Uint8List salt) async {
    return _pbkdf2.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );
  }

  // ============================================================
  // ENCRYPT
  // ============================================================

  Future<String> encrypt(String plainText, SecretKey secretKey) async {
    final data = utf8.encode(plainText);
    final secretBox = await _aesGcm.encrypt(
      data,
      secretKey: secretKey,
    );

    // Combine nonce and cipher text for storage
    final combined = Uint8List(secretBox.nonce.length + secretBox.cipherText.length + secretBox.mac.bytes.length);
    var offset = 0;
    
    combined.setAll(offset, secretBox.nonce);
    offset += secretBox.nonce.length;
    
    combined.setAll(offset, secretBox.cipherText);
    offset += secretBox.cipherText.length;
    
    combined.setAll(offset, secretBox.mac.bytes);

    return base64.encode(combined);
  }

  // ============================================================
  // DECRYPT
  // ============================================================

  Future<String> decrypt(String encryptedText, SecretKey secretKey) async {
    final combined = base64.decode(encryptedText);
    
    // Nonce is typically 12 bytes for AesGcm in this library
    // Mac is typically 16 bytes
    const nonceLength = 12;
    const macLength = 16;
    
    if (combined.length < nonceLength + macLength) {
      throw Exception('Invalid encrypted data');
    }

    final nonce = combined.sublist(0, nonceLength);
    final cipherText = combined.sublist(nonceLength, combined.length - macLength);
    final macBytes = combined.sublist(combined.length - macLength);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final clearTextBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return utf8.decode(clearTextBytes);
  }
}
