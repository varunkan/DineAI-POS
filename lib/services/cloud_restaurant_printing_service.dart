import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/order.dart';
import '../models/printer_configuration.dart';
import '../models/printer_assignment.dart';
import 'printing_service.dart';
import 'enhanced_printer_assignment_service.dart';

/// 🌐 Cloud Restaurant Printing Service
/// Enables printing from any POS app instance to restaurant printers over the internet
/// 
/// Architecture:
/// 1. POS App → Cloud Service → Restaurant Printer Bridge → Physical Printer
/// 2. Real-time order routing with automatic failover
/// 3. Secure, encrypted connections with authentication
/// 4. Offline queue with automatic retry
class CloudRestaurantPrintingService extends ChangeNotifier {
  static const String _logTag = '🌐 CloudRestaurantPrinting';
  
  // Cloud service configuration
  static const String _cloudServiceUrl = 'https://restaurant-print.cloud/api/v1';
  static const String _apiKey = 'your-restaurant-api-key'; // Replace with actual key
  static const String _restaurantId = 'your-restaurant-id'; // Replace with actual ID
  
  // Service dependencies
  final PrintingService _printingService;
  final EnhancedPrinterAssignmentService _assignmentService;
  
  // Service state
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isPolling = false;
  Timer? _pollingTimer;
  Timer? _retryTimer;
  Timer? _heartbeatTimer;
  
  // Connection management
  String? _sessionId;
  DateTime? _lastHeartbeat;
  int _connectionRetries = 0;
  static const int _maxRetries = 5;
  
  // Order queue management
  final List<Map<String, dynamic>> _pendingOrders = [];
  final List<Map<String, dynamic>> _failedOrders = [];
  final Map<String, DateTime> _orderTimestamps = {};
  
  // Statistics
  int _ordersSent = 0;
  int _ordersDelivered = 0;
  int _ordersFailed = 0;
  int _printersOnline = 0;
  Map<String, int> _printerSuccessCount = {};
  Map<String, int> _printerFailureCount = {};
  
  // Real-time status
  Map<String, bool> _printerStatus = {};
  Map<String, DateTime> _lastPrinterActivity = {};
  
  CloudRestaurantPrintingService({
    required PrintingService printingService,
    required EnhancedPrinterAssignmentService assignmentService,
  }) : _printingService = printingService,
       _assignmentService = assignmentService;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isPolling => _isPolling;
  String? get sessionId => _sessionId;
  DateTime? get lastHeartbeat => _lastHeartbeat;
  int get ordersSent => _ordersSent;
  int get ordersDelivered => _ordersDelivered;
  int get ordersFailed => _ordersFailed;
  int get printersOnline => _printersOnline;
  List<Map<String, dynamic>> get pendingOrders => List.unmodifiable(_pendingOrders);
  List<Map<String, dynamic>> get failedOrders => List.unmodifiable(_failedOrders);
  Map<String, bool> get printerStatus => Map.unmodifiable(_printerStatus);
  
  /// Initialize cloud printing service
  Future<bool> initialize() async {
    try {
      debugPrint('$_logTag 🚀 Initializing cloud restaurant printing service...');
      
      // Check internet connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        debugPrint('$_logTag ❌ No internet connection available');
        return false;
      }
      
      // Test cloud service connection
      final cloudConnected = await _testCloudConnection();
      if (!cloudConnected) {
        debugPrint('$_logTag ❌ Failed to connect to cloud service');
        return false;
      }
      
      // Register restaurant with cloud service
      final registered = await _registerRestaurant();
      if (!registered) {
        debugPrint('$_logTag ❌ Failed to register restaurant with cloud service');
        return false;
      }
      
      // Start service monitoring
      _startServiceMonitoring();
      
      _isInitialized = true;
      _isConnected = true;
      _lastHeartbeat = DateTime.now();
      
      debugPrint('$_logTag ✅ Cloud restaurant printing service initialized successfully');
      notifyListeners();
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error initializing cloud printing service: $e');
      return false;
    }
  }
  
  /// Send order to restaurant printers via cloud
  Future<Map<String, dynamic>> sendOrderToRestaurantPrinters({
    required Order order,
    required String userId,
    required String userName,
  }) async {
    try {
      debugPrint('$_logTag 📤 Sending order ${order.orderNumber} to restaurant printers...');
      
      // Get printer assignments for order items
      final itemsByPrinter = await _getItemsByPrinter(order);
      if (itemsByPrinter.isEmpty) {
        return {
          'success': false,
          'message': 'No printer assignments found for order items',
          'itemsSent': 0,
          'printerCount': 0,
        };
      }
      
      // Prepare order data for each printer
      final printJobs = <Map<String, dynamic>>[];
      
      for (final entry in itemsByPrinter.entries) {
        final printerId = entry.key;
        final items = entry.value;
        
        final printJob = {
          'orderId': order.id,
          'orderNumber': order.orderNumber,
          'restaurantId': _restaurantId,
          'targetPrinterId': printerId,
          'items': items.map((item) => {
            'id': item.id,
            'name': item.menuItem.name,
            'quantity': item.quantity,
            'variants': item.selectedVariant,
            'instructions': item.specialInstructions,
            'notes': item.notes,
          }).toList(),
          'orderData': {
            'tableId': order.tableId,
            'customerName': order.customerName,
            'userId': userId,
            'userName': userName,
            'orderTime': order.orderTime.toIso8601String(),
            'isUrgent': order.isUrgent,
            'priority': order.priority,
          },
          'timestamp': DateTime.now().toIso8601String(),
          'priority': _getOrderPriority(order),
          'sessionId': _sessionId,
        };
        
        printJobs.add(printJob);
      }
      
      // Send print jobs to cloud service
      final results = await Future.wait(
        printJobs.map((job) => _sendPrintJobToCloud(job)),
      );
      
      // Process results
      final successfulJobs = results.where((result) => result['success']).length;
      final totalJobs = results.length;
      
      _ordersSent += totalJobs;
      
      if (successfulJobs > 0) {
        _ordersDelivered += successfulJobs;
        debugPrint('$_logTag ✅ Successfully sent $successfulJobs/$totalJobs print jobs');
      } else {
        _ordersFailed += totalJobs;
        debugPrint('$_logTag ❌ All print jobs failed');
      }
      
      notifyListeners();
      
      return {
        'success': successfulJobs > 0,
        'message': _generateResultMessage(successfulJobs, totalJobs),
        'itemsSent': order.items.length,
        'printerCount': successfulJobs,
        'results': results,
      };
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error sending order to restaurant printers: $e');
      _ordersFailed += 1;
      notifyListeners();
      
      return {
        'success': false,
        'message': 'Failed to send order: ${e.toString()}',
        'itemsSent': 0,
        'printerCount': 0,
        'error': e.toString(),
      };
    }
  }
  
  /// Get items grouped by their assigned printers
  Future<Map<String, List<OrderItem>>> _getItemsByPrinter(Order order) async {
    final Map<String, List<OrderItem>> itemsByPrinter = {};
    
    for (final item in order.items) {
      // Skip items already sent to kitchen
      if (item.sentToKitchen) continue;
      
      final assignments = _assignmentService.getAssignmentsForMenuItem(
        item.menuItem.id,
        item.menuItem.categoryId ?? '',
      );
      
      if (assignments.isNotEmpty) {
        for (final assignment in assignments) {
          final printerId = assignment.printerId;
          itemsByPrinter.putIfAbsent(printerId, () => []).add(item);
        }
      }
    }
    
    return itemsByPrinter;
  }
  
  /// Send print job to cloud service
  Future<Map<String, dynamic>> _sendPrintJobToCloud(Map<String, dynamic> printJob) async {
    try {
      final response = await http.post(
        Uri.parse('$_cloudServiceUrl/print-jobs/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'X-Restaurant-ID': _restaurantId,
          'X-Session-ID': _sessionId ?? '',
        },
        body: json.encode(printJob),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'jobId': data['jobId'],
          'printerId': printJob['targetPrinterId'],
          'message': 'Print job queued successfully',
        };
      } else {
        debugPrint('$_logTag ❌ Failed to send print job: ${response.statusCode} - ${response.body}');
        
        // Add to pending queue for retry
        _pendingOrders.add(printJob);
        
        return {
          'success': false,
          'printerId': printJob['targetPrinterId'],
          'message': 'Failed to send print job: ${response.statusCode}',
          'error': response.body,
        };
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error sending print job: $e');
      
      // Add to pending queue for offline retry
      _pendingOrders.add(printJob);
      
      return {
        'success': false,
        'printerId': printJob['targetPrinterId'],
        'message': 'Network error: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }
  
  /// Start service monitoring (polling, retry, heartbeat)
  void _startServiceMonitoring() {
    // Start polling for printer status updates
    _startPolling();
    
    // Start retry mechanism for failed orders
    _startRetryMechanism();
    
    // Start heartbeat to maintain connection
    _startHeartbeat();
  }
  
  /// Start polling for printer status and order confirmations
  void _startPolling() {
    if (_isPolling) return;
    
    _isPolling = true;
    debugPrint('$_logTag 🔄 Starting status polling...');
    
    // Poll every 10 seconds for updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _pollForUpdates();
    });
  }
  
  /// Poll cloud service for updates
  Future<void> _pollForUpdates() async {
    if (!_isInitialized || !_isConnected) return;
    
    try {
      final response = await http.get(
        Uri.parse('$_cloudServiceUrl/status/poll?restaurantId=$_restaurantId'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'X-Session-ID': _sessionId ?? '',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Update printer status
        final printerStatus = data['printerStatus'] as Map<String, dynamic>?;
        if (printerStatus != null) {
          _updatePrinterStatus(printerStatus);
        }
        
        // Process order confirmations
        final confirmations = data['orderConfirmations'] as List<dynamic>?;
        if (confirmations != null) {
          await _processOrderConfirmations(confirmations);
        }
        
        // Process failed orders
        final failures = data['failedOrders'] as List<dynamic>?;
        if (failures != null) {
          await _processFailedOrders(failures);
        }
        
      } else if (response.statusCode != 204) {
        debugPrint('$_logTag ⚠️ Polling failed: ${response.statusCode}');
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error polling for updates: $e');
    }
  }
  
  /// Update printer status from cloud
  void _updatePrinterStatus(Map<String, dynamic> statusData) {
    int onlineCount = 0;
    
    for (final entry in statusData.entries) {
      final printerId = entry.key;
      final status = entry.value as Map<String, dynamic>;
      
      final isOnline = status['isOnline'] as bool? ?? false;
      final lastActivity = status['lastActivity'] as String?;
      
      _printerStatus[printerId] = isOnline;
      
      if (isOnline) {
        onlineCount++;
        if (lastActivity != null) {
          _lastPrinterActivity[printerId] = DateTime.parse(lastActivity);
        }
      }
    }
    
    _printersOnline = onlineCount;
    notifyListeners();
  }
  
  /// Process order confirmations from cloud
  Future<void> _processOrderConfirmations(List<dynamic> confirmations) async {
    for (final confirmation in confirmations) {
      final orderId = confirmation['orderId'] as String?;
      final printerId = confirmation['printerId'] as String?;
      final success = confirmation['success'] as bool? ?? false;
      
      if (orderId != null && printerId != null) {
        if (success) {
          _printerSuccessCount[printerId] = (_printerSuccessCount[printerId] ?? 0) + 1;
          debugPrint('$_logTag ✅ Order $orderId confirmed printed on $printerId');
        } else {
          _printerFailureCount[printerId] = (_printerFailureCount[printerId] ?? 0) + 1;
          debugPrint('$_logTag ❌ Order $orderId failed to print on $printerId');
        }
      }
    }
  }
  
  /// Process failed orders from cloud
  Future<void> _processFailedOrders(List<dynamic> failures) async {
    for (final failure in failures) {
      final orderId = failure['orderId'] as String?;
      final printerId = failure['printerId'] as String?;
      final error = failure['error'] as String?;
      
      if (orderId != null && printerId != null) {
        _failedOrders.add({
          'orderId': orderId,
          'printerId': printerId,
          'error': error ?? 'Unknown error',
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        debugPrint('$_logTag ❌ Order $orderId failed on $printerId: $error');
      }
    }
    
    notifyListeners();
  }
  
  /// Start retry mechanism for failed orders
  void _startRetryMechanism() {
    _retryTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _retryFailedOrders();
    });
  }
  
  /// Retry failed orders
  Future<void> _retryFailedOrders() async {
    if (_pendingOrders.isEmpty) return;
    
    debugPrint('$_logTag 🔄 Retrying ${_pendingOrders.length} failed orders...');
    
    final ordersToRetry = List<Map<String, dynamic>>.from(_pendingOrders);
    _pendingOrders.clear();
    
    for (final order in ordersToRetry) {
      final result = await _sendPrintJobToCloud(order);
      if (!result['success']) {
        _pendingOrders.add(order);
      }
    }
    
    notifyListeners();
  }
  
  /// Start heartbeat to maintain connection
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _sendHeartbeat();
    });
  }
  
  /// Send heartbeat to cloud service
  Future<void> _sendHeartbeat() async {
    try {
      final response = await http.post(
        Uri.parse('$_cloudServiceUrl/heartbeat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'X-Restaurant-ID': _restaurantId,
          'X-Session-ID': _sessionId ?? '',
        },
        body: json.encode({
          'timestamp': DateTime.now().toIso8601String(),
          'status': 'active',
          'pendingOrders': _pendingOrders.length,
          'failedOrders': _failedOrders.length,
        }),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        _lastHeartbeat = DateTime.now();
        _connectionRetries = 0;
      } else {
        _connectionRetries++;
        debugPrint('$_logTag ⚠️ Heartbeat failed: ${response.statusCode}');
      }
      
    } catch (e) {
      _connectionRetries++;
      debugPrint('$_logTag ❌ Heartbeat error: $e');
      
      if (_connectionRetries >= _maxRetries) {
        debugPrint('$_logTag ❌ Connection lost after $_maxRetries failed heartbeats');
        _isConnected = false;
        notifyListeners();
      }
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
  
  /// Register restaurant with cloud service
  Future<bool> _registerRestaurant() async {
    try {
      debugPrint('$_logTag 📝 Registering restaurant with cloud service...');
      
      final registrationData = {
        'restaurantId': _restaurantId,
        'name': 'Your Restaurant Name', // Replace with actual name
        'location': 'Your Restaurant Location', // Replace with actual location
        'printerCount': _assignmentService.assignments.length,
        'capabilities': ['thermal_printing', 'order_routing', 'real_time_status'],
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final response = await http.post(
        Uri.parse('$_cloudServiceUrl/restaurants/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(registrationData),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _sessionId = data['sessionId'] as String?;
        debugPrint('$_logTag ✅ Restaurant registered successfully');
        return true;
      } else {
        debugPrint('$_logTag ❌ Restaurant registration failed: ${response.statusCode}');
        return false;
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error registering restaurant: $e');
      return false;
    }
  }
  
  /// Get order priority for routing
  int _getOrderPriority(Order order) {
    if (order.isUrgent) return 1; // Highest priority
    if (order.priority > 0) return order.priority;
    return 5; // Default priority
  }
  
  /// Generate result message
  String _generateResultMessage(int successfulJobs, int totalJobs) {
    if (successfulJobs == totalJobs) {
      return 'Order sent to all $successfulJobs printers successfully!';
    } else if (successfulJobs > 0) {
      return 'Order sent to $successfulJobs of $totalJobs printers (some failed).';
    } else {
      return 'Order queued for printing (all printers offline).';
    }
  }
  
  /// Get service statistics
  Map<String, dynamic> getStatistics() {
    return {
      'ordersSent': _ordersSent,
      'ordersDelivered': _ordersDelivered,
      'ordersFailed': _ordersFailed,
      'printersOnline': _printersOnline,
      'pendingOrders': _pendingOrders.length,
      'failedOrders': _failedOrders.length,
      'printerSuccessCount': Map.from(_printerSuccessCount),
      'printerFailureCount': Map.from(_printerFailureCount),
      'lastHeartbeat': _lastHeartbeat?.toIso8601String(),
      'connectionRetries': _connectionRetries,
    };
  }
  
  /// Reset statistics
  void resetStatistics() {
    _ordersSent = 0;
    _ordersDelivered = 0;
    _ordersFailed = 0;
    _printersOnline = 0;
    _printerSuccessCount.clear();
    _printerFailureCount.clear();
    _pendingOrders.clear();
    _failedOrders.clear();
    _connectionRetries = 0;
    notifyListeners();
  }
  
  /// Dispose service
  @override
  void dispose() {
    _pollingTimer?.cancel();
    _retryTimer?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}

/// 🏪 Restaurant Printer Bridge Service
/// Runs at the restaurant to receive print jobs from cloud and send to physical printers
class RestaurantPrinterBridgeService extends ChangeNotifier {
  static const String _logTag = '🏪 RestaurantPrinterBridge';
  
  final CloudRestaurantPrintingService _cloudService;
  final PrintingService _printingService;
  
  bool _isRunning = false;
  String? _bridgeId;
  Timer? _pollingTimer;
  
  RestaurantPrinterBridgeService({
    required CloudRestaurantPrintingService cloudService,
    required PrintingService printingService,
  }) : _cloudService = cloudService,
       _printingService = printingService;
  
  bool get isRunning => _isRunning;
  String? get bridgeId => _bridgeId;
  
  /// Start the restaurant printer bridge
  Future<bool> startBridge() async {
    try {
      debugPrint('$_logTag 🌉 Starting restaurant printer bridge...');
      
      _bridgeId = 'bridge_${DateTime.now().millisecondsSinceEpoch}';
      
      // Start polling for print jobs from cloud
      _startPrintJobPolling();
      
      _isRunning = true;
      debugPrint('$_logTag ✅ Restaurant printer bridge started successfully');
      notifyListeners();
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error starting printer bridge: $e');
      return false;
    }
  }
  
  /// Start polling for print jobs from cloud
  void _startPrintJobPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _pollForPrintJobs();
    });
  }
  
  /// Poll cloud service for print jobs
  Future<void> _pollForPrintJobs() async {
    try {
      // This would poll the cloud service for print jobs
      // and send them to local printers
      debugPrint('$_logTag 🔄 Polling for print jobs...');
      
      // Implementation would include:
      // 1. Get print jobs from cloud
      // 2. Route to appropriate local printers
      // 3. Send confirmation back to cloud
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error polling for print jobs: $e');
    }
  }
  
  /// Stop the printer bridge
  void stopBridge() {
    _pollingTimer?.cancel();
    _isRunning = false;
    debugPrint('$_logTag 🛑 Restaurant printer bridge stopped');
    notifyListeners();
  }
  
  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
} 