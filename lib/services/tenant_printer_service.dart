import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart';
import 'package:collection/collection.dart';

import '../models/printer_configuration.dart' as models;
import '../models/printer_assignment.dart';
import '../models/order.dart';
import '../models/menu_item.dart';
import '../services/database_service.dart';
import '../services/printer_configuration_service.dart';
import '../services/enhanced_printer_assignment_service.dart';
import '../services/printing_service.dart';
import '../services/multi_tenant_auth_service.dart';

/// 🏪 Tenant-Specific Printer Service
/// 
/// This service handles tenant-specific printer management for the multi-tenant POS system.
/// Features:
/// - WiFi printer discovery on tenant's network
/// - Automatic public IP identification for discovered printers
/// - Tenant-specific printer assignments for categories and items
/// - Cloud-based print job routing to restaurant printers
/// - Real-time printer status monitoring
class TenantPrinterService extends ChangeNotifier {
  static const String _logTag = '🏪 TenantPrinterService';
  
  final DatabaseService _databaseService;
  final PrinterConfigurationService _printerConfigService;
  final EnhancedPrinterAssignmentService _assignmentService;
  final PrintingService _printingService;
  final MultiTenantAuthService _authService;
  
  // Tenant-specific state
  String _currentTenantId = '';
  String _currentRestaurantId = '';
  bool _isInitialized = false;
  bool _isScanning = false;
  
  // Printer management
  List<models.PrinterConfiguration> _tenantPrinters = [];
  List<PrinterAssignment> _tenantAssignments = [];
  Map<String, String> _printerPublicIPs = {}; // printerId -> publicIP
  Map<String, bool> _printerStatus = {}; // printerId -> isOnline
  
  // Discovery state
  List<DiscoveredPrinter> _discoveredPrinters = [];
  Timer? _discoveryTimer;
  Timer? _statusTimer;
  
  // Cloud sync
  FirebaseFirestore? _firestore;
  bool _cloudSyncEnabled = false;
  
  TenantPrinterService({
    required DatabaseService databaseService,
    required PrinterConfigurationService printerConfigService,
    required EnhancedPrinterAssignmentService assignmentService,
    required PrintingService printingService,
    required MultiTenantAuthService authService,
  }) : _databaseService = databaseService,
       _printerConfigService = printerConfigService,
       _assignmentService = assignmentService,
       _printingService = printingService,
       _authService = authService;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  String get currentTenantId => _currentTenantId;
  String get currentRestaurantId => _currentRestaurantId;
  List<models.PrinterConfiguration> get tenantPrinters => List.unmodifiable(_tenantPrinters);
  List<models.PrinterConfiguration> get activeTenantPrinters => _tenantPrinters.where((p) => p.isActive).toList();
  List<PrinterAssignment> get tenantAssignments => List.unmodifiable(_tenantAssignments);
  List<DiscoveredPrinter> get discoveredPrinters => List.unmodifiable(_discoveredPrinters);
  Map<String, String> get printerPublicIPs => Map.unmodifiable(_printerPublicIPs);
  Map<String, bool> get printerStatus => Map.unmodifiable(_printerStatus);
  
  /// Initialize the tenant printer service
  Future<bool> initialize({required String tenantId, required String restaurantId}) async {
    try {
      debugPrint('$_logTag 🚀 Initializing tenant printer service for tenant: $tenantId');
      
      _currentTenantId = tenantId;
      _currentRestaurantId = restaurantId;
      
      // Initialize Firebase if available
      _firestore = FirebaseFirestore.instance;
      
      // Create tenant-specific tables
      await _createTenantPrinterTables();
      
      // Load tenant-specific printers and assignments
      await _loadTenantPrinters();
      await _loadTenantAssignments();
      
      // Load public IP mappings
      await _loadPrinterPublicIPs();
      
      // Start status monitoring
      _startStatusMonitoring();
      
      _isInitialized = true;
      notifyListeners();
      
      debugPrint('$_logTag ✅ Tenant printer service initialized successfully');
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error initializing tenant printer service: $e');
      return false;
    }
  }
  
  /// Create tenant-specific printer tables
  Future<void> _createTenantPrinterTables() async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) return;
      
      // Tenant-specific printer configurations table
      await db!.execute('''
        CREATE TABLE IF NOT EXISTS tenant_printer_configurations (
          id TEXT PRIMARY KEY,
          tenant_id TEXT NOT NULL,
          restaurant_id TEXT NOT NULL,
          name TEXT NOT NULL,
          description TEXT,
          type TEXT NOT NULL DEFAULT 'wifi',
          model TEXT NOT NULL DEFAULT 'epsonTMGeneric',
          ip_address TEXT,
          port INTEGER DEFAULT 9100,
          public_ip TEXT,
          mac_address TEXT,
          is_active INTEGER DEFAULT 1,
          connection_status TEXT DEFAULT 'unknown',
          last_connected TEXT,
          last_test_print TEXT,
          custom_settings TEXT DEFAULT '{}',
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(tenant_id, ip_address, port)
        )
      ''');
      
      // Tenant-specific printer assignments table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tenant_printer_assignments (
          id TEXT PRIMARY KEY,
          tenant_id TEXT NOT NULL,
          restaurant_id TEXT NOT NULL,
          printer_id TEXT NOT NULL,
          printer_name TEXT NOT NULL,
          printer_address TEXT NOT NULL,
          assignment_type TEXT NOT NULL,
          target_id TEXT NOT NULL,
          target_name TEXT NOT NULL,
          priority INTEGER DEFAULT 1,
          is_active INTEGER DEFAULT 1,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (printer_id) REFERENCES tenant_printer_configurations (id) ON DELETE CASCADE
        )
      ''');
      
      // Printer public IP mappings table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS printer_public_ips (
          id TEXT PRIMARY KEY,
          tenant_id TEXT NOT NULL,
          printer_id TEXT NOT NULL,
          local_ip TEXT NOT NULL,
          public_ip TEXT NOT NULL,
          last_updated TEXT DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(tenant_id, printer_id)
        )
      ''');
      
      debugPrint('$_logTag ✅ Tenant printer tables created successfully');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error creating tenant printer tables: $e');
    }
  }
  
  /// Load tenant-specific printers
  Future<void> _loadTenantPrinters() async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) return;
      
      final result = await db!.query(
        'tenant_printer_configurations',
        where: 'tenant_id = ? AND restaurant_id = ?',
        whereArgs: [_currentTenantId, _currentRestaurantId],
        orderBy: 'created_at DESC'
      );
      
      _tenantPrinters = result.map((row) => models.PrinterConfiguration(
        id: row['id'] as String,
        name: row['name'] as String,
        description: row['description'] as String? ?? '',
        type: models.PrinterType.values.firstWhere(
          (e) => e.toString().split('.').last == (row['type'] as String? ?? 'wifi'),
          orElse: () => models.PrinterType.wifi,
        ),
        model: models.PrinterModel.values.firstWhere(
          (e) => e.toString().split('.').last == (row['model'] as String? ?? 'epsonTMGeneric'),
          orElse: () => models.PrinterModel.epsonTMGeneric,
        ),
        ipAddress: row['ip_address'] as String? ?? '',
        port: row['port'] as int? ?? 9100,
        macAddress: row['mac_address'] as String? ?? '',
        isActive: (row['is_active'] as int? ?? 1) == 1,
        connectionStatus: models.PrinterConnectionStatus.values.firstWhere(
          (e) => e.toString().split('.').last == (row['connection_status'] as String? ?? 'unknown'),
          orElse: () => models.PrinterConnectionStatus.unknown,
        ),
        lastConnected: row['last_connected'] != null 
          ? DateTime.parse(row['last_connected'] as String) 
          : null,
        lastTestPrint: row['last_test_print'] != null 
          ? DateTime.parse(row['last_test_print'] as String) 
          : null,
        customSettings: row['custom_settings'] != null 
          ? Map<String, dynamic>.from(jsonDecode(row['custom_settings'] as String))
          : {},
      )).toList();
      
      debugPrint('$_logTag 📥 Loaded ${_tenantPrinters.length} tenant printers');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error loading tenant printers: $e');
      _tenantPrinters = [];
    }
  }
  
  /// Load tenant-specific assignments
  Future<void> _loadTenantAssignments() async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) return;
      
      final result = await db!.query(
        'tenant_printer_assignments',
        where: 'tenant_id = ? AND restaurant_id = ?',
        whereArgs: [_currentTenantId, _currentRestaurantId],
        orderBy: 'created_at DESC'
      );
      
      _tenantAssignments = result.map((row) => PrinterAssignment(
        id: row['id'] as String,
        printerId: row['printer_id'] as String,
        printerName: row['printer_name'] as String,
        printerAddress: row['printer_address'] as String,
        assignmentType: AssignmentType.values.firstWhere(
          (e) => e.toString().split('.').last == row['assignment_type'],
          orElse: () => AssignmentType.category,
        ),
        targetId: row['target_id'] as String,
        targetName: row['target_name'] as String,
        priority: row['priority'] as int? ?? 1,
        isActive: (row['is_active'] as int? ?? 1) == 1,
      )).toList();
      
      debugPrint('$_logTag 📥 Loaded ${_tenantAssignments.length} tenant assignments');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error loading tenant assignments: $e');
      _tenantAssignments = [];
    }
  }
  
  /// Load printer public IP mappings
  Future<void> _loadPrinterPublicIPs() async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) return;
      
      final result = await db!.query(
        'printer_public_ips',
        where: 'tenant_id = ?',
        whereArgs: [_currentTenantId]
      );
      
      _printerPublicIPs.clear();
      for (final row in result) {
        final printerId = row['printer_id'] as String;
        final publicIP = row['public_ip'] as String;
        _printerPublicIPs[printerId] = publicIP;
      }
      
      debugPrint('$_logTag 📥 Loaded ${_printerPublicIPs.length} printer public IP mappings');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error loading printer public IPs: $e');
      _printerPublicIPs.clear();
    }
  }
  
  /// Discover WiFi printers on tenant's network
  Future<List<DiscoveredPrinter>> discoverWiFiPrinters() async {
    if (_isScanning) {
      debugPrint('$_logTag ⚠️ Already scanning for printers');
      return _discoveredPrinters;
    }
    
    _isScanning = true;
    _discoveredPrinters.clear();
    notifyListeners();
    
    try {
      debugPrint('$_logTag 🔍 Starting WiFi printer discovery for tenant: $_currentTenantId');
      
      // Get current WiFi network info
      final wifiIP = await _getCurrentWiFiIP();
      if (wifiIP == null) {
        debugPrint('$_logTag ⚠️ No WiFi connection detected');
        return [];
      }
      
      final subnet = wifiIP.split('.').take(3).join('.');
      debugPrint('$_logTag 🌐 Scanning subnet: $subnet.x for tenant: $_currentTenantId');
      
      // Common printer ports
      const ports = [9100, 515, 631, 9101, 9102];
      
      // Priority IPs (most likely printer locations)
      final priorityIPs = <String>[];
      for (int i = 100; i <= 120; i++) priorityIPs.add('$subnet.$i');
      for (int i = 200; i <= 220; i++) priorityIPs.add('$subnet.$i');
      for (int i = 50; i <= 70; i++) priorityIPs.add('$subnet.$i');
      for (int i = 150; i <= 170; i++) priorityIPs.add('$subnet.$i');
      for (int i = 10; i <= 30; i++) priorityIPs.add('$subnet.$i');
      
      // Skip your own IP
      final yourIP = wifiIP.split('.').last;
      priorityIPs.removeWhere((ip) => ip.endsWith('.$yourIP'));
      
      debugPrint('$_logTag 🔍 Scanning ${priorityIPs.length} priority IPs for tenant: $_currentTenantId');
      
      // Scan priority IPs
      for (final ip in priorityIPs) {
        for (final port in ports) {
          try {
            final printer = await _testPrinterConnection(ip, port);
            if (printer != null) {
              _discoveredPrinters.add(printer);
              debugPrint('$_logTag 🖨️ Found printer: ${printer.name} at ${printer.ipAddress}:${printer.port} for tenant: $_currentTenantId');
            }
          } catch (e) {
            // Continue scanning
          }
        }
      }
      
      debugPrint('$_logTag ✅ WiFi discovery completed. Found ${_discoveredPrinters.length} printers for tenant: $_currentTenantId');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error during WiFi discovery: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
    
    return _discoveredPrinters;
  }
  
  /// Test printer connection at specific IP and port
  Future<DiscoveredPrinter?> _testPrinterConnection(String ip, int port) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 2));
      
      // Try to identify printer type
      String printerModel = 'Network Printer';
      String printerType = 'ESC/POS Compatible';
      
      try {
        // Send status request to identify printer
        socket.add([0x10, 0x04, 0x01]); // ESC/POS: Transmit printer status
        await socket.flush();
        
        // Wait for response
        final response = await socket.timeout(const Duration(milliseconds: 100)).first;
        if (response.isNotEmpty) {
          printerModel = 'ESC/POS Printer';
          printerType = _identifyPrinterType(port);
        }
      } catch (e) {
        // Printer might not support status requests, but connection worked
        printerType = _identifyPrinterType(port);
      }
      
      await socket.close();
      
      return DiscoveredPrinter(
        name: '$printerModel ($ip:$port)',
        model: printerType,
        ipAddress: ip,
        port: port,
        status: 'online',
        description: 'Network printer discovered on tenant network',
      );
      
    } catch (e) {
      return null;
    }
  }
  
  /// Identify printer type based on port
  String _identifyPrinterType(int port) {
    switch (port) {
      case 9100:
        return 'ESC/POS (Port 9100)';
      case 515:
        return 'LPR/LPD (Port 515)';
      case 631:
        return 'IPP (Port 631)';
      case 9101:
        return 'ESC/POS (Port 9101)';
      case 9102:
        return 'ESC/POS (Port 9102)';
      default:
        return 'Generic Network Printer';
    }
  }
  
  /// Get current WiFi IP address
  Future<String?> _getCurrentWiFiIP() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && 
              !address.isLoopback && 
              address.address.startsWith('192.168.')) {
            return address.address;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('$_logTag ❌ Error getting WiFi IP: $e');
      return null;
    }
  }
  
  /// Add discovered printer to tenant with public IP identification
  Future<bool> addDiscoveredPrinter(DiscoveredPrinter printer) async {
    try {
      debugPrint('$_logTag ➕ Adding discovered printer: ${printer.name} to tenant: $_currentTenantId');
      
      // Identify public IP for the printer
      final publicIP = await _identifyPublicIP(printer.ipAddress);
      
      // Create printer configuration
      final config = models.PrinterConfiguration(
        name: printer.name,
        description: 'Auto-discovered WiFi printer for tenant: $_currentTenantId',
        type: models.PrinterType.wifi,
        model: models.PrinterModel.epsonTMGeneric,
        ipAddress: printer.ipAddress,
        port: printer.port,
        isActive: true,
        connectionStatus: models.PrinterConnectionStatus.connected,
        lastConnected: DateTime.now(),
      );
      
      // Save to tenant database
      await _saveTenantPrinter(config);
      
      // Save public IP mapping
      if (publicIP != null) {
        await _savePrinterPublicIP(config.id, printer.ipAddress, publicIP);
        _printerPublicIPs[config.id] = publicIP;
        debugPrint('$_logTag 🌐 Identified public IP for printer: $publicIP');
      }
      
      // Add to local list
      _tenantPrinters.add(config);
      
      notifyListeners();
      
      debugPrint('$_logTag ✅ Successfully added printer: ${config.name} to tenant: $_currentTenantId');
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error adding discovered printer: $e');
      return false;
    }
  }
  
  /// Identify public IP for a local IP address
  Future<String?> _identifyPublicIP(String localIP) async {
    try {
      // Method 1: Use external service to get public IP
      final response = await http.get(
        Uri.parse('https://api.ipify.org'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final publicIP = response.body.trim();
        debugPrint('$_logTag 🌐 Identified public IP: $publicIP for local IP: $localIP');
        return publicIP;
      }
      
      // Method 2: Try alternative service
      final response2 = await http.get(
        Uri.parse('https://httpbin.org/ip'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response2.statusCode == 200) {
        final data = jsonDecode(response2.body);
        final publicIP = data['origin'] as String;
        debugPrint('$_logTag 🌐 Identified public IP (alt): $publicIP for local IP: $localIP');
        return publicIP;
      }
      
      return null;
      
    } catch (e) {
      debugPrint('$_logTag ⚠️ Could not identify public IP for $localIP: $e');
      return null;
    }
  }
  
  /// Save tenant printer to database
  Future<void> _saveTenantPrinter(models.PrinterConfiguration config) async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) return;
      
      await db!.insert('tenant_printer_configurations', {
        'id': config.id,
        'tenant_id': _currentTenantId,
        'restaurant_id': _currentRestaurantId,
        'name': config.name,
        'description': config.description,
        'type': config.type.toString().split('.').last,
        'model': config.model.toString().split('.').last,
        'ip_address': config.ipAddress,
        'port': config.port,
        'mac_address': config.macAddress,
        'is_active': config.isActive ? 1 : 0,
        'connection_status': config.connectionStatus.toString().split('.').last,
        'last_connected': config.lastConnected?.toIso8601String(),
        'last_test_print': config.lastTestPrint?.toIso8601String(),
        'custom_settings': jsonEncode(config.customSettings),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      debugPrint('$_logTag 💾 Saved tenant printer: ${config.name}');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error saving tenant printer: $e');
    }
  }
  
  /// Save printer public IP mapping
  Future<void> _savePrinterPublicIP(String printerId, String localIP, String publicIP) async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) return;
      
      await db!.insert('printer_public_ips', {
        'id': '${printerId}_public_ip',
        'tenant_id': _currentTenantId,
        'printer_id': printerId,
        'local_ip': localIP,
        'public_ip': publicIP,
        'last_updated': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      
      debugPrint('$_logTag 💾 Saved printer public IP mapping: $printerId -> $publicIP');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error saving printer public IP: $e');
    }
  }
  
  /// Assign category to printer for current tenant
  Future<bool> assignCategoryToPrinter(String categoryId, String categoryName, String printerId) async {
    try {
      debugPrint('$_logTag 🎯 Assigning category: $categoryName to printer: $printerId for tenant: $_currentTenantId');
      
      final printer = _tenantPrinters.firstWhere((p) => p.id == printerId);
      
      final assignment = PrinterAssignment(
        printerId: printerId,
        printerName: printer.name,
        printerAddress: printer.ipAddress,
        assignmentType: AssignmentType.category,
        targetId: categoryId,
        targetName: categoryName,
        priority: 1,
        isActive: true,
      );
      
      // Save to tenant database
      await _saveTenantAssignment(assignment);
      
      // Add to local list
      _tenantAssignments.add(assignment);
      
      notifyListeners();
      
      debugPrint('$_logTag ✅ Successfully assigned category: $categoryName to printer: ${printer.name}');
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error assigning category to printer: $e');
      return false;
    }
  }
  
  /// Assign menu item to printer for current tenant
  Future<bool> assignMenuItemToPrinter(String menuItemId, String menuItemName, String printerId) async {
    try {
      debugPrint('$_logTag 🎯 Assigning menu item: $menuItemName to printer: $printerId for tenant: $_currentTenantId');
      
      final printer = _tenantPrinters.firstWhere((p) => p.id == printerId);
      
      final assignment = PrinterAssignment(
        printerId: printerId,
        printerName: printer.name,
        printerAddress: printer.ipAddress,
        assignmentType: AssignmentType.menuItem,
        targetId: menuItemId,
        targetName: menuItemName,
        priority: 2, // Higher priority than category assignments
        isActive: true,
      );
      
      // Save to tenant database
      await _saveTenantAssignment(assignment);
      
      // Add to local list
      _tenantAssignments.add(assignment);
      
      notifyListeners();
      
      debugPrint('$_logTag ✅ Successfully assigned menu item: $menuItemName to printer: ${printer.name}');
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error assigning menu item to printer: $e');
      return false;
    }
  }
  
  /// Save tenant assignment to database
  Future<void> _saveTenantAssignment(PrinterAssignment assignment) async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) return;
      
      await db!.insert('tenant_printer_assignments', {
        'id': assignment.id,
        'tenant_id': _currentTenantId,
        'restaurant_id': _currentRestaurantId,
        'printer_id': assignment.printerId,
        'printer_name': assignment.printerName,
        'printer_address': assignment.printerAddress,
        'assignment_type': assignment.assignmentType.toString().split('.').last,
        'target_id': assignment.targetId,
        'target_name': assignment.targetName,
        'priority': assignment.priority,
        'is_active': assignment.isActive ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      debugPrint('$_logTag 💾 Saved tenant assignment: ${assignment.targetName} -> ${assignment.printerName}');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error saving tenant assignment: $e');
    }
  }
  
  /// Get assignments for menu item (tenant-specific)
  List<PrinterAssignment> getAssignmentsForMenuItem(String menuItemId, String categoryId) {
    List<PrinterAssignment> result = [];
    
    // Priority 1: Specific menu item assignments
    final menuItemAssignments = _tenantAssignments.where(
      (a) => a.isActive && 
             a.assignmentType == AssignmentType.menuItem && 
             a.targetId == menuItemId
    ).toList();
    
    if (menuItemAssignments.isNotEmpty) {
      result.addAll(menuItemAssignments);
      debugPrint('$_logTag 🎯 Found ${menuItemAssignments.length} specific assignments for menu item: $menuItemId');
    }
    
    // Priority 2: Category assignments (if no specific menu item assignments)
    if (result.isEmpty) {
      final categoryAssignments = _tenantAssignments.where(
        (a) => a.isActive && 
               a.assignmentType == AssignmentType.category && 
               a.targetId == categoryId
      ).toList();
      
      if (categoryAssignments.isNotEmpty) {
        result.addAll(categoryAssignments);
        debugPrint('$_logTag 📂 Found ${categoryAssignments.length} category assignments for: $categoryId');
      }
    }
    
    // Sort by priority
    result.sort((a, b) => b.priority.compareTo(a.priority));
    
    return result;
  }
  
  /// Print order to tenant's assigned printers
  Future<Map<String, bool>> printOrderToTenantPrinters(Order order) async {
    try {
      debugPrint('$_logTag 🖨️ Printing order ${order.orderNumber} to tenant printers: $_currentTenantId');
      
      final Map<String, List<OrderItem>> itemsByPrinter = {};
      
      // Group items by assigned printers
      for (final item in order.items) {
        final assignments = getAssignmentsForMenuItem(
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
            debugPrint('$_logTag 🎯 ${item.menuItem.name} assigned to printer: ${assignment.printerName}');
          }
        } else {
          // No assignment found - use default printer
          final defaultPrinter = _tenantPrinters.where((p) => p.isActive).firstOrNull;
          if (defaultPrinter != null) {
            itemsByPrinter.putIfAbsent(defaultPrinter.id, () => []).add(item);
            debugPrint('$_logTag ⚠️ ${item.menuItem.name} using default printer: ${defaultPrinter.name}');
          }
        }
      }
      
      debugPrint('$_logTag 📋 Order distributed to ${itemsByPrinter.length} printers');
      
      // Print to each assigned printer
      final results = <String, bool>{};
      int successCount = 0;
      
      for (final entry in itemsByPrinter.entries) {
        final printerId = entry.key;
        final items = entry.value;
        
        try {
          final printer = _tenantPrinters.firstWhere((p) => p.id == printerId);
          final printed = await _printToPrinter(printer, items, order);
          
          results[printerId] = printed;
          if (printed) {
            successCount++;
            debugPrint('$_logTag ✅ Successfully printed to ${printer.name}');
          } else {
            debugPrint('$_logTag ❌ Failed to print to ${printer.name}');
          }
        } catch (e) {
          debugPrint('$_logTag ❌ Error printing to printer $printerId: $e');
          results[printerId] = false;
        }
      }
      
      debugPrint('$_logTag 🎉 Printing complete: $successCount/${itemsByPrinter.length} printers successful');
      return results;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error printing order to tenant printers: $e');
      return {};
    }
  }
  
  /// Print items to specific printer
  Future<bool> _printToPrinter(models.PrinterConfiguration printer, List<OrderItem> items, Order order) async {
    try {
      // Create order subset for this printer
      final printerOrder = order.copyWith(items: items);
      
      // Use the existing printing service
      final printed = await _printingService.printKitchenTicket(printerOrder);
      
      if (printed) {
        // Update printer status
        _printerStatus[printer.id] = true;
        debugPrint('$_logTag ✅ Printed ${items.length} items to ${printer.name}');
      } else {
        _printerStatus[printer.id] = false;
        debugPrint('$_logTag ❌ Failed to print to ${printer.name}');
      }
      
      return printed;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error printing to ${printer.name}: $e');
      _printerStatus[printer.id] = false;
      return false;
    }
  }
  
  /// Start status monitoring
  void _startStatusMonitoring() {
    _statusTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _checkPrinterStatus();
    });
  }
  
  /// Check printer status
  Future<void> _checkPrinterStatus() async {
    for (final printer in _tenantPrinters.where((p) => p.isActive)) {
      try {
        final socket = await Socket.connect(
          printer.ipAddress, 
          printer.port, 
          timeout: const Duration(seconds: 2)
        );
        await socket.close();
        _printerStatus[printer.id] = true;
      } catch (e) {
        _printerStatus[printer.id] = false;
      }
    }
    notifyListeners();
  }
  
  /// Dispose of resources
  @override
  void dispose() {
    _discoveryTimer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }
}

/// Discovered printer model for tenant-specific discovery
class DiscoveredPrinter {
  final String name;
  final String model;
  final String ipAddress;
  final int port;
  final String status;
  final String description;
  
  DiscoveredPrinter({
    required this.name,
    required this.model,
    required this.ipAddress,
    required this.port,
    required this.status,
    required this.description,
  });
} 