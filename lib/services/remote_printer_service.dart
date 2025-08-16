import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/order.dart';

import 'printing_service.dart';

/// Remote Printer Service for Internet-based printing
/// Enables POS app to send orders to kitchen printers over the internet
class RemotePrinterService extends ChangeNotifier {
  static const String _logTag = '[RemotePrinterService]';
  
  // Cloud service configuration
  static const String _cloudServiceUrl = 'https://your-cloud-service.com/api/v1';
  static const String _apiKey = 'your-api-key-here'; // Replace with actual API key
  
  // Local printing service
  final PrintingService _printingService;
  
  // Service state
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isPolling = false;
  Timer? _pollingTimer;
  String? _restaurantId;
  String? _printerId;
  
  // Statistics
  int _ordersSent = 0;
  int _ordersReceived = 0;
  int _failedOrders = 0;
  DateTime? _lastActivity;
  
  // Pending orders queue for offline mode
  final List<Map<String, dynamic>> _pendingOrders = [];
  
  RemotePrinterService(this._printingService);
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isPolling => _isPolling;
  String? get restaurantId => _restaurantId;
  String? get printerId => _printerId;
  int get ordersSent => _ordersSent;
  int get ordersReceived => _ordersReceived;
  int get failedOrders => _failedOrders;
  DateTime? get lastActivity => _lastActivity;
  List<Map<String, dynamic>> get pendingOrders => List.unmodifiable(_pendingOrders);
  
  /// Initialize the remote printer service
  Future<bool> initialize(String restaurantId, String printerId) async {
    try {
      debugPrint('$_logTag 🚀 Initializing remote printer service...');
      
      _restaurantId = restaurantId;
      _printerId = printerId;
      
      // Test cloud connection
      final cloudConnected = await _testCloudConnection();
      if (!cloudConnected) {
        debugPrint('$_logTag ❌ Failed to connect to cloud service');
        return false;
      }
      
      // Register printer with cloud service
      final registered = await _registerPrinter();
      if (!registered) {
        debugPrint('$_logTag ❌ Failed to register printer with cloud service');
        return false;
      }
      
      // Start polling for orders
      _startPolling();
      
      _isInitialized = true;
      _isConnected = true;
      _lastActivity = DateTime.now();
      
      debugPrint('$_logTag ✅ Remote printer service initialized successfully');
      notifyListeners();
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error initializing remote printer service: $e');
      return false;
    }
  }
  
  /// Send order to remote printer via cloud
  Future<bool> sendOrderToRemotePrinter(Order order, String targetPrinterId) async {
    try {
      debugPrint('$_logTag 📤 Sending order ${order.id} to remote printer $targetPrinterId...');
      
      // Prepare order data
      final orderData = {
        'orderId': order.id,
        'restaurantId': _restaurantId,
        'targetPrinterId': targetPrinterId,
        'orderData': order.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
        'priority': _getOrderPriority(order),
      };
      
      // Send to cloud service
      final response = await http.post(
        Uri.parse('$_cloudServiceUrl/orders/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(orderData),
      );
      
      if (response.statusCode == 200) {
        _ordersSent++;
        _lastActivity = DateTime.now();
        debugPrint('$_logTag ✅ Order sent successfully to remote printer');
        notifyListeners();
        return true;
      } else {
        debugPrint('$_logTag ❌ Failed to send order: ${response.statusCode} - ${response.body}');
        
        // Add to pending queue for retry
        _pendingOrders.add(orderData);
        _failedOrders++;
        notifyListeners();
        return false;
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error sending order to remote printer: $e');
      
      // Add to pending queue for offline retry
      final orderData = {
        'orderId': order.id,
        'restaurantId': _restaurantId,
        'targetPrinterId': targetPrinterId,
        'orderData': order.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
        'priority': _getOrderPriority(order),
      };
      _pendingOrders.add(orderData);
      _failedOrders++;
      notifyListeners();
      return false;
    }
  }
  
  /// Start polling for incoming orders from cloud
  void _startPolling() {
    if (_isPolling) return;
    
    _isPolling = true;
    debugPrint('$_logTag 🔄 Starting order polling...');
    
    // Poll every 5 seconds for new orders
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _pollForOrders();
    });
  }
  
  /// Poll cloud service for new orders
  Future<void> _pollForOrders() async {
    if (!_isInitialized || !_isConnected) return;
    
    try {
      final response = await http.get(
        Uri.parse('$_cloudServiceUrl/orders/poll?printerId=$_printerId'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> orders = data['orders'] ?? [];
        
        // Process each order
        for (final orderData in orders) {
          await _processIncomingOrder(orderData);
        }
        
        // Acknowledge processed orders
        if (orders.isNotEmpty) {
          await _acknowledgeOrders(orders.map((o) => o['id'].toString()).toList());
        }
        
        // Retry pending orders
        if (_pendingOrders.isNotEmpty) {
          await _retryPendingOrders();
        }
        
      } else if (response.statusCode != 204) {
        debugPrint('$_logTag ⚠️ Polling failed: ${response.statusCode}');
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error polling for orders: $e');
    }
  }
  
  /// Process incoming order from cloud
  Future<void> _processIncomingOrder(Map<String, dynamic> orderData) async {
    try {
      debugPrint('$_logTag 📥 Processing incoming order: ${orderData['orderId']}');
      
      // Parse order data
      final order = Order.fromJson(orderData['orderData']);
      
      // Print order to local printer
      final printed = await _printingService.printKitchenTicket(order);
      
      if (printed) {
        _ordersReceived++;
        debugPrint('$_logTag 🖨️ Order printed successfully');
      } else {
        debugPrint('$_logTag ❌ Failed to print order');
      }
      
      _lastActivity = DateTime.now();
      notifyListeners();
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error processing incoming order: $e');
    }
  }
  
  /// Test connection to cloud service
  Future<bool> _testCloudConnection() async {
    try {
      debugPrint('$_logTag 🔍 Testing cloud connection...');
      
      final response = await http.get(
        Uri.parse('$_cloudServiceUrl/health'),
        headers: {'Authorization': 'Bearer $_apiKey'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        debugPrint('$_logTag ✅ Cloud connection successful');
        return true;
      } else {
        debugPrint('$_logTag ❌ Cloud connection failed: ${response.statusCode}');
        return false;
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Cloud connection error: $e');
      return false;
    }
  }
  
  /// Register printer with cloud service
  Future<bool> _registerPrinter() async {
    try {
      debugPrint('$_logTag 📝 Registering printer with cloud service...');
      
      final registrationData = {
        'printerId': _printerId,
        'restaurantId': _restaurantId,
        'printerType': 'kitchen',
        'capabilities': ['ESC/POS', 'thermal', '80mm'],
        'location': 'kitchen',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final response = await http.post(
        Uri.parse('$_cloudServiceUrl/printers/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(registrationData),
      );
      
      if (response.statusCode == 200) {
        debugPrint('$_logTag ✅ Printer registered successfully');
        return true;
      } else {
        debugPrint('$_logTag ❌ Printer registration failed: ${response.statusCode}');
        return false;
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error registering printer: $e');
      return false;
    }
  }
  
  /// Acknowledge processed orders
  Future<void> _acknowledgeOrders(List<String> orderIds) async {
    try {
      final response = await http.post(
        Uri.parse('$_cloudServiceUrl/orders/acknowledge'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'orderIds': orderIds,
          'printerId': _printerId,
        }),
      );
      
      if (response.statusCode != 200) {
        debugPrint('$_logTag ⚠️ Failed to acknowledge orders: ${response.statusCode}');
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error acknowledging orders: $e');
    }
  }
  
  /// Retry pending orders
  Future<void> _retryPendingOrders() async {
    if (_pendingOrders.isEmpty) return;
    
    debugPrint('$_logTag 🔄 Retrying ${_pendingOrders.length} pending orders...');
    
    final ordersToRetry = List<Map<String, dynamic>>.from(_pendingOrders);
    _pendingOrders.clear();
    
    for (final orderData in ordersToRetry) {
      final response = await http.post(
        Uri.parse('$_cloudServiceUrl/orders/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(orderData),
      );
      
      if (response.statusCode == 200) {
        _ordersSent++;
        debugPrint('$_logTag ✅ Retry successful for order ${orderData['orderId']}');
      } else {
        // Add back to pending queue
        _pendingOrders.add(orderData);
      }
    }
    
    notifyListeners();
  }
  
  /// Get order priority for cloud processing
  int _getOrderPriority(Order order) {
    // Higher priority for urgent orders
    if (order.isUrgent || order.specialInstructions?.toLowerCase().contains('urgent') == true) {
      return 1;
    }
    
    // Medium priority for dine-in orders
    if (order.type == OrderType.dineIn) {
      return 2;
    }
    
    // Lower priority for takeout orders
    return 3;
  }
  
  /// Stop polling and cleanup
  void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    _isInitialized = false;
    _isConnected = false;
    
    debugPrint('$_logTag 🛑 Remote printer service disposed');
    super.dispose();
  }
  
  /// Get service statistics
  Map<String, dynamic> getStatistics() {
    return {
      'ordersSent': _ordersSent,
      'ordersReceived': _ordersReceived,
      'failedOrders': _failedOrders,
      'pendingOrders': _pendingOrders.length,
      'lastActivity': _lastActivity?.toIso8601String(),
      'uptime': _isInitialized ? DateTime.now().difference(_lastActivity ?? DateTime.now()).inSeconds : 0,
      'isConnected': _isConnected,
      'isPolling': _isPolling,
    };
  }
  
  /// Manual sync trigger
  Future<void> manualSync() async {
    debugPrint('$_logTag 🔄 Manual sync triggered');
    await _pollForOrders();
  }
  
  /// Reset statistics
  void resetStatistics() {
    _ordersSent = 0;
    _ordersReceived = 0;
    _failedOrders = 0;
    _pendingOrders.clear();
    notifyListeners();
    debugPrint('$_logTag 📊 Statistics reset');
  }
  
  /// Validate restaurant code (for backward compatibility)
  Future<bool> validateRestaurantCode(String code) async {
    try {
      debugPrint('$_logTag 🔍 Validating restaurant code: $code');
      
      // For demo purposes, accept any 6-digit code
      // In production, this would validate against your cloud service
      if (code.length == 6 && RegExp(r'^\d{6}$').hasMatch(code)) {
        debugPrint('$_logTag ✅ Restaurant code validated successfully');
        return true;
      }
      
      debugPrint('$_logTag ❌ Invalid restaurant code format');
      return false;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error validating restaurant code: $e');
      return false;
    }
  }
  
  /// Test print connection (for backward compatibility)
  Future<bool> testPrintConnection(String restaurantCode, String printerName) async {
    try {
      debugPrint('$_logTag 🖨️ Testing print connection for $printerName...');
      
      // For demo purposes, simulate a successful test
      // In production, this would test the actual connection
      await Future.delayed(const Duration(seconds: 2));
      
      debugPrint('$_logTag ✅ Test print connection successful');
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Test print connection failed: $e');
      return false;
    }
  }
}

/// Printer Bridge Service - Runs on kitchen side
class PrinterBridgeService extends ChangeNotifier {
  static const String _logTag = '[PrinterBridgeService]';
  
  final RemotePrinterService _remotePrinterService;
  final PrintingService _printingService;
  
  bool _isRunning = false;
  String? _bridgeId;
  
  PrinterBridgeService(this._remotePrinterService, this._printingService);
  
  bool get isRunning => _isRunning;
  String? get bridgeId => _bridgeId;
  
  /// Start the printer bridge
  Future<bool> startBridge(String restaurantId, String printerId) async {
    try {
      debugPrint('$_logTag 🌉 Starting printer bridge...');
      
      _bridgeId = 'bridge_${restaurantId}_${printerId}';
      
      // Initialize remote printer service
      final initialized = await _remotePrinterService.initialize(restaurantId, printerId);
      if (!initialized) {
        debugPrint('$_logTag ❌ Failed to initialize remote printer service');
        return false;
      }
      
      _isRunning = true;
      debugPrint('$_logTag ✅ Printer bridge started successfully');
      notifyListeners();
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error starting printer bridge: $e');
      return false;
    }
  }
  
  /// Stop the printer bridge
  void stopBridge() {
    _isRunning = false;
    _bridgeId = null;
    _remotePrinterService.dispose();
    debugPrint('$_logTag 🛑 Printer bridge stopped');
    notifyListeners();
  }
} 