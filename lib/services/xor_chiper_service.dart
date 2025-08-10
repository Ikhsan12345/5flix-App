import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';

class XorCipherService {
  // Static encryption key - In production, this should be more secure
  static const String _secretKey = "5FLIX_SECURE_KEY_2024_ENCRYPTION";
  
  /// Encrypt data using XOR cipher
  static Uint8List encrypt(Uint8List data) {
    final keyBytes = utf8.encode(_secretKey);
    final encrypted = Uint8List(data.length);
    
    for (int i = 0; i < data.length; i++) {
      encrypted[i] = data[i] ^ keyBytes[i % keyBytes.length];
    }
    
    return encrypted;
  }
  
  /// Decrypt data using XOR cipher
  static Uint8List decrypt(Uint8List encryptedData) {
    // XOR encryption is symmetric, so decryption is the same as encryption
    return encrypt(encryptedData);
  }
  
  /// Generate a random key for additional security
  static String generateRandomKey(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
        length, 
        (_) => chars.codeUnitAt(random.nextInt(chars.length))
      )
    );
  }
  
  /// Encrypt string data
  static String encryptString(String plainText) {
    final plainBytes = utf8.encode(plainText);
    final encryptedBytes = encrypt(Uint8List.fromList(plainBytes));
    return base64Encode(encryptedBytes);
  }
  
  /// Decrypt string data
  static String decryptString(String encryptedText) {
    final encryptedBytes = base64Decode(encryptedText);
    final decryptedBytes = decrypt(encryptedBytes);
    return utf8.decode(decryptedBytes);
  }
}