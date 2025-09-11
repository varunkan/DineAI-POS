import 'package:flutter/material.dart';
import 'package:ai_pos_system/services/order_service.dart';
import 'package:ai_pos_system/services/unified_sync_service.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/services/order_log_service.dart';
import 'package:ai_pos_system/services/inventory_service.dart';
import 'package:ai_pos_system/config/firebase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🔄 Triggering immediate sync...');

  try {
    // Initialize Firebase once for proper Firestore/Auth usage
    await FirebaseConfig.initialize();

    // Ensure a tenant is set; if your app sets it elsewhere at runtime,
    // this will be a no-op. Otherwise, set it from env/config if needed.
    final tenantId = FirebaseConfig.getCurrentTenantId();
    if (tenantId == null) {
      print('⚠️ No tenantId set. If expected, set it via FirebaseConfig.setCurrentTenantId(...) before running.');
    }

    // Wire up dependencies like in main.dart
    final databaseService = DatabaseService();
    final orderLogService = OrderLogService(databaseService);
    final inventoryService = InventoryService();

    final orderService = OrderService(databaseService, orderLogService, inventoryService);
    final unifiedSyncService = UnifiedSyncService();

    print('📊 Current local orders: ${orderService.allOrders.length}');

    // Kick off manual syncs
    print('🔄 Starting manual sync (OrderService)...');
    await orderService.manualSync();

    print('🔄 Starting manual sync (UnifiedSyncService)...');
    await unifiedSyncService.manualSync();

    // As a safety, process any pending changes queued in unified sync service
    await unifiedSyncService.processPendingChanges();

    print('📊 Orders after sync: ${orderService.allOrders.length}');
    print('✅ Unified sync completed');
    print('✅ Sync process completed');
  } catch (e) {
    print('❌ Sync failed: $e');
  }
} 