import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/services/order_reconstruction_service.dart';
import 'lib/services/database_service.dart';
import 'lib/services/order_service.dart';
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
    
    // Generate orders from order_items
    await generateOrdersFromItems();
    
  } catch (e) {
    print('❌ Error during initialization: $e');
    exit(1);
  }
}

Future<void> generateOrdersFromItems() async {
  print('\n🚀 GENERATING ORDERS FROM ORDER_ITEMS');
  print('=' * 60);
  
  try {
    final reconstructionService = OrderReconstructionService();
    final orderService = OrderService();
    
    // Step 1: Analyze the current state
    print('\n📊 STEP 1: ANALYZING ORDER_ITEMS TABLE');
    print('-' * 50);
    
    final analysis = await reconstructionService.analyzeOrderItems();
    
    print('Current Database State:');
    print('  📦 Total order items: ${analysis['totalOrderItems']}');
    print('  👻 Orphaned items (no orders): ${analysis['orphanedItems']}');
    print('  🔢 Unique order IDs in items: ${analysis['uniqueOrderIds']}');
    print('  📋 Existing orders: ${analysis['existingOrders']}');
    print('  🔄 Reconstructable orders: ${analysis['potentialReconstructableOrders']}');
    print('  ✅ Items with orders: ${analysis['itemsWithOrders']}');
    print('  🚨 Reconstruction needed: ${analysis['reconstructionNeeded']}');
    
    // Step 2: Show what will be generated
    if (analysis['reconstructionNeeded'] == true) {
      print('\n🔄 STEP 2: GENERATING ORDERS FROM ORPHANED ITEMS');
      print('-' * 50);
      
      print('Will generate ${analysis['potentialReconstructableOrders']} orders from ${analysis['orphanedItems']} orphaned items');
      
      // Ask for confirmation (in a real app, you might want user input)
      print('\n⚠️  This will create new orders from orphaned order_items.');
      print('   Continue? (This is an automated demo, proceeding...)');
      
      // Step 3: Perform the generation
      print('\n🏗️  STEP 3: CREATING ORDERS...');
      print('-' * 50);
      
      final result = await reconstructionService.performFullReconstruction();
      
      if (result['success'] == true) {
        final reconstructedCount = result['reconstructedOrders'] as int? ?? 0;
        print('✅ Successfully generated $reconstructedCount orders!');
        
        if (result['orders'] != null) {
          final orders = result['orders'] as List;
          print('\n📋 Generated Orders:');
          print('-' * 30);
          
          for (int i = 0; i < orders.length; i++) {
            final order = orders[i];
            print('  ${i + 1}. Order: ${order.orderNumber}');
            print('     - Items: ${order.items.length}');
            print('     - Subtotal: \$${order.subtotal.toStringAsFixed(2)}');
            print('     - HST (13%): \$${order.hstAmount.toStringAsFixed(2)}');
            print('     - Total: \$${order.totalAmount.toStringAsFixed(2)}');
            print('     - Customer: ${order.customerName ?? 'Walk-in'}');
            print('     - Type: ${order.type.toString().split('.').last}');
            print('     - Status: ${order.status.toString().split('.').last}');
            print('     - Created: ${order.createdAt.toString().substring(0, 19)}');
            
            // Show items in this order
            print('     - Items:');
            for (final item in order.items) {
              print('       • ${item.menuItem.name} x${item.quantity} = \$${item.totalPrice.toStringAsFixed(2)}');
            }
            print('');
          }
        }
        
        // Step 4: Reload orders to verify
        print('\n🔄 STEP 4: VERIFYING GENERATED ORDERS');
        print('-' * 50);
        
        await orderService.loadOrders();
        final allOrders = orderService.allOrders;
        final activeOrders = orderService.activeOrders;
        final completedOrders = orderService.completedOrders;
        
        print('Order Service Status:');
        print('  📊 Total orders loaded: ${allOrders.length}');
        print('  🟢 Active orders: ${activeOrders.length}');
        print('  ✅ Completed orders: ${completedOrders.length}');
        
        // Show recently generated orders
        final recentOrders = allOrders.where((o) => o.orderNumber.startsWith('REC-')).toList();
        print('  🆕 Recently generated orders: ${recentOrders.length}');
        
      } else {
        print('❌ Order generation failed: ${result['message']}');
      }
      
    } else {
      print('\n✅ STEP 2: NO ORDER GENERATION NEEDED');
      print('-' * 50);
      print('All order items are already associated with existing orders.');
      print('No orphaned items found to generate orders from.');
    }
    
    // Step 5: Final summary
    print('\n📊 STEP 5: FINAL SUMMARY');
    print('-' * 50);
    
    final finalAnalysis = await reconstructionService.analyzeOrderItems();
    print('Final Database State:');
    print('  📦 Total order items: ${finalAnalysis['totalOrderItems']}');
    print('  👻 Orphaned items: ${finalAnalysis['orphanedItems']}');
    print('  📋 Total orders: ${finalAnalysis['existingOrders']}');
    print('  ✅ Data integrity: ${finalAnalysis['orphanedItems'] == 0 ? 'GOOD' : 'NEEDS ATTENTION'}');
    
    print('\n🎉 ORDER GENERATION FROM ORDER_ITEMS COMPLETE!');
    
    if (finalAnalysis['orphanedItems'] == 0) {
      print('✅ All order items now have corresponding orders.');
    } else {
      print('⚠️  ${finalAnalysis['orphanedItems']} orphaned items still remain.');
    }
    
  } catch (e) {
    print('❌ Error during order generation: $e');
    rethrow;
  }
}

// Helper function to demonstrate manual order creation from items
Future<void> demonstrateManualOrderCreation() async {
  print('\n🔧 BONUS: MANUAL ORDER CREATION EXAMPLE');
  print('-' * 50);
  
  try {
    final dbService = DatabaseService();
    final db = await dbService.database;
    
    if (db == null) {
      print('❌ Database not available');
      return;
    }
    
    // Example: Create a sample order with items
    print('Creating a sample order with items...');
    
    // This would be how you manually create orders from items
    final sampleOrderId = 'sample_${DateTime.now().millisecondsSinceEpoch}';
    
    // Insert sample order_items first
    await db.insert('order_items', {
      'id': 'item_1_$sampleOrderId',
      'order_id': sampleOrderId,
      'menu_item_id': 'sample_menu_item_1',
      'quantity': 2,
      'unit_price': 15.99,
      'total_price': 31.98,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    
    await db.insert('order_items', {
      'id': 'item_2_$sampleOrderId',
      'order_id': sampleOrderId,
      'menu_item_id': 'sample_menu_item_2',
      'quantity': 1,
      'unit_price': 8.50,
      'total_price': 8.50,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    
    print('✅ Sample order items created');
    print('   - Order ID: $sampleOrderId');
    print('   - Items: 2');
    print('   - Total value: \$40.48');
    
    // Now these items would be detected as "orphaned" and can be converted to an order
    print('\n💡 These items can now be converted to a complete order using:');
    print('   OrderReconstructionService().performFullReconstruction()');
    
  } catch (e) {
    print('❌ Error in manual demonstration: $e');
  }
} 