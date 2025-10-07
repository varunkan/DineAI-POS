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
      
    } catch (e) {
      rethrow;
    }
  }

  /// Clear tenants collection and all subcollections
  static Future<void> _clearTenantsCollection() async {
    try {
      
      final tenantsSnapshot = await _firestore.collection('tenants').get();
      
      for (final tenantDoc in tenantsSnapshot.docs) {
        final tenantId = tenantDoc.id;
        
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
            
            // Delete all documents in subcollection
            final docsSnapshot = await tenantDoc.reference.collection(subcollectionName).get();
            for (final doc in docsSnapshot.docs) {
              await doc.reference.delete();
            }
            
          } catch (e) {
          }
        }
        
        // Delete the tenant document itself
        await tenantDoc.reference.delete();
      }
      
    } catch (e) {
    }
  }

  /// Clear global collections
  static Future<void> _clearGlobalCollections() async {
    try {
      
      final globalCollections = [
        'restaurants',
        'global_restaurants',
        'devices',
        'global_users',
        'sync_events',
        'active_devices',
      ];
      
      for (final collectionName in globalCollections) {
        
        final snapshot = await _firestore.collection(collectionName).get();
        
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
        
      }
      
    } catch (e) {
    }
  }

  /// Clear any other collections that might exist
  static Future<void> _clearOtherCollections() async {
    try {
      
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
          
          final snapshot = await _firestore.collection(collectionName).get();
          if (snapshot.docs.isNotEmpty) {
            
            for (final doc in snapshot.docs) {
              await doc.reference.delete();
            }
            
          }
        } catch (e) {
        }
      }
      
    } catch (e) {
    }
  }

  /// Verify that all data is cleared
  static Future<void> verifyDataCleared() async {
    try {
      
      // Check tenants collection
      final tenantsSnapshot = await _firestore.collection('tenants').get();
      
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
      }
      
      if (tenantsSnapshot.docs.isEmpty && totalRemaining == 0) {
      } else {
      }
    } catch (e) {
    }
  }

  /// Clear specific tenant data
  static Future<void> clearTenantData(String tenantId) async {
    try {
      
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
          
          // Delete all documents in subcollection
          final docsSnapshot = await tenantDoc.collection(subcollectionName).get();
          for (final doc in docsSnapshot.docs) {
            await doc.reference.delete();
          }
          
        } catch (e) {
        }
      }
      
      // Delete the tenant document itself
      await tenantDoc.delete();
    } catch (e) {
    }
  }
} 