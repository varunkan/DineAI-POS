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
    
    // Run comprehensive data recovery
    await runComprehensiveDataRecovery(dbService);
    
  } catch (e) {
    print('❌ Error during initialization: $e');
    exit(1);
  }
}

Future<void> runComprehensiveDataRecovery(DatabaseService dbService) async {
  print('🚨 Starting COMPREHENSIVE DATA RECOVERY...');
  
  int recoveredOrders = 0;
  int recoveredOrderItems = 0;
  int skippedOrders = 0;
  
  try {
    // Get current tenant ID
    final tenantId = FirebaseConfig.getCurrentTenantId();
    if (tenantId == null) {
      print('❌ No tenant ID found. Please login first.');
      return;
    }
    
    print('🏢 Recovering data for tenant: $tenantId');
    
    // Step 1: Get current local order count
    final db = await dbService.database;
    final localOrdersResult = await db!.query('orders');
    print('📊 Current local orders: ${localOrdersResult.length}');
    
    // Step 2: Get all orders from Firebase
    print('\n☁️ STEP 1: Fetching all orders from Firebase...');
    final firestore = FirebaseFirestore.instance;
    final ordersRef = firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('orders');
    
    final ordersSnapshot = await ordersRef.get();
    print('📊 Found ${ordersSnapshot.docs.length} orders in Firebase');
    
    if (ordersSnapshot.docs.isEmpty) {
      print('⚠️ No orders found in Firebase to recover');
      return;
    }
    
    // Step 3: Process each Firebase order
    print('\n💾 STEP 2: Recovering orders to local database...');
    
    for (final orderDoc in ordersSnapshot.docs) {
      try {
        final orderData = orderDoc.data();
        final orderId = orderDoc.id;
        final orderNumber = orderData['orderNumber'] ?? orderData['order_number'] ?? 'Unknown';
        
        // Check if order already exists locally
        final existingOrder = await db.query(
          'orders',
          where: 'id = ?',
          whereArgs: [orderId],
          limit: 1,
        );
        
        if (existingOrder.isNotEmpty) {
          print('⏭️ Order already exists: $orderNumber');
          skippedOrders++;
          continue;
        }
        
        // Validate order has items
        final items = orderData['items'] as List? ?? [];
        final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
        
        if (items.isEmpty && totalAmount == 0) {
          print('🚫 Skipping ghost order: $orderNumber (no items, \$0 total)');
          skippedOrders++;
          continue;
        }
        
        print('🔄 Recovering order: $orderNumber (${items.length} items, \$${totalAmount})');
        
        // Convert Firebase data to local database format
        final localOrderData = _convertFirebaseOrderToLocal(orderData, orderId);
        
        // Insert order into local database
        await db.transaction((txn) async {
          // Insert order
          await txn.insert(
            'orders',
            localOrderData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          
          // Insert order items
          for (final item in items) {
            final localItemData = _convertFirebaseOrderItemToLocal(item, orderId);
            await txn.insert(
              'order_items',
              localItemData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            recoveredOrderItems++;
          }
        });
        
        recoveredOrders++;
        
        if (recoveredOrders % 10 == 0) {
          print('📈 Progress: $recoveredOrders orders recovered...');
        }
        
      } catch (e) {
        print('❌ Error recovering order ${orderDoc.id}: $e');
        continue;
      }
    }
    
    // Step 4: Verify recovery
    print('\n✅ RECOVERY COMPLETE!');
    final finalOrdersResult = await db.query('orders');
    print('📊 Final local orders: ${finalOrdersResult.length}');
    
    print('\n📋 RECOVERY SUMMARY:');
    print('   - Orders recovered: $recoveredOrders');
    print('   - Order items recovered: $recoveredOrderItems');
    print('   - Orders skipped (already exist): $skippedOrders');
    print('   - Total orders in database: ${finalOrdersResult.length}');
    
    if (recoveredOrders > 0) {
      print('\n🎉 DATA RECOVERY SUCCESSFUL!');
      print('   Your orders have been restored from Firebase backup.');
    } else {
      print('\n⚠️ No new orders were recovered.');
      print('   This might mean your data is already up to date.');
    }
    
  } catch (e) {
    print('❌ Error during comprehensive recovery: $e');
    rethrow;
  }
}

Map<String, dynamic> _convertFirebaseOrderToLocal(Map<String, dynamic> firebaseData, String orderId) {
  final now = DateTime.now().toIso8601String();
  
  return {
    'id': orderId,
    'order_number': firebaseData['orderNumber'] ?? firebaseData['order_number'] ?? 'RECOVERED-$orderId',
    'customer_name': firebaseData['customerName'],
    'customer_phone': firebaseData['customerPhone'],
    'table_id': firebaseData['tableId'],
    'type': _convertOrderType(firebaseData['type']),
    'status': _convertOrderStatus(firebaseData['status']),
    'subtotal': (firebaseData['subtotal'] as num?)?.toDouble() ?? 0.0,
    'tax_amount': (firebaseData['taxAmount'] as num?)?.toDouble() ?? 0.0,
    'hst_amount': (firebaseData['hstAmount'] as num?)?.toDouble() ?? 0.0,
    'total_amount': (firebaseData['totalAmount'] as num?)?.toDouble() ?? 0.0,
    'payment_method': firebaseData['paymentMethod'] ?? 'cash',
    'special_instructions': firebaseData['specialInstructions'],
    'order_time': firebaseData['orderTime'] ?? now,
    'created_at': firebaseData['createdAt'] ?? now,
    'updated_at': firebaseData['updatedAt'] ?? now,
    'user_id': firebaseData['userId'] ?? 'recovered_user',
    'is_urgent': (firebaseData['isUrgent'] == true) ? 1 : 0,
    'sent_to_kitchen': (firebaseData['sentToKitchen'] == true) ? 1 : 0,
    'voided': (firebaseData['voided'] == true) ? 1 : 0,
    'comped': (firebaseData['comped'] == true) ? 1 : 0,
  };
}

Map<String, dynamic> _convertFirebaseOrderItemToLocal(Map<String, dynamic> firebaseItem, String orderId) {
  final now = DateTime.now().toIso8601String();
  
  return {
    'id': firebaseItem['id'] ?? 'recovered_${DateTime.now().millisecondsSinceEpoch}',
    'order_id': orderId,
    'menu_item_id': firebaseItem['menuItemId'] ?? firebaseItem['menuItem']?['id'] ?? 'unknown_item',
    'quantity': (firebaseItem['quantity'] as num?)?.toDouble() ?? 1.0,
    'unit_price': (firebaseItem['unitPrice'] as num?)?.toDouble() ?? 0.0,
    'total_price': (firebaseItem['totalPrice'] as num?)?.toDouble() ?? 0.0,
    'selected_variant': firebaseItem['selectedVariant'],
    'special_instructions': firebaseItem['specialInstructions'],
    'notes': firebaseItem['notes'],
    'is_available': (firebaseItem['isAvailable'] == true) ? 1 : 0,
    'sent_to_kitchen': (firebaseItem['sentToKitchen'] == true) ? 1 : 0,
    'created_at': firebaseItem['createdAt'] ?? now,
    'updated_at': firebaseItem['updatedAt'] ?? now,
  };
}

String _convertOrderType(dynamic type) {
  if (type == null) return 'dine_in';
  
  final typeStr = type.toString().toLowerCase();
  switch (typeStr) {
    case 'dinein':
    case 'dine_in':
      return 'dine_in';
    case 'takeout':
    case 'take_out':
      return 'takeout';
    case 'delivery':
      return 'delivery';
    default:
      return 'dine_in';
  }
}

String _convertOrderStatus(dynamic status) {
  if (status == null) return 'pending';
  
  final statusStr = status.toString().toLowerCase();
  switch (statusStr) {
    case 'pending':
      return 'pending';
    case 'confirmed':
      return 'confirmed';
    case 'preparing':
      return 'preparing';
    case 'ready':
      return 'ready';
    case 'completed':
      return 'completed';
    case 'cancelled':
      return 'cancelled';
    default:
      return 'pending';
  }
} 