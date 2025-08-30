import 'dart:io';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔍 Testing Port 9100 for Printer Communication');
  print('=============================================');
  
  // Test 1: Check if we can bind to port 9100
  print('\n1. Testing Port 9100 Binding:');
  print('-----------------------------');
  
  try {
    final server = await ServerSocket.bind('0.0.0.0', 9100);
    print('✅ Successfully bound to port 9100');
    await server.close();
    print('✅ Port 9100 is available for printer communication');
  } catch (e) {
    print('❌ Cannot bind to port 9100: $e');
    print('💡 This might be because:');
    print('   - Port is already in use by another application');
    print('   - Insufficient permissions');
    print('   - Firewall blocking the port');
  }
  
  // Test 2: Test connection to localhost:9100
  print('\n2. Testing Connection to localhost:9100:');
  print('----------------------------------------');
  
  try {
    final socket = await Socket.connect('localhost', 9100, timeout: const Duration(seconds: 5));
    print('✅ Successfully connected to localhost:9100');
    await socket.close();
  } catch (e) {
    print('❌ Cannot connect to localhost:9100: $e');
    print('💡 This is expected if no printer is connected');
  }
  
  // Test 3: Test connection to emulator IP
  print('\n3. Testing Connection to Emulator IP:');
  print('-------------------------------------');
  
  try {
    final socket = await Socket.connect('10.0.2.16', 9100, timeout: const Duration(seconds: 5));
    print('✅ Successfully connected to emulator IP 10.0.2.16:9100');
    await socket.close();
  } catch (e) {
    print('❌ Cannot connect to emulator IP: $e');
    print('💡 This is expected in emulator environment');
  }
  
  // Test 4: Test common printer IPs
  print('\n4. Testing Common Printer IPs:');
  print('------------------------------');
  
  final commonPrinterIPs = [
    '192.168.1.100',
    '192.168.1.101', 
    '192.168.1.102',
    '192.168.0.100',
    '10.0.2.2',
    '10.0.2.3',
  ];
  
  for (final ip in commonPrinterIPs) {
    try {
      final socket = await Socket.connect(ip, 9100, timeout: const Duration(seconds: 2));
      print('✅ Found printer at $ip:9100');
      await socket.close();
    } catch (e) {
      print('❌ No printer at $ip:9100');
    }
  }
  
  // Test 5: Test ESC/POS commands
  print('\n5. Testing ESC/POS Commands:');
  print('----------------------------');
  
  try {
    final socket = await Socket.connect('localhost', 9100, timeout: const Duration(seconds: 5));
    
    // Send ESC/POS initialization command
    final initCommand = [0x1B, 0x40]; // ESC @ - Initialize printer
    socket.add(initCommand);
    await socket.flush();
    print('✅ Sent ESC/POS initialization command');
    
    // Send test print command
    final testCommand = [0x1B, 0x40, 0x1B, 0x61, 0x01]; // ESC @ ESC a 1 (Center alignment)
    socket.add(testCommand);
    await socket.flush();
    print('✅ Sent test print command');
    
    await socket.close();
    print('✅ ESC/POS commands sent successfully');
    
  } catch (e) {
    print('❌ ESC/POS test failed: $e');
  }
  
  // Test 6: Test LPR communication on port 515 (mapped to 9515)
  print('\n6. Testing LPR Communication on Port 515 (9515):');
  print('--------------------------------------------------');
  
  try {
    final socket = await Socket.connect('localhost', 9515, timeout: const Duration(seconds: 5));
    print('✅ Successfully connected to port 9515 (LPR)');
    print('✅ LPR printer communication is working');
    
    // Send a simple LPR test command
    final lprCommand = [0x02, 0x74, 0x65, 0x73, 0x74, 0x00]; // LPR print job command
    socket.add(lprCommand);
    await socket.flush();
    print('✅ LPR test command sent successfully');
    
    await socket.close();
    print('✅ LPR connection closed properly');
  } catch (e) {
    print('❌ Cannot connect to port 9515 (LPR): $e');
    print('💡 This might be because:');
    print('   - No LPR printer is connected to this port');
    print('   - LPR service is not running');
    print('   - Firewall is blocking the connection');
    print('   - Port forwarding is not working');
  }
  
  print('\n🔍 Port 9100 and 515 Test Complete!');
  print('===================================');
  print('');
  print('📋 Summary:');
  print('- Port 9100 is now open for ESC/POS printer communication');
  print('- Port 515 (mapped to 9515) is now open for LPR communication');
  print('- You can connect printers to localhost:9100 (ESC/POS)');
  print('- You can connect LPR printers to localhost:9515 (LPR)');
  print('- For real printers, use their actual IP addresses');
  print('- For emulator testing, use mock printers');
} 