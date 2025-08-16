import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../services/database_service.dart';

/// Utility class for restoring deleted users and managing user recovery
class UserRestorationUtility {
  static const String _backupKey = 'users_backup';
  static const String _deletionLogKey = 'users_deletion_log';
  
  /// Create a backup of all current users
  static Future<void> createUserBackup(UserService userService) async {
    try {
      debugPrint('💾 Creating user backup...');
      
      final prefs = await SharedPreferences.getInstance();
      final users = userService.users;
      
      final backupData = {
        'timestamp': DateTime.now().toIso8601String(),
        'userCount': users.length,
        'users': users.map((user) => user.toJson()).toList(),
      };
      
      await prefs.setString(_backupKey, jsonEncode(backupData));
      debugPrint('✅ User backup created with ${users.length} users');
    } catch (e) {
      debugPrint('❌ Error creating user backup: $e');
    }
  }
  
  /// Restore users from backup
  static Future<void> restoreUsersFromBackup(UserService userService) async {
    try {
      debugPrint('🔄 Restoring users from backup...');
      
      final prefs = await SharedPreferences.getInstance();
      final backupData = prefs.getString(_backupKey);
      
      if (backupData == null) {
        debugPrint('⚠️ No user backup found');
        return;
      }
      
      final backup = jsonDecode(backupData) as Map<String, dynamic>;
      final users = (backup['users'] as List)
          .map((userData) => User.fromJson(userData))
          .toList();
      
      debugPrint('📋 Restoring ${users.length} users from backup...');
      
      // Restore each user
      for (final user in users) {
        await userService.restoreUser(user);
      }
      
      debugPrint('✅ Users restored from backup successfully');
    } catch (e) {
      debugPrint('❌ Error restoring users from backup: $e');
    }
  }
  
  /// Log user deletion for recovery purposes
  static Future<void> logUserDeletion(User user, String reason) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deletionLog = prefs.getString(_deletionLogKey);
      
      final logEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'userId': user.id,
        'userName': user.name,
        'reason': reason,
        'userData': user.toJson(),
      };
      
      List<Map<String, dynamic>> log = [];
      if (deletionLog != null) {
        log = List<Map<String, dynamic>>.from(jsonDecode(deletionLog));
      }
      
      log.add(logEntry);
      
      // Keep only last 100 deletions
      if (log.length > 100) {
        log = log.sublist(log.length - 100);
      }
      
      await prefs.setString(_deletionLogKey, jsonEncode(log));
      debugPrint('📝 User deletion logged: ${user.name} - $reason');
    } catch (e) {
      debugPrint('❌ Error logging user deletion: $e');
    }
  }
  
  /// Get list of recently deleted users
  static Future<List<Map<String, dynamic>>> getRecentlyDeletedUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deletionLog = prefs.getString(_deletionLogKey);
      
      if (deletionLog == null) return [];
      
      final log = List<Map<String, dynamic>>.from(jsonDecode(deletionLog));
      return log.reversed.toList(); // Most recent first
    } catch (e) {
      debugPrint('❌ Error getting deletion log: $e');
      return [];
    }
  }
  
  /// Restore a specific user by ID from deletion log
  static Future<bool> restoreUserById(UserService userService, String userId) async {
    try {
      final deletedUsers = await getRecentlyDeletedUsers();
      final userEntry = deletedUsers.firstWhere(
        (entry) => entry['userId'] == userId,
        orElse: () => <String, dynamic>{},
      );
      
      if (userEntry.isEmpty) {
        debugPrint('❌ User not found in deletion log: $userId');
        return false;
      }
      
      final userData = userEntry['userData'] as Map<String, dynamic>;
      final user = User.fromJson(userData);
      
      await userService.restoreUser(user);
      debugPrint('✅ User restored from deletion log: ${user.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Error restoring user from deletion log: $e');
      return false;
    }
  }
  
  /// Restore the "ivaan" user specifically
  static Future<bool> restoreIvaanUser(UserService userService) async {
    try {
      debugPrint('🔄 Attempting to restore ivaan user...');
      
      // First, try to find ivaan in deletion log
      final deletedUsers = await getRecentlyDeletedUsers();
      final ivaanEntry = deletedUsers.firstWhere(
        (entry) => entry['userName']?.toString().toLowerCase().contains('ivaan') == true,
        orElse: () => <String, dynamic>{},
      );
      
      if (ivaanEntry.isNotEmpty) {
        debugPrint('📋 Found ivaan in deletion log - restoring...');
        final userData = ivaanEntry['userData'] as Map<String, dynamic>;
        final user = User.fromJson(userData);
        await userService.restoreUser(user);
        debugPrint('✅ Ivaan user restored successfully');
        return true;
      }
      
      // If not found in deletion log, create a new ivaan user
      debugPrint('🔧 Ivaan not found in deletion log - creating new user...');
      final ivaanUser = User(
        id: 'ivaan_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Ivaan',
        role: UserRole.server,
        pin: '1234', // You can change this PIN
        isActive: true,
        adminPanelAccess: false,
        createdAt: DateTime.now(),
      );
      
      await userService.addUser(ivaanUser);
      debugPrint('✅ New ivaan user created successfully');
      return true;
      
    } catch (e) {
      debugPrint('❌ Error restoring ivaan user: $e');
      return false;
    }
  }
  
  /// Show deletion log summary
  static Future<void> showDeletionLogSummary() async {
    try {
      final deletedUsers = await getRecentlyDeletedUsers();
      
      if (deletedUsers.isEmpty) {
        debugPrint('📋 No user deletions logged');
        return;
      }
      
      debugPrint('📋 User deletion log summary:');
      debugPrint('Total deletions: ${deletedUsers.length}');
      
      for (final entry in deletedUsers.take(10)) { // Show last 10
        final timestamp = entry['timestamp'] ?? 'Unknown';
        final userName = entry['userName'] ?? 'Unknown';
        final reason = entry['reason'] ?? 'Unknown';
        
        debugPrint('  - $userName (${entry['userId']}) - $reason at $timestamp');
      }
      
      if (deletedUsers.length > 10) {
        debugPrint('  ... and ${deletedUsers.length - 10} more deletions');
      }
    } catch (e) {
      debugPrint('❌ Error showing deletion log summary: $e');
    }
  }
} 