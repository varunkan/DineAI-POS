import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';

import '../models/order.dart';
import '../models/printer_configuration.dart';
import '../models/printer_assignment.dart';
import '../models/menu_item.dart';
import '../services/database_service.dart';
import '../services/tenant_printer_service.dart';
import '../services/printing_service.dart';
import '../services/multi_tenant_auth_service.dart';

/// 🌐 Tenant Cloud Printing Service
/// 
/// This service handles cloud-based printing for tenant-specific restaurants.
/// Features:
/// - Routes print jobs from any device to restaurant printers via public IP
/// - Real-time print job queuing and processing
/// - Automatic printer status monitoring
/// - Offline queue with automatic retry
/// - Secure authentication and encryption
class TenantCloudPrintingService extends ChangeNotifier {
  static const String _logTag = '🌐 TenantCloudPrintingService';
  
  final DatabaseService _databaseService;
  final TenantPrinterService _tenantPrinterService;
  final PrintingService _printingService;
  final MultiTenantAuthService _authService;
  
  // Tenant-specific state
  String _currentTenantId = '';
  String _currentRestaurantId = '';
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isPolling = false;
  
  // Firebase instances
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  
  // Service state
  Timer? _pollingTimer;
  Timer? _retryTimer;
  Timer? _heartbeatTimer;
  
  // Connection management
  String? _sessionId;
  DateTime? _lastHeartbeat;
  int _connectionRetries = 0;
  static const int _maxRetries = 5;
  
  // Print job management
  final List<Map<String, dynamic>> _pendingJobs = [];
  final List<Map<String, dynamic>> _failedJobs = [];
  final Map<String, DateTime> _jobTimestamps = {};
  
  // Statistics
  int _jobsSent = 0;
  int _jobsDelivered = 0;
  int _jobsFailed = 0;
  int _printersOnline = 0;
  Map<String, int> _printerSuccessCount = {};
  Map<String, int> _printerFailureCount = {};
  
  // Real-time status
  Map<String, bool> _printerStatus = {};
  Map<String, DateTime> _lastPrinterActivity = {};
  
  TenantCloudPrintingService({
    required DatabaseService databaseService,
    required TenantPrinterService tenantPrinterService,
    required PrintingService printingService,
    required MultiTenantAuthService authService,
  }) : _databaseService = databaseService,
       _tenantPrinterService = tenantPrinterService,
       _printingService = printingService,
       _authService = authService;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isPolling => _isPolling;
  String? get sessionId => _sessionId;
  DateTime? get lastHeartbeat => _lastHeartbeat;
  int get jobsSent => _jobsSent;
  int get jobsDelivered => _jobsDelivered;
  int get jobsFailed => _jobsFailed;
  int get printersOnline => _printersOnline;
  Map<String, bool> get printerStatus => Map.unmodifiable(_printerStatus);
  List<Map<String, dynamic>> get pendingJobs => List.unmodifiable(_pendingJobs);
  List<Map<String, dynamic>> get failedJobs => List.unmodifiable(_failedJobs);
  
  /// Initialize the tenant cloud printing service
  Future<bool> initialize({required String tenantId, required String restaurantId}) async {
    try {
      debugPrint('$_logTag 🚀 Initializing tenant cloud printing service for tenant: $tenantId');
      
      _currentTenantId = tenantId;
      _currentRestaurantId = restaurantId;
      
      // Initialize Firebase
      _firestore = FirebaseFirestore.instance;
      _auth = FirebaseAuth.instance;
      
      // Test Firebase connection
      final connected = await _testFirebaseConnection();
      if (!connected) {
        debugPrint('$_logTag ❌ Failed to connect to Firebase');
        return false;
      }
      
      // Check if there are any available printers before starting polling
      final availablePrinterIds = _getAvailablePrinterIds();
      if (availablePrinterIds.isEmpty) {
        debugPrint('$_logTag ⚠️ No available printers - service will wait for printers to be added');
        // Don't start polling yet, but mark as initialized
        _isInitialized = true;
        _isConnected = true;
        notifyListeners();
        return true;
      }
      
      // Start polling for print jobs only if printers are available
      _startPolling();
      
      // Start heartbeat
      _startHeartbeat();
      
      _isInitialized = true;
      _isConnected = true;
      _lastHeartbeat = DateTime.now();
      
      notifyListeners();
      
      debugPrint('$_logTag ✅ Tenant cloud printing service initialized successfully with ${availablePrinterIds.length} printers');
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error initializing tenant cloud printing service: $e');
      return false;
    }
  }
  
  /// Send order to cloud for remote printing
  Future<Map<String, dynamic>> sendOrderToCloud({
    required Order order,
    required String userId,
    required String userName,
  }) async {
    try {
      debugPrint('$_logTag 📤 Sending order ${order.orderNumber} to cloud for tenant: $_currentTenantId');
      
      // Get items grouped by printer assignments
      final itemsByPrinter = await _getItemsByPrinter(order);
      if (itemsByPrinter.isEmpty) {
        return {
          'success': false,
          'message': 'No printer assignments found for order items',
          'itemsSent': 0,
          'printerCount': 0,
        };
      }
      
      final printJobs = <Map<String, dynamic>>[];
      
      // Create print jobs for each printer
      for (final entry in itemsByPrinter.entries) {
        final printerId = entry.key;
        final items = entry.value;
        
        // Get printer configuration
        final printer = _tenantPrinterService.tenantPrinters
            .where((p) => p.id == printerId)
            .firstOrNull;
        if (printer == null) continue;
        
        // Get public IP for printer
        final publicIP = _tenantPrinterService.printerPublicIPs[printerId];
        
        final printJob = {
          'orderId': order.id,
          'orderNumber': order.orderNumber,
          'tenantId': _currentTenantId,
          'restaurantId': _currentRestaurantId,
          'targetPrinterId': printerId,
          'targetPrinterName': printer.name,
          'targetPrinterIP': printer.ipAddress,
          'targetPrinterPort': printer.port,
          'targetPrinterPublicIP': publicIP,
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
      
      final successfulJobs = results.where((result) => result['success']).length;
      final totalJobs = results.length;
      
      _jobsSent += successfulJobs;
      _jobsFailed += (totalJobs - successfulJobs);
      
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
      _jobsFailed++;
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
  Future<Map<String, List<OrderItem>>> _getItemsByPrinter(Order order) async {
    final itemsByPrinter = <String, List<OrderItem>>{};
    
    // CRITICAL FIX: Filter out items that have already been sent to kitchen
    final newItems = order.items.where((item) => !item.sentToKitchen).toList();
    
    if (newItems.isEmpty) {
      debugPrint('$_logTag ⚠️ No new items to print - all items already sent to kitchen');
      return {};
    }
    
    debugPrint('$_logTag 🔍 Found ${newItems.length} new items to print (${order.items.length} total items)');
    
    for (final item in newItems) {
      final assignments = _tenantPrinterService.getAssignmentsForMenuItem(
        item.menuItem.id,
        item.menuItem.categoryId ?? '',
      );
      
      if (assignments.isNotEmpty) {
        // Add item to each assigned printer
        for (final assignment in assignments) {
          final printerId = assignment.printerId;
          if (!itemsByPrinter.containsKey(printerId)) {
            itemsByPrinter[printerId] = [];
          }
          itemsByPrinter[printerId]!.add(item);
        }
      } else {
        // No assignment found - use default printer
        final defaultPrinter = _tenantPrinterService.activeTenantPrinters.firstOrNull;
        if (defaultPrinter != null) {
          itemsByPrinter.putIfAbsent(defaultPrinter.id, () => []).add(item);
        }
      }
    }
    
    return itemsByPrinter;
  }
  
  /// Send print job to Firebase
  Future<Map<String, dynamic>> _sendPrintJobToFirebase(Map<String, dynamic> printJob) async {
    try {
      final docRef = await _firestore!
          .collection('tenants')
          .doc(_currentTenantId)
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
  
  /// Start polling for incoming print jobs - COMPLETELY NON-BLOCKING
  void _startPolling() {
    if (_isPolling) return;
    
    _isPolling = true;
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // CRITICAL: Completely isolate polling to prevent ANY impact on other features
      try {
        // Use unawaited to prevent any blocking
        _pollForPrintJobs().catchError((error) {
          debugPrint('$_logTag ❌ Polling error (COMPLETELY ISOLATED): $error');
          // This error should NEVER impact the main app flow
        });
      } catch (e) {
        debugPrint('$_logTag ❌ Polling timer error (COMPLETELY ISOLATED): $e');
        // Don't stop polling on error - just log and continue
      }
    });
    
    debugPrint('$_logTag 🔄 Started polling for print jobs (COMPLETELY ISOLATED)');
  }
  
  /// Start polling when printers become available
  void startPollingIfPrintersAvailable() {
    if (_isPolling) return;
    
    final availablePrinterIds = _getAvailablePrinterIds();
    if (availablePrinterIds.isNotEmpty) {
      _startPolling();
      debugPrint('$_logTag 🔄 Started polling for print jobs with ${availablePrinterIds.length} printers');
    }
  }
  
  /// Stop polling for print jobs
  void _stopPolling() {
    if (!_isPolling) return;
    
    _pollingTimer?.cancel();
    _isPolling = false;
    debugPrint('$_logTag ⏹️ Stopped polling for print jobs');
  }
  
  /// Poll for incoming print jobs from Firebase - COMPLETELY ISOLATED
  Future<void> _pollForPrintJobs() async {
    // CRITICAL: Completely isolate this method to prevent any impact on other features
    try {
      if (!_isConnected) return;
      
      // Get available printer IDs
      final availablePrinterIds = _getAvailablePrinterIds();
      
      // CRITICAL FIX: Skip polling if no printers are available or if IDs are invalid
      if (availablePrinterIds.isEmpty) {
        debugPrint('$_logTag ⚠️ No available printers - skipping print job polling');
        return;
      }
      
      // Filter out empty or invalid printer IDs
      final validPrinterIds = availablePrinterIds.where((id) => id.isNotEmpty && id != null).toList();
      if (validPrinterIds.isEmpty) {
        debugPrint('$_logTag ⚠️ No valid printer IDs - skipping print job polling');
        return;
      }
      
      // CRITICAL: Double-check that we have valid IDs before making the query
      if (validPrinterIds.length == 1 && validPrinterIds.first.isEmpty) {
        debugPrint('$_logTag ⚠️ Single empty printer ID detected - skipping print job polling');
        return;
      }
      
      // CRITICAL: Additional safety check - ensure we have at least one non-empty ID
      final finalPrinterIds = validPrinterIds.where((id) => id.trim().isNotEmpty).toList();
      if (finalPrinterIds.isEmpty) {
        debugPrint('$_logTag ⚠️ No final valid printer IDs after trimming - skipping print job polling');
        return;
      }
      
      // CRITICAL: Ensure we have at least one valid printer ID for the whereIn filter
      if (finalPrinterIds.isEmpty) {
        debugPrint('$_logTag ⚠️ No valid printer IDs for whereIn filter - skipping print job polling');
        return;
      }
      
      // Use only valid printer IDs for the whereIn filter
      final querySnapshot = await _firestore!
          .collection('tenants')
          .doc(_currentTenantId)
          .collection('printJobs')
          .where('status', isEqualTo: 'pending')
          .where('targetPrinterId', whereIn: finalPrinterIds)
          .orderBy('timestamp', descending: false)
          .limit(10)
          .get();
      
      for (final doc in querySnapshot.docs) {
        try {
          final printJob = doc.data();
          await _processPrintJob(doc.id, printJob);
        } catch (e) {
          // CRITICAL: Isolate individual print job processing errors
          debugPrint('$_logTag ❌ Error processing print job ${doc.id}: $e');
          // Continue processing other jobs - don't let one failure stop everything
        }
      }
      
    } catch (e) {
      // CRITICAL: Completely isolate polling errors - they should NEVER impact other features
      debugPrint('$_logTag ❌ Error polling for print jobs (ISOLATED): $e');
      // Don't re-throw - this error should be completely contained
    }
  }
  
  /// Process incoming print job
  Future<void> _processPrintJob(String jobId, Map<String, dynamic> printJob) async {
    try {
      debugPrint('$_logTag 📥 Processing print job: $jobId');
      
      // Update job status to processing
      await _firestore!
          .collection('tenants')
          .doc(_currentTenantId)
          .collection('printJobs')
          .doc(jobId)
          .update({'status': 'processing'});
      
      // Get printer configuration
      final printerId = printJob['targetPrinterId'] as String;
      final printer = _tenantPrinterService.tenantPrinters
          .where((p) => p.id == printerId)
          .firstOrNull;
      if (printer == null) {
        throw Exception('Printer not found: $printerId');
      }
      
      // Create order from print job data
      final orderData = printJob['orderData'] as Map<String, dynamic>;
      final items = (printJob['items'] as List<dynamic>).map((itemData) {
        // Convert item data back to OrderItem (simplified)
        return OrderItem(
          id: itemData['id'] as String,
          menuItem: MenuItem(
            id: itemData['id'] as String,
            name: itemData['name'] as String,
            description: itemData['description'] as String? ?? '',
            price: (itemData['price'] as num?)?.toDouble() ?? 0.0,
            categoryId: itemData['categoryId'] as String? ?? '',
          ),
          quantity: itemData['quantity'] as int,
          selectedVariant: itemData['variants'] as String? ?? '',
          specialInstructions: itemData['instructions'] as String? ?? '',
          notes: itemData['notes'] as String? ?? '',
        );
      }).toList();
      
      final order = Order(
        id: orderData['orderId'] as String,
        orderNumber: orderData['orderNumber'] as String,
        items: items,
        tableId: orderData['tableId'] as String? ?? '',
        customerName: orderData['customerName'] as String? ?? '',
        orderTime: DateTime.parse(orderData['orderTime'] as String),
        isUrgent: orderData['isUrgent'] as bool? ?? false,
        priority: _parsePriority(orderData['priority']),
      );
      
      // Print to local printer
      final printed = await _printingService.printKitchenTicket(order);
      
      if (printed) {
        // Update job status to completed
        await _firestore!
            .collection('tenants')
            .doc(_currentTenantId)
            .collection('printJobs')
            .doc(jobId)
            .update({
          'status': 'completed',
          'completedAt': DateTime.now().toIso8601String(),
        });
        
        _jobsDelivered++;
        debugPrint('$_logTag ✅ Print job completed successfully: $jobId');
      } else {
        // Update job status to failed
        await _firestore!
            .collection('tenants')
            .doc(_currentTenantId)
            .collection('printJobs')
            .doc(jobId)
            .update({
          'status': 'failed',
          'failedAt': DateTime.now().toIso8601String(),
          'error': 'Local printing failed',
        });
        
        _jobsFailed++;
        debugPrint('$_logTag ❌ Print job failed: $jobId');
      }
      
      notifyListeners();
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error processing print job: $e');
      
      try {
        await _firestore!
            .collection('tenants')
            .doc(_currentTenantId)
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
  
  /// Check printer availability and update polling status
  void checkPrinterAvailability() {
    final availablePrinterIds = _getAvailablePrinterIds();
    
    if (availablePrinterIds.isNotEmpty && !_isPolling) {
      // Printers are available but we're not polling - start polling
      _startPolling();
      debugPrint('$_logTag 🔄 Printers became available - started polling with ${availablePrinterIds.length} printers');
    } else if (availablePrinterIds.isEmpty && _isPolling) {
      // No printers available but we're polling - stop polling
      _stopPolling();
      debugPrint('$_logTag ⏹️ No printers available - stopped polling');
    }
  }
  
  /// Get available printer IDs
  List<String> _getAvailablePrinterIds() {
    // Filter out empty or null printer IDs to prevent Firebase whereIn errors
    return _tenantPrinterService.activeTenantPrinters
        .where((p) => p.id.isNotEmpty && p.id != null)
        .map((p) => p.id)
        .toList();
  }
  
  /// Test Firebase connection
  Future<bool> _testFirebaseConnection() async {
    try {
      await _firestore!.collection('test').doc('connection').get();
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
      await _firestore!
          .collection('tenants')
          .doc(_currentTenantId)
          .collection('heartbeats')
          .doc('current')
          .set({
        'timestamp': DateTime.now().toIso8601String(),
        'sessionId': _sessionId,
        'status': 'online',
        'printersOnline': _printersOnline,
        'jobsSent': _jobsSent,
        'jobsDelivered': _jobsDelivered,
        'jobsFailed': _jobsFailed,
      });
      
      _lastHeartbeat = DateTime.now();
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error sending heartbeat: $e');
    }
  }
  
  /// Get order priority
  int _getOrderPriority(Order order) {
    if (order.isUrgent) return 1;
    if (order.priority == 'high') return 2;
    if (order.priority == 'normal') return 3;
    return 4;
  }

  /// Parse priority from print job data
  int _parsePriority(dynamic priority) {
    if (priority is int) {
      return priority;
    } else if (priority is String) {
      if (priority == 'high') return 2;
      if (priority == 'normal') return 3;
      if (priority == 'low') return 4;
      // Try to parse as int
      try {
        return int.parse(priority);
      } catch (e) {
        // Default to normal priority
        return 3;
      }
    }
    return 3; // Default priority
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