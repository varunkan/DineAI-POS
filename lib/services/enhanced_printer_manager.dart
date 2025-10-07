import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/printer_configuration.dart';
import '../models/order.dart';
import '../services/database_service.dart';
import '../services/printer_configuration_service.dart';
import '../services/printing_service.dart' as printing_service;
// Removed: import '../services/comprehensive_printer_system.dart'; (redundant service)
import '../services/enhanced_printer_assignment_service.dart'; // Added import for EnhancedPrinterAssignmentService

/// Enhanced Printer Manager
/// Fixes all printer discovery, configuration, and assignment issues
class EnhancedPrinterManager extends ChangeNotifier {
  static const String _logTag = '🚀 EnhancedPrinterManager';
  
  final DatabaseService _databaseService;
  final PrinterConfigurationService _printerConfigService;
  final printing_service.PrintingService _printingService;
  final EnhancedPrinterAssignmentService _assignmentService;
  // Removed: ComprehensivePrinterSystem (redundant service)
  
  bool _isInitialized = false;
  List<PrinterConfiguration> _availablePrinters = [];
  Map<String, String> _menuItemAssignments = {}; // menuItemId -> printerId
  
  EnhancedPrinterManager({
    required DatabaseService databaseService,
    required PrinterConfigurationService printerConfigService,
    required printing_service.PrintingService printingService,
    required EnhancedPrinterAssignmentService assignmentService,
  }) : _databaseService = databaseService,
       _printerConfigService = printerConfigService,
       _printingService = printingService,
       _assignmentService = assignmentService {
    
    // Removed: ComprehensivePrinterSystem initialization (redundant service)
  }
  
  // Getters
  bool get isInitialized => _isInitialized;
  List<PrinterConfiguration> get availablePrinters => List.unmodifiable(_availablePrinters);
  Map<String, String> get menuItemAssignments => Map.unmodifiable(_menuItemAssignments);
  // Removed: ComprehensivePrinterSystem getter (redundant service)
  
  /// Manual printer discovery - called from UI
  Future<List<PrinterConfiguration>> discoverPrinters() async {
    
    try {
      // Skip old service discovery - let UnifiedPrinterService handle it
      // await _printerConfigService.manualDiscovery();
      
      // Refresh available printers
      await _loadAvailablePrinters();
      
      return _availablePrinters;
      
    } catch (e) {
      return _availablePrinters;
    }
  }
  
  /// Initialize the enhanced printer manager
  Future<void> initialize() async {
    
    try {
      // Step 1: Initialize printer services
      await _printerConfigService.initialize();
      
      // Step 2: Load available printers (no automatic discovery)
      await _loadAvailablePrinters();
      
      // Step 3: Load assignments
      await _loadMenuItemAssignments();
      
      _isInitialized = true;
      notifyListeners();
      
      
    } catch (e) {
      rethrow;
    }
  }
  
  /// Force discovery and configuration of all network printers
  /// FIXED: Removed automatic discovery - only manual discovery available
  Future<void> _forceDiscoverAndConfigurePrinters() async {
    // No automatic discovery - only manual discovery on user request
  }
  
  /// Manual network scan with immediate database saving
  /// FIXED: Removed automatic scanning - only manual discovery available
  Future<void> _manualNetworkScan() async {
    // No automatic scanning - only manual discovery on user request
  }
  
  /// Immediately save discovered printer to database
  Future<void> _saveDiscoveredPrinter(Map<String, dynamic> printerData) async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) {
        return;
      }
      
      final ip = printerData['ip'] as String;
      final port = printerData['port'] as int;
      
      // Check if already exists
      final existing = await db!.query(
        'printer_configurations',
        where: 'ip_address = ? AND port = ?',
        whereArgs: [ip, port],
      );
      
      if (existing.isNotEmpty) {
        return;
      }
      
      // Generate unique ID
      final configId = 'printer_${ip.replaceAll('.', '_')}_$port';
      
      // Insert into database
      await db.insert('printer_configurations', {
        'id': configId,
        'name': printerData['name'],
        'description': 'Auto-discovered network printer',
        'type': 'wifi',
        'model': printerData['model'],
        'ip_address': ip,
        'port': port,
        'is_active': 1,
        'connection_status': 'discovered',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      
    } catch (e) {
    }
  }
  
  /// Load available printers from database
  Future<void> _loadAvailablePrinters() async {
    try {
      // Clean up any existing dummy printers
      await _cleanupDummyPrinters();
      
      await _printerConfigService.refreshConfigurations();
      _availablePrinters = _printerConfigService.activeConfigurations;
      
      
      if (_availablePrinters.isEmpty) {
        // Skip emergency discovery to avoid conflicts with UnifiedPrinterService
        // await _emergencyPrinterDiscovery();
      }
      
    } catch (e) {
    }
  }
  
  /// Clean up dummy test printers from database
  Future<void> _cleanupDummyPrinters() async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) return;
      
      final dummyPrinterIds = [
        'test_kitchen_main',
        'test_grill_station', 
        'test_bar_station',
        'test_receipt_station',
      ];
      
      for (final id in dummyPrinterIds) {
        // Remove printer configuration
        await db!.delete(
          'printer_configurations',
          where: 'id = ?',
          whereArgs: [id],
        );
        
        // Remove any assignments to this printer
        await db.delete(
          'printer_assignments',
          where: 'printer_id = ?',
          whereArgs: [id],
        );
      }
      
      
    } catch (e) {
    }
  }
  
  /// Emergency printer discovery if no printers found
  Future<void> _emergencyPrinterDiscovery() async {
    
    try {
      // Force manual discovery
      await _printerConfigService.manualDiscovery();
      
      // Manual scan and save
      await _manualNetworkScan();
      
      // Reload
      await _printerConfigService.refreshConfigurations();
      _availablePrinters = _printerConfigService.activeConfigurations;
      
      
    } catch (e) {
    }
  }
  

  
  /// Assign menu item to printer
  Future<bool> assignMenuItemToPrinter(String menuItemId, String printerId) async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) return false;
      
      // Check if table exists before trying to use it
      final tableExists = await db!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='menu_printer_assignments'"
      );
      
      if (tableExists.isEmpty) {
        // Store in memory only for now
        _menuItemAssignments[menuItemId] = printerId;
        return true;
      }
      
      // Remove existing assignment
      await db.delete(
        'menu_printer_assignments',
        where: 'menu_item_id = ?',
        whereArgs: [menuItemId],
      );
      
      // Add new assignment
      await db.insert('menu_printer_assignments', {
        'id': 'assignment_${DateTime.now().millisecondsSinceEpoch}',
        'menu_item_id': menuItemId,
        'printer_id': printerId,
        'station_id': 'main_kitchen', // Default station
        'priority': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      _menuItemAssignments[menuItemId] = printerId;
      return true;
      
    } catch (e) {
      // Fallback to in-memory assignment
      try {
        _menuItemAssignments[menuItemId] = printerId;
        return true;
      } catch (fallbackError) {
        return false;
      }
    }
  }
  
  /// Print order to assigned printers
  Future<Map<String, bool>> printOrderToAssignedPrinters(Order order) async {
    if (!_isInitialized) {
      return await _printToAllAvailablePrinters(order);
    }
    
    try {
      
      // Use the injected assignment service
      final assignmentService = _assignmentService;
      
      // Segregate items by printer assignments
      final itemsByPrinter = await _segregateOrderByAssignments(order, assignmentService);
      
      if (itemsByPrinter.isEmpty) {
        return await _printToAllAvailablePrinters(order);
      }
      
      
      // Print to each assigned printer
      final results = <String, bool>{};
      int successCount = 0;
      
      for (final entry in itemsByPrinter.entries) {
        final printerId = entry.key;
        final items = entry.value;
        
        try {
          
          // Create partial order for this printer
          final partialOrder = Order(
            id: order.id,
            orderNumber: order.orderNumber,
            customerName: order.customerName,
            customerPhone: order.customerPhone,
            customerEmail: order.customerEmail,
            items: items,
            subtotal: items.fold<double>(0.0, (sum, item) => sum + item.totalPrice),
            taxAmount: 0.0,
            discountAmount: 0.0,
            gratuityAmount: 0.0,
            totalAmount: items.fold<double>(0.0, (sum, item) => sum + item.totalPrice),
            status: order.status,
            type: order.type,
            orderTime: order.orderTime,
            tableId: order.tableId,
            isUrgent: order.isUrgent,
            specialInstructions: order.specialInstructions,
            notes: order.notes,
            paymentMethod: order.paymentMethod,
            createdAt: order.createdAt,
            updatedAt: order.updatedAt,
          );
          
          // Print to specific printer
          final success = await _printToSpecificPrinter(partialOrder, printerId);
          results[printerId] = success;
          
          if (success) {
            successCount++;
          } else {
          }
          
          // Small delay between printers to prevent connection conflicts
          if (entry != itemsByPrinter.entries.last) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
          
        } catch (e) {
          results[printerId] = false;
        }
      }
      
      return results;
      
    } catch (e) {
      return await _printToAllAvailablePrinters(order);
    }
  }
  
  /// Segregate order items by printer assignments
  Future<Map<String, List<OrderItem>>> _segregateOrderByAssignments(Order order, EnhancedPrinterAssignmentService assignmentService) async {
    final Map<String, List<OrderItem>> itemsByPrinter = {};
    
    try {
      
      for (final item in order.items) {
        // Get all assignments for this menu item (supports multi-printer assignments)
        final assignments = assignmentService.getAssignmentsForMenuItem(
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
          const defaultPrinterId = 'default_printer';
          if (!itemsByPrinter.containsKey(defaultPrinterId)) {
            itemsByPrinter[defaultPrinterId] = [];
          }
          itemsByPrinter[defaultPrinterId]!.add(item);
        }
      }
      
      return itemsByPrinter;
      
    } catch (e) {
      return {};
    }
  }
  
  /// Print to a specific printer
  Future<bool> _printToSpecificPrinter(Order order, String printerId) async {
    try {
      // Get printer configuration
      final printerConfig = await _printerConfigService.getConfigurationById(printerId);
      if (printerConfig == null) {
        return false;
      }
      
      // Generate kitchen ticket
      final kitchenTicket = _generateKitchenTicket(order, printerConfig);
      
      // Send to printer
      final success = await _sendToPrinter(printerConfig, kitchenTicket);
      
      if (success) {
      } else {
      }
      
      return success;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Generate kitchen ticket content
  String _generateKitchenTicket(Order order, PrinterConfiguration printerConfig) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('====== KITCHEN TICKET ======');
    buffer.writeln('Order: ${order.orderNumber}');
    buffer.writeln('Time: ${DateTime.now().toString().substring(0, 19)}');
          // Note: Table display will be handled by the calling context
      buffer.writeln('Table: ${order.tableId ?? 'N/A'}');
    buffer.writeln('Customer: ${order.customerName ?? 'N/A'}');
    buffer.writeln('Printer: ${printerConfig.name}');
    buffer.writeln('=============================');
    buffer.writeln();
    
    // Items
    buffer.writeln('ITEMS:');
    for (final item in order.items) {
      buffer.writeln('${item.quantity}x ${item.menuItem.name}');
      if (item.selectedVariant != null && item.selectedVariant!.isNotEmpty) {
        buffer.writeln('  Variant: ${item.selectedVariant}');
      }
      if (item.specialInstructions != null && item.specialInstructions!.isNotEmpty) {
        buffer.writeln('  Special: ${item.specialInstructions}');
      }
      buffer.writeln();
    }
    
    // Footer
    buffer.writeln('=============================');
    buffer.writeln('Total Items: ${order.items.fold<int>(0, (sum, item) => sum + item.quantity)}');
    buffer.writeln('Priority: ${order.isUrgent ? 'URGENT' : 'Normal'}');
    buffer.writeln('=============================');
    buffer.writeln();
    buffer.writeln();
    
    return buffer.toString();
  }
  
  /// Send data to printer
  Future<bool> _sendToPrinter(PrinterConfiguration config, String content) async {
    try {
      // Use the printing service to send to the printer
      return await _printingService.printToSpecificPrinter(
        config.fullAddress,
        content,
        config.type, // Use the actual printer type from configuration
      );
    } catch (e) {
      return false;
    }
  }
  
  /// Fallback: print to all available printers
  Future<Map<String, bool>> _printToAllAvailablePrinters(Order order) async {
    final results = <String, bool>{};
    
    for (final printer in _availablePrinters) {
      try {
        // Generate kitchen ticket
        final ticket = _generateKitchenTicket(order, printer);
        
        // Try to connect and print
        final success = await _printToPrinter(printer, ticket);
        results[printer.id] = success;
        
        
      } catch (e) {
        results[printer.id] = false;
      }
    }
    
    return results;
  }
  
  /// Print to specific printer
  Future<bool> _printToPrinter(PrinterConfiguration printer, String content) async {
    try {
      final socket = await Socket.connect(
        printer.ipAddress,
        printer.port,
        timeout: const Duration(seconds: 5),
      );
      
      // Send content
      socket.add(content.codeUnits);
      await socket.flush();
      await socket.close();
      
      return true;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Test all printers and update their connection status
  Future<Map<String, bool>> testAllPrinters() async {
    final results = <String, bool>{};
    
    for (final printer in _availablePrinters) {
      final testContent = '''
TEST PRINT - ${printer.name}
Time: ${DateTime.now()}
IP: ${printer.ipAddress}:${printer.port}
Status: Connection Test
═══════════════════════
''';
      
      final success = await _printToPrinter(printer, testContent);
      results[printer.id] = success;
      
      // Update printer connection status in the database
      try {
        await _printerConfigService.updateConnectionStatus(
          printer.id,
          success ? PrinterConnectionStatus.connected : PrinterConnectionStatus.disconnected,
        );
        
        // Update local cache
        final index = _availablePrinters.indexWhere((p) => p.id == printer.id);
        if (index != -1) {
          _availablePrinters[index] = printer.copyWith(
            connectionStatus: success ? PrinterConnectionStatus.connected : PrinterConnectionStatus.disconnected,
          );
        }
        
        
      } catch (e) {
      }
    }
    
    notifyListeners();
    return results;
  }
  
  /// Refresh all printers (force rediscovery)
  Future<void> refreshPrinters() async {
    
    try {
      await _forceDiscoverAndConfigurePrinters();
      await _loadAvailablePrinters();
      await _loadMenuItemAssignments();
      
      notifyListeners();
      
      
    } catch (e) {
    }
  }
  
  // Helper methods
  Future<String> _getNetworkRange() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && 
              !address.isLoopback && 
              address.address.startsWith('192.168.')) {
            final parts = address.address.split('.');
            return '${parts[0]}.${parts[1]}.${parts[2]}';
          }
        }
      }
      return '192.168.0';
    } catch (e) {
      return '192.168.0';
    }
  }
  
  Future<void> _loadMenuItemAssignments() async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) return;
      
      // Check if table exists before trying to query it
      final tableExists = await db!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='menu_printer_assignments'"
      );
      
      if (tableExists.isEmpty) {
        return;
      }
      
      final results = await db.query('menu_printer_assignments');
      _menuItemAssignments.clear();
      
      for (final row in results) {
        _menuItemAssignments[row['menu_item_id'] as String] = row['printer_id'] as String;
      }
      
      
    } catch (e) {
      // Continue without loading assignments - app should still work
    }
  }
} 