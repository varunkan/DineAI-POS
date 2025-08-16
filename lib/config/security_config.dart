import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Secure configuration for authentication and credentials
class SecurityConfig {
  static const String _saltKey = 'POS_SALT_2024';
  
  /// Generate a secure random PIN
  static String generateSecurePin() {
    final random = Random.secure();
    return (1000 + random.nextInt(9000)).toString(); // 4-digit PIN
  }
  
  /// Hash a PIN with salt for secure storage
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin + _saltKey);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Verify a PIN against a hash
  static bool verifyPin(String pin, String hash) {
    return hashPin(pin) == hash;
  }
  
  /// Get the default admin PIN (configurable via environment)
  static String getDefaultAdminPin() {
    // In production, this should come from environment variables or secure config
    const envPin = String.fromEnvironment('ADMIN_PIN');
    if (envPin.isNotEmpty) {
      return envPin;
    }
    
    // Development fallback - should be changed in production
    if (kDebugMode) {
      debugPrint('⚠️ Using development admin PIN - change in production!');
      return '1234'; // Development default
    }
    
    // Production requires environment variable
    throw Exception('ADMIN_PIN environment variable must be set in production');
  }
  
  /// Get the default admin PIN hash
  static String getDefaultAdminPinHash() {
    return hashPin(getDefaultAdminPin());
  }
  
  /// Validate admin credentials
  static Future<bool> validateAdminCredentials(String inputPin) async {
    try {
      final defaultHash = getDefaultAdminPinHash();
      
      // Check against default admin PIN
      if (verifyPin(inputPin, defaultHash)) {
        return true;
      }
      
      // Additional validation can be added here
      // e.g., checking against database of admin users
      
      return false;
    } catch (e) {
      debugPrint('❌ Error validating admin credentials: $e');
      return false;
    }
  }
  
  /// Create a secure admin user configuration
  static Map<String, dynamic> createSecureAdminConfig() {
    final pin = getDefaultAdminPin();
    final hashedPin = hashPin(pin);
    
    return {
      'id': 'admin',
      'name': 'Admin',
      'role': 'admin',
      'pin_hash': hashedPin,
      'admin_panel_access': true,
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
  
  /// Log security events (without exposing sensitive data)
  static void logSecurityEvent(String event, {Map<String, dynamic>? metadata}) {
    if (kDebugMode) {
      debugPrint('🔒 Security Event: $event');
      if (metadata != null) {
        // Remove sensitive fields before logging
        final safeMetadata = Map<String, dynamic>.from(metadata);
        safeMetadata.removeWhere((key, value) => 
          key.toLowerCase().contains('pin') || 
          key.toLowerCase().contains('password') ||
          key.toLowerCase().contains('hash'));
        
        if (safeMetadata.isNotEmpty) {
          debugPrint('   Metadata: $safeMetadata');
        }
      }
    }
  }
} 