import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔍 Network Diagnostic Tool');
  print('========================');
  
  // Initialize services
  final prefs = await SharedPreferences.getInstance();
  final networkInfo = NetworkInfo();
  
  // Test 1: Network Info
  print('\n1. Network Information Test:');
  print('----------------------------');
  
  try {
    final wifiIP = await networkInfo.getWifiIP();
    print('✅ WiFi IP: $wifiIP');
    
    if (wifiIP != null) {
      final parts = wifiIP.split('.');
      if (parts.length == 4) {
        final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
        print('✅ Subnet: $subnet.*');
        print('✅ Your IP: ${parts[3]}');
        
        // Test 2: Network Interface List
        print('\n2. Network Interfaces Test:');
        print('----------------------------');
        
        try {
          final interfaces = await NetworkInterface.list();
          print('✅ Found ${interfaces.length} network interfaces:');
          
          for (final interface in interfaces) {
            print('   📡 Interface: ${interface.name}');
            for (final address in interface.addresses) {
              if (address.type == InternetAddressType.IPv4) {
                print('      📍 IPv4: ${address.address}');
              }
            }
          }
        } catch (e) {
          print('❌ Network interface error: $e');
        }
        
        // Test 3: Socket Connection Test
        print('\n3. Socket Connection Test:');
        print('---------------------------');
        
        // Test common printer ports on your own IP first
        final testPorts = [9100, 515, 631, 9101, 9102];
        print('🔍 Testing connection to your own IP ($wifiIP) on printer ports:');
        
        for (final port in testPorts) {
          try {
            final socket = await Socket.connect(wifiIP, port, timeout: const Duration(seconds: 1));
            await socket.close();
            print('   ✅ Port $port: OPEN (something is listening)');
          } catch (e) {
            print('   ❌ Port $port: CLOSED (no service)');
          }
        }
        
        // Test 4: Network Range Scan
        print('\n4. Network Range Scan Test:');
        print('----------------------------');
        
        // Test a few IPs in your subnet
        final testIPs = <String>[];
        for (int i = 1; i <= 5; i++) {
          testIPs.add('$subnet.$i');
        }
        for (int i = 100; i <= 105; i++) {
          testIPs.add('$subnet.$i');
        }
        
        print('🔍 Testing connectivity to ${testIPs.length} IPs in your subnet:');
        
        for (final ip in testIPs) {
          try {
            final socket = await Socket.connect(ip, 80, timeout: const Duration(seconds: 1));
            await socket.close();
            print('   ✅ $ip:80 - REACHABLE');
          } catch (e) {
            print('   ❌ $ip:80 - UNREACHABLE');
          }
        }
        
        // Test 5: Printer Port Scan
        print('\n5. Printer Port Scan Test:');
        print('---------------------------');
        
        print('🔍 Scanning for printers on common IPs:');
        
        final commonPrinterIPs = <String>[];
        for (int i = 100; i <= 120; i++) commonPrinterIPs.add('$subnet.$i');
        for (int i = 200; i <= 220; i++) commonPrinterIPs.add('$subnet.$i');
        
        int foundPrinters = 0;
        
        for (final ip in commonPrinterIPs.take(10)) { // Test first 10 IPs
          for (final port in testPorts) {
            try {
              final socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 500));
              await socket.close();
              print('   🖨️ Found potential printer: $ip:$port');
              foundPrinters++;
            } catch (e) {
              // No printer found
            }
          }
        }
        
        if (foundPrinters == 0) {
          print('   ⚠️ No printers found in common IP ranges');
          print('   💡 This could mean:');
          print('      - No printers are connected to your network');
          print('      - Printers are on different IP ranges');
          print('      - Printers are not powered on');
          print('      - Network firewall is blocking connections');
        }
        
      } else {
        print('❌ Invalid IP format: $wifiIP');
      }
    } else {
      print('❌ No WiFi IP found - check network connection');
    }
    
  } catch (e) {
    print('❌ Network info error: $e');
  }
  
  // Test 6: Permission Check
  print('\n6. Permission Check:');
  print('--------------------');
  
  try {
    // Test if we can create a socket
    final testSocket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(seconds: 5));
    await testSocket.close();
    print('✅ Internet connectivity: OK');
  } catch (e) {
    print('❌ Internet connectivity: FAILED - $e');
  }
  
  print('\n🔍 Diagnostic Complete!');
  print('========================');
} 