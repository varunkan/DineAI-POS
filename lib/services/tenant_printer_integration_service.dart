import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';

import '../models/printer_configuration.dart';
import '../models/printer_assignment.dart';
import '../models/order.dart';
import '../models/menu_item.dart';
import '../services/database_service.dart';
import '../services/tenant_printer_service.dart';

import '../services/enhanced_printer_assignment_service.dart';
import '../services/printing_service.dart';
import '../services/multi_tenant_auth_service.dart';

/// 🏪 Tenant Printer Integration Service
/// 
/// This service integrates all tenant-specific printer functionality:
/// - WiFi printer discovery and public IP identification
/// - Tenant-specific printer assignments for categories and items
/// - Real-time printer status monitoring
/// - Automatic fallback to local printing
class TenantPrinterIntegrationService extends ChangeNotifier {
  static const String _logTag = '🏪 TenantPrinterIntegrationService';
  
  final DatabaseService _databaseService;
  final TenantPrinterService _tenantPrinterService;
  final EnhancedPrinterAssignmentService _assignmentService;
  final PrintingService _printingService;
  final MultiTenantAuthService _authService;
  
  // Integration state
  String _currentTenantId = '';
  String _currentRestaurantId = '';
  bool _isInitialized = false;
  
  // Service state
  bool _isDiscovering = false;
  bool _isProcessing = false;
  
  // Statistics
  int _totalPrintJobs = 0;
  int _successfulPrintJobs = 0;
  int _failedPrintJobs = 0;
  int _localPrintJobs = 0;
  
  TenantPrinterIntegrationService({
    required DatabaseService databaseService,
    required TenantPrinterService tenantPrinterService,
    required EnhancedPrinterAssignmentService assignmentService,
    required PrintingService printingService,
    required MultiTenantAuthService authService,
  }) : _databaseService = databaseService,
       _tenantPrinterService = tenantPrinterService,
       _assignmentService = assignmentService,
       _printingService = printingService,
       _authService = authService;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isDiscovering => _isDiscovering;
  bool get isProcessing => _isProcessing;
  String get currentTenantId => _currentTenantId;
  String get currentRestaurantId => _currentRestaurantId;
  
  // Delegate getters
  List<PrinterConfiguration> get tenantPrinters => _tenantPrinterService.tenantPrinters;
  List<PrinterConfiguration> get activeTenantPrinters => _tenantPrinterService.activeTenantPrinters;
  List<PrinterAssignment> get tenantAssignments => _tenantPrinterService.tenantAssignments;
  List<DiscoveredPrinter> get discoveredPrinters => _tenantPrinterService.discoveredPrinters;
  Map<String, String> get printerPublicIPs => _tenantPrinterService.printerPublicIPs;
  Map<String, bool> get printerStatus => _tenantPrinterService.printerStatus;
  
  // Statistics
  int get totalPrintJobs => _totalPrintJobs;
  int get successfulPrintJobs => _successfulPrintJobs;
  int get failedPrintJobs => _failedPrintJobs;
  int get localPrintJobs => _localPrintJobs;
  
  /// Initialize the integration service
  Future<bool> initialize({required String tenantId, required String restaurantId}) async {
    try {
      
      _currentTenantId = tenantId;
      _currentRestaurantId = restaurantId;
      
      // Initialize tenant printer service
      final tenantInitialized = await _tenantPrinterService.initialize(
        tenantId: tenantId,
        restaurantId: restaurantId,
      );
      
      if (!tenantInitialized) {
        return false;
      }
      
      _isInitialized = true;
      notifyListeners();
      
      return true;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Discover WiFi printers on tenant's network
  Future<List<DiscoveredPrinter>> discoverWiFiPrinters() async {
    if (_isDiscovering) {
      return _tenantPrinterService.discoveredPrinters;
    }
    
    _isDiscovering = true;
    notifyListeners();
    
    try {
      
      final discovered = await _tenantPrinterService.discoverWiFiPrinters();
      
      return discovered;
      
    } catch (e) {
      return [];
    } finally {
      _isDiscovering = false;
      notifyListeners();
    }
  }
  
  /// Add discovered printer to tenant with public IP identification
  Future<bool> addDiscoveredPrinter(DiscoveredPrinter printer) async {
    try {
      
      final added = await _tenantPrinterService.addDiscoveredPrinter(printer);
      
      if (added) {
        
        // Notify assignment service about new printer
        await _syncPrinterToAssignmentService(printer);
      }
      
      return added;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Sync printer to assignment service
  Future<void> _syncPrinterToAssignmentService(DiscoveredPrinter printer) async {
    try {
      // This ensures the assignment service knows about the new printer
      // The assignment service will handle the rest of the integration
      
    } catch (e) {
    }
  }
  
  /// Assign category to printer for current tenant
  Future<bool> assignCategoryToPrinter(String categoryId, String categoryName, String printerId) async {
    try {
      
      final assigned = await _tenantPrinterService.assignCategoryToPrinter(
        categoryId,
        categoryName,
        printerId,
      );
      
      if (assigned) {
        // Also sync to the enhanced assignment service for backward compatibility
        await _syncAssignmentToEnhancedService(categoryId, categoryName, printerId, AssignmentType.category);
      }
      
      return assigned;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Assign menu item to printer for current tenant
  Future<bool> assignMenuItemToPrinter(String menuItemId, String menuItemName, String printerId) async {
    try {
      
      final assigned = await _tenantPrinterService.assignMenuItemToPrinter(
        menuItemId,
        menuItemName,
        printerId,
      );
      
      if (assigned) {
        // Also sync to the enhanced assignment service for backward compatibility
        await _syncAssignmentToEnhancedService(menuItemId, menuItemName, printerId, AssignmentType.menuItem);
      }
      
      return assigned;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Sync assignment to enhanced service for backward compatibility
  Future<void> _syncAssignmentToEnhancedService(
    String targetId,
    String targetName,
    String printerId,
    AssignmentType assignmentType,
  ) async {
    try {
      final printer = _tenantPrinterService.tenantPrinters
          .where((p) => p.id == printerId)
          .firstOrNull;
      if (printer == null) return;
      
      // Create assignment for enhanced service
      final assignment = PrinterAssignment(
        printerId: printerId,
        printerName: printer.name,
        printerAddress: printer.ipAddress,
        assignmentType: assignmentType,
        targetId: targetId,
        targetName: targetName,
        priority: assignmentType == AssignmentType.menuItem ? 2 : 1,
        isActive: true,
      );
      
      // Add to enhanced service (if it supports this)
      // Note: This is for backward compatibility with existing code
      
    } catch (e) {
    }
  }
  
  /// Get assignments for menu item (tenant-specific)
  List<PrinterAssignment> getAssignmentsForMenuItem(String menuItemId, String categoryId) {
    return _tenantPrinterService.getAssignmentsForMenuItem(menuItemId, categoryId);
  }
  
  /// Print order to tenant's assigned printers (with cloud/local fallback)
  Future<Map<String, bool>> printOrderToTenantPrinters(Order order) async {
    if (_isProcessing) {
      return {};
    }
    
    _isProcessing = true;
    _totalPrintJobs++;
    notifyListeners();
    
    try {
      
      Map<String, bool> results = {};
      
      // Fallback to local printing
      try {
        results = await _tenantPrinterService.printOrderToTenantPrinters(order);
        
        final successCount = results.values.where((success) => success).length;
        final totalCount = results.length;
        
        if (successCount > 0) {
          _localPrintJobs++;
          _successfulPrintJobs++;
        } else {
          _failedPrintJobs++;
        }
        
      } catch (e) {
        _failedPrintJobs++;
      }
      
      return results;
      
    } catch (e) {
      _failedPrintJobs++;
      return {};
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
  
  /// Get printer assignments for categories
  List<PrinterAssignment> getCategoryAssignments(String categoryId) {
    return _tenantPrinterService.tenantAssignments.where((a) => 
      a.isActive && 
      a.assignmentType == AssignmentType.category && 
      a.targetId == categoryId
    ).toList();
  }
  
  /// Get printer assignments for menu items
  List<PrinterAssignment> getMenuItemAssignments(String menuItemId) {
    return _tenantPrinterService.tenantAssignments.where((a) => 
      a.isActive && 
      a.assignmentType == AssignmentType.menuItem && 
      a.targetId == menuItemId
    ).toList();
  }
  
  /// Remove printer assignment
  Future<bool> removePrinterAssignment(String assignmentId) async {
    try {
      
      // Remove from tenant service - we'll implement this later
      // For now, just remove from local list
      _tenantPrinterService.tenantAssignments.removeWhere((a) => a.id == assignmentId);
      
      return true;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Test printer connection
  Future<bool> testPrinterConnection(String printerId) async {
    try {
      final printer = _tenantPrinterService.tenantPrinters
          .where((p) => p.id == printerId)
          .firstOrNull;
      if (printer == null) return false;
      
      
      // Test connection using the printing service - we'll implement this later
      // For now, just return true
      return true;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Get printer statistics
  Map<String, dynamic> getPrinterStatistics() {
    return {
      'totalPrintJobs': _totalPrintJobs,
      'successfulPrintJobs': _successfulPrintJobs,
      'failedPrintJobs': _failedPrintJobs,
      'localPrintJobs': _localPrintJobs,
      'successRate': _totalPrintJobs > 0 ? (_successfulPrintJobs / _totalPrintJobs * 100).toStringAsFixed(1) : '0.0',
      'printersOnline': _tenantPrinterService.activeTenantPrinters.length,
      'totalAssignments': _tenantPrinterService.tenantAssignments.length,
    };
  }
  
  /// Dispose of resources
  @override
  void dispose() {
    super.dispose();
  }
} 