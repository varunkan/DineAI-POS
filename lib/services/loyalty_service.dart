import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/models/customer.dart';
import 'package:ai_pos_system/models/loyalty_transaction.dart';
import 'package:ai_pos_system/models/loyalty_reward.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:uuid/uuid.dart';

/// Customer loyalty and engagement service
class LoyaltyService extends ChangeNotifier {
  final DatabaseService _databaseService;
  
  // Loyalty program configuration
  static const int _pointsPerDollar = 1;
  static const int _pointsForRedemption = 100;
  static const double _redemptionValue = 10.0;
  
  LoyaltyService(this._databaseService);

  /// Register new customer or update existing
  Future<Map<String, dynamic>> registerCustomer({
    required String phone,
    String? name,
    String? email,
    DateTime? birthday,
  }) async {
    try {
      final db = await _databaseService.database;
      if (db == null) throw Exception('Database not available');
      
      // Check if customer exists
      final existing = await db.query(
        'customers',
        where: 'phone = ?',
        whereArgs: [phone],
      );
      
      if (existing.isNotEmpty) {
        // Update existing customer
        await db.update(
          'customers',
          {
            'name': name ?? existing.first['name'],
            'email': email ?? existing.first['email'],
            'birthday': birthday?.toIso8601String() ?? existing.first['birthday'],
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'phone = ?',
          whereArgs: [phone],
        );
        
        return await getCustomerProfile(phone);
      } else {
        // Create new customer
        final customerId = DateTime.now().millisecondsSinceEpoch.toString();
        await db.insert('customers', {
          'id': customerId,
          'phone': phone,
          'name': name,
          'email': email,
          'birthday': birthday?.toIso8601String(),
          'loyalty_points': 0,
          'total_spent': 0.0,
          'visit_count': 0,
          'tier': 'Bronze',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        
        return await getCustomerProfile(phone);
      }
    } catch (e) {
      debugPrint('Error registering customer: $e');
      rethrow;
    }
  }

  /// Get customer profile with loyalty info
  Future<Map<String, dynamic>> getCustomerProfile(String phone) async {
    try {
      final db = await _databaseService.database;
      if (db == null) throw Exception('Database not available');
      
      final customers = await db.query(
        'customers',
        where: 'phone = ?',
        whereArgs: [phone],
      );
      
      if (customers.isEmpty) {
        throw Exception('Customer not found');
      }
      
      final customer = customers.first;
      
      // Get recent orders
      final recentOrders = await db.query(
        'orders',
        where: 'customer_phone = ? AND status = ?',
        whereArgs: [phone, 'completed'],
        orderBy: 'created_at DESC',
        limit: 5,
      );
      
      // Get favorite items
      final favoriteItems = await _getFavoriteItems(phone);
      
      // Calculate next tier requirements
      final tierInfo = _calculateTierInfo(customer);
      
      return {
        'customer': customer,
        'recent_orders': recentOrders,
        'favorite_items': favoriteItems,
        'tier_info': tierInfo,
        'redemption_options': _getRedemptionOptions((customer['loyalty_points'] ?? 0) as int),
      };
    } catch (e) {
      debugPrint('Error getting customer profile: $e');
      rethrow;
    }
  }

  /// Award loyalty points for completed order
  Future<void> awardPoints(String phone, double orderAmount) async {
    try {
      final db = await _databaseService.database;
      if (db == null) throw Exception('Database not available');
      
      final pointsEarned = (orderAmount * _pointsPerDollar).round();
      
      await db.rawUpdate('''
        UPDATE customers 
        SET 
          loyalty_points = loyalty_points + ?,
          total_spent = total_spent + ?,
          visit_count = visit_count + 1,
          last_visit = ?,
          updated_at = ?
        WHERE phone = ?
      ''', [
        pointsEarned,
        orderAmount,
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
        phone,
      ]);
      
      // Update tier if necessary
      await _updateCustomerTier(phone);
      
      // Log points transaction
      await _logPointsTransaction(phone, pointsEarned, 'earned', 'Order completion');
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error awarding points: $e');
      rethrow;
    }
  }

  /// Redeem loyalty points
  Future<Map<String, dynamic>> redeemPoints(String phone, int pointsToRedeem) async {
    try {
      final db = await _databaseService.database;
      if (db == null) throw Exception('Database not available');
      
      final customers = await db.query(
        'customers',
        where: 'phone = ?',
        whereArgs: [phone],
      );
      
      if (customers.isEmpty) {
        throw Exception('Customer not found');
      }
      
      final customer = customers.first;
      final currentPoints = (customer['loyalty_points'] ?? 0) as int;
      
      if (currentPoints < pointsToRedeem) {
        throw Exception('Insufficient points');
      }
      
      final discountAmount = (pointsToRedeem / _pointsForRedemption) * _redemptionValue;
      
      await db.rawUpdate('''
        UPDATE customers 
        SET 
          loyalty_points = loyalty_points - ?,
          updated_at = ?
        WHERE phone = ?
      ''', [
        pointsToRedeem,
        DateTime.now().toIso8601String(),
        phone,
      ]);
      
      // Log points transaction
      await _logPointsTransaction(phone, pointsToRedeem, 'redeemed', 'Discount applied');
      
      notifyListeners();
      
      return {
        'discount_amount': discountAmount,
        'points_redeemed': pointsToRedeem,
        'remaining_points': currentPoints - pointsToRedeem,
      };
    } catch (e) {
      debugPrint('Error redeeming points: $e');
      rethrow;
    }
  }

  /// Get customer favorites
  Future<List<Map<String, dynamic>>> _getFavoriteItems(String phone) async {
    final db = await _databaseService.database;
    if (db == null) return [];
    
    return await db.rawQuery('''
      SELECT 
        mi.id,
        mi.name,
        mi.price,
        COUNT(oi.id) as order_count,
        SUM(oi.quantity) as total_quantity
      FROM menu_items mi
      JOIN order_items oi ON mi.id = oi.menu_item_id
      JOIN orders o ON oi.order_id = o.id
      WHERE o.customer_phone = ? AND o.status = 'completed'
      GROUP BY mi.id, mi.name, mi.price
      ORDER BY order_count DESC, total_quantity DESC
      LIMIT 5
    ''', [phone]);
  }

  /// Calculate tier information
  Map<String, dynamic> _calculateTierInfo(Map<String, dynamic> customer) {
    final totalSpent = (customer['total_spent'] ?? 0.0).toDouble();
    
    String currentTier;
    String nextTier;
    double nextTierRequirement;
    double progress;
    
    if (totalSpent >= 1000) {
      currentTier = 'Platinum';
      nextTier = 'Platinum';
      nextTierRequirement = 1000;
      progress = 1.0;
    } else if (totalSpent >= 500) {
      currentTier = 'Gold';
      nextTier = 'Platinum';
      nextTierRequirement = 1000;
      progress = totalSpent / 1000;
    } else if (totalSpent >= 200) {
      currentTier = 'Silver';
      nextTier = 'Gold';
      nextTierRequirement = 500;
      progress = totalSpent / 500;
    } else {
      currentTier = 'Bronze';
      nextTier = 'Silver';
      nextTierRequirement = 200;
      progress = totalSpent / 200;
    }
    
    return {
      'current_tier': currentTier,
      'next_tier': nextTier,
      'next_tier_requirement': nextTierRequirement,
      'progress': progress,
      'benefits': _getTierBenefits(currentTier),
    };
  }

  /// Get tier benefits
  List<String> _getTierBenefits(String tier) {
    switch (tier) {
      case 'Platinum':
        return [
          '20% birthday discount',
          'Free delivery',
          'Priority seating',
          'Exclusive menu items',
          'Personal chef consultation',
        ];
      case 'Gold':
        return [
          '15% birthday discount',
          'Free appetizer monthly',
          'Priority reservations',
          'Special event invitations',
        ];
      case 'Silver':
        return [
          '10% birthday discount',
          'Free dessert on birthday',
          'Early access to new menu items',
        ];
      default:
        return [
          '5% birthday discount',
          'Welcome bonus points',
        ];
    }
  }

  /// Get redemption options
  List<Map<String, dynamic>> _getRedemptionOptions(int currentPoints) {
    final options = <Map<String, dynamic>>[];
    
    if (currentPoints >= 50) {
      options.add({
        'points': 50,
        'value': 5.0,
        'description': '\$5 off your order',
        'available': true,
      });
    }
    
    if (currentPoints >= 100) {
      options.add({
        'points': 100,
        'value': 10.0,
        'description': '\$10 off your order',
        'available': true,
      });
    }
    
    if (currentPoints >= 200) {
      options.add({
        'points': 200,
        'value': 25.0,
        'description': '\$25 off your order',
        'available': true,
      });
    }
    
    // Add unavailable options for reference
    if (currentPoints < 50) {
      options.add({
        'points': 50,
        'value': 5.0,
        'description': '\$5 off your order',
        'available': false,
      });
    }
    
    if (currentPoints < 100) {
      options.add({
        'points': 100,
        'value': 10.0,
        'description': '\$10 off your order',
        'available': false,
      });
    }
    
    return options;
  }

  /// Update customer tier
  Future<void> _updateCustomerTier(String phone) async {
    try {
      final profile = await getCustomerProfile(phone);
      final tierInfo = profile['tier_info'] as Map<String, dynamic>;
      final newTier = tierInfo['current_tier'] as String;
      
      final db = await _databaseService.database;
      if (db == null) return;
      await db.update(
        'customers',
        {'tier': newTier},
        where: 'phone = ?',
        whereArgs: [phone],
      );
    } catch (e) {
      debugPrint('Error updating customer tier: $e');
    }
  }

  /// Log points transaction
  Future<void> _logPointsTransaction(String phone, int points, String type, String description) async {
    try {
      final db = await _databaseService.database;
      if (db == null) return;
      
      await db.insert('loyalty_transactions', {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'customer_phone': phone,
        'points': points,
        'type': type, // 'earned' or 'redeemed'
        'description': description,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error logging points transaction: $e');
    }
  }

  /// Get loyalty analytics
  Future<Map<String, dynamic>> getLoyaltyAnalytics() async {
    try {
      final db = await _databaseService.database;
      if (db == null) throw Exception('Database not available');
      
      // Customer tier distribution
      final tierDistribution = await db.rawQuery('''
        SELECT tier, COUNT(*) as count
        FROM customers
        GROUP BY tier
      ''');
      
      // Points redemption trends
      final redemptionTrends = await db.rawQuery('''
        SELECT 
          DATE(created_at) as date,
          SUM(CASE WHEN type = 'redeemed' THEN points ELSE 0 END) as points_redeemed,
          SUM(CASE WHEN type = 'earned' THEN points ELSE 0 END) as points_earned
        FROM loyalty_transactions
        WHERE created_at >= date('now', '-30 days')
        GROUP BY DATE(created_at)
        ORDER BY date
      ''');
      
      // Top customers
      final topCustomers = await db.rawQuery('''
        SELECT 
          phone,
          name,
          total_spent,
          loyalty_points,
          tier,
          visit_count
        FROM customers
        ORDER BY total_spent DESC
        LIMIT 10
      ''');
      
      return {
        'tier_distribution': tierDistribution,
        'redemption_trends': redemptionTrends,
        'top_customers': topCustomers,
      };
    } catch (e) {
      debugPrint('Error getting loyalty analytics: $e');
      rethrow;
    }
  }

  Future<Customer?> getCustomerByPhone(String phone) async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        final List<Map<String, dynamic>> maps = await db.query(
          'customers',
          where: 'phone = ?',
          whereArgs: [phone],
        );
        
        if (maps.isNotEmpty) {
          return Customer.fromJson(maps.first);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting customer by phone: $e');
      return null;
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        await db.update(
          'customers',
          customer.toJson(),
          where: 'id = ?',
          whereArgs: [customer.id],
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating customer: $e');
    }
  }

  Future<void> createCustomer(Customer customer) async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        await db.insert('customers', customer.toJson());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error creating customer: $e');
    }
  }

  Future<List<Customer>> getTopCustomers({int limit = 10}) async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        final List<Map<String, dynamic>> maps = await db.query(
          'customers',
          orderBy: 'total_spent DESC',
          limit: limit,
        );
        
        return maps.map((map) => Customer.fromJson(map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting top customers: $e');
      return [];
    }
  }

  Future<List<Customer>> searchCustomers(String query) async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        final List<Map<String, dynamic>> maps = await db.query(
          'customers',
          where: 'name LIKE ? OR phone LIKE ? OR email LIKE ?',
          whereArgs: ['%$query%', '%$query%', '%$query%'],
          orderBy: 'name ASC',
        );
        
        return maps.map((map) => Customer.fromJson(map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error searching customers: $e');
      return [];
    }
  }

  Future<void> addLoyaltyPoints(String customerId, double points, String reason) async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        await db.rawUpdate('''
          UPDATE customers 
          SET loyalty_points = loyalty_points + ? 
          WHERE id = ?
        ''', [points, customerId]);
        
        // Add loyalty transaction record
        await _addLoyaltyTransaction(customerId, points, 'earned', reason);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error adding loyalty points: $e');
    }
  }

  Future<List<LoyaltyTransaction>> getLoyaltyHistory(String customerId) async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        final List<Map<String, dynamic>> maps = await db.query(
          'loyalty_transactions',
          where: 'customer_id = ?',
          whereArgs: [customerId],
          orderBy: 'created_at DESC',
        );
        
        return maps.map((map) => LoyaltyTransaction.fromJson(map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting loyalty history: $e');
      return [];
    }
  }

  Future<void> redeemLoyaltyPoints(String customerId, double points, String reason) async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        await db.rawUpdate('''
          UPDATE customers 
          SET loyalty_points = loyalty_points - ? 
          WHERE id = ? AND loyalty_points >= ?
        ''', [points, customerId, points]);
        
        // Add loyalty transaction record
        await _addLoyaltyTransaction(customerId, -points, 'redeemed', reason);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error redeeming loyalty points: $e');
    }
  }

  Future<Map<String, dynamic>> getLoyaltyStats() async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        final result = await db.rawQuery('''
          SELECT 
            COUNT(*) as total_customers,
            SUM(loyalty_points) as total_points,
            AVG(loyalty_points) as average_points
          FROM customers
        ''');
        
        if (result.isNotEmpty) {
          return result.first;
        }
      }
      return {
        'total_customers': 0,
        'total_points': 0.0,
        'average_points': 0.0,
      };
    } catch (e) {
      debugPrint('Error getting loyalty stats: $e');
      return {
        'total_customers': 0,
        'total_points': 0.0,
        'average_points': 0.0,
      };
    }
  }

  Future<void> updateCustomerFromOrder(Order order) async {
    if (order.customerPhone == null || order.customerPhone!.isEmpty) return;
    
    try {
      // Calculate points (1 point per dollar spent)
      final pointsEarned = order.totalAmount.floor().toDouble();
      
      // Get or create customer
      Customer? customer = await getCustomerByPhone(order.customerPhone!);
      
      if (customer == null) {
        // Create new customer
        customer = Customer(
          id: const Uuid().v4(),
          name: order.customerName ?? 'Customer',
          phone: order.customerPhone!,
          email: order.customerEmail,
          loyaltyPoints: pointsEarned,
          totalSpent: order.totalAmount,
          visitCount: 1,
          lastVisit: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await createCustomer(customer);
      } else {
        // Update existing customer
        final visitCount = customer.visitCount + 1;
        final updatedCustomer = Customer(
          id: customer.id,
          name: order.customerName ?? customer.name,
          phone: customer.phone,
          email: order.customerEmail ?? customer.email,
          loyaltyPoints: customer.loyaltyPoints + pointsEarned,
          totalSpent: customer.totalSpent + order.totalAmount,
          visitCount: visitCount,
          lastVisit: DateTime.now(),
          createdAt: customer.createdAt,
          updatedAt: DateTime.now(),
        );
        
        final db = await _databaseService.database;
        if (db != null) {
          await db.update(
            'customers',
            updatedCustomer.toJson(),
            where: 'id = ?',
            whereArgs: [customer.id],
          );
        }
      }
      
      // Add loyalty transaction
      await _addLoyaltyTransaction(
        customer.id,
        pointsEarned,
        'earned',
        'Order #${order.orderNumber}',
      );
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating customer from order: $e');
    }
  }

  Future<void> _addLoyaltyTransaction(
    String customerId,
    double points,
    String type,
    String description,
  ) async {
    try {
      final transaction = LoyaltyTransaction(
        id: const Uuid().v4(),
        customerId: customerId,
        points: points,
        type: type,
        description: description,
        createdAt: DateTime.now(),
      );
      
      final db = await _databaseService.database;
      if (db != null) {
        await db.insert('loyalty_transactions', transaction.toJson());
      }
    } catch (e) {
      debugPrint('Error adding loyalty transaction: $e');
    }
  }

  Future<List<LoyaltyReward>> getAvailableRewards() async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        final List<Map<String, dynamic>> maps = await db.rawQuery('''
          SELECT * FROM loyalty_rewards 
          WHERE is_active = 1 
          ORDER BY points_required ASC
        ''');
        
        return maps.map((map) => LoyaltyReward.fromJson(map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting available rewards: $e');
      return [];
    }
  }

  Future<List<LoyaltyReward>> getEligibleRewards(String customerId) async {
    try {
      final customer = await getCustomerByPhone(''); // This needs to be fixed
      if (customer == null) return [];
      
      final db = await _databaseService.database;
      if (db != null) {
        final List<Map<String, dynamic>> maps = await db.rawQuery('''
          SELECT * FROM loyalty_rewards 
          WHERE is_active = 1 AND points_required <= ?
          ORDER BY points_required ASC
        ''', [customer.loyaltyPoints]);
        
        return maps.map((map) => LoyaltyReward.fromJson(map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting eligible rewards: $e');
      return [];
    }
  }

  Future<bool> redeemReward(String customerId, String rewardId) async {
    try {
      final db = await _databaseService.database;
      if (db == null) return false;
      
      // Get reward details
      final rewardMaps = await db.rawQuery('''
        SELECT * FROM loyalty_rewards WHERE id = ? AND is_active = 1
      ''', [rewardId]);
      
      if (rewardMaps.isEmpty) return false;
      
      final reward = LoyaltyReward.fromJson(rewardMaps.first);
      
      // Check if customer has enough points
      final customerMaps = await db.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
      );
      
      if (customerMaps.isEmpty) return false;
      
      final customer = Customer.fromJson(customerMaps.first);
      
      if (customer.loyaltyPoints < reward.pointsRequired) {
        return false;
      }
      
      // Redeem points
      await redeemLoyaltyPoints(
        customerId,
        reward.pointsRequired,
        'Redeemed: ${reward.name}',
      );
      
      return true;
    } catch (e) {
      debugPrint('Error redeeming reward: $e');
      return false;
    }
  }
} 