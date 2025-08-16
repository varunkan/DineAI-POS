import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/order.dart';
import '../models/menu_item.dart';
import '../services/database_service.dart';
import '../config/environment_config.dart';

/// Customer-facing API service for submitting orders from public app
/// This service allows customers to browse menus and submit orders from anywhere
class CustomerOrderApiService extends ChangeNotifier {
  static const String _logTag = '👥 CustomerOrderAPI';
  static CustomerOrderApiService? _instance;
  static CustomerOrderApiService get instance => _instance ??= CustomerOrderApiService._();
  
  CustomerOrderApiService._();
  
  final DatabaseService _databaseService = DatabaseService();
  final String _baseUrl = 'https://api.example.com'; // Default URL
  final String _restaurantName = 'Oh Bombay Milton';
  final Uuid _uuid = Uuid();
  
  // Available restaurants cache
  final Map<String, Map<String, dynamic>> _restaurantsCache = {};
  final Map<String, List<MenuItem>> _menuCache = {};
  DateTime? _lastCacheUpdate;
  
  /// Get list of available restaurants for public ordering
  Future<List<Map<String, dynamic>>> getAvailableRestaurants() async {
    debugPrint('$_logTag 🏪 Fetching available restaurants...');
    
    try {
      // Check cache freshness (update every 30 minutes)
      if (_lastCacheUpdate == null || 
          DateTime.now().difference(_lastCacheUpdate!).inMinutes > 30) {
        await _refreshRestaurantsCache();
      }
      
      return _restaurantsCache.values.toList();
    } catch (e) {
      debugPrint('$_logTag ❌ Error fetching restaurants: $e');
      return [];
    }
  }

  /// Get restaurant details and menu
  Future<Map<String, dynamic>?> getRestaurantDetails(String restaurantId) async {
    debugPrint('$_logTag 🍽️ Fetching restaurant details: $restaurantId');
    
    try {
      // Get restaurant info
      final restaurant = await _databaseService.getData('restaurants', restaurantId);
      if (restaurant == null) {
        debugPrint('$_logTag ❌ Restaurant not found: $restaurantId');
        return null;
      }
      
      // Get menu for this restaurant
      final menu = await _getRestaurantMenu(restaurantId);
      
      return {
        ...restaurant,
        'menu_items': menu.map((item) => item.toJson()).toList(),
        'is_open': _isRestaurantOpen(restaurant),
        'estimated_prep_time': _getEstimatedPrepTime(restaurant),
        'delivery_radius': restaurant['delivery_radius'] ?? 5.0,
        'minimum_order': restaurant['minimum_order'] ?? 15.0,
        'accepts_online_orders': restaurant['accepts_online_orders'] ?? true,
      };
    } catch (e) {
      debugPrint('$_logTag ❌ Error fetching restaurant details: $e');
      return null;
    }
  }

  /// Submit a new order from customer
  Future<Map<String, dynamic>> submitOrder({
    required String restaurantId,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    String? customerAddress,
    required String orderType, // 'pickup', 'delivery', 'dine_in'
    required List<Map<String, dynamic>> items,
    String? specialInstructions,
    String? tableId, // For dine-in orders
    required double subtotal,
    required double taxAmount,
    required double totalAmount,
    String? paymentMethod,
    String? promoCode,
    Map<String, dynamic>? customerLocation,
  }) async {
    debugPrint('$_logTag 📝 Submitting new order for: $customerName');
    
    try {
      // Validate restaurant is accepting orders
      final restaurant = await _databaseService.getData('restaurants', restaurantId);
      if (restaurant == null || !(restaurant['accepts_online_orders'] ?? true)) {
        throw Exception('Restaurant is not accepting online orders at this time');
      }
      
      // Validate minimum order amount
      final minimumOrder = restaurant['minimum_order'] ?? 0.0;
      if (totalAmount < minimumOrder) {
        throw Exception('Order total \$${totalAmount.toStringAsFixed(2)} is below minimum \$${minimumOrder.toStringAsFixed(2)}');
      }
      
      // Generate order ID and number
      final orderId = _uuid.v4();
      final orderNumber = await _generatePublicOrderNumber(restaurantId);
      
      // Create order data
      final orderData = {
        'id': orderId,
        'order_number': orderNumber,
        'restaurant_id': restaurantId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_email': customerEmail,
        'customer_address': customerAddress,
        'customer_location': customerLocation,
        'type': orderType,
        'table_id': tableId,
        'items': items,
        'special_instructions': specialInstructions,
        'subtotal': subtotal,
        'tax_amount': taxAmount,
        'total_amount': totalAmount,
        'payment_method': paymentMethod,
        'payment_status': 'pending',
        'promo_code': promoCode,
        'status': 'submitted',
        'status_message': 'Order submitted successfully',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'estimated_ready_time': _calculateEstimatedReadyTime(restaurant, items),
        'app_version': '1.0.0',
        'source': 'public_customer_app',
      };
      
      // Save order to cloud database
      await _databaseService.saveData('public_orders_$restaurantId', orderId, orderData);
      
      // Send confirmation notification (if available)
      await _sendOrderConfirmation(orderData);
      
      debugPrint('$_logTag ✅ Order submitted successfully: $orderNumber');
      
      return {
        'success': true,
        'order_id': orderId,
        'order_number': orderNumber,
        'estimated_ready_time': orderData['estimated_ready_time'],
        'message': 'Your order has been submitted successfully!',
        'tracking_info': {
          'restaurant_name': restaurant['name'],
          'restaurant_phone': restaurant['phone'],
          'order_status': 'submitted',
          'estimated_prep_time': orderData['estimated_ready_time'],
        }
      };
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error submitting order: $e');
      
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to submit order. Please try again.',
      };
    }
  }

  /// Get order status for customer tracking
  Future<Map<String, dynamic>?> getOrderStatus(String restaurantId, String orderId) async {
    try {
      final orderData = await _databaseService.getData('public_orders_$restaurantId', orderId);
      
      if (orderData == null) {
        return null;
      }
      
      return {
        'order_id': orderId,
        'order_number': orderData['order_number'],
        'status': orderData['status'],
        'status_message': orderData['status_message'],
        'created_at': orderData['created_at'],
        'estimated_ready_time': orderData['estimated_ready_time'],
        'restaurant_processed_at': orderData['restaurant_processed_at'],
        'total_amount': orderData['total_amount'],
        'payment_status': orderData['payment_status'],
      };
    } catch (e) {
      debugPrint('$_logTag ❌ Error getting order status: $e');
      return null;
    }
  }

  /// Search nearby restaurants
  Future<List<Map<String, dynamic>>> searchNearbyRestaurants({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    String? cuisine,
    bool? isOpen,
  }) async {
    debugPrint('$_logTag 🔍 Searching nearby restaurants...');
    
    try {
      final allRestaurants = await getAvailableRestaurants();
      final nearbyRestaurants = <Map<String, dynamic>>[];
      
      for (final restaurant in allRestaurants) {
        // Calculate distance if coordinates are available
        if (restaurant['latitude'] != null && restaurant['longitude'] != null) {
          final distance = _calculateDistance(
            latitude, 
            longitude, 
            restaurant['latitude'], 
            restaurant['longitude']
          );
          
          if (distance <= radiusKm) {
            // Apply filters
            bool matchesCriteria = true;
            
            if (cuisine != null && restaurant['cuisine'] != cuisine) {
              matchesCriteria = false;
            }
            
            if (isOpen != null && _isRestaurantOpen(restaurant) != isOpen) {
              matchesCriteria = false;
            }
            
            if (matchesCriteria) {
              nearbyRestaurants.add({
                ...restaurant,
                'distance_km': double.parse(distance.toStringAsFixed(2)),
              });
            }
          }
        }
      }
      
      // Sort by distance
      nearbyRestaurants.sort((a, b) => 
        (a['distance_km'] as double).compareTo(b['distance_km'] as double)
      );
      
      debugPrint('$_logTag 🎯 Found ${nearbyRestaurants.length} nearby restaurants');
      return nearbyRestaurants;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error searching nearby restaurants: $e');
      return [];
    }
  }

  /// Private helper methods
  
  /// Refresh restaurants cache
  Future<void> _refreshRestaurantsCache() async {
    try {
      // Get all restaurant data from cloud
      final restaurantsData = await _databaseService.getAllData('restaurants');
      
      _restaurantsCache.clear();
      for (final data in restaurantsData) {
        if (data['accepts_online_orders'] == true) {
          _restaurantsCache[data['id']] = data;
        }
      }
      
      _lastCacheUpdate = DateTime.now();
      debugPrint('$_logTag 🔄 Refreshed restaurant cache: ${_restaurantsCache.length} restaurants');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error refreshing restaurant cache: $e');
    }
  }

  /// Get restaurant menu
  Future<List<MenuItem>> _getRestaurantMenu(String restaurantId) async {
    try {
      // Check cache first
      if (_menuCache.containsKey(restaurantId)) {
        return _menuCache[restaurantId]!;
      }
      
      // Load from database
      final menuData = await _databaseService.getAllData('menu_items_$restaurantId');
      final menuItems = menuData
          .map((data) => MenuItem.fromJson(data))
          .where((item) => item.isAvailable)
          .toList();
      
      // Cache the menu
      _menuCache[restaurantId] = menuItems;
      
      return menuItems;
    } catch (e) {
      debugPrint('$_logTag ❌ Error loading restaurant menu: $e');
      return [];
    }
  }

  /// Check if restaurant is open
  bool _isRestaurantOpen(Map<String, dynamic> restaurant) {
    try {
      final openingHours = restaurant['opening_hours'] as Map<String, dynamic>?;
      if (openingHours == null) return true; // Assume open if no hours specified
      
      final now = DateTime.now();
      final dayOfWeek = _getDayOfWeek(now.weekday);
      final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      final dayHours = openingHours[dayOfWeek] as Map<String, dynamic>?;
      if (dayHours == null || dayHours['closed'] == true) return false;
      
      final openTime = dayHours['open'] as String?;
      final closeTime = dayHours['close'] as String?;
      
      if (openTime == null || closeTime == null) return true;
      
      return _isTimeBetween(currentTime, openTime, closeTime);
    } catch (e) {
      debugPrint('$_logTag ❌ Error checking restaurant hours: $e');
      return true; // Assume open on error
    }
  }

  /// Get estimated preparation time
  String _getEstimatedPrepTime(Map<String, dynamic> restaurant) {
    final baseTime = restaurant['avg_prep_time_minutes'] ?? 25;
    final now = DateTime.now();
    
    // Add extra time during peak hours
    final isLunchRush = now.hour >= 11 && now.hour <= 14;
    final isDinnerRush = now.hour >= 17 && now.hour <= 21;
    
    int estimatedMinutes = baseTime;
    if (isLunchRush || isDinnerRush) {
      estimatedMinutes += 10; // Add 10 minutes during rush
    }
    
    final readyTime = now.add(Duration(minutes: estimatedMinutes));
    return '${readyTime.hour.toString().padLeft(2, '0')}:${readyTime.minute.toString().padLeft(2, '0')}';
  }

  /// Generate public order number
  Future<String> _generatePublicOrderNumber(String restaurantId) async {
    try {
      final todayOrders = await _databaseService.getAllData('public_orders_$restaurantId');
      final today = DateTime.now();
      final todayString = '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
      
      // Count orders from today
      int todayCount = 0;
      for (final order in todayOrders) {
        final createdAt = DateTime.parse(order['created_at']);
        if (createdAt.day == today.day && 
            createdAt.month == today.month && 
            createdAt.year == today.year) {
          todayCount++;
        }
      }
      
      return 'PUB-$todayString-${(todayCount + 1).toString().padLeft(3, '0')}';
    } catch (e) {
      debugPrint('$_logTag ❌ Error generating order number: $e');
      return 'PUB-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Calculate estimated ready time
  String _calculateEstimatedReadyTime(Map<String, dynamic> restaurant, List<Map<String, dynamic>> items) {
    int totalPrepTime = restaurant['avg_prep_time_minutes'] ?? 25;
    
    // Add time based on number of items
    if (items.length > 5) {
      totalPrepTime += 5;
    }
    
    // Add time for complex items (if you have item complexity data)
    for (final item in items) {
      final complexity = item['complexity'] ?? 'normal';
      if (complexity == 'complex') {
        totalPrepTime += 3;
      }
    }
    
    // Add time during peak hours
    final now = DateTime.now();
    final isPeakHour = (now.hour >= 11 && now.hour <= 14) || (now.hour >= 17 && now.hour <= 21);
    if (isPeakHour) {
      totalPrepTime += 10;
    }
    
    final readyTime = now.add(Duration(minutes: totalPrepTime));
    return readyTime.toIso8601String();
  }

  /// Send order confirmation (placeholder - implement with your notification system)
  Future<void> _sendOrderConfirmation(Map<String, dynamic> orderData) async {
    try {
      // TODO: Implement SMS/Email/Push notification
      debugPrint('$_logTag 📱 Order confirmation sent for: ${orderData['order_number']}');
    } catch (e) {
      debugPrint('$_logTag ❌ Error sending confirmation: $e');
    }
  }

  /// Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double lat1Rad = _degreesToRadians(lat1);
    final double lat2Rad = _degreesToRadians(lat2);
    
    final double a = 
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * 
        sin(dLon / 2) * sin(dLon / 2);
    
    final double c = 2 * asin(sqrt(a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }

  /// Utility methods
  String _getDayOfWeek(int weekday) {
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return days[weekday - 1];
  }

  bool _isTimeBetween(String current, String start, String end) {
    final currentMinutes = _timeToMinutes(current);
    final startMinutes = _timeToMinutes(start);
    final endMinutes = _timeToMinutes(end);
    
    if (endMinutes < startMinutes) {
      // Crosses midnight
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    } else {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    }
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
} 