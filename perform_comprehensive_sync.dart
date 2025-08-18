import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'lib/services/order_service.dart';
import 'lib/services/unified_sync_service.dart';
import 'lib/services/multi_tenant_auth_service.dart';
import 'lib/config/firebase_config.dart';
import 'lib/models/restaurant.dart';
import 'lib/models/user.dart' as app_user;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 Starting comprehensive sync operations...');
  
  try {
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
    
    // Initialize services
    final orderService = OrderService();
    final unifiedSyncService = UnifiedSyncService();
    
    print('📊 Current local orders: ${orderService.allOrders.length}');
    
    // STEP 1: Perform Comprehensive Timestamp-Based Sync
    print('\n🔄 STEP 1: Performing Comprehensive Timestamp-Based Sync...');
    await _performComprehensiveTimestampSync(tenantId, firestoreInstance, orderService);
    
    // STEP 2: Perform Smart Time-Based Sync
    print('\n🔄 STEP 2: Performing Smart Time-Based Sync...');
    await _performSmartTimeBasedSync(unifiedSyncService, tenantId);
    
    // STEP 3: Force Manual Sync as Backup
    print('\n🔄 STEP 3: Performing Force Manual Sync...');
    await orderService.manualSync();
    
    print('\n📊 Final order count: ${orderService.allOrders.length}');
    print('✅ All comprehensive sync operations completed successfully!');
    
  } catch (e) {
    print('❌ Comprehensive sync failed: $e');
  }
}

/// Perform comprehensive timestamp-based sync
Future<void> _performComprehensiveTimestampSync(
  String tenantId, 
  fs.FirebaseFirestore firestoreInstance, 
  OrderService orderService
) async {
  try {
    print('🔄 Starting comprehensive timestamp-based sync...');
    
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
    
    print('✅ Comprehensive timestamp-based sync completed:');
    print('   📥 Successfully synced: $syncedCount orders');
    print('   ❌ Failed to sync: $errorCount orders');
    
  } catch (e) {
    print('❌ Comprehensive timestamp-based sync failed: $e');
  }
}

/// Perform smart time-based sync
Future<void> _performSmartTimeBasedSync(
  UnifiedSyncService unifiedSyncService, 
  String tenantId
) async {
  try {
    print('🔄 Starting smart time-based sync...');
    
    // Initialize the unified sync service
    await unifiedSyncService.initialize();
    
    // Create a temporary restaurant session for sync
    final tempRestaurant = Restaurant(
      id: tenantId,
      name: 'Temp Restaurant',
      email: tenantId,
      adminUserId: 'temp_admin',
      adminPassword: 'temp_password',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    final tempSession = RestaurantSession(
      restaurantId: tenantId,
      userId: 'temp_user',
      userName: 'temp_user',
      userRole: app_user.UserRole.admin,
      loginTime: DateTime.now(),
    );
    
    // Connect to restaurant for sync
    await unifiedSyncService.connectToRestaurant(tempRestaurant, tempSession);
    
    // Check if sync is needed
    final needsSync = await unifiedSyncService.needsSync();
    
    if (needsSync) {
      print('🔄 Smart sync needed - performing time-based sync...');
      
      // Perform the smart time-based sync
      await unifiedSyncService.performSmartTimeBasedSync();
      
      print('✅ Smart time-based sync completed');
    } else {
      print('✅ Smart sync not needed - data is already consistent');
    }
    
  } catch (e) {
    print('❌ Smart time-based sync failed: $e');
  }
} 