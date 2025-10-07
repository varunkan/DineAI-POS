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
      
      final prefs = await SharedPreferences.getInstance();
      final users = userService.users;
      
      final backupData = {
        'timestamp': DateTime.now().toIso8601String(),
        'userCount': users.length,
        'users': users.map((user) => user.toJson()).toList(),
      };
      
      await prefs.setString(_backupKey, jsonEncode(backupData));
    } catch (e) {
    }
  }
  
  /// Restore users from backup
  static Future<void> restoreUsersFromBackup(UserService userService) async {
    try {
      
      final prefs = await SharedPreferences.getInstance();
      final backupData = prefs.getString(_backupKey);
      
      if (backupData == null) {
        return;
      }
      
      final backup = jsonDecode(backupData) as Map<String, dynamic>;
      final users = (backup['users'] as List)
          .map((userData) => User.fromJson(userData))
          .toList();
      
      
      // Restore each user
      for (final user in users) {
        await userService.restoreUser(user);
      }
      
    } catch (e) {
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
    } catch (e) {
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
        return false;
      }
      
      final userData = userEntry['userData'] as Map<String, dynamic>;
      final user = User.fromJson(userData);
      
      await userService.restoreUser(user);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Restore the "ivaan" user specifically
  static Future<bool> restoreIvaanUser(UserService userService) async {
    try {
      
      // First, try to find ivaan in deletion log
      final deletedUsers = await getRecentlyDeletedUsers();
      final ivaanEntry = deletedUsers.firstWhere(
        (entry) => entry['userName']?.toString().toLowerCase().contains('ivaan') == true,
        orElse: () => <String, dynamic>{},
      );
      
      if (ivaanEntry.isNotEmpty) {
        final userData = ivaanEntry['userData'] as Map<String, dynamic>;
        final user = User.fromJson(userData);
        await userService.restoreUser(user);
        return true;
      }
      
      // If not found in deletion log, create a new ivaan user
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
      return true;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Show deletion log summary
  static Future<void> showDeletionLogSummary() async {
    try {
      final deletedUsers = await getRecentlyDeletedUsers();
      
      if (deletedUsers.isEmpty) {
        return;
      }
      
      
      for (final entry in deletedUsers.take(10)) { // Show last 10
        final timestamp = entry['timestamp'] ?? 'Unknown';
        final userName = entry['userName'] ?? 'Unknown';
        final reason = entry['reason'] ?? 'Unknown';
        
      }
      
      if (deletedUsers.length > 10) {
      }
    } catch (e) {
    }
  }
} 