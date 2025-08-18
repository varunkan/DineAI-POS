import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lib/services/order_service.dart';
import 'lib/services/unified_sync_service.dart';
import 'lib/config/firebase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔄 Triggering immediate sync...');
  
  try {
    // Initialize services
    final orderService = OrderService();
    
    print('📊 Current local orders: ${orderService.allOrders.length}');
    
    // Trigger manual sync
    print('🔄 Starting manual sync...');
    await orderService.manualSync();
    
    print('📊 Orders after sync: ${orderService.allOrders.length}');
    
    // Also try the unified sync service
    try {
      final unifiedSyncService = UnifiedSyncService();
      print('🔄 Triggering unified sync...');
      await unifiedSyncService.manualSync();
      print('✅ Unified sync completed');
    } catch (e) {
      print('⚠️ Unified sync failed: $e');
    }
    
    print('✅ Sync process completed');
    
  } catch (e) {
    print('❌ Sync failed: $e');
  }
} 