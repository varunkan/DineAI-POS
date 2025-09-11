import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'lib/services/order_service.dart';
import 'lib/services/multi_tenant_auth_service.dart';
import 'lib/config/firebase_config.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/services/order_log_service.dart';
import 'package:ai_pos_system/services/inventory_service.dart';
import 'package:ai_pos_system/models/order.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔄 Starting manual order sync from Firebase...');
  
  try {
    await FirebaseConfig.initialize();
    // Get the current tenant ID
    final tenantId = FirebaseConfig.getCurrentTenantId();
    if (tenantId == null) {
      print('❌ No tenant ID available for sync');
      return;
    }
    
    print('🔍 Using tenant ID: $tenantId');
    
    // Test Firebase connection
    final firestoreInstance = fs.FirebaseFirestore.instance;
    try {
      await firestoreInstance.collection('tenants').doc(tenantId).get();
      print('✅ Firebase connection test successful');
    } catch (e) {
      print('❌ Firebase connection test failed: $e');
      return;
    }
    
    // Get orders from Firebase
    final ordersSnapshot = await firestoreInstance
        .collection('tenants')
        .doc(tenantId)
        .collection('orders')
        .get();
    
    print('📊 Found ${ordersSnapshot.docs.length} orders in Firebase');
    
    if (ordersSnapshot.docs.isEmpty) {
      print('✅ No orders found in Firebase');
      return;
    }
    
    // Initialize order service
    final databaseService = DatabaseService();
    final orderLogService = OrderLogService(databaseService);
    final inventoryService = InventoryService();
    final orderService = OrderService(databaseService, orderLogService, inventoryService);
    
    int syncedCount = 0;
    int errorCount = 0;
    
    for (final doc in ordersSnapshot.docs) {
      try {
        final orderData = doc.data();
        orderData['id'] = doc.id;
        
        // Skip non-order documents
        if (doc.id == '_persistence_config' || !orderData.containsKey('orderNumber')) {
          print('⏭️ Skipping non-order document: ${doc.id}');
          continue;
        }
        
        // Convert to Order object and save
        final order = Order.fromJson(orderData);
        await orderService.updateOrderFromFirebase(order);
        syncedCount++;
        print('✅ Synced order: ${order.orderNumber}');
      } catch (e) {
        errorCount++;
        print('❌ Failed to sync order ${doc.id}: $e');
      }
    }
    
    print('✅ Manual sync completed:');
    print('   📥 Successfully synced: $syncedCount orders');
    print('   ❌ Failed to sync: $errorCount orders');
    
  } catch (e) {
    print('❌ Manual sync failed: $e');
  }
} 