import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/services/order_service.dart';
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
    
    // Trigger order generation
    await triggerOrderGeneration();
    
  } catch (e) {
    print('❌ Error during initialization: $e');
    exit(1);
  }
}

Future<void> triggerOrderGeneration() async {
  print('\n🚀 TRIGGERING ORDER GENERATION FROM ORDER_ITEMS');
  print('=' * 60);
  
  try {
    // Method 1: Using OrderService (Recommended)
    print('\n📋 METHOD 1: Using OrderService.generateOrdersFromItems()');
    print('-' * 50);
    
    final orderService = OrderService();
    final result = await orderService.generateOrdersFromItems();
    
    print('Result: ${result['success'] ? '✅ SUCCESS' : '❌ FAILED'}');
    print('Message: ${result['message']}');
    print('Generated Orders: ${result['generated']}');
    
    if (result['analysis'] != null) {
      final analysis = result['analysis'] as Map<String, dynamic>;
      print('\nAnalysis Details:');
      print('  📦 Total order items: ${analysis['totalOrderItems']}');
      print('  👻 Orphaned items: ${analysis['orphanedItems']}');
      print('  🔢 Unique order IDs: ${analysis['uniqueOrderIds']}');
      print('  📋 Existing orders: ${analysis['existingOrders']}');
      print('  🔄 Potential orders: ${analysis['potentialReconstructableOrders']}');
      print('  🚨 Reconstruction needed: ${analysis['reconstructionNeeded']}');
    }
    
    // Method 2: Direct OrderReconstructionService (Alternative)
    print('\n📋 METHOD 2: Using OrderReconstructionService directly');
    print('-' * 50);
    
    final reconstructionService = OrderReconstructionService();
    
    // First analyze
    final analysis = await reconstructionService.analyzeOrderItems();
    print('Direct Analysis:');
    print('  📦 Total items: ${analysis['totalOrderItems']}');
    print('  👻 Orphaned: ${analysis['orphanedItems']}');
    print('  🔄 Can reconstruct: ${analysis['potentialReconstructableOrders']}');
    
    if (analysis['reconstructionNeeded'] == true) {
      print('\n🏗️ Performing direct reconstruction...');
      final directResult = await reconstructionService.performFullReconstruction();
      
      print('Direct Result: ${directResult['success'] ? '✅ SUCCESS' : '❌ FAILED'}');
      print('Direct Message: ${directResult['message']}');
      print('Direct Generated: ${directResult['reconstructedOrders']}');
    } else {
      print('✅ No direct reconstruction needed');
    }
    
    // Method 3: Check final state
    print('\n📊 FINAL STATE CHECK');
    print('-' * 50);
    
    await orderService.loadOrders();
    final allOrders = orderService.allOrders;
    final reconstructedOrders = allOrders.where((o) => o.orderNumber.startsWith('REC-')).toList();
    
    print('Total orders in system: ${allOrders.length}');
    print('Reconstructed orders: ${reconstructedOrders.length}');
    
    if (reconstructedOrders.isNotEmpty) {
      print('\n🆕 Recently Generated Orders:');
      for (int i = 0; i < reconstructedOrders.length && i < 5; i++) {
        final order = reconstructedOrders[i];
        print('  ${i + 1}. ${order.orderNumber}');
        print('     - Items: ${order.items.length}');
        print('     - Total: \$${order.totalAmount.toStringAsFixed(2)}');
        print('     - Customer: ${order.customerName}');
        print('     - Status: ${order.status.toString().split('.').last}');
        print('     - Created: ${order.createdAt.toString().substring(0, 19)}');
      }
    }
    
    print('\n🎉 ORDER GENERATION PROCESS COMPLETED!');
    
  } catch (e) {
    print('❌ Error during order generation: $e');
    rethrow;
  }
}

// Helper function to create sample orphaned items for testing
Future<void> createSampleOrphanedItems() async {
  print('\n🧪 CREATING SAMPLE ORPHANED ITEMS FOR TESTING');
  print('-' * 50);
  
  try {
    final dbService = DatabaseService();
    final db = await dbService.database;
    
    if (db == null) {
      print('❌ Database not available');
      return;
    }
    
    final sampleOrderId = 'test_${DateTime.now().millisecondsSinceEpoch}';
    
    // Create sample orphaned order_items
    final sampleItems = [
      {
        'id': 'item_1_$sampleOrderId',
        'order_id': sampleOrderId,
        'menu_item_id': 'sample_burger',
        'quantity': 2,
        'unit_price': 15.99,
        'total_price': 31.98,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'item_2_$sampleOrderId',
        'order_id': sampleOrderId,
        'menu_item_id': 'sample_fries',
        'quantity': 1,
        'unit_price': 4.99,
        'total_price': 4.99,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'item_3_$sampleOrderId',
        'order_id': sampleOrderId,
        'menu_item_id': 'sample_drink',
        'quantity': 2,
        'unit_price': 2.99,
        'total_price': 5.98,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    ];
    
    for (final item in sampleItems) {
      await db.insert('order_items', item);
    }
    
    print('✅ Created ${sampleItems.length} sample orphaned items');
    print('   Order ID: $sampleOrderId');
    print('   Total Value: \$${sampleItems.fold(0.0, (sum, item) => sum + (item['total_price'] as double))}');
    print('   These items can now be converted to a complete order');
    
  } catch (e) {
    print('❌ Error creating sample items: $e');
  }
} 