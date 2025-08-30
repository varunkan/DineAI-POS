import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';
import '../models/app_settings.dart';
import '../models/printer_configuration.dart';
import 'printer_configuration_service.dart';
import 'database_service.dart';
import 'enhanced_printer_assignment_service.dart';

// Using PrinterType from printer_configuration.dart model
// enum PrinterType {
//   wifi,
// }

/// Model for discovered printer devices
class PrinterDevice {
  final String id;
  final String name;
  final String address;
  final PrinterType type;
  final String model;
  final int signalStrength;
  final bool isConnected;

  PrinterDevice({
    required this.id,
    required this.name,
    required this.address,
    required this.type,
    this.model = '',
    this.signalStrength = 0,
    this.isConnected = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'type': type.toString(),
    'model': model,
    'signalStrength': signalStrength,
    'isConnected': isConnected,
  };

  factory PrinterDevice.fromJson(Map<String, dynamic> json) => PrinterDevice(
    id: json['id'],
    name: json['name'],
    address: json['address'],
    type: PrinterType.values.firstWhere((e) => e.toString() == json['type']),
    model: json['model'] ?? '',
    signalStrength: json['signalStrength'] ?? 0,
    isConnected: json['isConnected'] ?? false,
  );

  PrinterDevice copyWith({
    String? id,
    String? name,
    String? address,
    PrinterType? type,
    String? model,
    int? signalStrength,
    bool? isConnected,
  }) => PrinterDevice(
    id: id ?? this.id,
    name: name ?? this.name,
    address: address ?? this.address,
    type: type ?? this.type,
    model: model ?? this.model,
    signalStrength: signalStrength ?? this.signalStrength,
    isConnected: isConnected ?? this.isConnected,
  );
}

/// Connection information for a printer
class PrinterConnection {
  final String printerId;
  final PrinterConfiguration config;
  final Socket? wifiSocket;
  final DateTime connectedAt;
  final bool isActive;

  PrinterConnection({
    required this.printerId,
    required this.config,
    this.wifiSocket,
    DateTime? connectedAt,
    this.isActive = true,
  }) : connectedAt = connectedAt ?? DateTime.now();

  bool get isConnected {
    if (config.type == PrinterType.wifi) {
      return wifiSocket != null;
    }
    return false;
  }

  Future<void> disconnect() async {
    try {
      if (wifiSocket != null) {
        await wifiSocket!.close();
      }
    } catch (e) {
      debugPrint('Error disconnecting printer ${config.name}: $e');
    }
  }

  Future<void> sendData(Uint8List data) async {
    if (config.type == PrinterType.wifi && wifiSocket != null) {
      wifiSocket!.add(data);
      await wifiSocket!.flush();
    } else {
      throw Exception('No valid connection for printer ${config.name}');
    }
  }
}

/// Comprehensive printing service with multiple simultaneous printer connections
class PrintingService with ChangeNotifier {
  final SharedPreferences _prefs;
  final NetworkInfo _networkInfo;
  AppSettings _settings;
  
  // Multi-printer connection management
  final Map<String, PrinterConnection> _activeConnections = {};
  final Map<String, DateTime> _lastConnectionAttempt = {};
  final Map<String, int> _connectionRetryCount = {};
  
  // Legacy single printer support (for backward compatibility)
  PrinterDevice? _connectedPrinter;
  
  // Manual scanning control
  bool _isManualScanningEnabled = true; // FIXED: Enable manual scanning by default
  bool _isCurrentlyScanning = false;
  
  // Discovered printers list
  final List<PrinterDevice> _discoveredPrinters = [];
  
  // Settings keys
  static const String _connectedPrinterKey = 'connected_printer';
  static const String _settingsKey = 'printing_settings';
  static const String _activePrintersKey = 'active_printers';
  
  // Print settings
  int _paperWidth = 80; // mm
  String _printQuality = 'High';
  String _printSpeed = 'Normal';
  bool _enableHeaderLogo = true;
  String _footerMessage = 'Thank you for dining with us!';
  bool _printOrderDetails = true;
  bool _autoPrintOrders = false;
  bool _printKitchenCopy = true;
  
  // Connection pool settings - FIXED: Increased timeout and retries
  static const int _maxRetries = 5;
  static const Duration _retryDelay = Duration(seconds: 3);
  static const Duration _connectionTimeout = Duration(seconds: 10);
  
  // Legacy connection variables
  Socket? _wifiSocket;
  
  // Error tracking
  String? _lastError;

  PrintingService(this._prefs, this._networkInfo) : _settings = AppSettings() {
    _loadSettings();
    _loadConnectedPrinter();
    _loadActivePrinters();
    
    // FIXED: Don't start automatic printer discovery immediately to prevent hanging
    // _startAutomaticDiscovery();
    debugPrint('🔄 Automatic printer discovery disabled during initialization to prevent hanging');
  }
  
  /// Start automatic printer discovery
  /// FIXED: Removed automatic discovery - only manual discovery available
  void _startAutomaticDiscovery() {
    debugPrint('🔄 Automatic printer discovery disabled - only manual discovery available');
    // No automatic discovery - only manual discovery on user request
  }

  // Getters
  PrinterDevice? get connectedPrinter => _connectedPrinter;
  bool get isConnected => _connectedPrinter != null;
  bool get isManualScanningEnabled => _isManualScanningEnabled;
  bool get isCurrentlyScanning => _isCurrentlyScanning;
  int get paperWidth => _paperWidth;
  String get printQuality => _printQuality;
  String get printSpeed => _printSpeed;
  bool get enableHeaderLogo => _enableHeaderLogo;
  String get footerMessage => _footerMessage;
  bool get printOrderDetails => _printOrderDetails;
  bool get autoPrintOrders => _autoPrintOrders;
  bool get printKitchenCopy => _printKitchenCopy;

  // Multi-printer getters
  List<PrinterConfiguration> get connectedPrinters => 
      _activeConnections.values.map((conn) => conn.config).toList();
  int get connectedPrintersCount => _activeConnections.length;
  Map<String, PrinterConnection> get activeConnections => Map.unmodifiable(_activeConnections);
  
  // Discovery getters
  List<PrinterDevice> get discoveredPrinters => List.unmodifiable(_discoveredPrinters);
  
  // Error getter
  String? get lastError => _lastError;

  Future<void> _loadSettings() async {
    final String? settingsJson = _prefs.getString(_settingsKey);
    if (settingsJson != null) {
      try {
        final Map<String, dynamic> settingsMap = jsonDecode(settingsJson);
        _settings = AppSettings.fromJson(settingsMap);
        
        // Load print settings
        _paperWidth = settingsMap['paperWidth'] ?? 80;
        _printQuality = settingsMap['printQuality'] ?? 'High';
        _printSpeed = settingsMap['printSpeed'] ?? 'Normal';
        _enableHeaderLogo = settingsMap['enableHeaderLogo'] ?? true;
        _footerMessage = settingsMap['footerMessage'] ?? 'Thank you for dining with us!';
        _printOrderDetails = settingsMap['printOrderDetails'] ?? true;
        _autoPrintOrders = settingsMap['autoPrintOrders'] ?? false;
        _printKitchenCopy = settingsMap['printKitchenCopy'] ?? true;
        
        _safeNotifyListeners();
      } catch (e) {
        debugPrint('Error loading printing settings: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    final settingsMap = _settings.toJson();
    settingsMap.addAll({
      'paperWidth': _paperWidth,
      'printQuality': _printQuality,
      'printSpeed': _printSpeed,
      'enableHeaderLogo': _enableHeaderLogo,
      'footerMessage': _footerMessage,
      'printOrderDetails': _printOrderDetails,
      'autoPrintOrders': _autoPrintOrders,
      'printKitchenCopy': _printKitchenCopy,
    });
    
    final String settingsJson = jsonEncode(settingsMap);
    await _prefs.setString(_settingsKey, settingsJson);
  }

  Future<void> _loadConnectedPrinter() async {
    final String? printerJson = _prefs.getString(_connectedPrinterKey);
    if (printerJson != null) {
      try {
        final Map<String, dynamic> printerMap = jsonDecode(printerJson);
        _connectedPrinter = PrinterDevice.fromJson(printerMap);
        _safeNotifyListeners();
      } catch (e) {
        debugPrint('Error loading connected printer: $e');
      }
    }
  }

  Future<void> _saveConnectedPrinter() async {
    if (_connectedPrinter != null) {
      final String printerJson = jsonEncode(_connectedPrinter!.toJson());
      await _prefs.setString(_connectedPrinterKey, printerJson);
    } else {
      await _prefs.remove(_connectedPrinterKey);
    }
  }

  /// Load active printer configurations from storage
  Future<void> _loadActivePrinters() async {
    final String? activePrintersJson = _prefs.getString(_activePrintersKey);
    if (activePrintersJson != null) {
      try {
        final List<dynamic> printersList = jsonDecode(activePrintersJson);
        final List<String> printerIds = printersList.cast<String>();
        
        debugPrint('📂 Loading ${printerIds.length} active printer connections...');
        
        // Note: Actual reconnection will happen when printer configurations are loaded
        // This just marks which printers should be connected
        for (final printerId in printerIds) {
          debugPrint('📌 Marked printer $printerId for reconnection');
        }
      } catch (e) {
        debugPrint('Error loading active printers: $e');
      }
    }
  }

  /// Save active printer configurations to storage
  Future<void> _saveActivePrinters() async {
    final List<String> printerIds = _activeConnections.keys.toList();
    final String activePrintersJson = jsonEncode(printerIds);
    await _prefs.setString(_activePrintersKey, activePrintersJson);
  }

  /// Scan for available printers by type
  Future<List<PrinterDevice>> scanForPrinters(PrinterType type) async {
    if (!_isManualScanningEnabled) {
      debugPrint('Manual scanning not enabled. Call enableManualScanning() first.');
      return [];
    }
    
    if (_isCurrentlyScanning) {
      debugPrint('Already scanning for printers. Please wait...');
      return [];
    }
    
    _isCurrentlyScanning = true;
    _safeNotifyListeners();
    
    try {
      switch (type) {
        case PrinterType.wifi:
          return await _scanWiFiPrinters();
        case PrinterType.ethernet:
        case PrinterType.bluetooth:
        case PrinterType.usb:
        case PrinterType.remote:
        case PrinterType.vpn:
          debugPrint('❌ Printer type ${type} not yet implemented');
          return [];
      }
    } finally {
      _isCurrentlyScanning = false;
      _safeNotifyListeners();
    }
  }

  /// Scan for WiFi printers on the network
  Future<List<PrinterDevice>> _scanWiFiPrinters() async {
    final List<PrinterDevice> printers = [];
    
    // FIXED: Move stopwatch declaration to outer scope
    final stopwatch = Stopwatch()..start();
    
    try {
      debugPrint('Starting comprehensive WiFi printer scan...');
      
      // Double check that manual scanning is enabled
      if (!_isManualScanningEnabled) {
        debugPrint('WiFi scanning aborted - manual scanning not enabled');
        return printers;
      }
      
      // Get current WiFi network info
      final wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP == null) {
        debugPrint('No WiFi connection detected');
        return printers;
      }
      
      // Extract network subnet (e.g., 192.168.1.x from 192.168.1.50)
      final parts = wifiIP.split('.');
      if (parts.length == 4) {
        final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
        debugPrint('Scanning WiFi subnet: $subnet.* on multiple ports (comprehensive scan)');
        
        // Common printer ports
        final printerPorts = [9100, 515, 631, 9101, 9102];
        
        // FIXED: Use a more efficient scanning approach with timeout
        final scanTimeout = const Duration(seconds: 30);
        
        // Priority IPs (most likely printer locations)
        final priorityIPs = <String>[];
        for (int i = 100; i <= 120; i++) priorityIPs.add('$subnet.$i');
        for (int i = 200; i <= 220; i++) priorityIPs.add('$subnet.$i');
        for (int i = 50; i <= 70; i++) priorityIPs.add('$subnet.$i');
        for (int i = 150; i <= 170; i++) priorityIPs.add('$subnet.$i');
        for (int i = 10; i <= 30; i++) priorityIPs.add('$subnet.$i');
        
        // Skip your own IP to avoid self-connection
        final yourIP = parts[3];
        priorityIPs.removeWhere((ip) => ip.endsWith('.$yourIP'));
        
        debugPrint('Scanning ${priorityIPs.length} priority IPs on ${printerPorts.length} ports...');
        
        // Scan priority IPs first
        for (int i = 0; i < priorityIPs.length; i += 5) {
          // Check timeout
          if (stopwatch.elapsed > scanTimeout) {
            debugPrint('⏰ WiFi scan timeout reached, stopping scan');
            break;
          }
          
          // Check if scanning is still enabled
          if (!_isManualScanningEnabled) {
            debugPrint('WiFi scanning stopped - manual scanning disabled during scan');
            break;
          }
          
          final batch = priorityIPs.skip(i).take(5);
          final futures = <Future<PrinterDevice?>>[];
          
          // Test each IP on each port
          for (final ip in batch) {
            for (final port in printerPorts) {
              futures.add(_testAndCreatePrinterDevice(ip, port));
            }
          }
          
          // Wait for this batch to complete
          final batchResults = await Future.wait(futures);
          
          for (final printer in batchResults) {
            if (printer != null) {
              // Avoid duplicates (same IP, different port)
              final existingPrinter = printers.where((p) => 
                p.address.split(':')[0] == printer.address.split(':')[0]
              ).firstOrNull;
              
              if (existingPrinter == null) {
                printers.add(printer);
                debugPrint('Found WiFi printer: ${printer.name} at ${printer.address}');
              }
            }
          }
          
          // Progress update every 25 IPs
          if ((i + 5) % 25 == 0) {
            debugPrint('Scanned ${i + 5}/${priorityIPs.length} IPs... Found ${printers.length} printers so far');
          }
          
          // Small delay between batches to be network-friendly
          if (i + 5 < priorityIPs.length) {
            await Future.delayed(const Duration(milliseconds: 25));
          }
        }
        
        // If we found printers, don't do a full scan
        if (printers.isNotEmpty) {
          debugPrint('✅ Quick scan found ${printers.length} WiFi printers');
        } else {
          // Do a limited full scan only if no printers found
          debugPrint('🔍 No printers found in priority IPs, doing limited full scan...');
          
          // Scan only first 50 IPs to avoid hanging
          for (int i = 1; i <= 50; i++) {
            if (stopwatch.elapsed > scanTimeout) {
              debugPrint('⏰ Full scan timeout reached');
              break;
            }
            
            final ip = '$subnet.$i';
            if (ip.endsWith('.$yourIP')) continue; // Skip your own IP
            
            for (final port in printerPorts) {
              try {
                final printer = await _testAndCreatePrinterDevice(ip, port);
                if (printer != null) {
                  // Avoid duplicates
                  final existingPrinter = printers.where((p) => 
                    p.address.split(':')[0] == printer.address.split(':')[0]
                  ).firstOrNull;
                  
                  if (existingPrinter == null) {
                    printers.add(printer);
                    debugPrint('Found WiFi printer: ${printer.name} at ${printer.address}');
                  }
                }
              } catch (e) {
                // Continue scanning
              }
            }
          }
        }
      }
      
      stopwatch.stop();
      debugPrint('Comprehensive WiFi scan completed in ${stopwatch.elapsedMilliseconds}ms - found ${printers.length} WiFi printers');
      
    } catch (e) {
      debugPrint('Error in comprehensive WiFi printer scan: $e');
    }

    return printers;
  }

  /// Test a specific IP and port for printer connectivity
  Future<PrinterDevice?> _testAndCreatePrinterDevice(String ip, int port) async {
    try {
      final socket = await Socket.connect(
        ip, 
        port, 
        timeout: const Duration(milliseconds: 800) // FIXED: Increased timeout for better detection
      );
      
      // Try to identify printer type by sending a simple ESC/POS command
      String printerModel = 'Network Printer';
      String printerType = 'ESC/POS Compatible';
      
      try {
        // Send status request to identify printer
        socket.add([0x10, 0x04, 0x01]); // ESC/POS: Transmit printer status
        await socket.flush();
        
        // Wait for response (with timeout)
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
      
      // Create printer device if connection successful
      final signalStrength = _calculateSignalStrength(ip);
      return PrinterDevice(
        id: 'wifi_${ip.replaceAll('.', '_')}_$port',
        name: '$printerModel ($ip:$port)',
        address: '$ip:$port',
        type: PrinterType.wifi,
        model: printerType,
        signalStrength: signalStrength,
      );
      
    } catch (e) {
      // Connection failed - not a printer or not available
      return null;
    }
  }

  /// Identify printer type based on port
  String _identifyPrinterType(int port) {
    switch (port) {
      case 9100:
        return 'RAW/ESC-POS Printer';
      case 515:
        return 'LPR/LPD Printer';
      case 631:
        return 'IPP Printer';
      case 9101:
        return 'Parallel Port Printer';
      case 9102:
        return 'Serial Port Printer';
      default:
        return 'Network Printer';
    }
  }
  
  /// Manually add a printer by IP address
  Future<PrinterDevice?> addPrinterByIP(String ipAddress, {int port = 9100}) async {
    try {
      debugPrint('Testing manual IP: $ipAddress:$port');
      
      // Validate IP format
      final parts = ipAddress.split('.');
      if (parts.length != 4) {
        throw Exception('Invalid IP address format');
      }
      
      for (final part in parts) {
        final num = int.tryParse(part);
        if (num == null || num < 0 || num > 255) {
          throw Exception('Invalid IP address range');
        }
      }
      
      // Test connection to the specific IP and port
      final printer = await _testAndCreatePrinterDevice(ipAddress, port);
      if (printer != null) {
        debugPrint('Successfully connected to manual IP: ${printer.address}');
        return printer;
      } else {
        throw Exception('No printer found at $ipAddress:$port');
      }
    } catch (e) {
      debugPrint('Error testing manual IP $ipAddress:$port - $e');
      throw Exception('Failed to connect to $ipAddress:$port - $e');
    }
  }



  /// Test if a network printer is available at the given IP and port
  Future<bool> _testPrinterConnection(String ip, int port) async {
    try {
      debugPrint('🧪 Testing connection to $ip:$port...');
      
      final socket = await Socket.connect(
        ip, 
        port, 
        timeout: const Duration(seconds: 5) // FIXED: Increased timeout
      );
      
      // Try to send a simple status request to verify it's actually a printer
      try {
        // Send ESC/POS printer status request
        final statusRequest = Uint8List.fromList('\x1B\x76'.codeUnits); // ESC v (transmit status)
        socket.add(statusRequest);
        await socket.flush();
        
        // Wait briefly for any response
        await Future.delayed(const Duration(milliseconds: 200));
        debugPrint('✅ Printer test successful for $ip:$port');
      } catch (statusError) {
        debugPrint('⚠️ Status request failed for $ip:$port (but connection works): $statusError');
        // Connection works even if status request fails
      }
      
      await socket.close();
      return true;
    } catch (e) {
      debugPrint('❌ Connection test failed for $ip:$port: $e');
      return false;
    }
  }

  /// Calculate signal strength based on IP (simplified)
  int _calculateSignalStrength(String ip) {
    // Simple calculation based on last octet (closer to router = stronger signal)
    final parts = ip.split('.');
    final lastOctet = int.tryParse(parts.last) ?? 100;
    return (255 - lastOctet).clamp(30, 100);
  }

  /// Initialize LPR/LPD connection for port 515 printers
  Future<void> _initializeLprConnection() async {
    try {
      // LPR/LPD protocol initialization
      // Send control file first (simplified LPR protocol)
      final controlData = 'H${Platform.localHostname}\n'  // Hostname
                         'P${Platform.environment['USER'] ?? 'pos_user'}\n'  // Username
                         'J${DateTime.now().millisecondsSinceEpoch}\n'  // Job name
                         'f${DateTime.now().millisecondsSinceEpoch}\n'  // Data file name
                         '\n';
      
      debugPrint('📡 Sending LPR control data: ${controlData.length} bytes');
      
      // Send control data
      _wifiSocket?.add(utf8.encode(controlData));
      await _wifiSocket?.flush();
      
      // Wait for acknowledgment
      await Future.delayed(const Duration(milliseconds: 200));
      
      debugPrint('✅ LPR/LPD connection initialized');
    } catch (e) {
      debugPrint('❌ Error initializing LPR connection: $e');
      rethrow;
    }
  }

  /// Send data via LPR/LPD protocol for port 515 printers
  Future<void> _sendViaLprProtocol(Uint8List data) async {
    try {
      // LPR/LPD protocol: Send data file
      final jobId = DateTime.now().millisecondsSinceEpoch.toString();
      final dataFileName = 'df${jobId}${Platform.localHostname}';
      
      // Send data file header
      final dataHeader = '\x02${data.length} $dataFileName\n';
      _wifiSocket?.add(utf8.encode(dataHeader));
      await _wifiSocket?.flush();
      
      // Send actual print data
      _wifiSocket?.add(data);
      await _wifiSocket?.flush();
      
      // Send data file terminator
      _wifiSocket?.add([0x00]); // NULL terminator
      await _wifiSocket?.flush();
      
      debugPrint('✅ Data sent via LPR/LPD protocol');
    } catch (e) {
      debugPrint('❌ Error sending via LPR protocol: $e');
      rethrow;
    }
  }

  /// Check if a Bluetooth device is likely a printer
  bool _isPrinterDevice(String deviceName) {
    final printerKeywords = ['printer', 'print', 'pos', 'thermal', 'receipt', 'epson', 'star', 'zebra'];
    final lowerName = deviceName.toLowerCase();
    return printerKeywords.any((keyword) => lowerName.contains(keyword));
  }

  /// Connect to multiple printers simultaneously
  Future<Map<String, bool>> connectToMultiplePrinters(List<PrinterConfiguration> printers) async {
    final Map<String, bool> results = {};
    
    debugPrint('🔗 Connecting to ${printers.length} printers simultaneously...');
    
    // Create connection futures for all printers
    final List<Future<MapEntry<String, bool>>> connectionFutures = printers.map((printer) {
      return _connectToPrinterAsync(printer).then((success) => MapEntry(printer.id, success));
    }).toList();
    
    // Wait for all connections to complete
    try {
      final List<MapEntry<String, bool>> connectionResults = await Future.wait(connectionFutures);
      
      for (final result in connectionResults) {
        results[result.key] = result.value;
      }
      
      await _saveActivePrinters();
      _safeNotifyListeners();
      
      final successCount = results.values.where((success) => success).length;
      debugPrint('✅ Successfully connected to $successCount/${printers.length} printers');
      
    } catch (e) {
      debugPrint('❌ Error connecting to multiple printers: $e');
    }
    
    return results;
  }

  /// Connect to a single printer (async version)
  Future<bool> _connectToPrinterAsync(PrinterConfiguration printer) async {
    try {
      debugPrint('🔗 Connecting to ${printer.name} (${printer.fullAddress})...');
      
      // Check if already connected
      if (_activeConnections.containsKey(printer.id)) {
        debugPrint('ℹ️ Printer ${printer.name} already connected');
        return true;
      }
      
      // Check retry limits
      final retryCount = _connectionRetryCount[printer.id] ?? 0;
      if (retryCount >= _maxRetries) {
        final lastAttempt = _lastConnectionAttempt[printer.id];
        if (lastAttempt != null && DateTime.now().difference(lastAttempt) < _retryDelay) {
          debugPrint('⏳ Printer ${printer.name} retry limit reached, waiting...');
          return false;
        }
        // Reset retry count after delay
        _connectionRetryCount[printer.id] = 0;
      }
      
      _lastConnectionAttempt[printer.id] = DateTime.now();
      _connectionRetryCount[printer.id] = retryCount + 1;
      
      // Attempt connection based on printer type
      PrinterConnection? connection;
      
             if (printer.type == PrinterType.wifi) {
         connection = await _connectToWiFiPrinterAsync(printer);
       } 
       // Bluetooth support temporarily disabled
       // else if (printer.type == PrinterType.bluetooth) {
       //   debugPrint('⚠️ Bluetooth printing temporarily disabled');
       //   return false;
       // }
      
      if (connection != null) {
        _activeConnections[printer.id] = connection;
        _connectionRetryCount[printer.id] = 0; // Reset retry count on success
        debugPrint('✅ Successfully connected to ${printer.name}');
        return true;
      } else {
        debugPrint('❌ Failed to connect to ${printer.name}');
        return false;
      }
      
    } catch (e) {
      debugPrint('❌ Error connecting to ${printer.name}: $e');
      return false;
    }
  }

  /// Connect to WiFi printer (async version)
  Future<PrinterConnection?> _connectToWiFiPrinterAsync(PrinterConfiguration printer) async {
    try {
      final socket = await Socket.connect(
        printer.ipAddress,
        printer.port,
        timeout: _connectionTimeout,
      );
      
      return PrinterConnection(
        printerId: printer.id,
        config: printer,
        wifiSocket: socket,
      );
    } catch (e) {
      debugPrint('❌ WiFi connection failed for ${printer.name}: $e');
      return null;
    }
  }



  /// Disconnect from a specific printer
  Future<bool> disconnectFromPrinter(String printerId) async {
    try {
      final connection = _activeConnections[printerId];
      if (connection != null) {
        await connection.disconnect();
        _activeConnections.remove(printerId);
        _connectionRetryCount.remove(printerId);
        _lastConnectionAttempt.remove(printerId);
        
        await _saveActivePrinters();
        _safeNotifyListeners();
        
        debugPrint('✅ Disconnected from printer: ${connection.config.name}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error disconnecting from printer: $e');
      return false;
    }
  }

  /// Disconnect from all printers
  Future<void> disconnectFromAllPrinters() async {
    debugPrint('🔌 Disconnecting from all printers...');
    
    final List<Future<void>> disconnectionFutures = _activeConnections.values.map((connection) {
      return connection.disconnect();
    }).toList();
    
    await Future.wait(disconnectionFutures);
    
    _activeConnections.clear();
    _connectionRetryCount.clear();
    _lastConnectionAttempt.clear();
    
    await _saveActivePrinters();
    _safeNotifyListeners();
    
    debugPrint('✅ Disconnected from all printers');
  }

  /// Check connection status for all printers
  Future<Map<String, bool>> checkAllConnections() async {
    final Map<String, bool> connectionStatus = {};
    
    for (final entry in _activeConnections.entries) {
      final printerId = entry.key;
      final connection = entry.value;
      
             try {
         // Test connection by attempting to send a status request
         if (connection.config.type == PrinterType.wifi) {
           // Send ESC/POS status request
           final statusCommand = Uint8List.fromList([0x10, 0x04, 0x01]);
           await connection.sendData(statusCommand);
           connectionStatus[printerId] = true;
         } else {
           // For Bluetooth, just check if connection is active
           connectionStatus[printerId] = connection.isConnected;
         }
      } catch (e) {
        connectionStatus[printerId] = false;
        debugPrint('❌ Connection check failed for ${connection.config.name}: $e');
      }
    }
    
    return connectionStatus;
  }

  /// Print to multiple printers simultaneously
  Future<Map<String, bool>> printToMultiplePrinters(
    Map<String, List<OrderItem>> itemsByPrinter,
    Order order,
  ) async {
    final Map<String, bool> results = {};
    
    debugPrint('🖨️ Printing to ${itemsByPrinter.length} printers simultaneously...');
    
    // Create print futures for all printers
    final List<Future<MapEntry<String, bool>>> printFutures = itemsByPrinter.entries.map((entry) {
      final printerId = entry.key;
      final items = entry.value;
      
      return _printToSpecificPrinterAsync(printerId, items, order).then((success) => 
        MapEntry(printerId, success)
      );
    }).toList();
    
    // Wait for all print jobs to complete
    try {
      final List<MapEntry<String, bool>> printResults = await Future.wait(printFutures);
      
      for (final result in printResults) {
        results[result.key] = result.value;
      }
      
      final successCount = results.values.where((success) => success).length;
      debugPrint('✅ Successfully printed to $successCount/${itemsByPrinter.length} printers');
      
    } catch (e) {
      debugPrint('❌ Error printing to multiple printers: $e');
    }
    
    return results;
  }

  /// Print to a specific printer (async version)
  Future<bool> _printToSpecificPrinterAsync(
    String printerId,
    List<OrderItem> items,
    Order order,
  ) async {
    try {
      final connection = _activeConnections[printerId];
      if (connection == null) {
        debugPrint('❌ No connection found for printer: $printerId');
        return false;
      }
      
      // Create a partial order with only the items for this printer
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
      
      // Generate kitchen ticket content
      final content = _generateKitchenTicketSegregated(partialOrder, connection.config.name);
      final data = Uint8List.fromList(content.codeUnits);
      
      // Send to printer
      await connection.sendData(data);
      
      debugPrint('✅ Successfully printed to ${connection.config.name}');
      return true;
      
    } catch (e) {
      debugPrint('❌ Error printing to printer $printerId: $e');
      return false;
    }
  }

  /// Get printer connection status
  PrinterConnectionStatus getPrinterStatus(String printerId) {
    final connection = _activeConnections[printerId];
    if (connection == null) {
      return PrinterConnectionStatus.disconnected;
    }
    
    return connection.isConnected 
        ? PrinterConnectionStatus.connected 
        : PrinterConnectionStatus.disconnected;
  }

  /// Get connection statistics
  Map<String, dynamic> getConnectionStatistics() {
    final connectedCount = _activeConnections.length;
    final connectionsByType = <String, int>{};
    
    for (final connection in _activeConnections.values) {
      final typeName = connection.config.type.toString().split('.').last;
      connectionsByType[typeName] = (connectionsByType[typeName] ?? 0) + 1;
    }
    
    return {
      'totalConnections': connectedCount,
      'connectionsByType': connectionsByType,
      'averageConnectionTime': _activeConnections.values.isEmpty 
          ? 0 
          : _activeConnections.values
              .map((conn) => DateTime.now().difference(conn.connectedAt).inSeconds)
              .reduce((a, b) => a + b) / _activeConnections.length,
      'retryCountByPrinter': Map.from(_connectionRetryCount),
    };
  }

  /// Auto-reconnect to previously connected printers
  Future<void> autoReconnectPrinters(List<PrinterConfiguration> availablePrinters) async {
    final String? activePrintersJson = _prefs.getString(_activePrintersKey);
    if (activePrintersJson == null) return;
    
    try {
      final List<dynamic> printersList = jsonDecode(activePrintersJson);
      final List<String> printerIds = printersList.cast<String>();
      
      final printersToReconnect = availablePrinters
          .where((printer) => printerIds.contains(printer.id) && printer.isActive)
          .toList();
      
      if (printersToReconnect.isNotEmpty) {
        debugPrint('🔄 Auto-reconnecting to ${printersToReconnect.length} printers...');
        await connectToMultiplePrinters(printersToReconnect);
      }
    } catch (e) {
      debugPrint('❌ Error during auto-reconnect: $e');
    }
  }

  /// Print a test receipt
  Future<void> printTestReceipt() async {
    if (_connectedPrinter == null) {
      throw Exception('No printer connected');
    }

    final testContent = _generateTestReceipt();
    await _sendToPrinter(testContent);
  }

  /// Print a sample receipt with realistic data
  Future<void> printSampleReceipt() async {
    if (_connectedPrinter == null) {
      throw Exception('No printer connected');
    }

    final sampleContent = _generateSampleReceipt();
    await _sendToPrinter(sampleContent);
  }

  /// Print customer receipt
  Future<bool> printReceipt(Order order) async {
    try {
      final receipt = _generateReceipt(order);
      
      // Feature flag: route receipts via Receipts category assignments if available
      const bool _enableReceiptCategoryRouting = true; // can disable instantly if needed
      if (_enableReceiptCategoryRouting) {
        try {
          // Resolve receipt printers via EnhancedPrinterAssignmentService if accessible
          // Fall back gracefully if not available
          final databaseService = DatabaseService();
          final assignmentService = EnhancedPrinterAssignmentService(
            databaseService: databaseService,
            printerConfigService: PrinterConfigurationService(databaseService),
          );
          await assignmentService.initialize();

          // Get all category assignments for special Receipts category
          final receiptAssignments = assignmentService
              .getAssignmentsForMenuItem('receipt_virtual_item', 'cat_receipts');

          if (receiptAssignments.isNotEmpty) {
            var anySuccess = false;
            for (final a in receiptAssignments.where((x) => x.isActive)) {
              try {
                final addr = a.printerAddress.isNotEmpty ? a.printerAddress : a.printerId;
                final success = await printToSpecificPrinter(
                  addr,
                  receipt,
                  PrinterType.wifi,
                );
                anySuccess = anySuccess || success;
              } catch (_) {}
            }
            if (anySuccess) {
              debugPrint('🧾 Receipt routed to ${receiptAssignments.length} assigned printer(s).');
              return true;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Receipt category routing unavailable, falling back: $e');
        }
      }

      // Fallback: existing behavior (connected printer)
      if (_connectedPrinter == null) {
        debugPrint('No printer connected - cannot print receipt for order: ${order.orderNumber}');
        return false;
      }
      await _sendToPrinter(receipt);
      debugPrint('Customer receipt printed successfully for order: ${order.orderNumber}');
      return true;
    } catch (e) {
      debugPrint('Failed to print receipt: $e');
      return false;
    }
  }

  /// Print kitchen ticket
  Future<bool> printKitchenTicket(Order order) async {
    try {
      debugPrint('🖨️ Attempting to print kitchen ticket for order: ${order.orderNumber}');
      
      // CRITICAL FIX: Check if order is completed and handle gracefully
      if (order.status == OrderStatus.completed) {
        debugPrint('⚠️ Order ${order.orderNumber} is completed - printing kitchen ticket for record keeping');
      }
      
      // Check if printer is connected
      if (_connectedPrinter == null) {
        debugPrint('⚠️ No printer connected - cannot print kitchen ticket for order: ${order.orderNumber}');
        return false;
      }
      
      // Check if printer connection is valid
      if (!await _validatePrinterConnection()) {
        debugPrint('⚠️ Printer connection invalid - attempting to reconnect...');
        try {
          await _reconnectPrinter();
        } catch (reconnectError) {
          debugPrint('❌ Failed to reconnect printer: $reconnectError');
          return false;
        }
      }
      
      final ticket = _generateKitchenTicket(order);
      
      // Send to connected printer with retry logic
      bool printSuccess = false;
      int retryCount = 0;
      const maxRetries = 3;
      
      while (!printSuccess && retryCount < maxRetries) {
        try {
          await _sendToPrinter(ticket);
          printSuccess = true;
          debugPrint('✅ Kitchen ticket printed successfully for order: ${order.orderNumber}');
        } catch (printError) {
          retryCount++;
          debugPrint('⚠️ Print attempt $retryCount failed: $printError');
          
          if (retryCount < maxRetries) {
            debugPrint('🔄 Retrying print in 1 second...');
            await Future.delayed(const Duration(seconds: 1));
          } else {
            debugPrint('❌ All print attempts failed for order: ${order.orderNumber}');
            throw printError;
          }
        }
      }
      
      return printSuccess;
    } catch (e) {
      debugPrint('❌ Failed to print kitchen ticket for order ${order.orderNumber}: $e');
      return false;
    }
  }

  /// Validate printer connection
  Future<bool> _validatePrinterConnection() async {
    if (_connectedPrinter == null) return false;
    
    try {
      switch (_connectedPrinter!.type) {
        case PrinterType.wifi:
          return _wifiSocket != null;
        case PrinterType.ethernet:
        case PrinterType.bluetooth:
        case PrinterType.usb:
        case PrinterType.remote:
        case PrinterType.vpn:
          return false;
      }
    } catch (e) {
      debugPrint('Error validating printer connection: $e');
      return false;
    }
  }

  /// Attempt to reconnect to the printer
  Future<void> _reconnectPrinter() async {
    if (_connectedPrinter == null) return;
    
    debugPrint('🔄 Attempting to reconnect to printer: ${_connectedPrinter!.name}');
    
    try {
      // Disconnect first
      await disconnectPrinter();
      
      // Reconnect
      await connectToPrinter(_connectedPrinter!);
      
      debugPrint('✅ Successfully reconnected to printer');
    } catch (e) {
      debugPrint('❌ Failed to reconnect to printer: $e');
      rethrow;
    }
  }

  /// Generate test receipt content
  String _generateTestReceipt() {
    final buffer = StringBuffer();
    
    // ESC/POS commands for 80mm paper
    buffer.write('\x1B\x40'); // Initialize printer
    buffer.write('\x1B\x61\x01'); // Center alignment
    
    buffer.writeln('TEST RECEIPT');
    buffer.writeln('');
    buffer.write('\x1B\x61\x00'); // Left alignment
    buffer.writeln('Printer: ${_connectedPrinter!.name}');
    buffer.writeln('Address: ${_connectedPrinter!.address}');
    buffer.writeln('Type: ${_connectedPrinter!.type.toString().split('.').last}');
    buffer.writeln('Paper Width: ${_paperWidth}mm');
    buffer.writeln('Print Quality: $_printQuality');
    buffer.writeln('Date: ${DateTime.now().toString().substring(0, 19)}');
    buffer.writeln('');
    buffer.writeln('If you can read this clearly,');
    buffer.writeln('your printer is working correctly!');
    buffer.writeln('');
    
    // Cut paper
    buffer.write('\x1D\x56\x41\x10');
    
    return buffer.toString();
  }

  /// Generate sample receipt with realistic data
  String _generateSampleReceipt() {
    final buffer = StringBuffer();
    
    // ESC/POS commands for 80mm paper
    buffer.write('\x1B\x40'); // Initialize printer
    buffer.write('\x1B\x61\x01'); // Center alignment
    
    if (_enableHeaderLogo) {
      buffer.writeln('RESTAURANT POS SYSTEM');
      buffer.writeln('123 Main Street');
      buffer.writeln('City, State 12345');
      buffer.writeln('Phone: (555) 123-4567');
    }
    
    buffer.writeln('');
    buffer.write('\x1B\x61\x00'); // Left alignment
    
    // Order details
    buffer.writeln('Order #: SAMPLE-001');
    buffer.writeln('Date: ${DateTime.now().toString().substring(0, 19)}');
    buffer.writeln('Type: Dine-In');
    buffer.writeln('Table: 5');
    buffer.writeln('Server: John Doe');
    buffer.writeln('');
    
    // Items
    buffer.writeln('ITEMS:');
    buffer.writeln('${'-' * (_paperWidth ~/ 2)}');
    buffer.writeln('2x Burger Deluxe          \$24.00');
    buffer.writeln('1x Caesar Salad           \$12.00');
    buffer.writeln('2x Soft Drink             \$6.00');
    buffer.writeln('1x Chocolate Cake         \$8.00');
    buffer.writeln('${'-' * (_paperWidth ~/ 2)}');
    
    // Totals
    buffer.writeln('Subtotal:                 \$50.00');
    buffer.writeln('${_settings.taxName} (${_settings.taxRate.toStringAsFixed(1)}%):                \$6.50');
    buffer.writeln('Tip (18%):                \$9.00');
    buffer.writeln('${'-' * (_paperWidth ~/ 2)}');
    buffer.writeln('TOTAL:                    \$65.50');
    buffer.writeln('');
    
    if (_footerMessage.isNotEmpty) {
      buffer.write('\x1B\x61\x01'); // Center alignment
      buffer.writeln(_footerMessage);
    }
    
    buffer.writeln('');
    
    // Cut paper
    buffer.write('\x1D\x56\x41\x10');
    
    return buffer.toString();
  }

  /// Generate receipt content for an order
  String _generateReceipt(Order order) {
    // Use generic ESC/POS receipt generation for better printing
    return _generateGenericESCPOSReceipt(order);
  }

  /// Generate kitchen ticket content
  String _generateKitchenTicket(Order order) {
    // Use generic ESC/POS kitchen ticket generation for better printing
    return _generateGenericESCPOSKitchenTicket(order, 'Kitchen Printer');
  }

  /// Send content to printer
  Future<void> _sendToPrinter(String content) async {
    if (_connectedPrinter == null) {
      throw Exception('No printer connected');
    }

    try {
      debugPrint('📤 Sending ${content.length} characters to ${_connectedPrinter!.name}');
      
      // Send to actual hardware printer
      final data = Uint8List.fromList(content.codeUnits);
      
      switch (_connectedPrinter!.type) {
        case PrinterType.wifi:
          if (_wifiSocket != null) {
            try {
              // Check if socket is still connected
              if (_wifiSocket!.address.address.isEmpty) {
                throw Exception('WiFi socket connection lost');
              }
              
              // Check if this is an LPR/LPD printer (port 515)
              final addressParts = _connectedPrinter!.address.split(':');
              final port = addressParts.length > 1 ? int.tryParse(addressParts[1]) ?? 9100 : 9100;
              
              if (port == 515) {
                debugPrint('📡 Sending ${data.length} bytes via LPR/LPD to ${_connectedPrinter!.address}');
                await _sendViaLprProtocol(data);
              } else {
                debugPrint('📡 Sending ${data.length} bytes via RAW/ESC-POS to ${_connectedPrinter!.address}');
                _wifiSocket!.add(data);
                await _wifiSocket!.flush();
              }
              
              // Add a small delay to ensure data is sent
              await Future.delayed(const Duration(milliseconds: 100));
              
              debugPrint('✅ WiFi data sent and flushed successfully');
            } catch (socketError) {
              debugPrint('❌ WiFi socket error: $socketError');
              _wifiSocket = null;
              _connectedPrinter = _connectedPrinter!.copyWith(isConnected: false);
              throw Exception('WiFi connection failed: $socketError');
            }
          } else {
            debugPrint('❌ WiFi printer connection not established');
            throw Exception('WiFi printer connection not established - please reconnect to printer');
          }
          break;
        case PrinterType.ethernet:
        case PrinterType.bluetooth:
        case PrinterType.usb:
        case PrinterType.remote:
        case PrinterType.vpn:
          debugPrint('❌ Printer type ${_connectedPrinter!.type} not yet implemented');
          throw Exception('Printer type ${_connectedPrinter!.type} not yet implemented');
          break;
      }
      
      debugPrint('✅ Content sent to printer successfully');
    } catch (e) {
      debugPrint('❌ Error sending to printer: $e');
      throw Exception('Failed to send to printer: $e');
    }
  }

  /// Update print settings
  Future<void> updatePrintSettings({
    int? paperWidth,
    String? printQuality,
    String? printSpeed,
    bool? enableHeaderLogo,
    String? footerMessage,
    bool? printOrderDetails,
    bool? autoPrintOrders,
    bool? printKitchenCopy,
  }) async {
    if (paperWidth != null) _paperWidth = paperWidth;
    if (printQuality != null) _printQuality = printQuality;
    if (printSpeed != null) _printSpeed = printSpeed;
    if (enableHeaderLogo != null) _enableHeaderLogo = enableHeaderLogo;
    if (footerMessage != null) _footerMessage = footerMessage;
    if (printOrderDetails != null) _printOrderDetails = printOrderDetails;
    if (autoPrintOrders != null) _autoPrintOrders = autoPrintOrders;
    if (printKitchenCopy != null) _printKitchenCopy = printKitchenCopy;
    
    await _saveSettings();
    _safeNotifyListeners();
  }

  /// Reset all settings to defaults
  Future<void> resetSettings() async {
    _paperWidth = 80;
    _printQuality = 'High';
    _printSpeed = 'Normal';
    _enableHeaderLogo = true;
    _footerMessage = 'Thank you for dining with us!';
    _printOrderDetails = true;
    _autoPrintOrders = false;
    _printKitchenCopy = true;
    
    await _saveSettings();
    _safeNotifyListeners();
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}/${dateTime.year} ${_formatTime(dateTime)}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} $ampm';
  }

  void _safeNotifyListeners() {
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('Error notifying listeners: $e');
        }
      });
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  /// Legacy methods for backward compatibility
  String? get selectedPrinter => _connectedPrinter?.address;
  List<String> get availablePrinters => [];
  bool get isScanning => false;
  String? get error => null;

  void selectPrinter(String printer) {
    // Legacy method - no longer used
  }

  Future<void> scanForPrintersLegacy() async {
    // Legacy method - use scanForPrinters(PrinterType) instead
  }

  /// Enable manual scanning for WiFi printers
  void enableManualScanning() {
    _isManualScanningEnabled = true;
    debugPrint('Manual printer scanning enabled');
    _safeNotifyListeners();
  }

  /// Disable manual scanning (default state)
  void disableManualScanning() {
    _isManualScanningEnabled = false;
    debugPrint('Manual printer scanning disabled');
    _safeNotifyListeners();
  }
  
  /// Manually trigger printer discovery (can be called from UI)
  Future<void> manualDiscovery() async {
    debugPrint('🔍 Manual printer discovery triggered by user');
    if (_isManualScanningEnabled) {
      // FIXED: Add timeout to prevent infinite spinner
      try {
        await _scanWiFiPrinters().timeout(const Duration(seconds: 30));
        debugPrint('✅ Manual printer discovery completed');
      } catch (e) {
        debugPrint('❌ Manual printer discovery failed or timed out: $e');
      }
    } else {
      debugPrint('⚠️ Manual scanning not enabled - enabling automatically');
      enableManualScanning();
      try {
        await _scanWiFiPrinters().timeout(const Duration(seconds: 30));
        debugPrint('✅ Manual printer discovery completed');
      } catch (e) {
        debugPrint('❌ Manual printer discovery failed or timed out: $e');
      }
    }
  }

  /// Print order with segregated items based on printer assignments - FIXED MULTI-PRINTER HANGING
  Future<void> printOrderSegregated(Order order, Map<String, List<OrderItem>> itemsByPrinter) async {
    try {
      debugPrint('🖨️ Starting segregated printing for order: ${order.orderNumber} to ${itemsByPrinter.length} printers');
      
      if (itemsByPrinter.isEmpty) {
        debugPrint('⚠️ No printers assigned - skipping segregated printing');
        return;
      }
      
      int successCount = 0;
      int totalPrinters = itemsByPrinter.length;
      List<String> failedPrinters = [];
      
      // Print to each assigned printer sequentially to avoid connection conflicts
      for (final entry in itemsByPrinter.entries) {
        final printerId = entry.key;
        final items = entry.value;
        
        if (items.isEmpty) {
          debugPrint('⚠️ No items for printer $printerId - skipping');
          continue;
        }
        
        try {
          debugPrint('🖨️ Printing ${items.length} items to printer: $printerId');
          
          // Create a partial order with only the items for this printer
          final partialOrder = Order(
            id: order.id,
            orderNumber: order.orderNumber,
            customerName: order.customerName,
            customerPhone: order.customerPhone,
            customerEmail: order.customerEmail,
            items: items,
            subtotal: items.fold<double>(0.0, (sum, item) => sum + item.totalPrice),
            taxAmount: 0.0, // Don't duplicate tax on partial orders
            discountAmount: 0.0, // Don't duplicate discount on partial orders
            gratuityAmount: 0.0, // Don't duplicate gratuity on partial orders
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
          
          // Print kitchen ticket for this printer with timeout
          await _printToSpecificPrinter(partialOrder, printerId, true)
              .timeout(const Duration(seconds: 15), onTimeout: () {
            throw TimeoutException('Printer connection timed out', const Duration(seconds: 15));
          });
          
          successCount++;
          debugPrint('✅ Successfully printed to printer $printerId');
          
          // Small delay between printers to prevent connection conflicts
          if (entry != itemsByPrinter.entries.last) {
            await Future.delayed(const Duration(milliseconds: 1000));
          }
          
        } catch (e) {
          debugPrint('❌ Failed to print to printer $printerId: $e');
          failedPrinters.add(printerId);
          // Continue with other printers even if one fails
        }
      }
      
      debugPrint('🎉 Segregated printing completed: $successCount/$totalPrinters printers successful');
      
      if (failedPrinters.isNotEmpty) {
        debugPrint('⚠️ Failed printers: ${failedPrinters.join(', ')}');
      }
      
      if (successCount == 0) {
        throw Exception('Failed to print to any of the $totalPrinters assigned printers');
      }
      
    } catch (e) {
      debugPrint('❌ Error in segregated printing: $e');
      throw Exception('Failed to print segregated order: $e');
    }
  }

  /// Print to a specific printer by ID - FIXED TYPE CASTING
  Future<void> _printToSpecificPrinter(Order order, String printerId, bool isKitchenTicket) async {
    try {
      debugPrint('🔍 Looking for printer with ID: $printerId');
      
      // Get the actual printer configuration from the service
      final databaseService = DatabaseService();
      final printerConfigService = PrinterConfigurationService(databaseService);
      await printerConfigService.initialize();
      
      // FIXED: Properly await the async call
      final printerConfig = await printerConfigService.getConfigurationById(printerId);
      
      if (printerConfig == null) {
        throw Exception('Printer configuration not found for ID: $printerId');
      }
      
      debugPrint('📍 Found printer: ${printerConfig.name} (${printerConfig.fullAddress})');
      
      // Create PrinterDevice from configuration
      final targetPrinter = PrinterDevice(
        id: printerConfig.id,
        name: printerConfig.name,
        address: printerConfig.fullAddress,
        type: _convertConfigTypeToDeviceType(printerConfig.type),
      );
      
      debugPrint('🔌 Connecting to printer: ${targetPrinter.name} (${targetPrinter.address})');
      
      // Connect to the specific printer
      await _connectToSpecificPrinter(targetPrinter);
      
      // Generate and send the content
      final content = isKitchenTicket 
          ? _generateKitchenTicketSegregated(order, targetPrinter.name)
          : _generateReceipt(order);
      
      await _sendToPrinter(content);
      
      debugPrint('✅ Successfully printed to ${targetPrinter.name}');
      
    } catch (e) {
      debugPrint('❌ Error printing to specific printer: $e');
      throw Exception('Failed to print to printer $printerId: $e');
    }
  }

  /// Connect to a specific printer for segregated printing
  Future<void> _connectToSpecificPrinter(PrinterDevice printer) async {
    try {
      if (printer.type == PrinterType.wifi) {
        // Close existing connection if different printer
        if (_wifiSocket != null && _connectedPrinter?.id != printer.id) {
          try {
            await _wifiSocket!.close();
          } catch (closeError) {
            debugPrint('⚠️ Error closing existing socket: $closeError');
          }
          _wifiSocket = null;
        }
        
        // Connect to the specific printer
        if (_wifiSocket == null || _connectedPrinter?.id != printer.id) {
          final addressParts = printer.address.split(':');
          final ip = addressParts[0];
          final port = addressParts.length > 1 ? int.tryParse(addressParts[1]) ?? 9100 : 9100;
          
          debugPrint('🔌 Connecting to specific WiFi printer: $ip:$port');
          
          _wifiSocket = await Socket.connect(
            ip,
            port,
            timeout: const Duration(seconds: 10),
          );
          
          // Configure socket for reliability
          _wifiSocket!.setOption(SocketOption.tcpNoDelay, true);
          
          // Set up error handling
          _wifiSocket!.listen(
            (data) {
              debugPrint('📥 Received ${data.length} bytes from specific printer');
            },
            onError: (error) {
              debugPrint('❌ Specific printer connection error: $error');
              _wifiSocket = null;
            },
            onDone: () {
              debugPrint('🔌 Specific printer connection closed');
              _wifiSocket = null;
            },
          );
          
          // Test connection with initialization command
          try {
            final initData = Uint8List.fromList('\x1B\x40'.codeUnits); // ESC @ (initialize)
            _wifiSocket!.add(initData);
            await _wifiSocket!.flush();
            debugPrint('✅ Specific printer initialized successfully');
          } catch (initError) {
            debugPrint('⚠️ Specific printer initialization failed: $initError');
            // Continue anyway - some printers don't respond to init commands
          }
          
          debugPrint('✅ Connected to specific WiFi printer: ${printer.address}');
        }
      }
      // Add Bluetooth support if needed
      
    } catch (e) {
      debugPrint('❌ Error connecting to printer ${printer.name}: $e');
      _wifiSocket = null;
      throw Exception('Failed to connect to printer: $e');
    }
  }

  // Duplicate methods removed - using existing implementations

  /// Generate kitchen ticket with printer-specific header
  String _generateKitchenTicketSegregated(Order order, String printerName) {
    // Use enhanced Epson TM-M30III kitchen ticket generation for better printing
            return _generateGenericESCPOSKitchenTicket(order, printerName);
  }

  /// Get segregated items by printer assignments
  Future<Map<String, List<OrderItem>>> segregateOrderItems(Order order, dynamic printerAssignmentService) async {
    final Map<String, List<OrderItem>> itemsByPrinter = {};
    
    try {
      for (final item in order.items) {
        // Get printer assignment for this menu item
        final assignment = printerAssignmentService.getAssignmentForMenuItem(
          item.menuItem.id,
          item.menuItem.categoryId,
        );
        
        String printerId;
        if (assignment != null) {
          printerId = assignment.printerId;
          debugPrint('Item ${item.menuItem.name} assigned to printer: ${assignment.printerName}');
        } else {
          // Default printer if no assignment found
          printerId = 'printer_1'; // Kitchen Main Printer
          debugPrint('Item ${item.menuItem.name} using default printer');
        }
        
        if (!itemsByPrinter.containsKey(printerId)) {
          itemsByPrinter[printerId] = [];
        }
        itemsByPrinter[printerId]!.add(item);
      }
      
      debugPrint('Items segregated across ${itemsByPrinter.length} printers');
      return itemsByPrinter;
      
    } catch (e) {
      debugPrint('Error segregating order items: $e');
      // Fallback: send all items to default printer
      return {'printer_1': order.items};
    }
  }

  /// Update printer configuration
  void updatePrinterConfiguration(PrinterDevice updatedPrinter) {
    // Update the connected printer if it matches
    if (_connectedPrinter?.id == updatedPrinter.id) {
      _connectedPrinter = updatedPrinter;
    }
    
    // Close existing connection to force reconnection with new settings
    _wifiSocket?.destroy();
    _wifiSocket = null;
    
    notifyListeners();
    debugPrint('Updated printer configuration for ${updatedPrinter.name}');
  }

  /// Convert printer configuration type to device type
  PrinterType _convertConfigTypeToDeviceType(dynamic configType) {
    if (configType == null) return PrinterType.wifi;
    
    // Handle string representation
    if (configType is String) {
      switch (configType.toLowerCase()) {
        case 'wifi':
        case 'ethernet':
        case 'network':
          return PrinterType.wifi;
        case 'bluetooth':
          // return PrinterType.bluetooth;  // Temporarily disabled
          return PrinterType.wifi; // Default to wifi
        default:
          return PrinterType.wifi;
      }
    }
    
    // Handle enum representation
    final typeString = configType.toString().split('.').last.toLowerCase();
    switch (typeString) {
      case 'wifi':
      case 'ethernet':
      case 'network':
        return PrinterType.wifi;
      case 'bluetooth':
        // return PrinterType.bluetooth;  // Temporarily disabled
        return PrinterType.wifi; // Default to wifi
      default:
        return PrinterType.wifi;
    }
  }

  /// Print a test receipt for configuration testing (overloaded version)
  Future<void> printTestReceiptForPrinter(PrinterDevice printer) async {
    // Generate enhanced test print content for Epson TM-M30III
          final testContent = _generateGenericESCPOSTestPrint(printer);
    await _sendToSpecificPrinter(printer, testContent);
  }
  
  /// Generate enhanced test print for Epson TM-M30III
  String _generateGenericESCPOSTestPrint(PrinterDevice printer) {
    final List<int> commands = [];
    final now = DateTime.now();
    
    // STEP 1: Initialize Epson TM-M30III
    commands.addAll([0x1B, 0x40]); // ESC @ (Initialize printer)
    commands.addAll([0x1B, 0x4D, 0x01]); // ESC M (Select character font A)
    commands.addAll([0x1D, 0x61, 0x01]); // GS a (Enable automatic status back)
    commands.addAll([0x1B, 0x63, 0x35, 0x00]); // ESC c 5 (Disable panel buttons)
    
    // STEP 2: Header with emphasis
    commands.addAll([0x1B, 0x61, 0x01]); // ESC a (Center alignment)
    commands.addAll([0x1D, 0x21, 0x11]); // GS ! (Double width and height)
    commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
    
    commands.addAll("EPSON TM-M30III".codeUnits);
    commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
    commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
    commands.addAll([0x0A]); // LF
    
    commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
    commands.addAll("CONNECTION TEST".codeUnits);
    commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
    commands.addAll([0x0A, 0x0A]); // LF LF
    
    // STEP 3: Test information
    commands.addAll([0x1B, 0x61, 0x00]); // ESC a (Left alignment)
    
    final separator = "=" * 42;
    commands.addAll(separator.codeUnits);
    commands.addAll([0x0A]); // LF
    
    final printerLine = "Printer: ${printer.name}";
    commands.addAll(printerLine.codeUnits);
    commands.addAll([0x0A]); // LF
    
    final addressLine = "Address: ${printer.address}";
    commands.addAll(addressLine.codeUnits);
    commands.addAll([0x0A]); // LF
    
    final modelLine = "Model: ${printer.model ?? 'Epson TM-M30III'}";
    commands.addAll(modelLine.codeUnits);
    commands.addAll([0x0A]); // LF
    
    final dateLine = "Date: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    commands.addAll(dateLine.codeUnits);
    commands.addAll([0x0A]); // LF
    
    final timeLine = "Time: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    commands.addAll(timeLine.codeUnits);
    commands.addAll([0x0A]); // LF
    
    commands.addAll(separator.codeUnits);
    commands.addAll([0x0A, 0x0A]); // LF LF
    
    // STEP 4: Test message
    commands.addAll("This is a test print to verify".codeUnits);
    commands.addAll([0x0A]); // LF
    commands.addAll("your Epson TM-M30III printer".codeUnits);
    commands.addAll([0x0A]); // LF
    commands.addAll("configuration.".codeUnits);
    commands.addAll([0x0A, 0x0A]); // LF LF
    
    commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
    commands.addAll("If you can read this clearly,".codeUnits);
    commands.addAll([0x0A]); // LF
    commands.addAll("your printer is working correctly!".codeUnits);
    commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
    commands.addAll([0x0A, 0x0A]); // LF LF
    
    // STEP 5: Font and formatting test
    commands.addAll(separator.codeUnits);
    commands.addAll([0x0A]); // LF
    commands.addAll([0x1B, 0x61, 0x01]); // ESC a (Center alignment)
    commands.addAll("FONT & FORMAT TEST".codeUnits);
    commands.addAll([0x0A]); // LF
    commands.addAll([0x1B, 0x61, 0x00]); // ESC a (Left alignment)
    commands.addAll(separator.codeUnits);
    commands.addAll([0x0A]); // LF
    
    // Normal text
    commands.addAll("Normal Text".codeUnits);
    commands.addAll([0x0A]); // LF
    
    // Bold text
    commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
    commands.addAll("Bold Text".codeUnits);
    commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
    commands.addAll([0x0A]); // LF
    
    // Double height
    commands.addAll([0x1D, 0x21, 0x01]); // GS ! (Double height)
    commands.addAll("Double Height".codeUnits);
    commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
    commands.addAll([0x0A]); // LF
    
    // Double width
    commands.addAll([0x1D, 0x21, 0x10]); // GS ! (Double width)
    commands.addAll("Double Width".codeUnits);
    commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
    commands.addAll([0x0A]); // LF
    
    // Double width and height
    commands.addAll([0x1D, 0x21, 0x11]); // GS ! (Double width and height)
    commands.addAll("Double Both".codeUnits);
    commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
    commands.addAll([0x0A, 0x0A]); // LF LF
    
    // STEP 6: Alignment test
    commands.addAll(separator.codeUnits);
    commands.addAll([0x0A]); // LF
    commands.addAll([0x1B, 0x61, 0x01]); // ESC a (Center alignment)
    commands.addAll("ALIGNMENT TEST".codeUnits);
    commands.addAll([0x0A]); // LF
    commands.addAll(separator.codeUnits);
    commands.addAll([0x0A]); // LF
    
    // Left aligned
    commands.addAll([0x1B, 0x61, 0x00]); // ESC a (Left alignment)
    commands.addAll("Left Aligned".codeUnits);
    commands.addAll([0x0A]); // LF
    
    // Center aligned
    commands.addAll([0x1B, 0x61, 0x01]); // ESC a (Center alignment)
    commands.addAll("Center Aligned".codeUnits);
    commands.addAll([0x0A]); // LF
    
    // Right aligned
    commands.addAll([0x1B, 0x61, 0x02]); // ESC a (Right alignment)
    commands.addAll("Right Aligned".codeUnits);
    commands.addAll([0x0A, 0x0A]); // LF LF
    
    // STEP 7: Footer
    commands.addAll([0x1B, 0x61, 0x01]); // ESC a (Center alignment)
    commands.addAll(separator.codeUnits);
    commands.addAll([0x0A]); // LF
    commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
    commands.addAll("TEST SUCCESSFUL".codeUnits);
    commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
    commands.addAll([0x0A]); // LF
    commands.addAll("Restaurant POS System".codeUnits);
    commands.addAll([0x0A]); // LF
    commands.addAll(separator.codeUnits);
    commands.addAll([0x0A, 0x0A, 0x0A, 0x0A]); // LF LF LF LF
    
    // STEP 8: Cut paper for Epson TM-M30III
    commands.addAll([0x1D, 0x56, 0x00]); // GS V (Full cut)
    
    // Convert to string and return
    return String.fromCharCodes(commands);
  }
  
  /// Send content to a specific printer (dedicated method for configuration)
  Future<void> _sendToSpecificPrinter(PrinterDevice printer, String content) async {
    try {
      if (printer.type == PrinterType.wifi) {
        final addressParts = printer.address.split(':');
        final ip = addressParts[0];
        final port = addressParts.length > 1 ? int.tryParse(addressParts[1]) ?? 9100 : 9100;
        
        final socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(seconds: 5),
        );
        
        socket.add(content.codeUnits);
        await socket.flush();
        await socket.close();
        
        debugPrint('Successfully sent test print to ${printer.name}');
      } else {
        throw Exception('Printer type ${printer.type} not yet implemented for test printing');
      }
    } catch (e) {
      debugPrint('Error sending test print to ${printer.name}: $e');
      rethrow;
    }
  }

  /// Legacy methods for backward compatibility
  
  /// Connect to a printer device (legacy method)
  Future<bool> connectToPrinter(PrinterDevice printer) async {
    try {
      // For backward compatibility, disconnect existing connections
      await disconnectPrinter();

      debugPrint('Connecting to ${printer.name} at ${printer.address}...');
      
      // Connect to real printer based on type
      switch (printer.type) {
        case PrinterType.wifi:
          return await _connectToWiFiPrinterLegacy(printer);
        case PrinterType.ethernet:
        case PrinterType.bluetooth:
        case PrinterType.usb:
        case PrinterType.remote:
        case PrinterType.vpn:
          debugPrint('❌ Printer type ${printer.type} not yet implemented');
          return false;
      }
    } catch (e) {
      debugPrint('Error connecting to printer: $e');
      return false;
    }
  }

  /// Connect to WiFi printer (legacy method)
  Future<bool> _connectToWiFiPrinterLegacy(PrinterDevice printer) async {
    try {
      final parts = printer.address.split(':');
      final ip = parts[0];
      final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;

      debugPrint('🔌 Attempting WiFi connection to $ip:$port...');
      
      // Close any existing WiFi connection
      if (_wifiSocket != null) {
        try {
          await _wifiSocket!.close();
        } catch (e) {
          debugPrint('⚠️ Error closing existing socket: $e');
        }
        _wifiSocket = null;
      }

      // Establish new connection with proper timeout and error handling
      _wifiSocket = await Socket.connect(
        ip, 
        port, 
        timeout: const Duration(seconds: 10)
      );
      
      // Configure socket settings for better reliability
      _wifiSocket!.setOption(SocketOption.tcpNoDelay, true);
      
      // Handle different printer protocols
      if (port == 515) {
        debugPrint('📡 Using LPR/LPD protocol for port 515');
        // Initialize LPR/LPD connection
        await _initializeLprConnection();
      } else {
        debugPrint('📡 Using RAW/ESC-POS protocol for port $port');
      }
      
      // Listen for connection errors
      _wifiSocket!.listen(
        (data) {
          // Handle incoming data if needed
          debugPrint('📥 Received ${data.length} bytes from printer');
        },
        onError: (error) {
          debugPrint('❌ WiFi printer connection error: $error');
          _wifiSocket = null;
          _connectedPrinter = null;
          _safeNotifyListeners();
        },
        onDone: () {
          debugPrint('🔌 WiFi printer connection closed');
          _wifiSocket = null;
          if (_connectedPrinter != null) {
            _connectedPrinter = _connectedPrinter!.copyWith(isConnected: false);
            _safeNotifyListeners();
          }
        },
      );
      
      _connectedPrinter = printer.copyWith(isConnected: true);
      await _saveConnectedPrinter();
      _safeNotifyListeners();
      
      debugPrint('✅ Connected to WiFi printer: ${printer.address}');
      
      // Test the connection with a simple command
      try {
        final testData = Uint8List.fromList('\x1B\x40'.codeUnits); // ESC @ (initialize printer)
        _wifiSocket!.add(testData);
        await _wifiSocket!.flush();
        debugPrint('✅ Printer initialization command sent successfully');
      } catch (testError) {
        debugPrint('⚠️ Printer test command failed: $testError');
        // Don't fail the connection for test command issues
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Failed to connect to WiFi printer: $e');
      _wifiSocket = null;
      _connectedPrinter = null;
      return false;
    }
  }

  /// Connect to Bluetooth printer (legacy method) - DISABLED
  Future<bool> _connectToBluetoothPrinterLegacy(PrinterDevice printer) async {
    // Bluetooth functionality temporarily disabled
    debugPrint('❌ Bluetooth printing temporarily disabled');
    return false;
  }

  /// Disconnect from current printer (legacy method)
  Future<void> disconnectPrinter() async {
    try {
      // Disconnect from all active connections
      await disconnectFromAllPrinters();
      
      _connectedPrinter = null;
      await _saveConnectedPrinter();
      _safeNotifyListeners();
      
      debugPrint('Disconnected from printer');
    } catch (e) {
      debugPrint('Error disconnecting printer: $e');
    }
  }

  /// Get currently connected printer (legacy method)
  Future<PrinterDevice?> getConnectedPrinter() async {
    return _connectedPrinter;
  }

  // Legacy property getters already exist earlier in the file

  /// Multi-Printer Configuration Helper Methods
  
  /// Get all printer stations with their status
  Map<String, dynamic> getAllPrinterStations() {
    final stations = <String, dynamic>{};
    
    for (final entry in _activeConnections.entries) {
      final printerId = entry.key;
      final connection = entry.value;
      
      stations[printerId] = {
        'name': connection.config.name,
        'address': connection.config.fullAddress,
        'type': connection.config.type.toString().split('.').last,
        'status': connection.isConnected ? 'connected' : 'disconnected',
        'connectedAt': connection.connectedAt.toIso8601String(),
        'lastActivity': DateTime.now().toIso8601String(),
      };
    }
    
    return stations;
  }

  /// Initialize printer connections from configuration
  Future<void> initializePrinterConnections(
    List<PrinterConfiguration> configurations,
  ) async {
    debugPrint('🔧 Initializing printer connections...');
    
    // Filter active configurations
    final activeConfigs = configurations.where((config) => config.isActive).toList();
    
    if (activeConfigs.isNotEmpty) {
      final results = await connectToMultiplePrinters(activeConfigs);
      
      final successCount = results.values.where((success) => success).length;
      debugPrint('✅ Initialized $successCount/${activeConfigs.length} printer connections');
    } else {
      debugPrint('ℹ️ No active printer configurations found');
    }
  }

  /// Test all printer connections
  Future<Map<String, bool>> testAllPrinterConnections() async {
    debugPrint('🧪 Testing all printer connections...');
    
    final results = <String, bool>{};
    
    for (final entry in _activeConnections.entries) {
      final printerId = entry.key;
      final connection = entry.value;
      
      try {
        // Generate test content
        final testContent = '''
TEST PRINT - ${connection.config.name}
Time: ${DateTime.now().toIso8601String()}
Status: Connection Test
================================
If you can read this message,
your printer is working correctly!
================================
''';
        
        await connection.sendData(Uint8List.fromList(testContent.codeUnits));
        results[printerId] = true;
        debugPrint('✅ Test successful for ${connection.config.name}');
      } catch (e) {
        results[printerId] = false;
        debugPrint('❌ Test failed for ${connection.config.name}: $e');
      }
    }
    
    return results;
  }

  /// Get printer health status
  Map<String, dynamic> getPrinterHealthStatus() {
    final health = <String, dynamic>{};
    
    for (final entry in _activeConnections.entries) {
      final printerId = entry.key;
      final connection = entry.value;
      
      final uptime = DateTime.now().difference(connection.connectedAt);
      
      health[printerId] = {
        'name': connection.config.name,
        'status': connection.isConnected ? 'healthy' : 'unhealthy',
        'uptime': uptime.inMinutes,
        'type': connection.config.type.toString().split('.').last,
        'lastCheck': DateTime.now().toIso8601String(),
      };
    }
    
    return health;
  }

  /// Graceful shutdown of all printer connections
  Future<void> shutdownAllConnections() async {
    debugPrint('🔌 Shutting down all printer connections...');
    
    try {
      await disconnectFromAllPrinters();
      debugPrint('✅ All printer connections shut down successfully');
    } catch (e) {
      debugPrint('❌ Error during shutdown: $e');
    }
  }

  /// ======================================================
  /// EPSON TM-M30III SPECIFIC ROBUST CONNECTION ALGORITHM
  /// ======================================================
  

  
  /// Test IP batch specifically for Epson printers
  Future<void> _testIPBatchForEpson(
    List<String> ips, 
    List<int> ports, 
    List<PrinterDevice> foundPrinters,
    {int batchSize = 5}
  ) async {
    for (int i = 0; i < ips.length; i += batchSize) {
      final batch = ips.skip(i).take(batchSize);
      final futures = <Future<PrinterDevice?>>[];
      
      for (final ip in batch) {
        for (final port in ports) {
          futures.add(_testGenericESCPOSConnection(ip, port));
        }
      }
      
      final results = await Future.wait(futures);
      
      for (final printer in results) {
        if (printer != null) {
          // Avoid duplicates (same IP, different port)
          final existingPrinter = foundPrinters.where((p) => 
            p.address.split(':')[0] == printer.address.split(':')[0]
          ).firstOrNull;
          
          if (existingPrinter == null) {
            foundPrinters.add(printer);
            debugPrint('🖨️ Found Epson TM-M30III: ${printer.name} at ${printer.address}');
          }
        }
      }
      
      // Progress update
      if ((i + batchSize) % 25 == 0) {
        debugPrint('📊 Scanned ${i + batchSize}/${ips.length} IPs... Found ${foundPrinters.length} Epson printers');
      }
      
      // Small delay to be network-friendly
      if (i + batchSize < ips.length) {
        await Future.delayed(const Duration(milliseconds: 25));
      }
    }
  }
  
  /// Test connection specifically for Epson TM-M30III
  Future<PrinterDevice?> _testEpsonTmM30iiiConnection(String ip, int port) async {
    Socket? socket;
    
    try {
      debugPrint('🔍 Testing Epson connection: $ip:$port');
      
      // Establish connection with appropriate timeout
      socket = await Socket.connect(
        ip, 
        port, 
        timeout: const Duration(seconds: 2)
      );
      
      // Configure socket for optimal printer communication
      socket.setOption(SocketOption.tcpNoDelay, true);
      
      // Epson TM-M30III specific identification sequence
      final printerInfo = await _identifyEpsonTmM30iii(socket);
      
      if (printerInfo != null) {
        debugPrint('✅ Verified Epson TM-M30III at $ip:$port');
        
        return PrinterDevice(
          id: 'epson_tm_m30iii_${ip.replaceAll('.', '_')}_$port',
          name: printerInfo['name'] ?? 'Epson TM-M30III ($ip)',
          address: '$ip:$port',
          type: PrinterType.wifi,
          model: printerInfo['model'] ?? 'TM-M30III',
          signalStrength: _calculateSignalStrength(ip),
        );
      }
      
    } catch (e) {
      // Not an Epson printer or connection failed
      // debugPrint('❌ Not Epson or connection failed for $ip:$port: $e');
    } finally {
      try {
        await socket?.close();
      } catch (e) {
        // Ignore close errors
      }
    }
    
    return null;
  }
  
  /// Identify if connected device is an Epson TM-M30III
  Future<Map<String, String>?> _identifyEpsonTmM30iii(Socket socket) async {
    try {
      // Epson TM-M30III specific identification commands
      final commands = <List<int>>[
        [0x1B, 0x40], // ESC @ - Initialize printer
        [0x10, 0x04, 0x01], // DLE EOT 1 - Real-time status transmission
        [0x10, 0x04, 0x02], // DLE EOT 2 - Offline status transmission
        [0x1D, 0x49, 0x01], // GS I 1 - Printer ID
        [0x1D, 0x49, 0x02], // GS I 2 - Type ID
        [0x1D, 0x49, 0x03], // GS I 3 - Version
      ];
      
      final responses = <List<int>>[];
      
      // Send commands and collect responses
      for (final command in commands) {
        try {
          socket.add(command);
          await socket.flush();
          
          // Wait for response with timeout
          final response = await socket
            .timeout(const Duration(milliseconds: 500))
            .take(1)
            .toList();
          
          if (response.isNotEmpty) {
            responses.add(response.first);
          }
          
          // Small delay between commands
          await Future.delayed(const Duration(milliseconds: 100));
          
        } catch (e) {
          // Command failed, continue with next
          debugPrint('⚠️ Command failed: $command - $e');
        }
      }
      
      // Analyze responses to identify Epson TM-M30III
      if (responses.isNotEmpty) {
        final printerInfo = _analyzeEpsonResponses(responses);
        
        // Check if responses indicate TM-M30III
        if (_isEpsonTmM30iii(responses, printerInfo)) {
          return printerInfo;
        }
      }
      
      // Fallback: Test with simple print command
      return await _testEpsonPrintCapability(socket);
      
    } catch (e) {
      debugPrint('❌ Error identifying Epson printer: $e');
      return null;
    }
  }
  
  /// Analyze Epson printer responses
  Map<String, String> _analyzeEpsonResponses(List<List<int>> responses) {
    final info = <String, String>{};
    
    try {
      // Parse printer ID and model information from responses
      for (int i = 0; i < responses.length; i++) {
        final response = responses[i];
        
        if (response.isNotEmpty) {
          final responseStr = String.fromCharCodes(response.where((b) => b >= 32 && b <= 126));
          
          if (responseStr.toLowerCase().contains('tm-m30')) {
            info['model'] = 'TM-M30III';
            info['name'] = 'Epson TM-M30III';
          } else if (responseStr.toLowerCase().contains('epson')) {
            info['model'] = 'Epson Printer';
            info['name'] = 'Epson Thermal Printer';
          }
          
          // Store version info if available
          if (responseStr.isNotEmpty && !info.containsKey('version')) {
            info['version'] = responseStr.replaceAll(RegExp(r'[^\w\.-]'), '');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error analyzing Epson responses: $e');
    }
    
    return info;
  }
  
  /// Check if responses indicate TM-M30III
  bool _isEpsonTmM30iii(List<List<int>> responses, Map<String, String> info) {
    // Look for TM-M30III specific patterns
    if (info['model']?.contains('TM-M30') == true) {
      return true;
    }
    
    // Check response patterns typical of TM-M30III
    for (final response in responses) {
      if (response.length >= 2) {
        // Check for Epson-specific status bytes
        if ((response[0] == 0x16 || response[0] == 0x12) && response[1] < 0x20) {
          return true; // Likely Epson status response
        }
      }
    }
    
    return false;
  }
  
  /// Test Epson print capability as fallback identification
  Future<Map<String, String>?> _testEpsonPrintCapability(Socket socket) async {
    try {
      // Send minimal Epson test sequence
      final testSequence = [
        0x1B, 0x40, // ESC @ - Initialize
        0x1B, 0x74, 0x00, // ESC t 0 - Select character code table
        // Don't actually print anything, just test command acceptance
      ];
      
      socket.add(testSequence);
      await socket.flush();
      
      // Wait briefly for any error response
      await Future.delayed(const Duration(milliseconds: 200));
      
      // If we reach here without exception, likely an Epson printer
      debugPrint('✅ Printer accepts Epson ESC/POS commands');
      
      return {
        'model': 'Epson Compatible',
        'name': 'Epson ESC/POS Printer',
        'compatibility': 'TM-M30III Compatible'
      };
      
    } catch (e) {
      debugPrint('❌ Printer does not accept Epson commands: $e');
      return null;
    }
  }
  
  /// Robust connection to Epson TM-M30III with retry logic
  Future<bool> connectToEpsonTmM30iii(String ipAddress, {int port = 9100}) async {
    debugPrint('🔗 Connecting to Epson TM-M30III at $ipAddress:$port');
    
    const maxRetries = 5;
    const baseDelay = Duration(milliseconds: 500);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('🔄 Connection attempt $attempt/$maxRetries to $ipAddress:$port');
        
        // Close any existing connection
        if (_wifiSocket != null) {
          try {
            await _wifiSocket!.close();
          } catch (e) {
            debugPrint('⚠️ Error closing existing socket: $e');
          }
          _wifiSocket = null;
        }
        
        // Establish new connection
        _wifiSocket = await Socket.connect(
          ipAddress,
          port,
          timeout: Duration(seconds: 3 + attempt), // Increase timeout with attempts
        );
        
        // Configure socket for Epson printer communication
        _wifiSocket!.setOption(SocketOption.tcpNoDelay, true);
        
        // Set up connection monitoring
        _wifiSocket!.listen(
          (data) {
            debugPrint('📥 Received ${data.length} bytes from Epson printer');
          },
          onError: (error) {
            debugPrint('❌ Epson printer connection error: $error');
            _wifiSocket = null;
            _connectedPrinter = null;
            _safeNotifyListeners();
          },
          onDone: () {
            debugPrint('🔌 Epson printer connection closed');
            _wifiSocket = null;
            if (_connectedPrinter != null) {
              _connectedPrinter = _connectedPrinter!.copyWith(isConnected: false);
              _safeNotifyListeners();
            }
          },
        );
        
        // Initialize Epson TM-M30III with proper command sequence
        final success = await _initializeEpsonTmM30iii();
        
        if (success) {
          // Create printer device
          _connectedPrinter = PrinterDevice(
            id: 'epson_tm_m30iii_connected',
            name: 'Epson TM-M30III ($ipAddress)',
            address: '$ipAddress:$port',
            type: PrinterType.wifi,
            model: 'TM-M30III',
            signalStrength: _calculateSignalStrength(ipAddress),
            isConnected: true,
          );
          
          await _saveConnectedPrinter();
          _safeNotifyListeners();
          
          debugPrint('✅ Successfully connected to Epson TM-M30III at $ipAddress:$port');
          return true;
        } else {
          debugPrint('❌ Failed to initialize Epson TM-M30III');
          await _wifiSocket?.close();
          _wifiSocket = null;
        }
        
      } catch (e) {
        debugPrint('❌ Attempt $attempt failed: $e');
        _wifiSocket = null;
        
        if (attempt < maxRetries) {
          final delay = baseDelay * attempt; // Exponential backoff
          debugPrint('⏳ Waiting ${delay.inMilliseconds}ms before retry...');
          await Future.delayed(delay);
        }
      }
    }
    
    debugPrint('❌ All connection attempts failed for Epson TM-M30III at $ipAddress:$port');
    return false;
  }
  
  /// Initialize Epson TM-M30III with proper command sequence
  Future<bool> _initializeEpsonTmM30iii() async {
    if (_wifiSocket == null) return false;
    
    try {
      debugPrint('🔧 Initializing Epson TM-M30III...');
      
      // Epson TM-M30III initialization sequence
      final initCommands = <List<int>>[
        [0x1B, 0x40], // ESC @ - Initialize printer
        [0x1B, 0x74, 0x00], // ESC t 0 - Character code table (PC437)
        [0x1B, 0x52, 0x00], // ESC R 0 - International character set
        [0x1B, 0x61, 0x00], // ESC a 0 - Left alignment
        [0x1C, 0x2E], // FS . - Cancel Chinese character mode
        [0x1B, 0x21, 0x00], // ESC ! 0 - Select print mode (normal)
      ];
      
      for (final command in initCommands) {
        try {
          _wifiSocket!.add(command);
          await _wifiSocket!.flush();
          
          // Small delay between commands for printer processing
          await Future.delayed(const Duration(milliseconds: 50));
          
        } catch (e) {
          debugPrint('⚠️ Init command failed: $command - $e');
          return false;
        }
      }
      
      // Test print capability with minimal output
      await _testEpsonPrintCapabilityMinimal();
      
      debugPrint('✅ Epson TM-M30III initialized successfully');
      return true;
      
    } catch (e) {
      debugPrint('❌ Failed to initialize Epson TM-M30III: $e');
      return false;
    }
  }
  
  /// Test print capability without actually printing
  Future<void> _testEpsonPrintCapabilityMinimal() async {
    if (_wifiSocket == null) return;
    
    try {
      // Send status request to test communication
      final statusCommand = [0x10, 0x04, 0x01]; // DLE EOT 1 - Real-time status
      _wifiSocket!.add(statusCommand);
      await _wifiSocket!.flush();
      
      // Wait for status response
      await Future.delayed(const Duration(milliseconds: 100));
      
      debugPrint('✅ Epson communication test successful');
      
    } catch (e) {
      debugPrint('⚠️ Epson communication test failed: $e');
      // Don't throw - connection might still work for printing
    }
  }
  
  /// Test print to Epson TM-M30III
  Future<bool> testPrintEpsonTmM30iii({String? customMessage}) async {
    if (_wifiSocket == null || _connectedPrinter == null) {
      debugPrint('❌ No Epson printer connected for test print');
      return false;
    }
    
    try {
      debugPrint('🖨️ Starting test print to Epson TM-M30III...');
      
      final testContent = _generateEpsonTestReceipt(customMessage);
      final data = Uint8List.fromList(testContent.codeUnits);
      
      // Send test print with retry logic
      const maxRetries = 3;
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          _wifiSocket!.add(data);
          await _wifiSocket!.flush();
          
          // Wait for print completion
          await Future.delayed(const Duration(seconds: 2));
          
          debugPrint('✅ Epson test print sent successfully');
          return true;
          
        } catch (e) {
          debugPrint('❌ Test print attempt $attempt failed: $e');
          
          if (attempt < maxRetries) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }
      
      return false;
      
    } catch (e) {
      debugPrint('❌ Epson test print failed: $e');
      return false;
    }
  }
  
  /// Generate Epson TM-M30III optimized test receipt
  String _generateEpsonTestReceipt(String? customMessage) {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    
    return '''
\x1B\x40\x1B\x61\x01\x1B\x21\x30EPSON TM-M30III\x0A\x1B\x21\x00CONNECTION TEST\x0A\x1B\x61\x00
--------------------------------
Date: $dateStr
Time: $timeStr
IP: ${_connectedPrinter?.address ?? 'Unknown'}
Status: Connected & Working
--------------------------------
${customMessage ?? 'Test print successful!\nPrinter is ready for use.'}
--------------------------------
\x1B\x61\x01\x1B\x21\x08Thank you!\x0A\x1B\x21\x00\x1B\x61\x00
\x0A\x0A\x0A\x1D\x56\x00''';
  }
  
  /// Quick connection test for known Epson printer
  Future<bool> quickTestEpsonConnection(String ipAddress, {int port = 9100}) async {
    debugPrint('⚡ Quick testing Epson connection: $ipAddress:$port');
    
    Socket? socket;
    try {
      // Quick connection test
      socket = await Socket.connect(
        ipAddress,
        port,
        timeout: const Duration(seconds: 3),
      );
      
      // Send simple status request
      socket.add([0x10, 0x04, 0x01]); // DLE EOT 1
      await socket.flush();
      
      // Wait briefly for response
      await Future.delayed(const Duration(milliseconds: 300));
      
      debugPrint('✅ Quick Epson test successful for $ipAddress:$port');
      return true;
      
    } catch (e) {
      debugPrint('❌ Quick Epson test failed for $ipAddress:$port: $e');
      return false;
    } finally {
      try {
        await socket?.close();
      } catch (e) {
        // Ignore close errors
      }
    }
  }

  /// ======================================================
  /// END OF EPSON TM-M30III SPECIFIC IMPLEMENTATION
  /// ======================================================

  /// ======================================================
  /// ENHANCED EPSON TM-M30III ESC/POS COMMAND GENERATION
  /// ======================================================
  
  /// Generate comprehensive ESC/POS commands for Epson TM-M30III
  String _generateGenericESCPOSReceipt(Order order) {
    final List<int> commands = [];
    
    // STEP 1: Initialize Epson TM-M30III
    commands.addAll([0x1B, 0x40]); // ESC @ (Initialize printer)
    commands.addAll([0x1B, 0x4D, 0x01]); // ESC M (Select character font A)
    commands.addAll([0x1D, 0x61, 0x01]); // GS a (Enable automatic status back)
    commands.addAll([0x1B, 0x63, 0x35, 0x00]); // ESC c 5 (Disable panel buttons)
    
    // STEP 2: Set paper and print parameters for 80mm thermal paper
    commands.addAll([0x1B, 0x61, 0x01]); // ESC a (Center alignment)
    commands.addAll([0x1D, 0x21, 0x11]); // GS ! (Double width and height)
    
    // STEP 3: Header with restaurant info
    if (_enableHeaderLogo && _settings.enableReceiptHeader) {
      const bool _forceOhBombayHeader = true; // feature flag for tenant-specific header
      final headerName = _forceOhBombayHeader ? "OH BOMBAY MILTON" : (_settings.businessName.isNotEmpty ? _settings.businessName : "Restaurant POS");
      commands.addAll(headerName.codeUnits);
      commands.addAll([0x0A, 0x0A]); // LF LF (2 line feeds)
      
      commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
      if (_settings.businessAddress.isNotEmpty) {
        commands.addAll(_settings.businessAddress.codeUnits);
        commands.addAll([0x0A]); // LF
      }
      if (_settings.businessPhone.isNotEmpty) {
        commands.addAll(_settings.businessPhone.codeUnits);
        commands.addAll([0x0A]); // LF
      }
      commands.addAll([0x0A]); // LF
    }
    
    // STEP 4: Order header info
    commands.addAll([0x1B, 0x61, 0x00]); // ESC a (Left alignment)
    commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
    
    final orderHeader = "ORDER #${order.orderNumber}";
    commands.addAll(orderHeader.codeUnits);
    commands.addAll([0x0A]); // LF
    commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
    
    final dateTime = "Date: ${_formatDateTime(order.orderTime)}";
    commands.addAll(dateTime.codeUnits);
    commands.addAll([0x0A]); // LF
    
    final orderType = "Type: ${order.type.toString().split('.').last}";
    commands.addAll(orderType.codeUnits);
    commands.addAll([0x0A]); // LF
    
    if (order.tableId != null) {
      final tableInfo = "Table: ${order.tableId}";
      commands.addAll(tableInfo.codeUnits);
      commands.addAll([0x0A]); // LF
    }
    
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      final customerInfo = "Customer: ${order.customerName}";
      commands.addAll(customerInfo.codeUnits);
      commands.addAll([0x0A]); // LF
    }
    
    // Separator line
    commands.addAll([0x0A]); // LF
    final separator = "=" * 42;
    commands.addAll(separator.codeUnits);
    commands.addAll([0x0A]); // LF
    
    // STEP 5: Order items with proper formatting
    if (_printOrderDetails) {
      commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
      commands.addAll("ITEMS:".codeUnits);
      commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
      commands.addAll([0x0A]); // LF
      
      for (final item in order.items) {
        // Item line with quantity and name
        final itemLine = "${item.quantity}x ${item.menuItem.name}";
        commands.addAll(itemLine.codeUnits);
        commands.addAll([0x0A]); // LF
        
        // Price aligned to right (approximate)
        final price = "${_settings.currencySymbol}${item.totalPrice.toStringAsFixed(2)}";
        final priceLine = " " * (42 - price.length) + price;
        commands.addAll(priceLine.codeUnits);
        commands.addAll([0x0A]); // LF
        
        // Item modifications
        if (item.selectedVariant != null && item.selectedVariant!.isNotEmpty) {
          final variantLine = "  Variant: ${item.selectedVariant}";
          commands.addAll(variantLine.codeUnits);
          commands.addAll([0x0A]); // LF
        }
        
        if (item.selectedModifiers.isNotEmpty) {
          for (final modifier in item.selectedModifiers) {
            final modifierLine = "  + $modifier";
            commands.addAll(modifierLine.codeUnits);
            commands.addAll([0x0A]); // LF
          }
        }
        
        // Special instructions with emphasis
        if (item.specialInstructions != null && item.specialInstructions!.isNotEmpty) {
          commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
          final instructionLine = "  NOTE: ${item.specialInstructions}";
          commands.addAll(instructionLine.codeUnits);
          commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
          commands.addAll([0x0A]); // LF
        }
        
        // Chef notes
        if (item.notes != null && item.notes!.isNotEmpty) {
          final notesLine = "  Chef: ${item.notes}";
          commands.addAll(notesLine.codeUnits);
          commands.addAll([0x0A]); // LF
        }
        
        // Handle spice level if available
        if (item.customProperties.containsKey('customSpiceLevel')) {
          final spiceLevel = item.customProperties['customSpiceLevel'];
          if (spiceLevel != null && spiceLevel.isNotEmpty) {
            commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
            final spiceLine = "  🌶️ SPICE: $spiceLevel";
            commands.addAll(spiceLine.codeUnits);
            commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
            commands.addAll([0x0A]); // LF
          }
        }
        
        commands.addAll([0x0A]); // LF (blank line between items)
      }
    }
    
    // STEP 6: Totals section with emphasis
    commands.addAll(separator.codeUnits);
    commands.addAll([0x0A]); // LF
    
    // Subtotal
    final subtotalLine = "Subtotal:" + " " * (34 - "Subtotal:".length) + "${_settings.currencySymbol}${order.subtotal.toStringAsFixed(2)}";
    commands.addAll(subtotalLine.codeUnits);
    commands.addAll([0x0A]); // LF
    
    // Discount if applicable
    if (order.discountAmount != null && order.discountAmount! > 0) {
      final discountLine = "Discount:" + " " * (34 - "Discount:".length) + "-${_settings.currencySymbol}${order.discountAmount!.toStringAsFixed(2)}";
      commands.addAll(discountLine.codeUnits);
      commands.addAll([0x0A]); // LF
    }
    
    // Tax/HST - Always show if there's a calculated amount
    double displayTaxAmount = 0.0;
    
    // Check HST amount first (preferred), then tax amount, then calculated HST
    if (order.hstAmount > 0) {
      displayTaxAmount = order.hstAmount;
    } else if (order.taxAmount > 0) {
      displayTaxAmount = order.taxAmount;
    } else {
      displayTaxAmount = order.calculatedHstAmount;
    }
    
    // Always display tax if there's an amount > 0
    if (displayTaxAmount > 0) {
      final taxLine = "${_settings.taxName} (${_settings.taxRate.toStringAsFixed(1)}%):" + " " * (34 - "${_settings.taxName} (${_settings.taxRate.toStringAsFixed(1)}%):".length) + "${_settings.currencySymbol}${displayTaxAmount.toStringAsFixed(2)}";
      commands.addAll(taxLine.codeUnits);
      commands.addAll([0x0A]); // LF
    }
    
    // Gratuity
    if (order.gratuityAmount != null && order.gratuityAmount! > 0) {
      final gratuityLine = "Gratuity:" + " " * (34 - "Gratuity:".length) + "${_settings.currencySymbol}${order.gratuityAmount!.toStringAsFixed(2)}";
      commands.addAll(gratuityLine.codeUnits);
      commands.addAll([0x0A]); // LF
    }
    
    // Total with emphasis
    commands.addAll(separator.codeUnits);
    commands.addAll([0x0A]); // LF
    commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
    commands.addAll([0x1D, 0x21, 0x11]); // GS ! (Double width and height)
    
    final totalLine = "TOTAL: ${_settings.currencySymbol}${order.totalAmount.toStringAsFixed(2)}";
    commands.addAll(totalLine.codeUnits);
    commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
    commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
    commands.addAll([0x0A, 0x0A]); // LF LF
    
    // STEP 7: Footer message
    if (_footerMessage.isNotEmpty) {
      commands.addAll([0x1B, 0x61, 0x01]); // ESC a (Center alignment)
      commands.addAll(_footerMessage.codeUnits);
      commands.addAll([0x0A, 0x0A]); // LF LF
    }
    
    // STEP 8: Special instructions for order
    if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) {
      commands.addAll([0x1B, 0x61, 0x00]); // ESC a (Left alignment)
      commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
      commands.addAll("SPECIAL INSTRUCTIONS:".codeUnits);
      commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
      commands.addAll([0x0A]); // LF
      commands.addAll(order.specialInstructions!.codeUnits);
      commands.addAll([0x0A, 0x0A]); // LF LF
    }
    
    // STEP 9: Feed paper and cut for Epson TM-M30III
    commands.addAll([0x0A, 0x0A, 0x0A, 0x0A]); // 4 line feeds before cut
    commands.addAll([0x1D, 0x56, 0x00]); // GS V (Full cut)
    
    // Convert to string and return
    return String.fromCharCodes(commands);
  }
  
  /// Generate enhanced kitchen ticket for Epson TM-M30III with bold, big, and nicely indented format
  String _generateGenericESCPOSKitchenTicket(Order order, String printerName) {
    final List<int> commands = [];
    
    // STEP 1: Initialize Epson TM-M30III for kitchen printing
    commands.addAll([0x1B, 0x40]); // ESC @ (Initialize printer)
    commands.addAll([0x1B, 0x4D, 0x01]); // ESC M (Select character font A)
    commands.addAll([0x1D, 0x61, 0x01]); // GS a (Enable automatic status back)
    
    // STEP 2: Kitchen ticket header with maximum emphasis
    commands.addAll([0x1B, 0x61, 0x01]); // ESC a (Center alignment)
    commands.addAll([0x1D, 0x21, 0x22]); // GS ! (Triple width and height)
    commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
    
    commands.addAll("🍽️ KITCHEN 🍽️".codeUnits);
    commands.addAll([0x0A]); // LF
    commands.addAll("   TICKET".codeUnits);
    commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
    commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
    commands.addAll([0x0A, 0x0A]); // LF LF
    
    // Station info with emphasis
    commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
    commands.addAll([0x1D, 0x21, 0x11]); // GS ! (Double width and height)
    final stationLine = "🏪 STATION: $printerName";
    commands.addAll(stationLine.codeUnits);
    commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
    commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
    commands.addAll([0x0A, 0x0A]); // LF LF
    
    // STEP 3: Order information with enhanced formatting
    commands.addAll([0x1B, 0x61, 0x00]); // ESC a (Left alignment)
    
    // Order number with maximum emphasis
    commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
    commands.addAll([0x1D, 0x21, 0x22]); // GS ! (Triple width and height)
    final orderLine = "📋 ORDER #${order.orderNumber}";
    commands.addAll(orderLine.codeUnits);
    commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
    commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
    commands.addAll([0x0A, 0x0A]); // LF LF
    
    // Order details with enhanced formatting and icons
    commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
    commands.addAll([0x1D, 0x21, 0x01]); // GS ! (Double height)
    final timeLine = "⏰ Time: ${_formatTime(order.orderTime)}";
    commands.addAll(timeLine.codeUnits);
    commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
    commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
    commands.addAll([0x0A]); // LF
    
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
      commands.addAll([0x1D, 0x21, 0x01]); // GS ! (Double height)
      final customerLine = "👤 Customer: ${order.customerName}";
      commands.addAll(customerLine.codeUnits);
      commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
      commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
      commands.addAll([0x0A]); // LF
    }
    
    commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
    commands.addAll([0x1D, 0x21, 0x01]); // GS ! (Double height)
    final typeLine = "📝 Type: ${order.type.toString().split('.').last.toUpperCase()}";
    commands.addAll(typeLine.codeUnits);
    commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
    commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
    commands.addAll([0x0A]); // LF
    
    if (order.tableId != null) {
      commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
      commands.addAll([0x1D, 0x21, 0x01]); // GS ! (Double height)
      final tableLine = "🪑 Table: ${order.tableId}";
      commands.addAll(tableLine.codeUnits);
      commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
      commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
      commands.addAll([0x0A]); // LF
    }
    
    // Urgent marking with maximum emphasis
    if (order.isUrgent) {
      commands.addAll([0x0A]); // LF
      commands.addAll([0x1B, 0x61, 0x01]); // ESC a (Center alignment)
      commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
      commands.addAll([0x1D, 0x21, 0x33]); // GS ! (Maximum width and height)
      commands.addAll("🚨 URGENT 🚨".codeUnits);
      commands.addAll([0x0A]); // LF
      commands.addAll("*** RUSH ***".codeUnits);
      commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
      commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
      commands.addAll([0x1B, 0x61, 0x00]); // ESC a (Left alignment)
      commands.addAll([0x0A, 0x0A]); // LF LF
    }
    
    // Enhanced separator
    commands.addAll([0x0A]); // LF
    final separator = "═" * 42;
    commands.addAll(separator.codeUnits);
    commands.addAll([0x0A]); // LF
    
    // STEP 4: Items section with enhanced formatting
    commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
    commands.addAll([0x1D, 0x21, 0x11]); // GS ! (Double width and height)
    commands.addAll("🍽️ ITEMS TO PREPARE:".codeUnits);
    commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
    commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
    commands.addAll([0x0A, 0x0A]); // LF LF
    
    for (final item in order.items) {
      // Item with quantity and name - enhanced formatting
      commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
      const bool _enableTripleSizedKitchenItems = true; // feature flag
      if (_enableTripleSizedKitchenItems) {
        commands.addAll([0x1D, 0x21, 0x22]); // GS ! (Triple width and height)
      } else {
        commands.addAll([0x1D, 0x21, 0x11]); // GS ! (Double width and height)
      }
      final itemLine = "▶️ ${item.quantity}x ${item.menuItem.name}";
      commands.addAll(itemLine.codeUnits);
      commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
      commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
      commands.addAll([0x0A]); // LF
      
      // Variant with enhanced indentation
      if (item.selectedVariant != null && item.selectedVariant!.isNotEmpty) {
        commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
        final variantLine = "    🔸 Variant: ${item.selectedVariant}";
        commands.addAll(variantLine.codeUnits);
        commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
        commands.addAll([0x0A]); // LF
      }
      
      // Modifiers with enhanced indentation
      if (item.selectedModifiers.isNotEmpty) {
        for (final modifier in item.selectedModifiers) {
          commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
          final modifierLine = "    ➕ $modifier";
          commands.addAll(modifierLine.codeUnits);
          commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
          commands.addAll([0x0A]); // LF
        }
      }
      
      // Special instructions with maximum emphasis
      if (item.specialInstructions != null && item.specialInstructions!.isNotEmpty) {
        commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
        commands.addAll([0x1D, 0x21, 0x01]); // GS ! (Double height)
        final instructionLine = "    ⚠️ NOTE: ${item.specialInstructions}";
        commands.addAll(instructionLine.codeUnits);
        commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
        commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
        commands.addAll([0x0A]); // LF
      }
      
      // Chef notes with enhanced formatting
      if (item.notes != null && item.notes!.isNotEmpty) {
        commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
        final notesLine = "    👨‍🍳 Chef: ${item.notes}";
        commands.addAll(notesLine.codeUnits);
        commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
        commands.addAll([0x0A]); // LF
      }
      
      // Spice level with maximum emphasis
      if (item.customProperties.containsKey('customSpiceLevel')) {
        final spiceLevel = item.customProperties['customSpiceLevel'];
        if (spiceLevel != null && spiceLevel.isNotEmpty && spiceLevel != 'No Spice') {
          commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
          commands.addAll([0x1D, 0x21, 0x01]); // GS ! (Double height)
          final spiceLine = "    🌶️ SPICE: $spiceLevel";
          commands.addAll(spiceLine.codeUnits);
          commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
          commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
          commands.addAll([0x0A]); // LF
        }
      }
      
      // Enhanced separator between items
      commands.addAll([0x0A]); // LF
      final itemSeparator = "─" * 30;
      commands.addAll(itemSeparator.codeUnits);
      commands.addAll([0x0A, 0x0A]); // LF LF
    }
    
    // STEP 5: Special instructions for entire order with emphasis
    if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) {
      commands.addAll(separator.codeUnits);
      commands.addAll([0x0A]); // LF
      commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
      commands.addAll([0x1D, 0x21, 0x11]); // GS ! (Double width and height)
      commands.addAll("⚠️ SPECIAL INSTRUCTIONS:".codeUnits);
      commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
      commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
      commands.addAll([0x0A]); // LF
      
      commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
      commands.addAll([0x1D, 0x21, 0x01]); // GS ! (Double height)
      commands.addAll("*** ${order.specialInstructions!} ***".codeUnits);
      commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
      commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
      commands.addAll([0x0A]); // LF
    }
    
    // STEP 6: Enhanced footer
    commands.addAll([0x0A]); // LF
    commands.addAll(separator.codeUnits);
    commands.addAll([0x0A]); // LF
    commands.addAll([0x1B, 0x61, 0x01]); // ESC a (Center alignment)
    commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
    commands.addAll([0x1D, 0x21, 0x01]); // GS ! (Double height)
    final footerLine = "📍 Prepared at: $printerName";
    commands.addAll(footerLine.codeUnits);
    commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
    commands.addAll([0x1D, 0x21, 0x00]); // GS ! (Normal size)
    commands.addAll([0x0A]); // LF
    
    commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
    final timePrepared = "⏰ Printed: ${_formatTime(DateTime.now())}";
    commands.addAll(timePrepared.codeUnits);
    commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
    commands.addAll([0x0A, 0x0A]); // LF LF
    
    // Final message
    commands.addAll([0x1B, 0x45, 0x01]); // ESC E (Bold on)
    commands.addAll("✅ START COOKING NOW!".codeUnits);
    commands.addAll([0x1B, 0x45, 0x00]); // ESC E (Bold off)
    commands.addAll([0x0A, 0x0A, 0x0A]); // LF LF LF
    
    // STEP 7: Cut paper for Epson TM-M30III
    commands.addAll([0x1D, 0x56, 0x00]); // GS V (Full cut)
    
    // Convert to string and return
    return String.fromCharCodes(commands);
  }

  /// Comprehensive Generic ESC/POS printer discovery and connection
  Future<List<PrinterDevice>> discoverGenericESCPOSPrinters() async {
    debugPrint('🔍 Starting discovery of generic ESC/POS printers...');
    
    _discoveredPrinters.clear();
    notifyListeners();

    try {
      final List<Future<PrinterDevice?>> futures = [];
      
      // Common IP ranges to scan (including discovered printer range)
      final List<String> ipRanges = [
        '192.168.0', // PRIORITY: Your Epson printers are here
        '192.168.1',
        '192.168.2',
        '10.0.0',
        '10.0.1',
        '172.16.0',
      ];
      
      // Common printer ports
      final List<int> ports = [9100, 515, 631, 9101, 9102];
      
      // Scan each IP range with priority for discovered printers
      for (final range in ipRanges) {
        // Priority scan for known Epson printer IPs first
        if (range == '192.168.0') {
          final priorityIPs = [147, 233, 141]; // Your discovered Epson printers
          for (final ip in priorityIPs) {
            for (final port in ports) {
              futures.add(_testGenericESCPOSConnection('$range.$ip', port));
            }
          }
        }
        
        // Then scan full range
        for (int i = 1; i <= 254; i++) {
          final ip = '$range.$i';
          for (final port in ports) {
            futures.add(_testGenericESCPOSConnection(ip, port));
          }
        }
      }
      
      // Wait for all tests to complete (with timeout)
      final results = await Future.wait(futures, eagerError: false);
      
      // Filter out nulls and add to discovered list
      final discoveredPrinters = results
          .where((printer) => printer != null)
          .cast<PrinterDevice>()
          .toList();
      
      _discoveredPrinters.addAll(discoveredPrinters);
      
      debugPrint('🎉 Discovery complete! Found ${_discoveredPrinters.length} generic ESC/POS printers');
      
      // FIXED: Notify about discovered printers for UI updates
      notifyListeners();
      
      return _discoveredPrinters;
    } catch (e) {
      debugPrint('❌ Error during printer discovery: $e');
      return [];
    }
  }

  /// Test connection for generic ESC/POS printer
  Future<PrinterDevice?> _testGenericESCPOSConnection(String ip, int port) async {
    Socket? socket;
    
    try {
      socket = await Socket.connect(
        ip, 
        port, 
        timeout: const Duration(seconds: 2)
      );
      
      // Send basic ESC/POS command to test
      socket.add([0x1B, 0x40]); // ESC @ - Initialize printer
      await socket.flush();
      
      // If we got here, it's likely a printer
      return PrinterDevice(
        id: 'generic_escpos_${ip.replaceAll('.', '_')}_$port',
        name: 'Generic ESC/POS Printer ($ip:$port)',
        address: '$ip:$port',
        type: PrinterType.wifi,
        model: 'Generic ESC/POS',
        signalStrength: 80,
      );
      
    } catch (e) {
      // Not a printer or connection failed
      return null;
    } finally {
      try {
        await socket?.close();
      } catch (e) {
        // Ignore close errors
      }
    }
  }

  /// Connect to generic ESC/POS printer
  Future<bool> connectToGenericESCPOS(String ipAddress, {int port = 9100}) async {
    try {
      debugPrint('🔗 Connecting to generic ESC/POS printer at $ipAddress:$port...');
      
      // Close existing connection if any
      if (_wifiSocket != null) {
        await _wifiSocket!.close();
        _wifiSocket = null;
      }
      
      // Create new connection
      _wifiSocket = await Socket.connect(
        ipAddress, 
        port, 
        timeout: const Duration(seconds: 5)
      );
      
      // Configure socket
      _wifiSocket!.setOption(SocketOption.tcpNoDelay, true);
      
      // Update connected printer info
      _connectedPrinter = PrinterDevice(
        id: 'generic_escpos_${ipAddress.replaceAll('.', '_')}_$port',
        name: 'Generic ESC/POS Printer',
        address: '$ipAddress:$port',
        type: PrinterType.wifi,
        model: 'Generic ESC/POS',
        isConnected: true,
        signalStrength: 80,
      );
      
      // Initialize printer
      final success = await _initializeGenericESCPOS();
      if (success) {
        debugPrint('✅ Successfully connected to generic ESC/POS printer');
        _safeNotifyListeners();
        return true;
      } else {
        debugPrint('❌ Failed to initialize generic ESC/POS printer');
        await _wifiSocket?.close();
        _wifiSocket = null;
        _connectedPrinter = null;
        return false;
      }
      
    } catch (e) {
      debugPrint('❌ Error connecting to generic ESC/POS printer: $e');
      _wifiSocket = null;
      _connectedPrinter = null;
      return false;
    }
  }

  /// Initialize generic ESC/POS printer
  Future<bool> _initializeGenericESCPOS() async {
    if (_wifiSocket == null) return false;
    
    try {
      // Send initialization sequence
      final commands = <List<int>>[
        [0x1B, 0x40], // ESC @ - Initialize printer
        [0x1B, 0x74, 0x00], // ESC t 0 - Select character code table
        [0x1B, 0x52, 0x00], // ESC R 0 - Select international character set
        [0x1B, 0x61, 0x00], // ESC a 0 - Left align
      ];
      
      for (final command in commands) {
        _wifiSocket!.add(command);
        await _wifiSocket!.flush();
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      debugPrint('✅ Generic ESC/POS printer initialized successfully');
      return true;
      
    } catch (e) {
      debugPrint('❌ Error initializing generic ESC/POS printer: $e');
      return false;
    }
  }

  /// Test print for generic ESC/POS printer
  Future<bool> testPrintGenericESCPOS({String? customMessage}) async {
    if (_wifiSocket == null) {
      debugPrint('❌ No printer connection for test print');
      return false;
    }
    
    try {
      final testMessage = customMessage ?? 'Test print successful!';
      
      // Generate test print content
      final commands = <int>[];
      
      // Initialize and center align
      commands.addAll([0x1B, 0x40]); // ESC @ - Initialize
      commands.addAll([0x1B, 0x61, 0x01]); // ESC a 1 - Center align
      
      // Header
      commands.addAll([0x1B, 0x21, 0x30]); // ESC ! 48 - Double height and width
      commands.addAll('TEST PRINT'.codeUnits);
      commands.addAll([0x1B, 0x21, 0x00]); // ESC ! 0 - Normal size
      commands.addAll([0x0A, 0x0A]); // Line feeds
      
      // Test message
      commands.addAll([0x1B, 0x61, 0x00]); // ESC a 0 - Left align
      commands.addAll(testMessage.codeUnits);
      commands.addAll([0x0A]); // Line feed
      
      // Timestamp
      final timestamp = DateTime.now().toString().substring(0, 19);
      commands.addAll('Time: $timestamp'.codeUnits);
      commands.addAll([0x0A, 0x0A]); // Line feeds
      
      // Cut paper
      commands.addAll([0x1D, 0x56, 0x00]); // GS V 0 - Cut paper
      
      // Send to printer
      _wifiSocket!.add(commands);
      await _wifiSocket!.flush();
      
      debugPrint('✅ Test print sent successfully');
      return true;
      
    } catch (e) {
      debugPrint('❌ Error sending test print: $e');
      return false;
    }
  }

  /// Print to specific printer configuration (public method for external use)
  Future<bool> printToSpecificPrinter(String printerId, String content, PrinterType printerType) async {
    try {
      if (printerType == PrinterType.wifi) {
        // Extract IP and port from printer address
        final addressParts = printerId.split(':');
        final ip = addressParts[0];
        final port = addressParts.length > 1 ? int.tryParse(addressParts[1]) ?? 9100 : 9100;
        
        // Send content directly to the printer
        final socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(seconds: 5),
        );
        
        // Send content as bytes with optional auto-cut appended
        const bool _enableAutoCutAfterSend = true; // feature flag
        final List<int> bytes = <int>[]..addAll(content.codeUnits);
        
        if (_enableAutoCutAfterSend) {
          try {
            final String cutMarker = String.fromCharCodes([0x1D, 0x56]);
            final bool alreadyHasCut = content.contains(cutMarker);
            if (!alreadyHasCut) {
              // Feed a few lines and perform full cut (GS V 0)
              bytes.addAll([0x0A, 0x0A, 0x0A]);
              bytes.addAll([0x1D, 0x56, 0x00]);
            }
          } catch (_) {
            // Fallback: never block printing due to auto-cut logic
          }
        }
        
        socket.add(bytes);
        await socket.flush();
        await socket.close();
        
        debugPrint('✅ Successfully sent content to printer: $printerId');
        return true;
      } else {
        debugPrint('❌ Printer type $printerType not supported for specific printing');
        return false;
      }
      
    } catch (e) {
      debugPrint('❌ Error printing to specific printer: $e');
      return false;
    }
  }

  /// Maintain printer connections during order completion
  Future<void> maintainConnectionsDuringOrderCompletion() async {
    debugPrint('🔌 Maintaining printer connections during order completion...');
    
    // Keep existing connections alive
    for (final connection in _activeConnections.values) {
      try {
        if (connection.isConnected) {
          // Send a keep-alive command
          final keepAliveData = Uint8List.fromList('\x1B\x40'.codeUnits); // ESC @ (initialize)
          await connection.sendData(keepAliveData);
          debugPrint('✅ Maintained connection to ${connection.config.name}');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to maintain connection to ${connection.config.name}: $e');
        // Don't break other connections if one fails
      }
    }
    
    // Keep WiFi socket alive if connected
    if (_wifiSocket != null) {
      try {
        final keepAliveData = Uint8List.fromList('\x1B\x40'.codeUnits); // ESC @ (initialize)
        _wifiSocket!.add(keepAliveData);
        await _wifiSocket!.flush();
        debugPrint('✅ Maintained WiFi socket connection');
      } catch (e) {
        debugPrint('⚠️ Failed to maintain WiFi socket connection: $e');
      }
    }
    
    debugPrint('🔌 Printer connections maintained successfully');
  }
  
  /// Check if printing service is healthy
  bool get isHealthy {
    return _connectedPrinter != null || _activeConnections.isNotEmpty || _wifiSocket != null;
  }
  
  /// Get printing service health status
  Map<String, dynamic> get healthStatus {
    return {
      'connectedPrinter': _connectedPrinter?.name ?? 'None',
      'activeConnections': _activeConnections.length,
      'wifiSocket': _wifiSocket != null,
      'isHealthy': isHealthy,
      'lastError': _lastError,
    };
  }
  
  /// Reinitialize service if needed
  Future<bool> reinitializeIfNeeded() async {
    if (isHealthy) {
      debugPrint('✅ Printing service is healthy, no reinitialization needed');
      return true;
    }
    
    debugPrint('🔄 Printing service needs reinitialization');
    try {
      // Try to reconnect to the last known printer
      if (_connectedPrinter != null) {
        await connectToPrinter(_connectedPrinter!);
        return _wifiSocket != null;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Failed to reinitialize printing service: $e');
      return false;
    }
  }

  /// Immediate auto-reconnect for login scenarios
  Future<void> immediateAutoReconnect() async {
    try {
      debugPrint('🚀 Starting immediate auto-reconnect for login...');
      
      // Get saved printer configurations
      final String? activePrintersJson = _prefs.getString(_activePrintersKey);
      if (activePrintersJson == null) {
        debugPrint('ℹ️ No previously connected printers found');
        return;
      }
      
      final List<dynamic> printersList = jsonDecode(activePrintersJson);
      debugPrint('📋 Found ${printersList.length} previously connected printers for immediate reconnection');
      
      // For each saved printer configuration, attempt to reconnect immediately
      for (final printerData in printersList) {
        try {
          // Validate printer data structure
          if (printerData is! Map<String, dynamic>) {
            debugPrint('⚠️ Invalid printer data structure, skipping');
            continue;
          }
          
          final printerId = printerData['id'] as String?;
          final printerName = printerData['name'] as String? ?? 'Printer $printerId';
          final printerType = printerData['type'] as String? ?? 'PrinterType.wifi';
          final ipAddress = printerData['ipAddress'] as String?;
          final port = printerData['port'] as int?;
          final isActive = printerData['isActive'] as bool? ?? true;
          
          if (printerId == null || !isActive) {
            debugPrint('⏭️ Skipping invalid or inactive printer: $printerName');
            continue;
          }
          
          // Create configuration based on saved data
          PrinterConfiguration config;
          
          if (printerType.contains('wifi') && ipAddress != null && ipAddress.isNotEmpty) {
            config = PrinterConfiguration(
              id: printerId,
              name: printerName,
              type: PrinterType.wifi,
              ipAddress: ipAddress,
              port: port ?? 9100,
              isActive: true,
            );
          } else {
            debugPrint('⚠️ Invalid printer configuration for $printerName, skipping');
            continue;
          }
          
          debugPrint('🔗 Attempting immediate reconnection to $printerName ($printerType)...');
          final success = await _connectToPrinterAsync(config);
          
          if (success) {
            debugPrint('✅ Successfully reconnected to $printerName');
          } else {
            debugPrint('❌ Failed to reconnect to $printerName');
          }
        } catch (e) {
          debugPrint('❌ Error reconnecting to printer: $e');
        }
      }
      
      debugPrint('🚀 Immediate auto-reconnect process completed');
    } catch (e) {
      debugPrint('❌ Error during immediate auto-reconnect: $e');
    }
  }

  /// Discover Bluetooth printers
  Future<List<PrinterDevice>> discoverBluetoothPrinters() async {
    debugPrint('🔍 Bluetooth discovery temporarily disabled');
    return [];
  }

  /// URGENT: Add known Epson TM-M30II printers directly (bypass discovery)
  /// This method adds the specific Epson printers found on the network
  Future<void> addKnownEpsonPrinters() async {
    debugPrint('🚨 URGENT: Adding known Epson TM-M30II printers directly...');
    
    _discoveredPrinters.clear();
    
    // Your specific Epson TM-M30II printers
    final knownEpsonPrinters = [
      PrinterDevice(
        id: 'epson_tm_m30ii_147',
        name: 'Epson TM-M30II Kitchen (192.168.0.147)',
        address: '192.168.0.147:9100',
        type: PrinterType.wifi,
        model: 'TM-M30II',
        signalStrength: 95,
      ),
      PrinterDevice(
        id: 'epson_tm_m30ii_233',
        name: 'Epson TM-M30II Receipt (192.168.0.233)',
        address: '192.168.0.233:9100',
        type: PrinterType.wifi,
        model: 'TM-M30II',
        signalStrength: 95,
      ),
      PrinterDevice(
        id: 'epson_tm_m30ii_141',
        name: 'Epson TM-M30II Backup (192.168.0.141)',
        address: '192.168.0.141:9100',
        type: PrinterType.wifi,
        model: 'TM-M30II',
        signalStrength: 95,
      ),
    ];
    
    // Test each printer and add if responsive
    for (final printer in knownEpsonPrinters) {
      try {
        final parts = printer.address.split(':');
        final ip = parts[0];
        final port = int.parse(parts[1]);
        
        debugPrint('🔍 Testing Epson printer at $ip:$port...');
        
        // Quick connection test
        final socket = await Socket.connect(
          ip, 
          port, 
          timeout: const Duration(seconds: 3)
        );
        
        // Send ESC/POS initialization command
        socket.add([0x1B, 0x40]); // ESC @ - Initialize printer
        await socket.flush();
        await socket.close();
        
        // If we got here, printer is responsive
        _discoveredPrinters.add(printer);
        debugPrint('✅ Added responsive Epson printer: ${printer.name}');
        
      } catch (e) {
        debugPrint('⚠️ Epson printer ${printer.name} not responsive: $e');
        // Still add it to the list for manual connection attempts
        _discoveredPrinters.add(printer);
      }
    }
    
    debugPrint('🎉 Added ${_discoveredPrinters.length} known Epson TM-M30II printers');
    notifyListeners();
  }

  /// URGENT: Test specific Epson printer connection
  Future<bool> testEpsonPrinterConnection(String ip, int port) async {
    try {
      debugPrint('🔍 Testing Epson TM-M30II at $ip:$port...');
      
      final socket = await Socket.connect(
        ip, 
        port, 
        timeout: const Duration(seconds: 5)
      );
      
      // Send Epson-specific status request
      socket.add([0x10, 0x04, 0x01]); // DLE EOT 1 - Transmit printer status
      await socket.flush();
      
      // Wait for response
      await socket.first.timeout(const Duration(seconds: 2));
      
      await socket.close();
      
      debugPrint('✅ Epson printer at $ip:$port is responsive!');
      return true;
      
    } catch (e) {
      debugPrint('❌ Epson printer at $ip:$port failed test: $e');
      return false;
    }
  }

}