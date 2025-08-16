import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Utility class to clear all Firebase data for the POS system
class FirebaseDataClearer {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Clear all data from Firebase
  static Future<void> clearAllFirebaseData() async {
    try {
      debugPrint('🗑️ Starting Firebase data cleanup...');
      
      // Ensure we're authenticated
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
      
      // Clear tenants collection
      await _clearTenantsCollection();
      
      // Clear global collections
      await _clearGlobalCollections();
      
      // Clear any other collections
      await _clearOtherCollections();
      
      debugPrint('✅ All Firebase data cleared successfully');
    } catch (e) {
      debugPrint('❌ Failed to clear Firebase data: $e');
      rethrow;
    }
  }

  /// Clear tenants collection and all subcollections
  static Future<void> _clearTenantsCollection() async {
    try {
      debugPrint('🗑️ Clearing tenants collection...');
      
      final tenantsSnapshot = await _firestore.collection('tenants').get();
      debugPrint('📊 Found ${tenantsSnapshot.docs.length} tenants to clear');
      
      for (final tenantDoc in tenantsSnapshot.docs) {
        final tenantId = tenantDoc.id;
        debugPrint('🗑️ Clearing tenant: $tenantId');
        
        // Clear known subcollections for this tenant
        final knownSubcollections = [
          'users',
          'categories',
          'menu_items',
          'tables',
          'inventory',
          'orders',
          'order_items',
          'printer_configs',
          'printer_assignments',
          'order_logs',
          'customers',
          'transactions',
          'reservations',
          'app_metadata',
        ];
        
        for (final subcollectionName in knownSubcollections) {
          try {
            debugPrint('🗑️ Clearing subcollection: $subcollectionName');
            
            // Delete all documents in subcollection
            final docsSnapshot = await tenantDoc.reference.collection(subcollectionName).get();
            for (final doc in docsSnapshot.docs) {
              await doc.reference.delete();
            }
            
            debugPrint('✅ Cleared ${docsSnapshot.docs.length} documents from $subcollectionName');
          } catch (e) {
            debugPrint('⚠️ Could not clear subcollection $subcollectionName: $e');
          }
        }
        
        // Delete the tenant document itself
        await tenantDoc.reference.delete();
        debugPrint('✅ Deleted tenant document: $tenantId');
      }
      
      debugPrint('✅ Tenants collection cleared successfully');
    } catch (e) {
      debugPrint('❌ Failed to clear tenants collection: $e');
    }
  }

  /// Clear global collections
  static Future<void> _clearGlobalCollections() async {
    try {
      debugPrint('🗑️ Clearing global collections...');
      
      final globalCollections = [
        'restaurants',
        'global_restaurants',
        'devices',
        'global_users',
        'sync_events',
        'active_devices',
      ];
      
      for (final collectionName in globalCollections) {
        debugPrint('🗑️ Clearing global collection: $collectionName');
        
        final snapshot = await _firestore.collection(collectionName).get();
        debugPrint('📊 Found ${snapshot.docs.length} documents in $collectionName');
        
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
        
        debugPrint('✅ Cleared $collectionName');
      }
      
      debugPrint('✅ Global collections cleared successfully');
    } catch (e) {
      debugPrint('❌ Failed to clear global collections: $e');
    }
  }

  /// Clear any other collections that might exist
  static Future<void> _clearOtherCollections() async {
    try {
      debugPrint('🗑️ Checking for other collections...');
      
      // Clear any additional known collections that might exist
      final additionalCollections = [
        'print_jobs',
        'device_registrations',
        'sync_metadata',
        'activity_logs',
        'audit_logs',
        'system_config',
        'backup_data',
      ];
      
      for (final collectionName in additionalCollections) {
        try {
          debugPrint('🗑️ Checking additional collection: $collectionName');
          
          final snapshot = await _firestore.collection(collectionName).get();
          if (snapshot.docs.isNotEmpty) {
            debugPrint('📊 Found ${snapshot.docs.length} documents in $collectionName');
            
            for (final doc in snapshot.docs) {
              await doc.reference.delete();
            }
            
            debugPrint('✅ Cleared $collectionName');
          }
        } catch (e) {
          debugPrint('⚠️ Could not clear collection $collectionName: $e');
        }
      }
      
      debugPrint('✅ Other collections cleared successfully');
    } catch (e) {
      debugPrint('❌ Failed to clear other collections: $e');
    }
  }

  /// Verify that all data is cleared
  static Future<void> verifyDataCleared() async {
    try {
      debugPrint('🔍 Verifying data cleanup...');
      
      // Check tenants collection
      final tenantsSnapshot = await _firestore.collection('tenants').get();
      debugPrint('📊 Tenants remaining: ${tenantsSnapshot.docs.length}');
      
      // Check global collections
      final globalCollections = [
        'restaurants',
        'global_restaurants',
        'devices',
        'global_users',
        'sync_events',
        'active_devices',
      ];
      
      int totalRemaining = 0;
      for (final collectionName in globalCollections) {
        final snapshot = await _firestore.collection(collectionName).get();
        totalRemaining += snapshot.docs.length;
        debugPrint('📊 $collectionName remaining: ${snapshot.docs.length}');
      }
      
      if (tenantsSnapshot.docs.isEmpty && totalRemaining == 0) {
        debugPrint('✅ All Firebase data successfully cleared!');
      } else {
        debugPrint('⚠️ Some data still remains in Firebase');
      }
    } catch (e) {
      debugPrint('❌ Failed to verify data cleanup: $e');
    }
  }

  /// Clear specific tenant data
  static Future<void> clearTenantData(String tenantId) async {
    try {
      debugPrint('🗑️ Clearing specific tenant: $tenantId');
      
      final tenantDoc = _firestore.collection('tenants').doc(tenantId);
      
      // Clear known subcollections for this tenant
      final knownSubcollections = [
        'users',
        'categories',
        'menu_items',
        'tables',
        'inventory',
        'orders',
        'order_items',
        'printer_configs',
        'printer_assignments',
        'order_logs',
        'customers',
        'transactions',
        'reservations',
        'app_metadata',
      ];
      
      for (final subcollectionName in knownSubcollections) {
        try {
          debugPrint('🗑️ Clearing subcollection: $subcollectionName');
          
          // Delete all documents in subcollection
          final docsSnapshot = await tenantDoc.collection(subcollectionName).get();
          for (final doc in docsSnapshot.docs) {
            await doc.reference.delete();
          }
          
          debugPrint('✅ Cleared ${docsSnapshot.docs.length} documents from $subcollectionName');
        } catch (e) {
          debugPrint('⚠️ Could not clear subcollection $subcollectionName: $e');
        }
      }
      
      // Delete the tenant document itself
      await tenantDoc.delete();
      debugPrint('✅ Deleted tenant document: $tenantId');
    } catch (e) {
      debugPrint('❌ Failed to clear tenant $tenantId: $e');
    }
  }
} 