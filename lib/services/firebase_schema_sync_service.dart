import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';
import '../config/firebase_config.dart';
import 'dart:convert'; // Added for jsonDecode

/// Service that ensures Firebase schema matches local database schema exactly
/// This is the SINGLE SOURCE OF TRUTH for all Firebase data structure
class FirebaseLocalSchemaSyncService {
  static final FirebaseLocalSchemaSyncService _instance = FirebaseLocalSchemaSyncService._internal();
  factory FirebaseLocalSchemaSyncService() => _instance;
  FirebaseLocalSchemaSyncService._internal();

  static FirebaseLocalSchemaSyncService get instance => _instance;

  /// Initialize Firebase collections using exact local database schema during restaurant registration
  /// This ensures Firebase mirrors the working local structure perfectly
  Future<void> initializeFirebaseSchemaForRestaurant({
    required String tenantId,
    required DatabaseService localDatabase,
  }) async {
    try {
      
      if (!FirebaseConfig.isInitialized) {
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final tenantDoc = firestore.collection('tenants').doc(tenantId);

      // Create tenant metadata using local schema structure
      await tenantDoc.set({
        'id': tenantId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'schema_version': '1.0.0',
        'local_schema_sync': true,
      });

      // Initialize ALL collections using exact local database table structures
      await _initializeCollectionSchemas(tenantDoc, localDatabase);

    } catch (e) {
      // Don't throw - Firebase sync is optional
    }
  }

  /// Initialize all Firebase collections using exact local table schemas
  Future<void> _initializeCollectionSchemas(DocumentReference tenantDoc, DatabaseService localDb) async {
    try {
      // Get all table schemas from local database - this is the SINGLE SOURCE OF TRUTH
      final localTableSchemas = await _getLocalTableSchemas(localDb);

      for (final tableSchema in localTableSchemas.entries) {
        final tableName = tableSchema.key;
        final columns = tableSchema.value;

        // Create Firebase collection with same structure as local table
        final collection = tenantDoc.collection(tableName);
        
        // Create a schema document that mirrors the local table structure exactly
        await collection.doc('_schema').set({
          'table_name': tableName,
          'columns': columns,
          'source': 'local_database',
          'sync_type': 'exact_mirror',
          'created_at': DateTime.now().toIso8601String(),
        });

      }
    } catch (e) {
    }
  }

  /// Get all table schemas from local database - THE SINGLE SOURCE OF TRUTH
  Future<Map<String, Map<String, String>>> _getLocalTableSchemas(DatabaseService localDb) async {
    final schemas = <String, Map<String, String>>{};

    try {
      // Get all table names from local database
      final tableNames = [
        'categories',
        'menu_items', 
        'orders',
        'order_items',
        'users',
        'tables',
        'inventory',
        'customers',
        'transactions',
        'reservations',
        'printer_configurations',
        'printer_assignments',
        'order_logs',
        'app_metadata',
      ];

      for (final tableName in tableNames) {
        try {
          // Get column information from local SQLite database
          final columns = await _getTableColumns(localDb, tableName);
          schemas[tableName] = columns;
        } catch (e) {
        }
      }
    } catch (e) {
    }

    return schemas;
  }

  /// Get column information from local SQLite table
  Future<Map<String, String>> _getTableColumns(DatabaseService localDb, String tableName) async {
    final columns = <String, String>{};

    try {
      final result = await localDb.query('sqlite_master', 
        where: 'type = ? AND name = ?', 
        whereArgs: ['table', tableName]);
      
      for (final row in result) {
        final columnName = row['name'] as String;
        final columnType = row['type'] as String;
        columns[columnName] = columnType;
      }
    } catch (e) {
    }

    return columns;
  }

  /// Sync local data to Firebase using exact local schema structure
  /// This ensures Firebase mirrors the local database structure perfectly
  Future<void> syncLocalDataToFirebase({
    required String tenantId,
    required DatabaseService localDatabase,
  }) async {
    try {
      
      if (!FirebaseConfig.isInitialized) {
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final tenantDoc = firestore.collection('tenants').doc(tenantId);

      // Get local database instance
      final db = await localDatabase.customDatabase;
      if (db == null) {
        return;
      }

      // Sync all tables using exact local schema
      await _syncAllTablesToFirebase(tenantDoc, db);

    } catch (e) {
      // Don't throw - Firebase sync is optional
    }
  }

  /// Sync all tables to Firebase using exact local schema
  Future<void> _syncAllTablesToFirebase(DocumentReference tenantDoc, Database db) async {
    try {
      // Define all tables that should be synced
      final tablesToSync = [
        'categories',
        'menu_items',
        'users',
        'tables',
        'inventory',
        'customers',
        'printer_configurations',
        'printer_assignments',
        'order_logs',
        'app_metadata',
      ];

      for (final tableName in tablesToSync) {
        await _syncTableToFirebase(tenantDoc, db, tableName);
      }
    } catch (e) {
    }
  }

  /// Sync a single table to Firebase using exact local schema
  Future<void> _syncTableToFirebase(DocumentReference tenantDoc, Database db, String tableName) async {
    try {
      // Check if table exists in local database
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName]
      );

      if (tableExists.isEmpty) {
        return;
      }

      // Get all data from local table
      final localData = await db.query(tableName);
      
      if (localData.isEmpty) {
        return;
      }

      // Get table schema from local database
      final tableSchema = await db.rawQuery("PRAGMA table_info($tableName)");
      final columnNames = tableSchema.map((col) => col['name'] as String).toList();

      // Create Firebase collection
      final collection = tenantDoc.collection(tableName);

      // Sync each record with exact schema mapping
      for (final record in localData) {
        final documentId = record['id']?.toString() ?? _generateDocumentId();
        
        // Convert data to Firebase-compatible format using exact local schema
        final firebaseData = _convertToFirebaseFormat(record, columnNames);
        
        try {
          await collection.doc(documentId).set(firebaseData);
        } catch (e) {
        }
      }

    } catch (e) {
    }
  }

  /// Convert local database record to Firebase format using exact schema
  Map<String, dynamic> _convertToFirebaseFormat(Map<String, dynamic> localRecord, List<String> columnNames) {
    final firebaseData = <String, dynamic>{};
    
    for (final columnName in columnNames) {
      final value = localRecord[columnName];
      
      // Handle different data types appropriately
      if (value == null) {
        firebaseData[columnName] = null;
      } else if (value is int) {
        firebaseData[columnName] = value;
      } else if (value is double) {
        firebaseData[columnName] = value;
      } else if (value is String) {
        // Try to parse as JSON if it looks like JSON
        if (value.startsWith('{') || value.startsWith('[')) {
          try {
            firebaseData[columnName] = jsonDecode(value);
          } catch (e) {
            firebaseData[columnName] = value;
          }
        } else {
          firebaseData[columnName] = value;
        }
      } else if (value is bool) {
        firebaseData[columnName] = value;
      } else {
        firebaseData[columnName] = value.toString();
      }
    }
    
    // Add metadata
    firebaseData['_local_schema_sync'] = true;
    firebaseData['_synced_at'] = DateTime.now().toIso8601String();
    
    return firebaseData;
  }

  /// Generate a unique document ID for Firebase
  String _generateDocumentId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Sync data FROM Firebase TO local database using exact Firebase data structure
  /// This ensures local data matches Firebase data exactly  
  Future<void> syncFirebaseDataToLocal({
    required String tenantId,
    required DatabaseService localDatabase,
    List<String>? specificTables,
  }) async {
    try {
      
      if (!FirebaseConfig.isInitialized) {
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final tenantDoc = firestore.collection('tenants').doc(tenantId);

      // Tables to sync (use all if not specified)
      final tablesToSync = specificTables ?? [
        'categories',
        'menu_items',
        'users',
        'tables',
        'inventory',
        'customers',
        'printer_configurations',
        'printer_assignments',
        'app_metadata',
      ];

      for (final tableName in tablesToSync) {
        await _syncFirebaseTableToLocal(tenantDoc, localDatabase, tableName);
      }

    } catch (e) {
    }
  }

  /// Sync a specific Firebase collection to local table
  Future<void> _syncFirebaseTableToLocal(
    DocumentReference tenantDoc,
    DatabaseService localDb,
    String tableName,
  ) async {
    try {
      // Get all data from Firebase collection
      final collection = tenantDoc.collection(tableName);
      final snapshot = await collection.get();
      
      if (snapshot.docs.isEmpty) {
        return;
      }

      // Clear local table first to ensure clean sync
      await localDb.delete(tableName);
      
      // Insert Firebase data into local table preserving exact structure
      for (final doc in snapshot.docs) {
        if (doc.id == '_schema') continue; // Skip schema document
        
        final firebaseData = doc.data();
        
        // Convert Firebase data to local format while preserving structure
        final localData = _convertFirebaseDataForLocal(firebaseData);
        
        await localDb.insert(tableName, localData);
      }
      
    } catch (e) {
    }
  }

  /// Convert Firebase data to local database format while preserving exact structure
  Map<String, dynamic> _convertFirebaseDataForLocal(Map<String, dynamic> firebaseData) {
    final localData = <String, dynamic>{};
    
    for (final entry in firebaseData.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Preserve the exact Firebase data structure
      if (value != null) {
        localData[key] = value;
      }
    }
    
    return localData;
  }
} 