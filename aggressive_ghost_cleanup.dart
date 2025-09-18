import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/config/firebase_config.dart';
import 'lib/services/database_service.dart';
import 'lib/models/order.dart';
import 'lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    print('🔥 Firebase initialized successfully');
    
    // Initialize database
    final dbService = DatabaseService();
    await dbService.initializeDatabase();
    
    print('💾 Database initialized successfully');
    
    // Run aggressive ghost cleanup
    await runAggressiveGhostCleanup(dbService);
    
  } catch (e) {
    print('❌ Error during initialization: $e');
    exit(1);
  }
}

Future<void> runAggressiveGhostCleanup(DatabaseService dbService) async {
  print('🧹 Starting AGGRESSIVE ghost order cleanup...');
  
  int localDeleted = 0;
  int firebaseDeleted = 0;
  
  try {
    // Get current tenant ID
    final tenantId = FirebaseConfig.getCurrentTenantId();
    if (tenantId == null) {
      print('❌ No tenant ID found. Please login first.');
      return;
    }
    
    print('🏢 Cleaning tenant: $tenantId');
    
    // Step 1: Clean local database
    print('\n📱 STEP 1: Cleaning local database...');
    localDeleted = await cleanLocalGhostOrders(dbService);
    
    // Step 2: Clean Firebase
    print('\n☁️ STEP 2: Cleaning Firebase...');
    firebaseDeleted = await cleanFirebaseGhostOrders(tenantId);
    
    print('\n✅ AGGRESSIVE CLEANUP COMPLETE!');
    print('📊 Summary:');
    print('   - Local orders deleted: $localDeleted');
    print('   - Firebase orders deleted: $firebaseDeleted');
    print('   - Total ghost orders eliminated: ${localDeleted + firebaseDeleted}');
    
  } catch (e) {
    print('❌ Error during aggressive cleanup: $e');
    rethrow;
  }
}

Future<int> cleanLocalGhostOrders(DatabaseService dbService) async {
  int deletedCount = 0;
  
  try {
    final db = await dbService.database;
    
    // Find all orders with no items or $0 total
    final ghostOrders = await db.rawQuery('''
      SELECT DISTINCT o.id, o.order_number, o.total_amount, 
             COUNT(oi.id) as item_count
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      GROUP BY o.id
      HAVING item_count = 0 OR o.total_amount = 0 OR o.total_amount IS NULL
    ''');
    
    print('🔍 Found ${ghostOrders.length} ghost orders in local database');
    
    if (ghostOrders.isEmpty) {
      print('✅ No ghost orders found in local database');
      return 0;
    }
    
    // Delete each ghost order
    await db.transaction((txn) async {
      for (final ghostOrder in ghostOrders) {
        final orderId = ghostOrder['id'] as String;
        final orderNumber = ghostOrder['order_number'] as String?;
        final totalAmount = ghostOrder['total_amount'] as double?;
        final itemCount = ghostOrder['item_count'] as int;
        
        print('🗑️ Deleting ghost order: $orderNumber (ID: $orderId, Items: $itemCount, Total: \$${totalAmount ?? 0})');
        
        // Delete order items first (if any)
        await txn.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
        
        // Delete the order
        await txn.delete('orders', where: 'id = ?', whereArgs: [orderId]);
        
        deletedCount++;
      }
    });
    
    print('✅ Deleted $deletedCount ghost orders from local database');
    
  } catch (e) {
    print('❌ Error cleaning local ghost orders: $e');
    rethrow;
  }
  
  return deletedCount;
}

Future<int> cleanFirebaseGhostOrders(String tenantId) async {
  int deletedCount = 0;
  
  try {
    final firestore = FirebaseFirestore.instance;
    final ordersRef = firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('orders');
    
    // Get all orders from Firebase
    final ordersSnapshot = await ordersRef.get();
    print('🔍 Checking ${ordersSnapshot.docs.length} orders in Firebase...');
    
    final batch = firestore.batch();
    int batchCount = 0;
    
    for (final orderDoc in ordersSnapshot.docs) {
      try {
        final orderData = orderDoc.data();
        final orderId = orderDoc.id;
        
        // Check if this is a ghost order
        final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final items = orderData['items'] as List? ?? [];
        
        bool isGhost = false;
        String reason = '';
        
        if (items.isEmpty) {
          isGhost = true;
          reason = 'no items';
        } else if (totalAmount == 0.0) {
          isGhost = true;
          reason = '\$0 total';
        }
        
        if (isGhost) {
          final orderNumber = orderData['orderNumber'] ?? 'Unknown';
          print('🗑️ Deleting Firebase ghost order: $orderNumber (ID: $orderId, Reason: $reason)');
          
          batch.delete(orderDoc.reference);
          batchCount++;
          deletedCount++;
          
          // Commit batch every 500 operations to avoid limits
          if (batchCount >= 500) {
            await batch.commit();
            print('📦 Committed batch of $batchCount deletions');
            batchCount = 0;
          }
        }
        
      } catch (e) {
        print('⚠️ Error processing Firebase order ${orderDoc.id}: $e');
        continue;
      }
    }
    
    // Commit remaining operations
    if (batchCount > 0) {
      await batch.commit();
      print('📦 Committed final batch of $batchCount deletions');
    }
    
    print('✅ Deleted $deletedCount ghost orders from Firebase');
    
  } catch (e) {
    print('❌ Error cleaning Firebase ghost orders: $e');
    rethrow;
  }
  
  return deletedCount;
} 