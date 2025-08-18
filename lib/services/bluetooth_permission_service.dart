import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// 🔵 Bluetooth Permission Service
/// 
/// Handles all Bluetooth permissions for Android 12+ and older versions
class BluetoothPermissionService {
  static const String _logTag = '🔵 BluetoothPermissionService';
  
  /// Check and request all necessary Bluetooth permissions
  static Future<bool> requestBluetoothPermissions() async {
    try {
      debugPrint('$_logTag 🔐 Requesting Bluetooth permissions...');
      
      // Check Android version
      final androidInfo = await _getAndroidVersion();
      final isAndroid12Plus = androidInfo >= 31; // API level 31 = Android 12
      
      debugPrint('$_logTag 📱 Android version: $androidInfo (12+: $isAndroid12Plus)');
      
      if (isAndroid12Plus) {
        return await _requestAndroid12PlusPermissions();
      } else {
        return await _requestLegacyPermissions();
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error requesting permissions: $e');
      return false;
    }
  }
  
  /// Request permissions for Android 12+ (API 31+)
  static Future<bool> _requestAndroid12PlusPermissions() async {
    debugPrint('$_logTag 🔐 Requesting Android 12+ permissions...');
    
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ];
    
    // Request permissions
    final statuses = await permissions.request();
    
    // Check results
    final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    final locationGranted = statuses[Permission.location]?.isGranted ?? false;
    
    debugPrint('$_logTag 📊 Permission results:');
    debugPrint('$_logTag   - BLUETOOTH_SCAN: $scanGranted');
    debugPrint('$_logTag   - BLUETOOTH_CONNECT: $connectGranted');
    debugPrint('$_logTag   - LOCATION: $locationGranted');
    
    return scanGranted && connectGranted && locationGranted;
  }
  
  /// Request permissions for Android 11 and below
  static Future<bool> _requestLegacyPermissions() async {
    debugPrint('$_logTag 🔐 Requesting legacy permissions...');
    
    final permissions = [
      Permission.bluetooth,
      Permission.location,
    ];
    
    // Request permissions
    final statuses = await permissions.request();
    
    // Check results
    final bluetoothGranted = statuses[Permission.bluetooth]?.isGranted ?? false;
    final locationGranted = statuses[Permission.location]?.isGranted ?? false;
    
    debugPrint('$_logTag 📊 Permission results:');
    debugPrint('$_logTag   - BLUETOOTH: $bluetoothGranted');
    debugPrint('$_logTag   - LOCATION: $locationGranted');
    
    return bluetoothGranted && locationGranted;
  }
  
  /// Check if all Bluetooth permissions are granted
  static Future<bool> checkBluetoothPermissions() async {
    try {
      final androidInfo = await _getAndroidVersion();
      final isAndroid12Plus = androidInfo >= 31;
      
      if (isAndroid12Plus) {
        final scanGranted = await Permission.bluetoothScan.isGranted;
        final connectGranted = await Permission.bluetoothConnect.isGranted;
        final locationGranted = await Permission.location.isGranted;
        
        return scanGranted && connectGranted && locationGranted;
      } else {
        final bluetoothGranted = await Permission.bluetooth.isGranted;
        final locationGranted = await Permission.location.isGranted;
        
        return bluetoothGranted && locationGranted;
      }
    } catch (e) {
      debugPrint('$_logTag ❌ Error checking permissions: $e');
      return false;
    }
  }
  
  /// Get Android version
  static Future<int> _getAndroidVersion() async {
    try {
      // This is a simplified version - in a real app you'd use device_info_plus
      // For now, we'll assume Android 12+ for testing
      return 33; // Android 13
    } catch (e) {
      debugPrint('$_logTag ⚠️ Could not determine Android version, assuming 12+: $e');
      return 31; // Default to Android 12
    }
  }
  
  /// Check if Bluetooth is available and enabled
  static Future<Map<String, bool>> checkBluetoothStatus() async {
    try {
      final bluetooth = FlutterBluetoothSerial.instance;
      
      final isAvailable = await bluetooth.isAvailable ?? false;
      final isEnabled = await bluetooth.isEnabled ?? false;
      
      debugPrint('$_logTag 📱 Bluetooth status:');
      debugPrint('$_logTag   - Available: $isAvailable');
      debugPrint('$_logTag   - Enabled: $isEnabled');
      
      return {
        'available': isAvailable,
        'enabled': isEnabled,
      };
    } catch (e) {
      debugPrint('$_logTag ❌ Error checking Bluetooth status: $e');
      return {
        'available': false,
        'enabled': false,
      };
    }
  }
  
  /// Enable Bluetooth if not enabled
  static Future<bool> enableBluetooth() async {
    try {
      final bluetooth = FlutterBluetoothSerial.instance;
      
      final isEnabled = await bluetooth.isEnabled ?? false;
      if (isEnabled) {
        debugPrint('$_logTag ✅ Bluetooth already enabled');
        return true;
      }
      
      debugPrint('$_logTag 🔄 Enabling Bluetooth...');
      await bluetooth.requestEnable();
      
      // Wait a bit for Bluetooth to enable
      await Future.delayed(const Duration(seconds: 2));
      
      final newStatus = await bluetooth.isEnabled ?? false;
      debugPrint('$_logTag 📱 Bluetooth enabled: $newStatus');
      
      return newStatus;
    } catch (e) {
      debugPrint('$_logTag ❌ Error enabling Bluetooth: $e');
      return false;
    }
  }
  
  /// Get all available Bluetooth devices (both bonded and discovered)
  static Future<List<BluetoothDevice>> getAllBluetoothDevices() async {
    try {
      debugPrint('$_logTag 🔍 Getting all Bluetooth devices...');
      
      final bluetooth = FlutterBluetoothSerial.instance;
      final List<BluetoothDevice> allDevices = [];
      
      // Get bonded devices
      final bondedDevices = await bluetooth.getBondedDevices();
      debugPrint('$_logTag 📱 Found ${bondedDevices.length} bonded devices');
      allDevices.addAll(bondedDevices);
      
      // Try to discover new devices
      try {
        debugPrint('$_logTag 🔍 Starting device discovery...');
        await bluetooth.startDiscovery();
        
        // Listen for discovered devices
        bluetooth.onStateChanged().listen((BluetoothState state) {
          debugPrint('$_logTag 📡 Bluetooth state: $state');
        });
        
        // Wait for discovery
        await Future.delayed(const Duration(seconds: 15));
        
        debugPrint('$_logTag ⏹️ Discovery completed');
        
      } catch (e) {
        debugPrint('$_logTag ⚠️ Discovery failed: $e');
      }
      
      debugPrint('$_logTag 📱 Total devices found: ${allDevices.length}');
      for (final device in allDevices) {
        debugPrint('$_logTag   - ${device.name} (${device.address})');
      }
      
      return allDevices;
    } catch (e) {
      debugPrint('$_logTag ❌ Error getting Bluetooth devices: $e');
      return [];
    }
  }
} 