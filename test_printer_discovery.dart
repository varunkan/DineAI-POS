import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'lib/services/printing_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🧪 Testing Printer Discovery...');
  
  // Initialize services
  final prefs = await SharedPreferences.getInstance();
  final networkInfo = NetworkInfo();
  final printingService = PrintingService(prefs, networkInfo);
  
  // Test printer discovery
  print('🔍 Starting printer discovery...');
  final printers = await printingService.discoverGenericESCPOSPrinters();
  
  print('🎉 Discovery Results:');
  print('Found ${printers.length} printers');
  
  for (final printer in printers) {
    print('  📄 ${printer.name}');
    print('     Address: ${printer.address}');
    print('     Type: ${printer.type}');
    print('     Model: ${printer.model}');
    print('     Signal: ${printer.signalStrength}%');
    print('');
  }
  
  // Test network info
  print('🌐 Network Information:');
  final wifiIP = await networkInfo.getWifiIP();
  print('WiFi IP: $wifiIP');
  
  if (wifiIP != null) {
    final parts = wifiIP.split('.');
    if (parts.length == 4) {
      final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
      print('Subnet: $subnet.*');
      print('Your IP: ${parts[3]}');
    }
  }
  
  print('✅ Test completed!');
} 