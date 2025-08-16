import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firebase connection test utility
class FirebaseConnectionTest {
  static const String _logTag = 'FirebaseConnectionTest';

  /// Test Firebase connection and return results
  static Future<Map<String, dynamic>> testConnection() async {
    final results = <String, dynamic>{
      'firebase_initialized': false,
      'firestore_available': false,
      'connection_timeout': false,
      'error': null,
    };

    try {
      debugPrint('$_logTag 🔍 Testing Firebase connection...');
      
      // Test Firestore connection
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('test').limit(1).get().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('$_logTag ⚠️ Firestore connection timed out');
          results['connection_timeout'] = true;
          throw TimeoutException('Firestore connection timed out', const Duration(seconds: 5));
        },
      );
      
      results['firebase_initialized'] = true;
      results['firestore_available'] = true;
      debugPrint('$_logTag ✅ Firebase connection successful');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Firebase connection failed: $e');
      results['error'] = e.toString();
    }
    
    return results;
  }

  /// Print connection test results
  static void printResults(Map<String, dynamic> results) {
    debugPrint('$_logTag 📊 Connection Test Results:');
    debugPrint('   Firebase Initialized: ${results['firebase_initialized']}');
    debugPrint('   Firestore Available: ${results['firestore_available']}');
    debugPrint('   Connection Timeout: ${results['connection_timeout']}');
    if (results['error'] != null) {
      debugPrint('   Error: ${results['error']}');
    }
  }
} 