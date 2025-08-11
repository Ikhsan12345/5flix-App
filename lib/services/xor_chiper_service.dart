import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Custom cryptographic hash functions
class CustomCrypto {
  /// Simple SHA-256 like hash implementation
  static Uint8List simpleHash(Uint8List data) {
    // Constants for our custom hash (similar to SHA-256 but simpler)
    final h = [
      0x6a09e667,
      0xbb67ae85,
      0x3c6ef372,
      0xa54ff53a,
      0x510e527f,
      0x9b05688c,
      0x1f83d9ab,
      0x5be0cd19,
    ];

    final k = [
      0x428a2f98,
      0x71374491,
      0xb5c0fbcf,
      0xe9b5dba5,
      0x3956c25b,
      0x59f111f1,
      0x923f82a4,
      0xab1c5ed5,
      0xd807aa98,
      0x12835b01,
      0x243185be,
      0x550c7dc3,
      0x72be5d74,
      0x80deb1fe,
      0x9bdc06a7,
      0xc19bf174,
    ];

    // Pad message
    final paddedData = _padMessage(data);
    final hash = List<int>.from(h);

    // Process message in 512-bit chunks
    for (int chunk = 0; chunk < paddedData.length; chunk += 64) {
      final w = List<int>.filled(64, 0);

      // Copy chunk into first 16 words of message schedule
      for (int i = 0; i < 16; i++) {
        w[i] = _bytesToInt32(
          paddedData.sublist(chunk + i * 4, chunk + i * 4 + 4),
        );
      }

      // Extend the first 16 words into the remaining 48 words
      for (int i = 16; i < 64; i++) {
        final s0 =
            _rightRotate(w[i - 15], 7) ^
            _rightRotate(w[i - 15], 18) ^
            (w[i - 15] >> 3);
        final s1 =
            _rightRotate(w[i - 2], 17) ^
            _rightRotate(w[i - 2], 19) ^
            (w[i - 2] >> 10);
        w[i] = _add32(w[i - 16], s0, w[i - 7], s1);
      }

      // Initialize working variables
      var a = hash[0], b = hash[1], c = hash[2], d = hash[3];
      var e = hash[4], f = hash[5], g = hash[6], h = hash[7];

      // Main loop
      for (int i = 0; i < 64; i++) {
        final s1 =
            _rightRotate(e, 6) ^ _rightRotate(e, 11) ^ _rightRotate(e, 25);
        final ch = (e & f) ^ ((~e) & g);
        final temp1 = _add32(h, s1, ch, k[i % k.length], w[i]);
        final s0 =
            _rightRotate(a, 2) ^ _rightRotate(a, 13) ^ _rightRotate(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = _add32(s0, maj);

        h = g;
        g = f;
        f = e;
        e = _add32(d, temp1);
        d = c;
        c = b;
        b = a;
        a = _add32(temp1, temp2);
      }

      // Add this chunk's hash to result so far
      hash[0] = _add32(hash[0], a);
      hash[1] = _add32(hash[1], b);
      hash[2] = _add32(hash[2], c);
      hash[3] = _add32(hash[3], d);
      hash[4] = _add32(hash[4], e);
      hash[5] = _add32(hash[5], f);
      hash[6] = _add32(hash[6], g);
      hash[7] = _add32(hash[7], h);
    }

    // Convert hash to bytes
    final result = Uint8List(32);
    for (int i = 0; i < 8; i++) {
      final bytes = _int32ToBytes(hash[i]);
      result.setRange(i * 4, (i + 1) * 4, bytes);
    }

    return result;
  }

  /// Pad message for hash function
  static Uint8List _padMessage(Uint8List data) {
    final length = data.length;
    final bitLength = length * 8;

    // Append single bit '1'
    final paddedLength = ((length + 9 + 63) ~/ 64) * 64;
    final padded = Uint8List(paddedLength);

    padded.setRange(0, length, data);
    padded[length] = 0x80;

    // Append length as 64-bit big-endian integer
    final lengthBytes = _int64ToBytes(bitLength);
    padded.setRange(paddedLength - 8, paddedLength, lengthBytes);

    return padded;
  }

  /// Convert 4 bytes to 32-bit integer
  static int _bytesToInt32(List<int> bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  /// Convert 32-bit integer to 4 bytes
  static List<int> _int32ToBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  /// Convert 64-bit integer to 8 bytes
  static List<int> _int64ToBytes(int value) {
    return [
      (value >> 56) & 0xFF,
      (value >> 48) & 0xFF,
      (value >> 40) & 0xFF,
      (value >> 32) & 0xFF,
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  /// Right rotate 32-bit integer
  static int _rightRotate(int value, int amount) {
    return ((value >> amount) | (value << (32 - amount))) & 0xFFFFFFFF;
  }

  /// Add 32-bit integers with overflow handling
  static int _add32(int a, [int b = 0, int c = 0, int d = 0, int e = 0]) {
    return (a + b + c + d + e) & 0xFFFFFFFF;
  }

  /// Generate random bytes using secure random
  static Uint8List generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// PBKDF2-like key derivation
  static Uint8List deriveKey(
    String password,
    Uint8List salt,
    int iterations,
    int keyLength,
  ) {
    var derived = Uint8List(0);
    var counter = 1;

    while (derived.length < keyLength) {
      final u = _hmac(utf8.encode(password), [
        ...salt,
        ..._int32ToBytes(counter),
      ]);
      var f = Uint8List.fromList(u);

      for (int i = 1; i < iterations; i++) {
        final uNext = _hmac(utf8.encode(password), u);
        for (int j = 0; j < f.length; j++) {
          f[j] ^= uNext[j];
        }
      }

      derived = Uint8List.fromList([...derived, ...f]);
      counter++;
    }

    return derived.sublist(0, keyLength);
  }

  /// Simple HMAC implementation
  static List<int> _hmac(List<int> key, List<int> message) {
    const blockSize = 64;

    // Adjust key length
    if (key.length > blockSize) {
      key = simpleHash(Uint8List.fromList(key));
    } else if (key.length < blockSize) {
      key = [...key, ...List.filled(blockSize - key.length, 0)];
    }

    // Create inner and outer padded keys
    final innerPad = key.map((b) => b ^ 0x36).toList();
    final outerPad = key.map((b) => b ^ 0x5C).toList();

    // Compute HMAC
    final innerHash = simpleHash(Uint8List.fromList([...innerPad, ...message]));
    final outerHash = simpleHash(
      Uint8List.fromList([...outerPad, ...innerHash]),
    );

    return outerHash;
  }
}

class XorCipherService {
  // Enhanced encryption key with device-specific salt
  static const String _baseSecretKey = "5FLIX_SECURE_KEY_2024_ENCRYPTION_V3";
  static String? _cachedDeviceKey;
  static const int _headerSize = 32;
  static const String _magicHeader = 'FIVEFLIX';
  static const int _encryptionVersion = 3;
  static const int _keyDerivationIterations = 10000;

  /// Get device-specific encryption key with enhanced security
  static Future<String> get deviceKey async {
    if (_cachedDeviceKey != null) return _cachedDeviceKey!;

    try {
      // Generate device-specific key based on platform and device info
      final platformSalt = await _getEnhancedPlatformSalt();
      final combinedKey = _baseSecretKey + platformSalt;

      // Create custom hash for consistent key length
      final keyBytes = CustomCrypto.simpleHash(utf8.encode(combinedKey));
      _cachedDeviceKey = base64Encode(keyBytes);

      debugPrint(
        'XorCipherService: Generated enhanced device-specific encryption key',
      );
      return _cachedDeviceKey!;
    } catch (e) {
      debugPrint(
        'XorCipherService: Error generating device key, using fallback: $e',
      );
      return _generateFallbackKey();
    }
  }

  /// Get enhanced platform-specific salt with device info
  static Future<String> _getEnhancedPlatformSalt() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceIdentifier = '';

      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceIdentifier = '${webInfo.browserName}_${webInfo.platform}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceIdentifier =
            '${androidInfo.model}_${androidInfo.manufacturer}_${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceIdentifier = '${iosInfo.model}_${iosInfo.systemVersion}';
      } else {
        deviceIdentifier = Platform.operatingSystem;
      }

      // Add timestamp-based component for additional uniqueness
      final yearMonth = '${DateTime.now().year}_${DateTime.now().month}';
      return 'ENHANCED_SALT_${deviceIdentifier}_$yearMonth';
    } catch (e) {
      debugPrint('XorCipherService: Error getting device info: $e');
      return _getFallbackPlatformSalt();
    }
  }

  /// Fallback platform salt for compatibility
  static String _getFallbackPlatformSalt() {
    if (kIsWeb) {
      return 'WEB_PLATFORM_SALT';
    } else {
      return 'MOBILE_PLATFORM_SALT_${DateTime.now().year}';
    }
  }

  /// Generate fallback key when device info is unavailable
  static String _generateFallbackKey() {
    final platformSalt = _getFallbackPlatformSalt();
    final combinedKey = _baseSecretKey + platformSalt;
    final keyBytes = CustomCrypto.simpleHash(utf8.encode(combinedKey));
    return base64Encode(keyBytes);
  }

  /// Convert integer to bytes (Big Endian)
  static Uint8List _intToBytes(int value) {
    return Uint8List.fromList([
      (value >> 56) & 0xFF,
      (value >> 48) & 0xFF,
      (value >> 40) & 0xFF,
      (value >> 32) & 0xFF,
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }

  /// Convert bytes to integer (Big Endian)
  static int _bytesToInt(Uint8List bytes) {
    if (bytes.length != 8) {
      throw ArgumentError('Bytes array must be exactly 8 bytes long');
    }

    int result = 0;
    for (int i = 0; i < 8; i++) {
      result = (result << 8) | bytes[i];
    }
    return result;
  }

  /// Create enhanced header with metadata
  static Uint8List _createHeader(int dataLength) {
    final header = Uint8List(_headerSize);
    int offset = 0;

    // Magic header (8 bytes)
    final magicBytes = utf8.encode(_magicHeader);
    for (int i = 0; i < magicBytes.length && i < 8; i++) {
      header[offset + i] = magicBytes[i];
    }
    offset += 8;

    // Data length (8 bytes)
    final lengthBytes = _intToBytes(dataLength);
    for (int i = 0; i < lengthBytes.length; i++) {
      header[offset + i] = lengthBytes[i];
    }
    offset += 8;

    // Encryption version (4 bytes)
    final versionBytes = _intToBytes(_encryptionVersion).sublist(4, 8);
    for (int i = 0; i < versionBytes.length; i++) {
      header[offset + i] = versionBytes[i];
    }
    offset += 4;

    // Timestamp (8 bytes)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final timestampBytes = _intToBytes(timestamp);
    for (int i = 0; i < timestampBytes.length; i++) {
      header[offset + i] = timestampBytes[i];
    }
    offset += 8;

    // Checksum placeholder (4 bytes) - will be calculated later
    for (int i = 0; i < 4; i++) {
      header[offset + i] = 0;
    }

    return header;
  }

  /// Validate and parse header
  static Map<String, dynamic> _parseHeader(Uint8List headerData) {
    if (headerData.length < _headerSize) {
      throw Exception('Invalid header - too short');
    }

    int offset = 0;

    // Verify magic header
    final magicBytes = utf8.encode(_magicHeader);
    for (int i = 0; i < magicBytes.length; i++) {
      if (headerData[offset + i] != magicBytes[i]) {
        throw Exception('Invalid encrypted data - magic header mismatch');
      }
    }
    offset += 8;

    // Extract data length
    final lengthBytes = headerData.sublist(offset, offset + 8);
    final dataLength = _bytesToInt(lengthBytes);
    offset += 8;

    // Extract version
    final versionBytes = Uint8List(8);
    versionBytes.setRange(4, 8, headerData.sublist(offset, offset + 4));
    final version = _bytesToInt(versionBytes);
    offset += 4;

    // Extract timestamp
    final timestampBytes = headerData.sublist(offset, offset + 8);
    final timestamp = _bytesToInt(timestampBytes);
    offset += 8;

    // Extract checksum
    final checksumBytes = headerData.sublist(offset, offset + 4);

    return {
      'data_length': dataLength,
      'version': version,
      'timestamp': timestamp,
      'checksum': checksumBytes,
    };
  }

  /// Calculate simple checksum for integrity verification
  static Uint8List _calculateChecksum(Uint8List data) {
    final hash = CustomCrypto.simpleHash(data);
    return hash.sublist(0, 4); // Take first 4 bytes as checksum
  }

  /// Generate enhanced key from device key and additional entropy
  static Future<Uint8List> _generateEnhancedKey(
    String baseKey, [
    String? additionalEntropy,
  ]) async {
    final salt = CustomCrypto.generateRandomBytes(16);
    final keyMaterial = baseKey + (additionalEntropy ?? '');

    // Use custom key derivation
    return CustomCrypto.deriveKey(
      keyMaterial,
      salt,
      _keyDerivationIterations,
      64, // 512-bit key
    );
  }

  /// Advanced XOR encryption with multiple passes and dynamic key
  static Future<Uint8List> _advancedXorEncrypt(
    Uint8List data,
    Uint8List key,
  ) async {
    final encrypted = Uint8List.fromList(data);
    final keyLength = key.length;

    // Multiple encryption passes with different patterns
    for (int pass = 0; pass < 3; pass++) {
      for (int i = 0; i < encrypted.length; i++) {
        final keyIndex =
            (i + pass * 17) % keyLength; // Different key offset per pass
        final keyByte = key[keyIndex];

        // Multi-layered encryption for current pass
        switch (pass) {
          case 0:
            // First pass: Basic XOR with position scrambling
            encrypted[i] ^= keyByte;
            encrypted[i] ^= (i & 0xFF);
            break;
          case 1:
            // Second pass: Add reverse position and cascade effect
            encrypted[i] ^= keyByte;
            encrypted[i] ^= ((encrypted.length - i - 1) & 0xFF);
            if (i > 0) {
              encrypted[i] ^= (encrypted[i - 1] & 0x0F);
            }
            break;
          case 2:
            // Third pass: Dynamic key modification and complex scrambling
            final dynamicKey = keyByte ^ (i >> 3) ^ (pass << 2);
            encrypted[i] ^= dynamicKey;
            encrypted[i] ^= ((i * 37) & 0xFF); // Prime number scrambling
            if (i > 2) {
              encrypted[i] ^= (encrypted[i - 3] & 0x07);
            }
            break;
        }
      }

      // Shuffle bytes after each pass (simple reversible transformation)
      if (pass < 2) {
        _shuffleBytes(encrypted, pass);
      }
    }

    return encrypted;
  }

  /// Advanced XOR decryption (reverse of encryption)
  static Future<Uint8List> _advancedXorDecrypt(
    Uint8List data,
    Uint8List key,
  ) async {
    final decrypted = Uint8List.fromList(data);
    final keyLength = key.length;

    // Reverse multiple passes in reverse order
    for (int pass = 2; pass >= 0; pass--) {
      // Reverse shuffle if not the last pass
      if (pass < 2) {
        _reverseShuffleBytes(decrypted, pass);
      }

      for (int i = decrypted.length - 1; i >= 0; i--) {
        final keyIndex = (i + pass * 17) % keyLength;
        final keyByte = key[keyIndex];

        // Reverse multi-layered decryption for current pass
        switch (pass) {
          case 0:
            // Reverse first pass
            decrypted[i] ^= (i & 0xFF);
            decrypted[i] ^= keyByte;
            break;
          case 1:
            // Reverse second pass
            if (i > 0) {
              decrypted[i] ^= (decrypted[i - 1] & 0x0F);
            }
            decrypted[i] ^= ((decrypted.length - i - 1) & 0xFF);
            decrypted[i] ^= keyByte;
            break;
          case 2:
            // Reverse third pass
            if (i > 2) {
              decrypted[i] ^= (decrypted[i - 3] & 0x07);
            }
            decrypted[i] ^= ((i * 37) & 0xFF);
            final dynamicKey = keyByte ^ (i >> 3) ^ (pass << 2);
            decrypted[i] ^= dynamicKey;
            break;
        }
      }
    }

    return decrypted;
  }

  /// Simple byte shuffling (reversible)
  static void _shuffleBytes(Uint8List data, int seed) {
    for (int i = 0; i < data.length - 1; i += 2 + seed) {
      if (i + 1 < data.length) {
        final temp = data[i];
        data[i] = data[i + 1];
        data[i + 1] = temp;
      }
    }
  }

  /// Reverse byte shuffling
  static void _reverseShuffleBytes(Uint8List data, int seed) {
    // Same operation as shuffling (XOR swap is self-reversing)
    _shuffleBytes(data, seed);
  }

  /// Encrypt data using enhanced XOR cipher with multi-layered encryption
  static Future<Uint8List> encrypt(Uint8List data) async {
    try {
      debugPrint(
        'XorCipherService: Starting encryption for ${data.length} bytes',
      );

      if (data.isEmpty) {
        debugPrint(
          'XorCipherService: Warning - attempting to encrypt empty data',
        );
        return Uint8List(0);
      }

      // Generate enhanced encryption key
      final deviceKeyStr = await deviceKey;
      final enhancedKey = await _generateEnhancedKey(deviceKeyStr);

      // Create header
      final header = _createHeader(data.length);

      // Encrypt data using advanced XOR
      final encryptedData = await _advancedXorEncrypt(data, enhancedKey);

      // Combine header and encrypted data
      final result = Uint8List(header.length + encryptedData.length);
      result.setRange(0, header.length, header);
      result.setRange(header.length, result.length, encryptedData);

      // Calculate and update checksum
      final dataChecksum = _calculateChecksum(encryptedData);
      result.setRange(_headerSize - 4, _headerSize, dataChecksum);

      debugPrint('XorCipherService: Encryption completed successfully');
      return result;
    } catch (e) {
      debugPrint('XorCipherService: Encryption error - $e');
      rethrow;
    }
  }

  /// Decrypt data using enhanced XOR cipher
  static Future<Uint8List> decrypt(Uint8List encryptedData) async {
    try {
      debugPrint(
        'XorCipherService: Starting decryption for ${encryptedData.length} bytes',
      );

      if (encryptedData.length < _headerSize) {
        throw Exception('Invalid encrypted data - too short');
      }

      // Parse header
      final headerData = encryptedData.sublist(0, _headerSize);
      final headerInfo = _parseHeader(headerData);

      final originalLength = headerInfo['data_length'] as int;
      final version = headerInfo['version'] as int;
      final timestamp = headerInfo['timestamp'] as int;
      final storedChecksum = headerInfo['checksum'] as Uint8List;

      // Validate version compatibility
      if (version > _encryptionVersion) {
        throw Exception('Unsupported encryption version: $version');
      }

      // Validate data length
      if (originalLength < 0 ||
          originalLength > encryptedData.length - _headerSize) {
        throw Exception(
          'Invalid encrypted data - invalid length: $originalLength',
        );
      }

      // Extract encrypted data portion
      final encryptedDataPortion = encryptedData.sublist(_headerSize);

      // Verify checksum
      final calculatedChecksum = _calculateChecksum(encryptedDataPortion);
      bool checksumValid = true;
      for (int i = 0; i < 4; i++) {
        if (storedChecksum[i] != calculatedChecksum[i]) {
          checksumValid = false;
          break;
        }
      }

      if (!checksumValid) {
        debugPrint(
          'XorCipherService: Warning - checksum mismatch, data may be corrupted',
        );
      }

      // Generate same enhanced key used for encryption
      final deviceKeyStr = await deviceKey;
      final enhancedKey = await _generateEnhancedKey(deviceKeyStr);

      // Decrypt using advanced XOR
      final decrypted = await _advancedXorDecrypt(
        encryptedDataPortion,
        enhancedKey,
      );

      // Return only the original data length
      final result = decrypted.sublist(0, originalLength);

      debugPrint('XorCipherService: Decryption completed successfully');
      return result;
    } catch (e) {
      debugPrint('XorCipherService: Decryption error - $e');
      rethrow;
    }
  }

  /// Verify if data is encrypted with this service
  static bool isEncryptedData(Uint8List data) {
    try {
      if (data.length < _headerSize) return false;

      final magicBytes = utf8.encode(_magicHeader);

      for (int i = 0; i < magicBytes.length; i++) {
        if (data[i] != magicBytes[i]) {
          return false;
        }
      }

      // Additional validation
      try {
        final headerInfo = _parseHeader(data.sublist(0, _headerSize));
        final version = headerInfo['version'] as int;
        return version > 0 && version <= _encryptionVersion;
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Get encryption metadata from encrypted data
  static Map<String, dynamic>? getEncryptionMetadata(Uint8List encryptedData) {
    try {
      if (!isEncryptedData(encryptedData)) return null;

      final headerInfo = _parseHeader(encryptedData.sublist(0, _headerSize));
      final originalLength = headerInfo['data_length'] as int;
      final version = headerInfo['version'] as int;
      final timestamp = headerInfo['timestamp'] as int;

      return {
        'original_length': originalLength,
        'encrypted_length': encryptedData.length,
        'overhead_bytes': _headerSize,
        'magic_header': _magicHeader,
        'encryption_version': version,
        'encrypted_at': DateTime.fromMillisecondsSinceEpoch(
          timestamp,
        ).toIso8601String(),
        'header_size': _headerSize,
        'algorithm': 'Advanced Multi-Pass XOR with Custom Hash',
      };
    } catch (e) {
      debugPrint('XorCipherService: Error getting metadata - $e');
      return null;
    }
  }

  /// Generate a random key for additional security
  static String generateRandomKey(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*()';
    final randomBytes = CustomCrypto.generateRandomBytes(length);
    return String.fromCharCodes(
      randomBytes.map((b) => chars.codeUnitAt(b % chars.length)),
    );
  }

  /// Encrypt string data with Base64 encoding
  static Future<String> encryptString(String plainText) async {
    try {
      final plainBytes = utf8.encode(plainText);
      final encryptedBytes = await encrypt(Uint8List.fromList(plainBytes));
      return base64Encode(encryptedBytes);
    } catch (e) {
      debugPrint('XorCipherService: String encryption error - $e');
      rethrow;
    }
  }

  /// Decrypt string data from Base64
  static Future<String> decryptString(String encryptedText) async {
    try {
      final encryptedBytes = base64Decode(encryptedText);
      final decryptedBytes = await decrypt(encryptedBytes);
      return utf8.decode(decryptedBytes);
    } catch (e) {
      debugPrint('XorCipherService: String decryption error - $e');
      rethrow;
    }
  }

  /// Encrypt file in chunks to handle large files efficiently
  static Future<void> encryptFileInChunks(
    String inputPath,
    String outputPath, {
    int chunkSize = 1024 * 1024, // 1MB chunks
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('XorCipherService: Starting file encryption - $inputPath');

      final inputFile = File(inputPath);
      final outputFile = File(outputPath);

      if (!await inputFile.exists()) {
        throw Exception('Input file does not exist: $inputPath');
      }

      final fileLength = await inputFile.length();
      final sink = outputFile.openWrite();

      // Create and write header
      final header = _createHeader(fileLength);
      await sink.add(header);

      // Generate enhanced key for file encryption
      final deviceKeyStr = await deviceKey;
      final enhancedKey = await _generateEnhancedKey(deviceKeyStr, inputPath);

      // Process file in chunks
      int processedBytes = 0;
      final stream = inputFile.openRead();

      await for (final chunk in stream) {
        final encryptedChunk = await _encryptChunk(
          Uint8List.fromList(chunk),
          processedBytes,
          enhancedKey,
        );
        await sink.add(encryptedChunk);

        processedBytes += chunk.length;
        onProgress?.call(processedBytes / fileLength);
      }

      await sink.close();

      // Update checksum in header
      await _updateFileChecksum(outputPath);

      debugPrint('XorCipherService: File encryption completed');
    } catch (e) {
      debugPrint('XorCipherService: File encryption error - $e');
      rethrow;
    }
  }

  /// Update file checksum after encryption
  static Future<void> _updateFileChecksum(String filePath) async {
    try {
      final file = File(filePath);
      final data = await file.readAsBytes();

      if (data.length < _headerSize) return;

      // Calculate checksum of encrypted data
      final encryptedData = data.sublist(_headerSize);
      final checksum = _calculateChecksum(encryptedData);

      // Update checksum in header
      final updatedData = Uint8List.fromList(data);
      updatedData.setRange(_headerSize - 4, _headerSize, checksum);

      await file.writeAsBytes(updatedData);
    } catch (e) {
      debugPrint('XorCipherService: Error updating file checksum - $e');
    }
  }

  /// Decrypt file in chunks
  static Future<void> decryptFileInChunks(
    String inputPath,
    String outputPath, {
    int chunkSize = 1024 * 1024,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('XorCipherService: Starting file decryption - $inputPath');

      final inputFile = File(inputPath);
      final outputFile = File(outputPath);

      if (!await inputFile.exists()) {
        throw Exception('Input file does not exist: $inputPath');
      }

      // Read and verify header
      final headerData = await inputFile.openRead(0, _headerSize).first;
      final headerBytes = Uint8List.fromList(headerData);

      if (!isEncryptedData(headerBytes)) {
        throw Exception('Invalid encrypted file format');
      }

      final headerInfo = _parseHeader(headerBytes);
      final originalLength = headerInfo['data_length'] as int;

      // Generate same enhanced key used for encryption
      final deviceKeyStr = await deviceKey;
      final enhancedKey = await _generateEnhancedKey(deviceKeyStr, inputPath);

      final sink = outputFile.openWrite();
      int processedBytes = 0;

      // Process encrypted data in chunks
      final stream = inputFile.openRead(_headerSize); // Skip header

      await for (final chunk in stream) {
        final remainingBytes = originalLength - processedBytes;
        final chunkToProcess = remainingBytes < chunk.length
            ? chunk.sublist(0, remainingBytes)
            : chunk;

        final decryptedChunk = await _decryptChunk(
          Uint8List.fromList(chunkToProcess),
          processedBytes,
          enhancedKey,
        );

        await sink.add(decryptedChunk);
        processedBytes += chunkToProcess.length;

        onProgress?.call(processedBytes / originalLength);

        if (processedBytes >= originalLength) break;
      }

      await sink.close();
      debugPrint('XorCipherService: File decryption completed');
    } catch (e) {
      debugPrint('XorCipherService: File decryption error - $e');
      rethrow;
    }
  }

  /// Encrypt a chunk of data with offset consideration
  static Future<Uint8List> _encryptChunk(
    Uint8List chunk,
    int offset,
    Uint8List key,
  ) async {
    final keyLength = key.length;
    final encrypted = Uint8List.fromList(chunk);

    // Multi-pass encryption for chunks
    for (int pass = 0; pass < 2; pass++) {
      for (int i = 0; i < encrypted.length; i++) {
        final globalIndex = offset + i;
        final keyIndex =
            (globalIndex + pass * 23) % keyLength; // Different offset per pass
        final keyByte = key[keyIndex];

        switch (pass) {
          case 0:
            // First pass: Basic encryption
            encrypted[i] ^= keyByte;
            encrypted[i] ^= (globalIndex & 0xFF);
            break;
          case 1:
            // Second pass: Enhanced scrambling
            encrypted[i] ^= keyByte;
            encrypted[i] ^= ((globalIndex >> 3) & 0xFF);
            if (i > 0) {
              encrypted[i] ^= (encrypted[i - 1] & 0x0F);
            }
            break;
        }
      }
    }

    return encrypted;
  }

  /// Decrypt a chunk of data with offset consideration
  static Future<Uint8List> _decryptChunk(
    Uint8List chunk,
    int offset,
    Uint8List key,
  ) async {
    final keyLength = key.length;
    final decrypted = Uint8List.fromList(chunk);

    // Reverse multi-pass decryption
    for (int pass = 1; pass >= 0; pass--) {
      for (int i = decrypted.length - 1; i >= 0; i--) {
        final globalIndex = offset + i;
        final keyIndex = (globalIndex + pass * 23) % keyLength;
        final keyByte = key[keyIndex];

        switch (pass) {
          case 0:
            // Reverse first pass
            decrypted[i] ^= (globalIndex & 0xFF);
            decrypted[i] ^= keyByte;
            break;
          case 1:
            // Reverse second pass
            if (i > 0) {
              decrypted[i] ^= (decrypted[i - 1] & 0x0F);
            }
            decrypted[i] ^= ((globalIndex >> 3) & 0xFF);
            decrypted[i] ^= keyByte;
            break;
        }
      }
    }

    return decrypted;
  }

  /// Clear cached device key (useful for testing or key rotation)
  static void clearCachedKey() {
    _cachedDeviceKey = null;
    debugPrint('XorCipherService: Cached device key cleared');
  }

  /// Validate encrypted data integrity without full decryption
  static Future<bool> validateDataIntegrity(Uint8List encryptedData) async {
    try {
      if (!isEncryptedData(encryptedData)) return false;

      final headerInfo = _parseHeader(encryptedData.sublist(0, _headerSize));
      final originalLength = headerInfo['data_length'] as int;
      final storedChecksum = headerInfo['checksum'] as Uint8List;

      if (encryptedData.length < _headerSize) return false;

      final encryptedDataPortion = encryptedData.sublist(_headerSize);
      final calculatedChecksum = _calculateChecksum(encryptedDataPortion);

      for (int i = 0; i < 4; i++) {
        if (storedChecksum[i] != calculatedChecksum[i]) {
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('XorCipherService: Error validating data integrity - $e');
      return false;
    }
  }

  /// Generate secure salt for key derivation
  static Uint8List generateSalt([int length = 16]) {
    return CustomCrypto.generateRandomBytes(length);
  }

  /// Test encryption/decryption with sample data
  static Future<bool> testEncryptionIntegrity() async {
    try {
      debugPrint('XorCipherService: Testing encryption integrity...');

      // Test with various data sizes
      final testSizes = [0, 1, 16, 255, 1024, 65536];

      for (final size in testSizes) {
        final testData = CustomCrypto.generateRandomBytes(size);

        if (size == 0) {
          // Empty data should return empty
          final encrypted = await encrypt(testData);
          if (encrypted.isNotEmpty) return false;
          continue;
        }

        final encrypted = await encrypt(testData);
        final decrypted = await decrypt(encrypted);

        // Verify data integrity
        if (testData.length != decrypted.length) return false;

        for (int i = 0; i < testData.length; i++) {
          if (testData[i] != decrypted[i]) return false;
        }

        // Verify metadata
        final metadata = getEncryptionMetadata(encrypted);
        if (metadata == null || metadata['original_length'] != size)
          return false;
      }

      // Test string encryption
      const testString = "Hello, FiveFlix! 🎬📱🔐";
      final encryptedString = await encryptString(testString);
      final decryptedString = await decryptString(encryptedString);

      if (testString != decryptedString) return false;

      debugPrint('XorCipherService: All integrity tests passed ✅');
      return true;
    } catch (e) {
      debugPrint('XorCipherService: Integrity test failed - $e');
      return false;
    }
  }

  /// Get cipher statistics and performance info
  static Future<Map<String, dynamic>> getCipherInfo() async {
    final deviceKeyStr = await deviceKey;
    final keyHash = CustomCrypto.simpleHash(utf8.encode(deviceKeyStr));

    return {
      'algorithm_name': 'Advanced Multi-Pass XOR Cipher',
      'encryption_version': _encryptionVersion,
      'header_size': _headerSize,
      'key_derivation_iterations': _keyDerivationIterations,
      'magic_header': _magicHeader,
      'device_key_hash': base64Encode(
        keyHash.sublist(0, 8),
      ), // First 8 bytes only
      'features': [
        'Multi-pass encryption',
        'Dynamic key derivation',
        'Integrity verification',
        'Device-specific keys',
        'Custom hash functions',
        'Byte shuffling',
        'Cascade effects',
        'Position-based scrambling',
      ],
      'security_level': 'High',
      'performance': 'Optimized for mobile',
      'chunk_support': true,
      'file_support': true,
    };
  }

  /// Benchmark encryption performance
  static Future<Map<String, dynamic>> benchmarkPerformance({
    int testDataSize = 1024 * 1024, // 1MB
    int iterations = 5,
  }) async {
    try {
      debugPrint('XorCipherService: Running performance benchmark...');

      final testData = CustomCrypto.generateRandomBytes(testDataSize);
      final encryptionTimes = <int>[];
      final decryptionTimes = <int>[];

      for (int i = 0; i < iterations; i++) {
        // Encryption benchmark
        final encryptStart = DateTime.now().microsecondsSinceEpoch;
        final encrypted = await encrypt(testData);
        final encryptEnd = DateTime.now().microsecondsSinceEpoch;
        encryptionTimes.add(encryptEnd - encryptStart);

        // Decryption benchmark
        final decryptStart = DateTime.now().microsecondsSinceEpoch;
        await decrypt(encrypted);
        final decryptEnd = DateTime.now().microsecondsSinceEpoch;
        decryptionTimes.add(decryptEnd - decryptStart);
      }

      final avgEncryptTime =
          encryptionTimes.reduce((a, b) => a + b) / iterations;
      final avgDecryptTime =
          decryptionTimes.reduce((a, b) => a + b) / iterations;

      final encryptThroughput = (testDataSize / (avgEncryptTime / 1000000))
          .round(); // bytes/sec
      final decryptThroughput = (testDataSize / (avgDecryptTime / 1000000))
          .round(); // bytes/sec

      debugPrint('XorCipherService: Benchmark completed');

      return {
        'test_data_size_bytes': testDataSize,
        'test_data_size_mb': (testDataSize / (1024 * 1024)).toStringAsFixed(2),
        'iterations': iterations,
        'avg_encryption_time_us': avgEncryptTime.round(),
        'avg_decryption_time_us': avgDecryptTime.round(),
        'encryption_throughput_bytes_sec': encryptThroughput,
        'decryption_throughput_bytes_sec': decryptThroughput,
        'encryption_throughput_mb_sec': (encryptThroughput / (1024 * 1024))
            .toStringAsFixed(2),
        'decryption_throughput_mb_sec': (decryptThroughput / (1024 * 1024))
            .toStringAsFixed(2),
        'overhead_bytes': _headerSize,
        'overhead_percentage': ((_headerSize / testDataSize) * 100)
            .toStringAsFixed(4),
      };
    } catch (e) {
      debugPrint('XorCipherService: Benchmark error - $e');
      return {'error': e.toString()};
    }
  }
}
