import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() async {
  try {
    print('🔍 Analyzing ghost orders (orders with \$0 total)...');
    
    // Connect to the database
    final dbPath = join(await getDatabasesPath(), 'ai_pos_database.db');
    final database = await openDatabase(dbPath);
    
    // Count total orders
    final totalResult = await database.rawQuery('SELECT COUNT(*) as count FROM orders');
    final totalOrders = totalResult.first['count'] as int;
    
    // Count ghost orders (total_amount = 0 or NULL)
    final ghostResult = await database.rawQuery('''
      SELECT COUNT(*) as count FROM orders 
      WHERE total_amount IS NULL OR total_amount = 0 OR total_amount = 0.0
    ''');
    final ghostOrders = ghostResult.first['count'] as int;
    
    // Count orders with empty items
    final emptyItemsResult = await database.rawQuery('''
      SELECT COUNT(*) as count FROM orders 
      WHERE items IS NULL OR TRIM(items) = '' OR TRIM(items) = '[]'
    ''');
    final emptyItemsOrders = emptyItemsResult.first['count'] as int;
    
    // Count orders with both zero total AND empty items
    final bothResult = await database.rawQuery('''
      SELECT COUNT(*) as count FROM orders 
      WHERE (total_amount IS NULL OR total_amount = 0 OR total_amount = 0.0)
      AND (items IS NULL OR TRIM(items) = '' OR TRIM(items) = '[]')
    ''');
    final bothIssues = bothResult.first['count'] as int;
    
    // Get sample ghost orders
    final sampleResult = await database.rawQuery('''
      SELECT order_number, total_amount, subtotal, status, created_at, items
      FROM orders 
      WHERE total_amount IS NULL OR total_amount = 0 OR total_amount = 0.0
      LIMIT 10
    ''');
    
    print('\n📊 GHOST ORDERS ANALYSIS:');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📦 Total orders in database: $totalOrders');
    print('👻 Ghost orders (\$0 total): $ghostOrders');
    print('📝 Orders with empty items: $emptyItemsOrders');
    print('💀 Orders with BOTH issues: $bothIssues');
    print('📈 Ghost order percentage: ${(ghostOrders / totalOrders * 100).toStringAsFixed(1)}%');
    
    if (sampleResult.isNotEmpty) {
      print('\n🔍 SAMPLE GHOST ORDERS:');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      for (final row in sampleResult) {
        final orderNumber = row['order_number'];
        final totalAmount = row['total_amount'];
        final status = row['status'];
        final createdAt = row['created_at'];
        final items = row['items'];
        final itemsLength = items?.toString().length ?? 0;
        print('📦 $orderNumber | \$$totalAmount | $status | $createdAt | items: ${itemsLength}chars');
      }
    }
    
    await database.close();
    print('\n✅ Analysis complete!');
    
  } catch (e) {
    print('❌ Error analyzing ghost orders: $e');
    exit(1);
  }
} 