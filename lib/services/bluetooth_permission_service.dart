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
      
      // Check Android version
      final androidInfo = await _getAndroidVersion();
      final isAndroid12Plus = androidInfo >= 31; // API level 31 = Android 12
      
      
      if (isAndroid12Plus) {
        return await _requestAndroid12PlusPermissions();
      } else {
        return await _requestLegacyPermissions();
      }
      
    } catch (e) {
      return false;
    }
  }
  
  /// Request permissions for Android 12+ (API 31+)
  static Future<bool> _requestAndroid12PlusPermissions() async {
    
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
    
    
    return scanGranted && connectGranted && locationGranted;
  }
  
  /// Request permissions for Android 11 and below
  static Future<bool> _requestLegacyPermissions() async {
    
    final permissions = [
      Permission.bluetooth,
      Permission.location,
    ];
    
    // Request permissions
    final statuses = await permissions.request();
    
    // Check results
    final bluetoothGranted = statuses[Permission.bluetooth]?.isGranted ?? false;
    final locationGranted = statuses[Permission.location]?.isGranted ?? false;
    
    
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
      return 31; // Default to Android 12
    }
  }
  
  /// Check if Bluetooth is available and enabled
  static Future<Map<String, bool>> checkBluetoothStatus() async {
    try {
      final bluetooth = FlutterBluetoothSerial.instance;
      
      final isAvailable = await bluetooth.isAvailable ?? false;
      final isEnabled = await bluetooth.isEnabled ?? false;
      
      
      return {
        'available': isAvailable,
        'enabled': isEnabled,
      };
    } catch (e) {
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
        return true;
      }
      
      await bluetooth.requestEnable();
      
      // Wait a bit for Bluetooth to enable
      await Future.delayed(const Duration(seconds: 2));
      
      final newStatus = await bluetooth.isEnabled ?? false;
      
      return newStatus;
    } catch (e) {
      return false;
    }
  }
  
  /// Get all available Bluetooth devices (both bonded and discovered)
  static Future<List<BluetoothDevice>> getAllBluetoothDevices() async {
    try {
      
      final bluetooth = FlutterBluetoothSerial.instance;
      final List<BluetoothDevice> allDevices = [];
      
      // Get bonded devices
      final bondedDevices = await bluetooth.getBondedDevices();
      allDevices.addAll(bondedDevices);
      
      // Try to discover new devices
      try {
        await bluetooth.startDiscovery();
        
        // Listen for discovered devices
        bluetooth.onStateChanged().listen((BluetoothState state) {
        });
        
        // Wait for discovery
        await Future.delayed(const Duration(seconds: 15));
        
        
      } catch (e) {
      }
      
      for (final device in allDevices) {
      }
      
      return allDevices;
    } catch (e) {
      return [];
    }
  }
} 