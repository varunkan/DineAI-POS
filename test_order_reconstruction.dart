import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/services/order_reconstruction_service.dart';
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
    
    // Run order reconstruction test
    await testOrderReconstruction();
    
  } catch (e) {
    print('❌ Error during initialization: $e');
    exit(1);
  }
}

Future<void> testOrderReconstruction() async {
  print('\n🚀 TESTING ORDER RECONSTRUCTION FROM ORDER_ITEMS');
  print('=' * 60);
  
  try {
    final reconstructionService = OrderReconstructionService();
    
    // Step 1: Analyze current state
    print('\n📊 STEP 1: ANALYZING ORDER_ITEMS TABLE');
    print('-' * 40);
    
    final analysis = await reconstructionService.analyzeOrderItems();
    
    print('Analysis Results:');
    print('  📦 Total order items: ${analysis['totalOrderItems']}');
    print('  👻 Orphaned items: ${analysis['orphanedItems']}');
    print('  🔢 Unique order IDs: ${analysis['uniqueOrderIds']}');
    print('  📋 Existing orders: ${analysis['existingOrders']}');
    print('  🔄 Potential reconstructable orders: ${analysis['potentialReconstructableOrders']}');
    print('  ✅ Items with orders: ${analysis['itemsWithOrders']}');
    print('  🚨 Reconstruction needed: ${analysis['reconstructionNeeded']}');
    
    // Step 2: Perform reconstruction if needed
    if (analysis['reconstructionNeeded'] == true) {
      print('\n🔄 STEP 2: RECONSTRUCTING ORDERS');
      print('-' * 40);
      
      final result = await reconstructionService.performFullReconstruction();
      
      if (result['success'] == true) {
        print('✅ ${result['message']}');
        print('📈 Orders reconstructed: ${result['reconstructedOrders']}');
        
        if (result['orders'] != null) {
          final orders = result['orders'] as List;
          print('\n📋 Reconstructed Orders:');
          for (int i = 0; i < orders.length; i++) {
            final order = orders[i];
            print('  ${i + 1}. ${order.orderNumber} - ${order.items.length} items - \$${order.totalAmount.toStringAsFixed(2)}');
          }
        }
      } else {
        print('❌ ${result['message']}');
      }
    } else {
      print('\n✅ STEP 2: NO RECONSTRUCTION NEEDED');
      print('-' * 40);
      print('All order items are properly associated with orders.');
    }
    
    // Step 3: Final analysis
    print('\n📊 STEP 3: FINAL ANALYSIS');
    print('-' * 40);
    
    final finalAnalysis = await reconstructionService.analyzeOrderItems();
    print('Final state:');
    print('  📦 Total order items: ${finalAnalysis['totalOrderItems']}');
    print('  👻 Orphaned items: ${finalAnalysis['orphanedItems']}');
    print('  📋 Total orders: ${finalAnalysis['existingOrders']}');
    
    print('\n🎉 ORDER RECONSTRUCTION TEST COMPLETE!');
    
  } catch (e) {
    print('❌ Error during order reconstruction test: $e');
    rethrow;
  }
} 