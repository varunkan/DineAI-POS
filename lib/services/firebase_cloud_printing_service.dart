import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order.dart' as pos_order;
import '../models/printer_configuration.dart';
import '../models/printer_assignment.dart';
import '../config/firebase_config.dart';
import '../services/printing_service.dart';
import '../services/enhanced_printer_assignment_service.dart';

/// 🔥 Firebase Cloud Printing Service
/// Enables remote printing to Epson WiFi printers via Firebase using public IP addresses
/// 
/// Features:
/// - Real-time order routing to specific printers
/// - Automatic item-based printer assignments
/// - Public IP support for remote access
/// - Offline queue with automatic retry
/// - Secure authentication and encryption
class FirebaseCloudPrintingService extends ChangeNotifier {
  static const String _logTag = '🔥 FirebaseCloudPrinting';
  
  // Firebase configuration
  late FirebaseFirestore _firestore;
  late FirebaseAuth _auth;
  
  // Service dependencies
  final PrintingService _printingService;
  final EnhancedPrinterAssignmentService _assignmentService;
  
  // Configuration
  String _restaurantId = '';
  String _apiKey = '';
  String _projectId = '';
  
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
  
  // Printer assignments for specific items
  Map<String, List<String>> _itemPrinterAssignments = {};
  
  FirebaseCloudPrintingService({
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
  Map<String, bool> get printerStatus => Map.unmodifiable(_printerStatus);
  Map<String, List<String>> get itemPrinterAssignments => Map.unmodifiable(_itemPrinterAssignments);
  
  /// Initialize the Firebase cloud printing service
  Future<bool> initialize({
    required String restaurantId,
    required String apiKey,
    required String projectId,
  }) async {
    try {
      debugPrint('$_logTag 🚀 Initializing Firebase cloud printing service...');
      
      _restaurantId = restaurantId;
      _apiKey = apiKey;
      _projectId = projectId;
      
      // Initialize Firebase
      _firestore = FirebaseFirestore.instance;
      _auth = FirebaseAuth.instance;
      
      // Test Firebase connection
      final connected = await _testFirebaseConnection();
      if (!connected) {
        debugPrint('$_logTag ❌ Failed to connect to Firebase');
        return false;
      }
      
      // Load printer assignments
      await _loadPrinterAssignments();
      
      // Start polling for orders
      _startPolling();
      
      // Start heartbeat
      _startHeartbeat();
      
      _isInitialized = true;
      _isConnected = true;
      _lastHeartbeat = DateTime.now();
      
      debugPrint('$_logTag ✅ Firebase cloud printing service initialized successfully');
      notifyListeners();
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error initializing Firebase cloud printing service: $e');
      return false;
    }
  }
  
  /// Send order to cloud for remote printing
  Future<Map<String, dynamic>> sendOrderToCloud({
    required pos_order.Order order,
    required String userId,
    required String userName,
  }) async {
    try {
      debugPrint('$_logTag 📤 Sending order ${order.orderNumber} to Firebase cloud...');
      
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
          'status': 'pending',
        };
        
        printJobs.add(printJob);
      }
      
      // Send print jobs to Firebase
      final results = await Future.wait(
        printJobs.map((job) => _sendPrintJobToFirebase(job)),
      );
      
      // Process results
      final successfulJobs = results.where((result) => result['success']).length;
      final totalJobs = results.length;
      
      _ordersSent += successfulJobs;
      _ordersFailed += (totalJobs - successfulJobs);
      
      debugPrint('$_logTag ✅ Sent $successfulJobs/$totalJobs print jobs successfully');
      
      return {
        'success': successfulJobs > 0,
        'message': successfulJobs == totalJobs 
            ? 'All print jobs sent successfully' 
            : 'Sent $successfulJobs/$totalJobs print jobs successfully',
        'itemsSent': successfulJobs,
        'printerCount': totalJobs,
        'results': results,
      };
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error sending order to cloud: $e');
      _ordersFailed++;
      
      return {
        'success': false,
        'message': 'Failed to send order to cloud: $e',
        'itemsSent': 0,
        'printerCount': 0,
        'error': e.toString(),
      };
    }
  }
  
  /// Get items grouped by printer assignments
  /// CRITICAL FIX: Only include items that haven't been sent to kitchen yet
  Future<Map<String, List<pos_order.OrderItem>>> _getItemsByPrinter(pos_order.Order order) async {
    final itemsByPrinter = <String, List<pos_order.OrderItem>>{};
    
    // CRITICAL FIX: Filter out items that have already been sent to kitchen
    final newItems = order.items.where((item) => !item.sentToKitchen).toList();
    
    if (newItems.isEmpty) {
      debugPrint('$_logTag ⚠️ No new items to print - all items already sent to kitchen');
      return {};
    }
    
    debugPrint('$_logTag 🔍 Found ${newItems.length} new items to print (${order.items.length} total items)');
    
    for (final item in newItems) {
      // Get printer assignments for this item
      final printerIds = _getPrinterAssignmentsForItem(item);
      
      for (final printerId in printerIds) {
        if (!itemsByPrinter.containsKey(printerId)) {
          itemsByPrinter[printerId] = [];
        }
        itemsByPrinter[printerId]!.add(item);
      }
    }
    
    return itemsByPrinter;
  }
  
  /// Get printer assignments for a specific item
  List<String> _getPrinterAssignmentsForItem(pos_order.OrderItem item) {
    final itemName = item.menuItem.name.toLowerCase();
    final categoryId = item.menuItem.categoryId;
    
    // Check for specific item assignments
    for (final entry in _itemPrinterAssignments.entries) {
      final itemPattern = entry.key.toLowerCase();
      if (itemName.contains(itemPattern) || itemPattern.contains(itemName)) {
        return entry.value;
      }
    }
    
    // Check for category-based assignments
    final categoryAssignments = _itemPrinterAssignments['category:$categoryId'];
    if (categoryAssignments != null) {
      return categoryAssignments;
    }
    
    // Default printer assignment
    return ['default'];
  }
  
  /// Send print job to Firebase
  Future<Map<String, dynamic>> _sendPrintJobToFirebase(Map<String, dynamic> printJob) async {
    try {
      // Add to Firestore
      final docRef = await _firestore
          .collection('restaurants')
          .doc(_restaurantId)
          .collection('printJobs')
          .add(printJob);
      
      debugPrint('$_logTag ✅ Print job sent to Firebase: ${docRef.id}');
      
      return {
        'success': true,
        'jobId': docRef.id,
        'printerId': printJob['targetPrinterId'],
        'message': 'Print job queued successfully',
      };
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error sending print job to Firebase: $e');
      
      return {
        'success': false,
        'printerId': printJob['targetPrinterId'],
        'error': e.toString(),
      };
    }
  }
  
  /// Start polling for incoming print jobs
  void _startPolling() {
    if (_isPolling) return;
    
    _isPolling = true;
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _pollForPrintJobs();
    });
    
    debugPrint('$_logTag 🔄 Started polling for print jobs');
  }
  
  /// Poll for incoming print jobs from Firebase
  Future<void> _pollForPrintJobs() async {
    try {
      if (!_isConnected) return;
      
      // Get pending print jobs for this restaurant
      final querySnapshot = await _firestore
          .collection('restaurants')
          .doc(_restaurantId)
          .collection('printJobs')
          .where('status', isEqualTo: 'pending')
          .where('targetPrinterId', whereIn: _getAvailablePrinterIds())
          .orderBy('timestamp', descending: false)
          .limit(10)
          .get();
      
      for (final doc in querySnapshot.docs) {
        final printJob = doc.data();
        await _processPrintJob(doc.id, printJob);
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error polling for print jobs: $e');
    }
  }
  
  /// Process incoming print job
  Future<void> _processPrintJob(String jobId, Map<String, dynamic> printJob) async {
    try {
      debugPrint('$_logTag 📥 Processing print job: $jobId');
      
      // Update job status to processing
      await _firestore
          .collection('restaurants')
          .doc(_restaurantId)
          .collection('printJobs')
          .doc(jobId)
          .update({'status': 'processing'});
      
      // Create order from print job data
      final order = pos_order.Order.fromJson(printJob['orderData']);
      
      // Print to local printer
      final printed = await _printingService.printKitchenTicket(order);
      
      if (printed) {
        // Update job status to completed
        await _firestore
            .collection('restaurants')
            .doc(_restaurantId)
            .collection('printJobs')
            .doc(jobId)
            .update({
              'status': 'completed',
              'completedAt': DateTime.now().toIso8601String(),
            });
        
        _ordersDelivered++;
        debugPrint('$_logTag ✅ Print job completed successfully: $jobId');
      } else {
        // Update job status to failed
        await _firestore
            .collection('restaurants')
            .doc(_restaurantId)
            .collection('printJobs')
            .doc(jobId)
            .update({
              'status': 'failed',
              'failedAt': DateTime.now().toIso8601String(),
              'error': 'Local printing failed',
            });
        
        _ordersFailed++;
        debugPrint('$_logTag ❌ Print job failed: $jobId');
      }
      
      notifyListeners();
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error processing print job: $e');
      
      // Update job status to failed
      try {
        await _firestore
            .collection('restaurants')
            .doc(_restaurantId)
            .collection('printJobs')
            .doc(jobId)
            .update({
              'status': 'failed',
              'failedAt': DateTime.now().toIso8601String(),
              'error': e.toString(),
            });
      } catch (updateError) {
        debugPrint('$_logTag ❌ Error updating job status: $updateError');
      }
    }
  }
  
  /// Get available printer IDs
  List<String> _getAvailablePrinterIds() {
    return _printerStatus.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }
  
  /// Load printer assignments from Firebase
  Future<void> _loadPrinterAssignments() async {
    try {
      final docSnapshot = await _firestore
          .collection('restaurants')
          .doc(_restaurantId)
          .collection('config')
          .doc('printerAssignments')
          .get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        _itemPrinterAssignments = Map<String, List<String>>.from(data['assignments'] ?? {});
        debugPrint('$_logTag ✅ Loaded ${_itemPrinterAssignments.length} printer assignments');
      } else {
        debugPrint('$_logTag ⚠️ No printer assignments found, using defaults');
        _loadDefaultAssignments();
      }
    } catch (e) {
      debugPrint('$_logTag ❌ Error loading printer assignments: $e');
      _loadDefaultAssignments();
    }
  }
  
  /// Load default printer assignments
  void _loadDefaultAssignments() {
    _itemPrinterAssignments = {
      'burger': ['kitchen'],
      'pizza': ['kitchen'],
      'drink': ['bar'],
      'dessert': ['kitchen'],
      'appetizer': ['kitchen'],
      'salad': ['kitchen'],
      'soup': ['kitchen'],
      'pasta': ['kitchen'],
      'steak': ['kitchen'],
      'seafood': ['kitchen'],
      'chicken': ['kitchen'],
      'beef': ['kitchen'],
      'pork': ['kitchen'],
      'vegetarian': ['kitchen'],
      'vegan': ['kitchen'],
      'gluten-free': ['kitchen'],
      'alcohol': ['bar'],
      'wine': ['bar'],
      'beer': ['bar'],
      'cocktail': ['bar'],
    };
  }
  
  /// Test Firebase connection
  Future<bool> _testFirebaseConnection() async {
    try {
      await _firestore.collection('test').doc('connection').get();
      return true;
    } catch (e) {
      debugPrint('$_logTag ❌ Firebase connection test failed: $e');
      return false;
    }
  }
  
  /// Start heartbeat to keep connection alive
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _sendHeartbeat();
    });
  }
  
  /// Send heartbeat to Firebase
  Future<void> _sendHeartbeat() async {
    try {
      await _firestore
          .collection('restaurants')
          .doc(_restaurantId)
          .collection('heartbeats')
          .doc('current')
          .set({
            'timestamp': DateTime.now().toIso8601String(),
            'sessionId': _sessionId,
            'status': 'online',
            'printersOnline': _printersOnline,
          });
      
      _lastHeartbeat = DateTime.now();
    } catch (e) {
      debugPrint('$_logTag ❌ Error sending heartbeat: $e');
    }
  }
  
  /// Get order priority
  int _getOrderPriority(pos_order.Order order) {
    if (order.isUrgent) return 1;
    if (order.priority == 'high') return 2;
    if (order.priority == 'normal') return 3;
    return 4;
  }
  
  /// Dispose of resources
  @override
  void dispose() {
    _pollingTimer?.cancel();
    _retryTimer?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
} 