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

/// 🆓 FREE Cloud Restaurant Printing Service
/// Uses free cloud platforms (Firebase, Heroku, etc.) for zero-cost printing
/// 
/// Free Options:
/// 1. Firebase (Google) - Free tier with generous limits
/// 2. Heroku - Free tier for basic usage
/// 3. Railway - Free tier for small projects
/// 4. Render - Free tier for web services
/// 5. Supabase - Free PostgreSQL database
class FreeCloudPrintingService extends ChangeNotifier {
  static const String _logTag = '🆓 FreeCloudPrinting';
  
  // Free cloud service options
  static const Map<String, String> _freeServices = {
    'firebase': 'https://your-project.firebaseapp.com/api',
    'heroku': 'https://your-app.herokuapp.com/api',
    'railway': 'https://your-app.railway.app/api',
    'render': 'https://your-app.onrender.com/api',
    'supabase': 'https://your-project.supabase.co/api',
  };
  
  // Service dependencies
  final PrintingService _printingService;
  final EnhancedPrinterAssignmentService _assignmentService;
  
  // Configuration
  String _selectedService = 'firebase';
  String _serviceUrl = '';
  String _apiKey = '';
  String _restaurantId = '';
  
  // Service state
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isPolling = false;
  Timer? _pollingTimer;
  Timer? _retryTimer;
  
  // Order queue management
  final List<Map<String, dynamic>> _pendingOrders = [];
  final List<Map<String, dynamic>> _failedOrders = [];
  
  // Statistics
  int _ordersSent = 0;
  int _ordersDelivered = 0;
  int _ordersFailed = 0;
  
  FreeCloudPrintingService({
    required PrintingService printingService,
    required EnhancedPrinterAssignmentService assignmentService,
  }) : _printingService = printingService,
       _assignmentService = assignmentService;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isPolling => _isPolling;
  int get ordersSent => _ordersSent;
  int get ordersDelivered => _ordersDelivered;
  int get ordersFailed => _ordersFailed;
  List<Map<String, dynamic>> get pendingOrders => List.unmodifiable(_pendingOrders);
  List<Map<String, dynamic>> get failedOrders => List.unmodifiable(_failedOrders);
  
  /// Initialize with free cloud service
  Future<bool> initialize({
    required String serviceType,
    required String serviceUrl,
    required String apiKey,
    required String restaurantId,
  }) async {
    try {
      debugPrint('$_logTag 🚀 Initializing FREE cloud printing service...');
      
      _selectedService = serviceType;
      _serviceUrl = serviceUrl;
      _apiKey = apiKey;
      _restaurantId = restaurantId;
      
      // Check internet connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        debugPrint('$_logTag ❌ No internet connection available');
        return false;
      }
      
      // Test connection to free service
      final connected = await _testFreeServiceConnection();
      if (!connected) {
        debugPrint('$_logTag ❌ Failed to connect to free service');
        return false;
      }
      
      // Start service monitoring
      _startServiceMonitoring();
      
      _isInitialized = true;
      _isConnected = true;
      
      debugPrint('$_logTag ✅ FREE cloud printing service initialized successfully');
      notifyListeners();
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error initializing free service: $e');
      return false;
    }
  }
  
  /// Send order to restaurant printers via free cloud service
  Future<Map<String, dynamic>> sendOrderToRestaurantPrinters({
    required Order order,
    required String userId,
    required String userName,
  }) async {
    try {
      debugPrint('$_logTag 📤 Sending order ${order.orderNumber} via FREE service...');
      
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
        };
        
        printJobs.add(printJob);
      }
      
      // Send print jobs to free service
      final results = await Future.wait(
        printJobs.map((job) => _sendPrintJobToFreeService(job)),
      );
      
      // Process results
      final successfulJobs = results.where((result) => result['success']).length;
      final totalJobs = results.length;
      
      _ordersSent += totalJobs;
      
      if (successfulJobs > 0) {
        _ordersDelivered += successfulJobs;
        debugPrint('$_logTag ✅ Successfully sent $successfulJobs/$totalJobs print jobs via FREE service');
      } else {
        _ordersFailed += totalJobs;
        debugPrint('$_logTag ❌ All print jobs failed via FREE service');
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
      debugPrint('$_logTag ❌ Error sending order via FREE service: $e');
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
  
  /// Send print job to free cloud service
  Future<Map<String, dynamic>> _sendPrintJobToFreeService(Map<String, dynamic> printJob) async {
    try {
      final response = await http.post(
        Uri.parse('$_serviceUrl/print-jobs'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'X-Restaurant-ID': _restaurantId,
        },
        body: json.encode(printJob),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'jobId': data['jobId'],
          'printerId': printJob['targetPrinterId'],
          'message': 'Print job queued successfully via FREE service',
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
  
  /// Test connection to free cloud service
  Future<bool> _testFreeServiceConnection() async {
    try {
      debugPrint('$_logTag 🔍 Testing FREE service connection...');
      
      final response = await http.get(
        Uri.parse('$_serviceUrl/health'),
        headers: {'Authorization': 'Bearer $_apiKey'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        debugPrint('$_logTag ✅ FREE service connection successful');
        return true;
      } else {
        debugPrint('$_logTag ❌ FREE service connection failed: ${response.statusCode}');
        return false;
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ FREE service connection error: $e');
      return false;
    }
  }
  
  /// Start service monitoring
  void _startServiceMonitoring() {
    // Start polling for updates
    _startPolling();
    
    // Start retry mechanism
    _startRetryMechanism();
  }
  
  /// Start polling for updates
  void _startPolling() {
    if (_isPolling) return;
    
    _isPolling = true;
    debugPrint('$_logTag 🔄 Starting status polling...');
    
    // Poll every 30 seconds for updates (free tier friendly)
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _pollForUpdates();
    });
  }
  
  /// Poll free service for updates
  Future<void> _pollForUpdates() async {
    if (!_isInitialized || !_isConnected) return;
    
    try {
      final response = await http.get(
        Uri.parse('$_serviceUrl/status?restaurantId=$_restaurantId'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
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
        
        // Retry pending orders
        if (_pendingOrders.isNotEmpty) {
          await _retryPendingOrders();
        }
        
      } else if (response.statusCode != 204) {
        debugPrint('$_logTag ⚠️ Polling failed: ${response.statusCode}');
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error polling for updates: $e');
    }
  }
  
  /// Process order confirmations
  Future<void> _processOrderConfirmations(List<dynamic> confirmations) async {
    for (final confirmation in confirmations) {
      final orderId = confirmation['orderId'] as String?;
      final success = confirmation['success'] as bool? ?? false;
      
      if (orderId != null && success) {
        debugPrint('$_logTag ✅ Order $orderId confirmed printed via FREE service');
      }
    }
  }
  
  /// Process failed orders
  Future<void> _processFailedOrders(List<dynamic> failures) async {
    for (final failure in failures) {
      final orderId = failure['orderId'] as String?;
      final error = failure['error'] as String?;
      
      if (orderId != null) {
        _failedOrders.add({
          'orderId': orderId,
          'error': error ?? 'Unknown error',
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        debugPrint('$_logTag ❌ Order $orderId failed via FREE service: $error');
      }
    }
    
    notifyListeners();
  }
  
  /// Start retry mechanism
  void _startRetryMechanism() {
    _retryTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _retryPendingOrders();
    });
  }
  
  /// Retry pending orders
  Future<void> _retryPendingOrders() async {
    if (_pendingOrders.isEmpty) return;
    
    debugPrint('$_logTag 🔄 Retrying ${_pendingOrders.length} failed orders...');
    
    final ordersToRetry = List<Map<String, dynamic>>.from(_pendingOrders);
    _pendingOrders.clear();
    
    for (final order in ordersToRetry) {
      final result = await _sendPrintJobToFreeService(order);
      if (!result['success']) {
        _pendingOrders.add(order);
      }
    }
    
    notifyListeners();
  }
  
  /// Get order priority
  int _getOrderPriority(Order order) {
    if (order.isUrgent) return 1;
    if (order.priority > 0) return order.priority;
    return 5;
  }
  
  /// Generate result message
  String _generateResultMessage(int successfulJobs, int totalJobs) {
    if (successfulJobs == totalJobs) {
      return 'Order sent to all $successfulJobs printers via FREE service!';
    } else if (successfulJobs > 0) {
      return 'Order sent to $successfulJobs of $totalJobs printers via FREE service (some failed).';
    } else {
      return 'Order queued for printing via FREE service (all printers offline).';
    }
  }
  
  /// Get service statistics
  Map<String, dynamic> getStatistics() {
    return {
      'ordersSent': _ordersSent,
      'ordersDelivered': _ordersDelivered,
      'ordersFailed': _ordersFailed,
      'pendingOrders': _pendingOrders.length,
      'failedOrders': _failedOrders.length,
      'serviceType': _selectedService,
      'isConnected': _isConnected,
    };
  }
  
  /// Reset statistics
  void resetStatistics() {
    _ordersSent = 0;
    _ordersDelivered = 0;
    _ordersFailed = 0;
    _pendingOrders.clear();
    _failedOrders.clear();
    notifyListeners();
  }
  
  /// Get available free services
  static Map<String, String> getAvailableFreeServices() {
    return Map.from(_freeServices);
  }
  
  /// Dispose service
  @override
  void dispose() {
    _pollingTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
} 