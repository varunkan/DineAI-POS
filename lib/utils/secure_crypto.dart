import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

/// Secure cryptography utility for password hashing and data encryption
/// Uses industry-standard algorithms to protect sensitive data
class SecureCrypto {
  // PBKDF2 parameters for password hashing
  static const int _saltLength = 32;
  static const int _iterations = 100000; // High iteration count for security
  static const int _keyLength = 64;

  // AES encryption parameters
  static const int _aesKeyLength = 32; // 256-bit key
  static const int _ivLength = 16; // 128-bit IV

  static final Random _random = Random.secure();

  /// Generate cryptographically secure random bytes
  static Uint8List generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// Generate a cryptographically secure salt
  static String generateSalt() {
    final saltBytes = generateRandomBytes(_saltLength);
    return base64Encode(saltBytes);
  }

  /// Hash password using PBKDF2 with SHA-256
  /// This is the secure replacement for simple SHA-256 hashing
  static String hashPassword(String password, {String? salt}) {
    // Generate salt if not provided
    salt ??= generateSalt();
    
    // Convert salt and password to bytes
    final saltBytes = base64Decode(salt);
    final passwordBytes = utf8.encode(password);
    
    // Perform PBKDF2 key derivation
    final hashedBytes = _pbkdf2(passwordBytes, saltBytes, _iterations, _keyLength);
    
    // Combine salt and hash for storage
    final combined = <int>[];
    combined.addAll(saltBytes);
    combined.addAll(hashedBytes);
    
    return base64Encode(combined);
  }

  /// Verify password against stored hash
  static bool verifyPassword(String password, String storedHash) {
    try {
      // Decode the stored hash
      final combined = base64Decode(storedHash);
      
      // Extract salt and hash
      final saltBytes = combined.sublist(0, _saltLength);
      final storedHashBytes = combined.sublist(_saltLength);
      
      // Hash the provided password with the extracted salt
      final passwordBytes = utf8.encode(password);
      final computedHashBytes = _pbkdf2(passwordBytes, saltBytes, _iterations, _keyLength);
      
      // Compare hashes in constant time to prevent timing attacks
      return _constantTimeEquals(storedHashBytes, computedHashBytes);
    } catch (e) {
      // If any error occurs during verification, password is invalid
      return false;
    }
  }

  /// PBKDF2 implementation using HMAC-SHA256
  static Uint8List _pbkdf2(List<int> password, List<int> salt, int iterations, int keyLength) {
    final hmac = Hmac(sha256, password);
    final saltedPassword = List<int>.from(salt)..addAll([0, 0, 0, 1]);
    
    var u = hmac.convert(saltedPassword).bytes;
    var result = List<int>.from(u);
    
    for (int i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (int j = 0; j < u.length; j++) {
        result[j] ^= u[j];
      }
    }
    
    return Uint8List.fromList(result.take(keyLength).toList());
  }

  /// Constant-time comparison to prevent timing attacks
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    
    return result == 0;
  }

  /// Generate AES encryption key from password
  static Key _generateKeyFromPassword(String password, String salt) {
    final saltBytes = base64Decode(salt);
    final passwordBytes = utf8.encode(password);
    final keyBytes = _pbkdf2(passwordBytes, saltBytes, _iterations, _aesKeyLength);
    return Key(keyBytes);
  }

  /// Encrypt sensitive data (like session tokens)
  static String encryptData(String data, String password) {
    try {
      // Generate salt and IV
      final salt = generateSalt();
      final iv = IV(generateRandomBytes(_ivLength));
      
      // Generate encryption key from password
      final key = _generateKeyFromPassword(password, salt);
      
      // Create encrypter
      final encrypter = Encrypter(AES(key));
      
      // Encrypt the data
      final encrypted = encrypter.encrypt(data, iv: iv);
      
      // Combine salt, IV, and encrypted data
      final combined = {
        'salt': salt,
        'iv': iv.base64,
        'data': encrypted.base64,
      };
      
      return base64Encode(utf8.encode(json.encode(combined)));
    } catch (e) {
      throw CryptoException('Failed to encrypt data: $e');
    }
  }

  /// Decrypt sensitive data
  static String decryptData(String encryptedData, String password) {
    try {
      // Decode the encrypted data
      final decodedString = utf8.decode(base64Decode(encryptedData));
      final combined = json.decode(decodedString) as Map<String, dynamic>;
      
      // Extract components
      final salt = combined['salt'] as String;
      final iv = IV.fromBase64(combined['iv'] as String);
      final encrypted = Encrypted.fromBase64(combined['data'] as String);
      
      // Generate decryption key from password
      final key = _generateKeyFromPassword(password, salt);
      
      // Create decrypter
      final encrypter = Encrypter(AES(key));
      
      // Decrypt the data
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw CryptoException('Failed to decrypt data: $e');
    }
  }

  /// Generate secure session token
  static String generateSessionToken() {
    final tokenBytes = generateRandomBytes(32);
    return base64Encode(tokenBytes);
  }

  /// Generate secure API key
  static String generateAPIKey() {
    final keyBytes = generateRandomBytes(24);
    return base64Encode(keyBytes).replaceAll('/', '_').replaceAll('+', '-');
  }

  /// Hash data for integrity checking (SHA-256)
  static String hashData(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify data integrity
  static bool verifyDataIntegrity(String data, String expectedHash) {
    final computedHash = hashData(data);
    return _constantTimeEquals(
      utf8.encode(expectedHash),
      utf8.encode(computedHash),
    );
  }

  /// Generate secure random ID
  static String generateSecureId([int length = 16]) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final result = StringBuffer();
    
    for (int i = 0; i < length; i++) {
      result.write(chars[_random.nextInt(chars.length)]);
    }
    
    return result.toString();
  }

  /// Generate secure numeric PIN
  static String generateSecurePIN(int length) {
    final result = StringBuffer();
    
    for (int i = 0; i < length; i++) {
      result.write(_random.nextInt(10));
    }
    
    return result.toString();
  }

  /// Mask sensitive data for logging
  static String maskSensitiveData(String data, {int visibleChars = 4}) {
    if (data.length <= visibleChars) {
      return '*' * data.length;
    }
    
    final prefix = data.substring(0, visibleChars ~/ 2);
    final suffix = data.substring(data.length - (visibleChars ~/ 2));
    final maskedLength = data.length - visibleChars;
    
    return '$prefix${'*' * maskedLength}$suffix';
  }

  /// Secure comparison for sensitive strings
  static bool secureCompare(String a, String b) {
    return _constantTimeEquals(utf8.encode(a), utf8.encode(b));
  }
}

/// Custom exception for cryptographic operations
class CryptoException implements Exception {
  final String message;
  
  CryptoException(this.message);
  
  @override
  String toString() => 'CryptoException: $message';
} 