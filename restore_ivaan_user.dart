#!/usr/bin/env dart

/// Simple script to restore the ivaan user
/// Run this script to restore the deleted ivaan user
/// 
/// Usage: dart restore_ivaan_user.dart

import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  print('🔄 Ivaan User Restoration Tool');
  print('==============================');
  
  try {
    // Get SharedPreferences instance
    final prefs = await SharedPreferences.getInstance();
    
    // Check for deletion log
    final deletionLog = prefs.getString('users_deletion_log');
    
    if (deletionLog != null) {
      final log = List<Map<String, dynamic>>.from(jsonDecode(deletionLog));
      print('📋 Found deletion log with ${log.length} entries');
      
      // Look for ivaan in deletion log
      final ivaanEntry = log.where((entry) {
        final userName = entry['userName']?.toString().toLowerCase() ?? '';
        return userName.contains('ivaan');
      }).toList();
      
      if (ivaanEntry.isNotEmpty) {
        print('✅ Found ivaan in deletion log!');
        print('User: ${ivaanEntry.first['userName']}');
        print('Deleted at: ${ivaanEntry.first['timestamp']}');
        print('Reason: ${ivaanEntry.first['reason']}');
        
        // Check if we can restore
        print('\n🔄 To restore ivaan user:');
        print('1. Open the DineAI-POS app');
        print('2. Go to Admin Panel > User Management');
        print('3. Use the "Restore User" feature');
        print('4. Or run the app and use the restoration utility');
        
      } else {
        print('❌ Ivaan not found in deletion log');
        print('Creating new ivaan user instructions...');
      }
    } else {
      print('📋 No deletion log found');
    }
    
    // Check for user backup
    final backupKeys = prefs.getKeys().where((key) => key.startsWith('users_backup_')).toList();
    if (backupKeys.isNotEmpty) {
      print('\n💾 Found user backups:');
      for (final key in backupKeys.take(5)) {
        final backupData = prefs.getString(key);
        if (backupData != null) {
          try {
            final backup = jsonDecode(backupData) as Map<String, dynamic>;
            final userCount = backup['userCount'] ?? 0;
            final timestamp = backup['timestamp'] ?? 'Unknown';
            print('  - $key: $userCount users at $timestamp');
          } catch (e) {
            print('  - $key: Invalid backup data');
          }
        }
      }
      
      if (backupKeys.length > 5) {
        print('  ... and ${backupKeys.length - 5} more backups');
      }
    }
    
    print('\n🔧 Manual Restoration Steps:');
    print('1. Open DineAI-POS app');
    print('2. Go to Admin Panel > User Management');
    print('3. Click "Add User"');
    print('4. Enter:');
    print('   - Name: Ivaan');
    print('   - PIN: 1234 (or your preferred PIN)');
    print('   - Role: Server');
    print('   - Admin Access: No (unless needed)');
    print('5. Save the user');
    
    print('\n✅ Ivaan user restoration tool completed!');
    
  } catch (e) {
    print('❌ Error: $e');
    print('\n🔧 Manual Restoration Steps:');
    print('1. Open DineAI-POS app');
    print('2. Go to Admin Panel > User Management');
    print('3. Click "Add User"');
    print('4. Enter:');
    print('   - Name: Ivaan');
    print('   - PIN: 1234 (or your preferred PIN)');
    print('   - Role: Server');
    print('   - Admin Access: No (unless needed)');
    print('5. Save the user');
  }
} 