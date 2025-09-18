import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/services/unified_sync_service.dart';
import 'lib/services/multi_tenant_auth_service.dart';
import 'lib/services/database_service.dart';
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
    
    // Trigger comprehensive sync recovery
    await triggerComprehensiveSyncRecovery();
    
  } catch (e) {
    print('❌ Error during recovery: $e');
    exit(1);
  }
}

Future<void> triggerComprehensiveSyncRecovery() async {
  print('🚨 TRIGGERING COMPREHENSIVE SYNC RECOVERY...');
  
  try {
    // Get the unified sync service
    final syncService = UnifiedSyncService.instance;
    
    // Initialize the sync service
    await syncService.initialize();
    print('✅ Sync service initialized');
    
    // Force a comprehensive sync from Firebase
    print('🔄 Forcing comprehensive sync from Firebase...');
    await syncService.forceSync();
    print('✅ Comprehensive sync completed');
    
    // Perform manual sync to ensure everything is up to date
    print('🔄 Performing manual sync...');
    await syncService.manualSync();
    print('✅ Manual sync completed');
    
    print('\n🎉 DATA RECOVERY PROCESS COMPLETED!');
    print('   All available orders should now be restored from Firebase.');
    print('   Please check the app to verify your data has been recovered.');
    
  } catch (e) {
    print('❌ Error during sync recovery: $e');
    rethrow;
  }
} 