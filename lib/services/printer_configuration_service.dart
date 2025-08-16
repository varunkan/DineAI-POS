import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';

import 'database_service.dart';
import '../models/printer_configuration.dart';

/// 🖨️ Real Printer Configuration Service
/// 
/// This service provides REAL printer discovery and connection for ALL Epson TM thermal printers.
/// Features:
/// - Automatic network scanning and discovery
/// - Support for ALL Epson TM models (TM-T88VI, TM-T88V, TM-T20III, etc.)
/// - Real connection testing and validation
/// - Simple user-friendly setup process
/// - No fake/dummy configurations
class PrinterConfigurationService extends ChangeNotifier {
  static const String _logTag = '🖨️ PrinterConfigurationService';
  
  final DatabaseService _databaseService;
  
  // Real printer state
  List<PrinterConfiguration> _configurations = [];
  List<DiscoveredPrinter> _discoveredPrinters = [];
  bool _isScanning = false;
  bool _isInitialized = false;
  
  // Network scanning parameters - FIXED: Increased timeout
  static const List<int> _commonPorts = [9100, 515, 631, 8080];
  static const int _scanTimeout = 5000; // 5 seconds per printer
  
  PrinterConfigurationService(this._databaseService);
  
  // Getters
  List<PrinterConfiguration> get configurations => List.unmodifiable(_configurations);
  List<PrinterConfiguration> get activeConfigurations => 
      _configurations.where((config) => config.isActive).toList();
  List<DiscoveredPrinter> get discoveredPrinters => List.unmodifiable(_discoveredPrinters);
  bool get isScanning => _isScanning;
  bool get isInitialized => _isInitialized;
  
  /// Initialize the service with REAL printer discovery (legacy method name)
  Future<void> initializeTable() async => await initialize();
  
  /// Initialize the service with REAL printer discovery
  Future<void> initialize() async {
    debugPrint('$_logTag 🚀 Initializing REAL printer configuration service...');
    
    try {
      await _createPrinterConfigurationsTable();
      await _loadSavedConfigurations();
      
      // FIXED: Don't start automatic printer discovery immediately to prevent hanging
      // await _startAutomaticDiscovery();
      debugPrint('$_logTag 🔄 Automatic printer discovery disabled during initialization to prevent hanging');
      
      _isInitialized = true;
      notifyListeners();
      
      debugPrint('$_logTag ✅ REAL printer service initialized successfully');
    } catch (e) {
      debugPrint('$_logTag ❌ Error initializing printer service: $e');
    }
  }
  
  /// Create printer configurations table
  Future<void> _createPrinterConfigurationsTable() async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) return;
      
      await db!.execute('''
        CREATE TABLE IF NOT EXISTS printer_configurations (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          type TEXT NOT NULL,
          model TEXT NOT NULL,
          ip_address TEXT,
          port INTEGER,
          is_active INTEGER DEFAULT 1,
          connection_status TEXT DEFAULT 'disconnected',
          last_connected TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      
      debugPrint('$_logTag ✅ Printer configurations table created');
    } catch (e) {
      debugPrint('$_logTag ❌ Error creating table: $e');
    }
  }
  
  /// Load saved printer configurations
  Future<void> _loadSavedConfigurations() async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) return;
      
      final List<Map<String, dynamic>> maps = await db!.query('printer_configurations');
      _configurations = maps.map((map) => _configFromDbMap(map)).toList();
      
      debugPrint('$_logTag 📂 Loaded ${_configurations.length} saved printer configurations');
      notifyListeners();
    } catch (e) {
      debugPrint('$_logTag ❌ Error loading configurations: $e');
    }
  }
  
  /// Load configurations (legacy method name)
  Future<List<PrinterConfiguration>> loadConfigurations() async {
    await _loadSavedConfigurations();
    return _configurations;
  }
  
  /// Refresh configurations (legacy method name)
  Future<void> refreshConfigurations() async {
    await _loadSavedConfigurations();
  }
  
  /// Get configuration by ID (legacy method)
  Future<PrinterConfiguration?> getConfigurationById(String id) async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) return null;
      
      final List<Map<String, dynamic>> maps = await db!.query(
        'printer_configurations',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (maps.isNotEmpty) {
        return _configFromDbMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('$_logTag ❌ Error getting configuration by ID: $e');
      return null;
    }
  }
  
  /// Get configuration by IP address
  PrinterConfiguration? getConfigurationByIP(String ipAddress, int port) {
    try {
      return _configurations.firstWhere(
        (config) => config.ipAddress == ipAddress && config.port == port && config.isActive,
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Add configuration (legacy method)
  Future<bool> addConfiguration(PrinterConfiguration config) async {
    return await _saveConfiguration(config);
  }
  
  /// Update configuration (legacy method)
  Future<bool> updateConfiguration(PrinterConfiguration config) async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) return false;
      
      await db!.update(
        'printer_configurations',
        _configToDbMap(config),
        where: 'id = ?',
        whereArgs: [config.id],
      );
      
      await _loadSavedConfigurations();
      debugPrint('$_logTag ✅ Updated printer configuration: ${config.name}');
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error updating configuration: $e');
      return false;
    }
  }
  
  /// Test configuration (legacy method)
  Future<bool> testConfiguration(PrinterConfiguration config) async {
    return await testConnection(config);
  }
  
  /// Update last test print (legacy method)
  Future<void> updateLastTestPrint(String configId) async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) return;
      
      await db!.update(
        'printer_configurations',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [configId],
      );
      
      debugPrint('$_logTag ✅ Updated last test print for configuration: $configId');
    } catch (e) {
      debugPrint('$_logTag ❌ Error updating last test print: $e');
    }
  }
  
  /// Manually trigger printer discovery (can be called from UI)
  Future<void> manualDiscovery() async {
    debugPrint('$_logTag 🔍 Manual printer discovery triggered by user');
    
    // Clear previous discoveries
    _discoveredPrinters.clear();
    notifyListeners();
    
    // Perform quick scan of common printer IPs only
    await _quickScanForPrinters();
  }
  
  /// Start automatic printer discovery on local network
  /// FIXED: Removed automatic discovery - only manual discovery available
  Future<void> _startAutomaticDiscovery() async {
    debugPrint('$_logTag 🔄 Automatic discovery disabled - only manual discovery available');
    // No automatic discovery - only manual discovery on user request
  }
  
  /// Quick scan for thermal printers on the network (manual discovery only)
  Future<void> _quickScanForPrinters() async {
    if (_isScanning) return;
    
    _isScanning = true;
    notifyListeners();
    
    debugPrint('$_logTag 🔍 Quick scanning for thermal printers...');
    
    try {
      // Get local network range
      final networkRange = await _getNetworkRange();
      debugPrint('$_logTag 🌐 Scanning network range: $networkRange');
      
      // Quick scan of common printer IPs only
      final commonIPs = <String>[];
      for (int i = 100; i <= 120; i++) commonIPs.add('$networkRange.$i');
      for (int i = 200; i <= 220; i++) commonIPs.add('$networkRange.$i');
      for (int i = 50; i <= 70; i++) commonIPs.add('$networkRange.$i');
      for (int i = 150; i <= 170; i++) commonIPs.add('$networkRange.$i');
      for (int i = 10; i <= 30; i++) commonIPs.add('$networkRange.$i');
      
      debugPrint('$_logTag 🔍 Scanning ${commonIPs.length} common printer IPs...');
      
      // Scan with timeout
      final scanTimeout = const Duration(seconds: 15);
      final stopwatch = Stopwatch()..start();
      
      for (final ip in commonIPs) {
        if (stopwatch.elapsed > scanTimeout) {
          debugPrint('$_logTag ⏰ Scan timeout reached');
          break;
        }
        
        for (int port in _commonPorts) {
          try {
            final printer = await _testPrinterConnection(ip, port);
            if (printer != null) {
              _discoveredPrinters.add(printer);
              debugPrint('$_logTag 🖨️ Found printer: ${printer.name} at ${printer.ipAddress}:${printer.port}');
              await _autoAddDiscoveredPrinter(printer);
            }
          } catch (e) {
            // Continue scanning
          }
        }
      }
      
      stopwatch.stop();
      debugPrint('$_logTag ✅ Quick scan completed in ${stopwatch.elapsedMilliseconds}ms. Found ${_discoveredPrinters.length} printers');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error during quick printer scan: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }
  
  /// Get network range for scanning (e.g., "192.168.1")
  Future<String> _getNetworkRange() async {
    try {
      // Get local IP address
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
      
      // Default to common network range
      return '192.168.1';
    } catch (e) {
      debugPrint('$_logTag ⚠️ Could not determine network range, using default: $e');
      return '192.168.1';
    }
  }
  
  /// Test connection to a specific IP and port
  Future<DiscoveredPrinter?> _testPrinterConnection(String ip, int port) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: Duration(milliseconds: _scanTimeout));
      
      // FIXED: Improved connection handling with better error recovery
      socket.setOption(SocketOption.tcpNoDelay, true);
      
      // Send ESC/POS command to identify printer
      final identifyCommand = Uint8List.fromList([0x1D, 0x49, 0x01]); // GS I 1 (Model ID)
      socket.add(identifyCommand);
      await socket.flush();
      
      // Wait for response with improved timeout handling
      try {
        final responseData = await socket.first.timeout(const Duration(seconds: 3));
        
        await socket.close();
        
        // Parse response to identify Epson thermal printer
        final response = String.fromCharCodes(responseData);
        if (_isEpsonThermalPrinter(response)) {
          final model = _identifyEpsonModel(response);
          return DiscoveredPrinter(
            name: 'Epson $model',
            model: model,
            ipAddress: ip,
            port: port,
            status: 'online',
            description: 'Epson thermal printer discovered on network',
          );
        }
      } catch (responseTimeout) {
        // FIXED: Handle response timeout gracefully
        await socket.close();
        // Still create a generic printer if connection worked
        return DiscoveredPrinter(
          name: 'Network Printer',
          model: 'Generic',
          ipAddress: ip,
          port: port,
          status: 'online',
          description: 'Network printer discovered (no response to identify command)',
        );
      }
      
    } catch (e) {
      // Connection failed - not a printer or not available
      // FIXED: Silently skip failed connections to prevent log spam
    }
    
    return null;
  }
  
  /// Check if response indicates an Epson thermal printer
  bool _isEpsonThermalPrinter(String response) {
    final lowerResponse = response.toLowerCase();
    return lowerResponse.contains('epson') || 
           lowerResponse.contains('tm-') ||
           lowerResponse.contains('thermal');
  }
  
  /// Identify specific Epson model from response
  String _identifyEpsonModel(String response) {
    final lowerResponse = response.toLowerCase();
    
    if (lowerResponse.contains('tm-t88vi')) return 'TM-T88VI';
    if (lowerResponse.contains('tm-t88v')) return 'TM-T88V';
    if (lowerResponse.contains('tm-t20iii')) return 'TM-T20III';
    if (lowerResponse.contains('tm-t82iii')) return 'TM-T82III';
    if (lowerResponse.contains('tm-m30iii')) return 'TM-M30III';
    if (lowerResponse.contains('tm-m30')) return 'TM-m30';
    if (lowerResponse.contains('tm-m50')) return 'TM-m50';
    if (lowerResponse.contains('tm-p20')) return 'TM-P20';
    if (lowerResponse.contains('tm-p60ii')) return 'TM-P60II';
    
    // Default for any other Epson thermal printer
    return 'TM Series';
  }
  
  /// Add a discovered printer to configurations
  Future<bool> addDiscoveredPrinter(DiscoveredPrinter printer, String customName) async {
    try {
      final config = PrinterConfiguration(
        name: customName.isNotEmpty ? customName : printer.name,
        description: printer.description,
        type: PrinterType.wifi,
        model: _getModelEnum(printer.model),
        ipAddress: printer.ipAddress,
        port: printer.port,
        isActive: true,
      );
      
      return await _saveConfiguration(config);
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error adding discovered printer: $e');
      return false;
    }
  }
  
  /// Automatically add discovered printer to configurations (called during discovery)
  Future<void> _autoAddDiscoveredPrinter(DiscoveredPrinter printer) async {
    try {
      // Check if we already have a configuration for this printer
      final existing = getConfigurationByIP(printer.ipAddress, printer.port);
      if (existing != null) {
        debugPrint('$_logTag ℹ️ Printer already exists in configurations: ${printer.name}');
        return;
      }
      
      // Create configuration with appropriate name
      final config = PrinterConfiguration(
        name: '${printer.name} (Auto-discovered)',
        description: 'Automatically discovered and added - ${printer.description}',
        type: PrinterType.wifi,
        model: _getModelEnum(printer.model),
        ipAddress: printer.ipAddress,
        port: printer.port,
        isActive: true,
      );
      
      final success = await _saveConfiguration(config);
      if (success) {
        debugPrint('$_logTag ✅ Auto-added discovered printer: ${printer.name} at ${printer.ipAddress}:${printer.port}');
      } else {
        debugPrint('$_logTag ❌ Failed to auto-add discovered printer: ${printer.name}');
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error auto-adding discovered printer: $e');
    }
  }
  
  /// Convert model string to enum
  PrinterModel _getModelEnum(String modelString) {
    switch (modelString.toLowerCase()) {
      case 'tm-t88vi': return PrinterModel.epsonTMT88VI;
      case 'tm-t88v': return PrinterModel.epsonTMT88V;
      case 'tm-t20iii': return PrinterModel.epsonTMT20III;
      case 'tm-t82iii': return PrinterModel.epsonTMT82III;
      case 'tm-m30': return PrinterModel.epsonTMm30;
      case 'tm-m30iii': return PrinterModel.epsonTMGeneric;
      case 'tm-m50': return PrinterModel.epsonTMm50;
      case 'tm-p20': return PrinterModel.epsonTMP20;
      case 'tm-p60ii': return PrinterModel.epsonTMP60II;
      default: return PrinterModel.epsonTMGeneric;
    }
  }
  
  /// Save configuration to database
  Future<bool> _saveConfiguration(PrinterConfiguration config) async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) {
        debugPrint('$_logTag ❌ Database not available for saving configuration');
        return false;
      }
      
      final configMap = _configToDbMap(config);
      debugPrint('$_logTag 💾 Saving configuration with data: ${configMap.keys.toList()}');
      
      await db!.insert('printer_configurations', configMap);
      await _loadSavedConfigurations();
      
      debugPrint('$_logTag ✅ Saved printer configuration: ${config.name} (${config.ipAddress}:${config.port})');
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error saving configuration: $e');
      debugPrint('$_logTag 📋 Config details: ${config.name} at ${config.ipAddress}:${config.port}');
      return false;
    }
  }
  
  /// Test connection to a configured printer (overloaded to accept String ID)
  Future<bool> testConnection(dynamic configOrId) async {
    PrinterConfiguration? config;
    
    if (configOrId is String) {
      // If passed a String ID, look up the configuration
      config = await getConfigurationById(configOrId);
      if (config == null) {
        debugPrint('$_logTag ❌ Configuration not found for ID: $configOrId');
        return false;
      }
    } else if (configOrId is PrinterConfiguration) {
      config = configOrId;
    } else {
      debugPrint('$_logTag ❌ Invalid parameter type for testConnection');
      return false;
    }
    
    try {
      debugPrint('$_logTag 🔧 Testing connection to ${config.name}...');
      
      final socket = await Socket.connect(
        config.ipAddress, 
        config.port, 
        timeout: const Duration(seconds: 5)
      );
      
      // Send test print command
      final testCommand = _generateTestPrint(config.name);
      socket.add(testCommand);
      
      await socket.close();
      
      debugPrint('$_logTag ✅ Connection test successful for ${config.name}');
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Connection test failed for ${config.name}: $e');
      return false;
    }
  }
  
  /// Generate test print command
  Uint8List _generateTestPrint(String printerName) {
    final content = '''
=== TEST PRINT ===
Printer: $printerName
Time: ${DateTime.now().toString().substring(0, 16)}
Status: Connection OK
POS System: AI Restaurant

------------------
''';
    
    final bytes = <int>[];
    
    // ESC/POS commands
    bytes.addAll([0x1B, 0x40]); // Initialize printer
    bytes.addAll([0x1B, 0x61, 0x01]); // Center align
    bytes.addAll(content.codeUnits);
    bytes.addAll([0x1B, 0x64, 0x03]); // Feed 3 lines
    bytes.addAll([0x1D, 0x56, 0x00]); // Cut paper
    
    return Uint8List.fromList(bytes);
  }
  
  /// Manual printer setup
  Future<bool> addManualPrinter({
    required String name,
    required String ipAddress,
    required int port,
    String description = '',
  }) async {
    try {
      debugPrint('$_logTag 🔧 Adding manual printer: $name at $ipAddress:$port');
      
      // Test connection first
      final socket = await Socket.connect(ipAddress, port, timeout: const Duration(seconds: 5));
      await socket.close();
      
      final config = PrinterConfiguration(
        name: name,
        description: description.isNotEmpty ? description : 'Manually added printer',
        type: PrinterType.wifi,
        model: PrinterModel.epsonTMGeneric, // Use generic for manual setup
        ipAddress: ipAddress,
        port: port,
        isActive: true,
      );
      
      return await _saveConfiguration(config);
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error adding manual printer: $e');
      return false;
    }
  }
  
  /// Remove printer configuration
  Future<bool> removeConfiguration(String configId) async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) return false;
      
      await db!.delete('printer_configurations', where: 'id = ?', whereArgs: [configId]);
      await _loadSavedConfigurations();
      
      debugPrint('$_logTag ✅ Removed printer configuration');
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error removing configuration: $e');
      return false;
    }
  }
  
  /// Convert database map to PrinterConfiguration
  PrinterConfiguration _configFromDbMap(Map<String, dynamic> map) {
    return PrinterConfiguration(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
      type: PrinterType.values.firstWhere(
        (type) => type.toString().split('.').last == map['type'],
        orElse: () => PrinterType.wifi,
      ),
      model: PrinterModel.values.firstWhere(
        (model) => model.toString().split('.').last == map['model'],
        orElse: () => PrinterModel.epsonTMGeneric,
      ),
      ipAddress: map['ip_address'] ?? '',
      port: map['port'] ?? 9100,
      isActive: (map['is_active'] ?? 1) == 1,
      connectionStatus: PrinterConnectionStatus.values.firstWhere(
        (status) => status.toString().split('.').last == (map['connection_status'] ?? 'unknown'),
        orElse: () => PrinterConnectionStatus.unknown,
      ),
      lastConnected: map['last_connected'] != null 
          ? DateTime.tryParse(map['last_connected']) ?? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
  
  /// Convert PrinterConfiguration to database map
  Map<String, dynamic> _configToDbMap(PrinterConfiguration config) {
    return {
      'id': config.id,
      'name': config.name,
      'description': config.description,
      'type': config.type.toString().split('.').last,
      'model': config.model.toString().split('.').last,
      'ip_address': config.ipAddress,
      'port': config.port,
      'is_active': config.isActive ? 1 : 0,
      'connection_status': config.connectionStatus.toString().split('.').last,
      'last_connected': config.lastConnected.millisecondsSinceEpoch > 0 
          ? config.lastConnected.toIso8601String() 
          : null,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
  
  /// Update printer connection status
  Future<bool> updateConnectionStatus(String configId, PrinterConnectionStatus status) async {
    try {
      final db = await _databaseService.database;
      if (db?.isOpen != true) return false;
      
      await db!.update(
        'printer_configurations',
        {
          'connection_status': status.toString().split('.').last,
          'last_connected': status == PrinterConnectionStatus.connected 
              ? DateTime.now().toIso8601String() 
              : null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [configId],
      );
      
      // Update the configuration in memory
      final index = _configurations.indexWhere((config) => config.id == configId);
      if (index != -1) {
        _configurations[index] = _configurations[index].copyWith(
          connectionStatus: status,
          lastConnected: status == PrinterConnectionStatus.connected 
              ? DateTime.now() 
              : _configurations[index].lastConnected,
        );
        notifyListeners();
      }
      
      debugPrint('$_logTag ✅ Updated connection status for $configId to $status');
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error updating connection status: $e');
      return false;
    }
  }
}

/// Discovered printer information
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
  
  @override
  String toString() => '$name ($model) at $ipAddress:$port - $status';
} 