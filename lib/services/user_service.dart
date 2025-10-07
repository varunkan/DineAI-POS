import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

import '../models/user.dart';
import '../config/security_config.dart';
import '../services/database_service.dart';
import '../services/unified_sync_service.dart';
import '../utils/user_restoration_utility.dart';

class UserService with ChangeNotifier {
  final SharedPreferences _prefs;
  final DatabaseService _databaseService;
  List<User> _users = [];
  User? _currentUser;
  static const String _usersKey = 'users';

  UserService(this._prefs, this._databaseService) {
    _loadUsers();
  }

  /// Load users from database
  Future<void> _loadUsers() async {
    try {
      
      if (_databaseService.isWeb) {
        await _loadWebUsers();
      } else {
        await _loadSQLiteUsers();
      }
      
      
      // Log each user for debugging
      for (final user in _users) {
      }
      
      // Ensure admin user exists with proper permissions
      await _ensureAdminUserExists();
      
    } catch (e) {
      
      // Create default admin user if loading fails
      await _createDefaultAdminUser();
    }
  }

  /// Ensure admin user exists with proper permissions
  Future<void> _ensureAdminUserExists() async {
    try {
      // Check if admin user already exists
      final adminUser = _users.where((user) => user.id == 'admin').firstOrNull;
      
      if (adminUser != null) {
        
        // Ensure admin user has proper permissions
        if (!adminUser.adminPanelAccess || adminUser.role != UserRole.admin) {
          final updatedAdminUser = adminUser.copyWith(
            role: UserRole.admin,
            adminPanelAccess: true,
            isActive: true,
          );
          
          await _updateUserInDatabase(updatedAdminUser);
          
          // Update in memory
          final index = _users.indexWhere((u) => u.id == 'admin');
          if (index != -1) {
            _users[index] = updatedAdminUser;
          }
          
        }
        return;
      }
      
      // Only create admin user if NO users exist at all
      if (_users.isEmpty) {
        final newAdminUser = User(
          id: 'admin',
          name: 'Admin',
          role: UserRole.admin,
          pin: SecurityConfig.getDefaultAdminPin(),
          adminPanelAccess: true,
          isActive: true,
          createdAt: DateTime.now(),
        );
        
        await _saveUserToDatabase(newAdminUser);
        _users.add(newAdminUser);
      } else {
        
        // Find the first active user and promote to admin
        final firstUser = _users.firstWhere(
          (user) => user.isActive,
          orElse: () => _users.first,
        );
        
        final promotedUser = firstUser.copyWith(
          role: UserRole.admin,
          adminPanelAccess: true,
        );
        
        await _updateUserInDatabase(promotedUser);
        
        // Update in memory
        final index = _users.indexWhere((u) => u.id == firstUser.id);
        if (index != -1) {
          _users[index] = promotedUser;
        }
        
      }
    } catch (e) {
      // Don't throw - this is not critical for app operation
    }
  }
  
  /// Ensure admin user has all necessary permissions for order creation
  Future<void> _ensureAdminUserHasOrderCreationAccess() async {
    try {
      final adminUser = _users.where((user) => user.id == 'admin').firstOrNull;
      
      if (adminUser != null) {
        // Admin users should have all permissions by default
        if (!adminUser.adminPanelAccess || adminUser.role != UserRole.admin) {
          
          final updatedAdmin = adminUser.copyWith(
            role: UserRole.admin,
            adminPanelAccess: true,
            isActive: true,
          );
          
          await _updateUserInDatabase(updatedAdmin);
          
          // Update in memory
          final adminIndex = _users.indexWhere((user) => user.id == 'admin');
          if (adminIndex != -1) {
            _users[adminIndex] = updatedAdmin;
          }
          
          // Update current user if it's the admin
          if (_currentUser?.id == 'admin') {
            _currentUser = updatedAdmin;
          }
          
        }
      }
    } catch (e) {
    }
  }

  /// Create a default admin user if none exists
  Future<void> _createDefaultAdminUser() async {
    try {
      
      final adminUser = User(
        id: 'admin',
        name: 'Admin',
        role: UserRole.admin,
        pin: SecurityConfig.getDefaultAdminPin(),
        adminPanelAccess: true,
        isActive: true,
      );
      
      await _saveUserToDatabase(adminUser);
      _users.add(adminUser);
      
    } catch (e) {
    }
  }

  Future<void> _loadWebUsers() async {
    try {
      final webUsers = await _databaseService.getWebUsers();
      _users = webUsers.map((userMap) {
        return User(
          id: userMap['id'],
          name: userMap['name'],
          role: UserRole.values.firstWhere(
            (e) => e.toString().split('.').last == userMap['role'],
            orElse: () => UserRole.server,
          ),
          pin: userMap['pin'],
          isActive: userMap['is_active'] == true,
          adminPanelAccess: userMap['admin_panel_access'] == true,
          createdAt: DateTime.parse(userMap['created_at']),
          lastLogin: userMap['last_login'] != null ? DateTime.parse(userMap['last_login']) : null,
        );
      }).toList();
    } catch (e) {
      _users = [];
    }
  }

  Future<void> _loadSQLiteUsers() async {
    try {
      final db = await _databaseService.database;
      if (db == null) return;
      
      final List<Map<String, dynamic>> userMaps = await db.query('users');
      
      _users = userMaps.map((userMap) {
        return User(
          id: userMap['id'],
          name: userMap['name'],
          role: UserRole.values.firstWhere(
            (e) => e.toString().split('.').last == userMap['role'],
            orElse: () => UserRole.server,
          ),
          pin: userMap['pin'],
          isActive: userMap['is_active'] == 1,
          adminPanelAccess: userMap['admin_panel_access'] == 1,
          createdAt: DateTime.parse(userMap['created_at']),
          lastLogin: userMap['last_login'] != null ? DateTime.parse(userMap['last_login']) : null,
        );
      }).toList();
      
    } catch (e) {
      _users = [];
    }
  }

  Future<void> _migrateUsersFromSharedPreferences() async {
    try {
      final String? usersJson = _prefs.getString(_usersKey);
      if (usersJson != null) {
        final List<dynamic> usersList = jsonDecode(usersJson);
        final List<User> prefsUsers = usersList.map((user) => User.fromJson(user)).toList();
        
        if (prefsUsers.isNotEmpty) {
          
          for (final user in prefsUsers) {
            await _saveUserToDatabase(user);
          }
          
          _users = prefsUsers;
          
          // Clear from SharedPreferences after successful migration
          await _prefs.remove(_usersKey);
        }
      }
    } catch (e) {
    }
  }

  Future<void> _createDefaultUsers() async {
    try {
      final defaultUsers = [
        User(id: 'admin', name: 'Admin', role: UserRole.admin, pin: SecurityConfig.getDefaultAdminPin(), adminPanelAccess: true),
        User(id: 'server1', name: 'Server 1', role: UserRole.server, pin: '1111'),
        User(id: 'server2', name: 'Server 2', role: UserRole.server, pin: '2222'),
        // Add 2 more dummy servers
        User(id: 'server3', name: 'Emma Thompson', role: UserRole.server, pin: '3333'),
        User(id: 'server4', name: 'Alex Johnson', role: UserRole.server, pin: '4444'),
      ];
      
      for (final user in defaultUsers) {
        await _saveUserToDatabase(user);
      }
      
      _users = defaultUsers;
      
      // Ensure admin user has full admin access
      await _ensureAdminUserHasFullAccess();
    } catch (e) {
    }
  }

  /// Ensures the admin user has full admin access
  Future<void> _ensureAdminUserHasFullAccess() async {
    try {
      final adminUser = _users.where((user) => user.id == 'admin').firstOrNull;
      
      if (adminUser == null) {
        // Create admin user if it doesn't exist
        SecurityConfig.logSecurityEvent('Creating admin user with full access');
        final newAdmin = User(
          id: 'admin',
          name: 'Admin',
          role: UserRole.admin,
          pin: SecurityConfig.getDefaultAdminPin(),
          adminPanelAccess: true,
          isActive: true,
        );
        
        await _saveUserToDatabase(newAdmin);
        _users.add(newAdmin);
        
        SecurityConfig.logSecurityEvent('Admin user created with full access');
      } else {
        // Check if admin user needs to be updated (role, access, or PIN)
        final expectedPin = SecurityConfig.getDefaultAdminPin();
        if (adminUser.role != UserRole.admin || 
            !adminUser.adminPanelAccess || 
            adminUser.pin != expectedPin) {
          SecurityConfig.logSecurityEvent('Updating admin user to have full admin access');
          
          final updatedAdmin = adminUser.copyWith(
            role: UserRole.admin,
            adminPanelAccess: true,
            pin: expectedPin,
            isActive: true,
          );
          
          await _updateUserInDatabase(updatedAdmin);
          
          // Update in memory
          final adminIndex = _users.indexWhere((user) => user.id == 'admin');
          if (adminIndex != -1) {
            _users[adminIndex] = updatedAdmin;
          }
          
          // Update current user if it's the admin
          if (_currentUser?.id == 'admin') {
            _currentUser = updatedAdmin;
          }
          
          SecurityConfig.logSecurityEvent('Admin user updated with full access');
        } else {
        }
      }
    } catch (e) {
    }
  }

  /// Manually fix admin permissions - can be called if admin access is broken
  Future<void> fixAdminPermissions() async {
    try {
      
      // Remove any existing admin user
      _users.removeWhere((user) => user.id == 'admin');
      
      // Create new admin user with proper permissions
      final adminUser = User(
        id: 'admin',
        name: 'Admin',
        role: UserRole.admin,
        pin: SecurityConfig.getDefaultAdminPin(),
        adminPanelAccess: true,
        isActive: true,
      );
      
      await _saveUserToDatabase(adminUser);
      _users.add(adminUser);
      
      
      // Notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
          }
        });
      } catch (e) {
      }
    } catch (e) {
    }
  }

  /// Creates additional dummy servers for testing
  Future<void> createDummyServers() async {
    try {
      
      // Check if dummy servers already exist
      final existingEmma = _users.where((u) => u.id == 'server3').isNotEmpty;
      final existingAlex = _users.where((u) => u.id == 'server4').isNotEmpty;
      
      if (existingEmma && existingAlex) {
        return;
      }
      
      final dummyServers = [
        User(id: 'server3', name: 'Emma Thompson', role: UserRole.server, pin: '3333'),
        User(id: 'server4', name: 'Alex Johnson', role: UserRole.server, pin: '4444'),
      ];
      
      for (final server in dummyServers) {
        if (!_users.any((u) => u.id == server.id)) {
          await _saveUserToDatabase(server);
          _users.add(server);
        }
      }
      
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
          }
        });
      } catch (e) {
      }
    } catch (e) {
    }
  }

  Future<void> _saveUserToDatabase(User user) async {
    try {
      if (_databaseService.isWeb) {
        // Web platform - use Hive storage with consistent data format
        await _databaseService.saveWebUser({
          'id': user.id,
          'name': user.name,
          'role': user.role.toString().split('.').last,
          'pin': user.pin,
          'is_active': user.isActive ? 1 : 0,
          'admin_panel_access': user.adminPanelAccess ? 1 : 0, // Ensure admin panel access is saved
          'created_at': user.createdAt.toIso8601String(),
          'last_login': user.lastLogin?.toIso8601String(),
        });
      } else {
        // Mobile/Desktop platform - use SQLite
        final db = await _databaseService.database;
        if (db == null) return;
        
        await db.insert(
          'users',
          {
            'id': user.id,
            'name': user.name,
            'role': user.role.toString().split('.').last,
            'pin': user.pin,
            'is_active': user.isActive ? 1 : 0,
            'admin_panel_access': user.adminPanelAccess ? 1 : 0, // Ensure admin panel access is saved
            'created_at': user.createdAt.toIso8601String(),
            'last_login': user.lastLogin?.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      // Sync to Firebase using unified sync service
      try {
        final syncService = UnifiedSyncService.instance;
        if (syncService.isConnected) {
          await syncService.createOrUpdateUser(user);
        }
      } catch (e) {
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _updateUserInDatabase(User user) async {
    try {
      if (_databaseService.isWeb) {
        // Web platform - use Hive storage
        await _databaseService.saveWebUser({
          'id': user.id,
          'name': user.name,
          'role': user.role.toString().split('.').last,
          'pin': user.pin,
          'is_active': user.isActive ? 1 : 0,
          'admin_panel_access': user.adminPanelAccess ? 1 : 0,
          'created_at': user.createdAt.toIso8601String(),
          'last_login': user.lastLogin?.toIso8601String(),
        });
      } else {
        // Mobile/Desktop platform - use SQLite
        final db = await _databaseService.database;
        if (db == null) return;
        
        await db.update(
          'users',
          {
            'id': user.id,
            'name': user.name,
            'role': user.role.toString().split('.').last,
            'pin': user.pin,
            'is_active': user.isActive ? 1 : 0,
            'admin_panel_access': user.adminPanelAccess ? 1 : 0,
            'created_at': user.createdAt.toIso8601String(),
            'last_login': user.lastLogin?.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [user.id],
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _deleteUserFromDatabase(String userId) async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        await db.delete(
          'users',
          where: 'id = ?',
          whereArgs: [userId],
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveUsers(List<User> users) async {
    try {
      for (final user in users) {
        await _saveUserToDatabase(user);
      }
      _users = users;
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
          }
        });
      } catch (e) {
      }
    } catch (e) {
      throw Exception('Failed to save users: $e');
    }
  }

  /// Clears all existing users and saves the new list
  Future<void> clearAndSaveUsers(List<User> users) async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        await db.delete('users');
      }
      
      for (final user in users) {
        await _saveUserToDatabase(user);
      }
      
      _users = users;
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
          }
        });
      } catch (e) {
      }
    } catch (e) {
      throw Exception('Failed to clear and save users: $e');
    }
  }

  /// Clears all users except admin, keeping only the admin user
  Future<void> clearAllUsersExceptAdmin() async {
    try {
      
      // Create backup before clearing
      await createUserBackup();
      
      // Find admin user
      final adminUser = _users.where((user) => user.id == 'admin').firstOrNull;
      
      // Log all users being deleted (except admin)
      final usersToDelete = _users.where((user) => user.id != 'admin').toList();
      for (final user in usersToDelete) {
        await UserRestorationUtility.logUserDeletion(user, 'Cleared during system reset');
      }
      
      if (adminUser == null) {
        // Create admin user if it doesn't exist
        final newAdminUser = User(
          id: 'admin',
          name: 'Admin',
          role: UserRole.admin,
          pin: SecurityConfig.getDefaultAdminPin(),
          adminPanelAccess: true,
          isActive: true,
        );
        
        // Clear all users from database
        final db = await _databaseService.database;
        if (db != null) {
          await db.delete('users');
        }
        
        // Save only admin user
        await _saveUserToDatabase(newAdminUser);
        _users = [newAdminUser];
        
      } else {
        // Clear all users except admin
        final db = await _databaseService.database;
        if (db != null) {
          await db.delete('users');
        }
        
        // Save only admin user
        await _saveUserToDatabase(adminUser);
        _users = [adminUser];
        
      }
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
          }
        });
      } catch (e) {
      }
      
    } catch (e) {
      throw Exception('Failed to clear users except admin: $e');
    }
  }

  /// Clear all users from memory and database
  Future<void> clearAllUsers() async {
    try {
      
      // Clear from memory
      _users.clear();
      _currentUser = null;
      
      // Clear from database
      final db = await _databaseService.database;
      if (db != null) {
        await db.delete('users');
      }
      
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Gets all users
  List<User> get users => List.unmodifiable(_users);

  /// Gets the current logged-in user
  User? get currentUser => _currentUser;

  /// Sets the current user and notifies listeners
  void setCurrentUser(User? user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Validates user credentials and returns the user if valid
  User? validateUserCredentials(String id, String pin) {
    try {
      return _users.firstWhere((user) => user.id == id && user.pin == pin && user.isActive);
    } catch (e) {
      return null;
    }
  }

  /// Grants full admin access to a user (both role and admin panel access)
  Future<bool> grantFullAdminAccess(String userId) async {
    try {
      final userIndex = _users.indexWhere((user) => user.id == userId);
      if (userIndex == -1) {
        return false;
      }

      final user = _users[userIndex];
      final updatedUser = user.copyWith(
        role: UserRole.admin,
        adminPanelAccess: true,
      );
      
      // Update in database
      await _updateUserInDatabase(updatedUser);
      
      // Update in memory
      _users[userIndex] = updatedUser;
      
      // Update current user if it's the same user
      if (_currentUser?.id == userId) {
        _currentUser = updatedUser;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Grants admin panel access to a user
  Future<bool> grantAdminPanelAccess(String userId) async {
    try {
      final userIndex = _users.indexWhere((user) => user.id == userId);
      if (userIndex == -1) {
        return false;
      }

      final user = _users[userIndex];
      final updatedUser = user.copyWith(adminPanelAccess: true);
      
      // Update in database
      await _updateUserInDatabase(updatedUser);
      
      // Update in memory
      _users[userIndex] = updatedUser;
      
      // Update current user if it's the same user
      if (_currentUser?.id == userId) {
        _currentUser = updatedUser;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Revokes admin panel access from a user
  Future<bool> revokeAdminPanelAccess(String userId) async {
    try {
      final userIndex = _users.indexWhere((user) => user.id == userId);
      if (userIndex == -1) {
        return false;
      }

      final user = _users[userIndex];
      final updatedUser = user.copyWith(adminPanelAccess: false);
      
      // Update in database
      await _updateUserInDatabase(updatedUser);
      
      // Update in memory
      _users[userIndex] = updatedUser;
      
      // Update current user if it's the same user
      if (_currentUser?.id == userId) {
        _currentUser = updatedUser;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Checks if the current user can access admin panel
  bool get currentUserCanAccessAdminPanel {
    return _currentUser?.canAccessAdminPanel ?? false;
  }

  /// Gets all users with admin panel access
  List<User> get usersWithAdminAccess {
    return _users.where((user) => user.canAccessAdminPanel).toList();
  }

  Future<List<User>> getUsers() async {
    return _users;
  }

  /// Add a new user
  Future<void> addUser(User user) async {
    try {
      await _saveUserToDatabase(user);
      _users.add(user);
      
      // ENHANCEMENT: Automatic Firebase sync trigger
      final unifiedSyncService = UnifiedSyncService.instance;
      await unifiedSyncService.syncUserToFirebase(user, 'created');
      
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing user
  Future<void> updateUser(User user) async {
    try {
      await _updateUserInDatabase(user);
      
      final index = _users.indexWhere((u) => u.id == user.id);
      if (index != -1) {
        _users[index] = user;
      }
      
      // ENHANCEMENT: Automatic Firebase sync trigger
      final unifiedSyncService = UnifiedSyncService.instance;
      await unifiedSyncService.syncUserToFirebase(user, 'updated');
      
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a user
  Future<void> deleteUser(String userId) async {
    try {
      final user = _users.firstWhere((u) => u.id == userId);
      
      // Log the deletion for recovery purposes
      await UserRestorationUtility.logUserDeletion(user, 'Manual deletion by admin');
      
      await _deleteUserFromDatabase(userId);
      _users.removeWhere((u) => u.id == userId);
      
      // ENHANCEMENT: Automatic Firebase sync trigger
      final unifiedSyncService = UnifiedSyncService.instance;
      await unifiedSyncService.syncUserToFirebase(user, 'deleted');
      
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Auto-sync user to Firebase
  Future<void> _autoSyncToFirebase(User user, String action) async {
    try {
      final syncService = UnifiedSyncService.instance;
      if (syncService.isConnected) {
        if (action == 'deleted') {
          await syncService.deleteItem('users', user.id);
        } else {
          await syncService.createOrUpdateUser(user);
        }
      }
    } catch (e) {
    }
  }

  Future<void> updateLastLogin(String userId) async {
    try {
      final index = _users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        final updatedUser = _users[index].copyWith(lastLogin: DateTime.now());
        await _updateUserInDatabase(updatedUser);
        _users[index] = updatedUser;
        
        // Safely notify listeners
        try {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            try {
              notifyListeners();
            } catch (e) {
            }
          });
        } catch (e) {
        }
      }
    } catch (e) {
    }
  }

  User? getUserById(String userId) {
    try {
      return _users.firstWhere((user) => user.id == userId);
    } catch (e) {
      return null;
    }
  }

  User? authenticateUser(String pin) {
    try {
      return _users.firstWhere((user) => user.pin == pin && user.isActive);
    } catch (e) {
      return null;
    }
  }

  List<User> getUsersByRole(UserRole role) {
    return _users.where((user) => user.role == role).toList();
  }

  List<User> getActiveUsers() {
    return _users.where((user) => user.isActive).toList();
  }

  /// Update user from Firebase (for cross-device sync)
  Future<void> updateUserFromFirebase(User firebaseUser) async {
    try {
      
      // Check if user already exists locally
      final existingIndex = _users.indexWhere((user) => user.id == firebaseUser.id);
      
      if (existingIndex != -1) {
        // Update existing user
        _users[existingIndex] = firebaseUser;
      } else {
        // Add new user from Firebase
        _users.add(firebaseUser);
      }
      
      // Save to local database
      final db = await _databaseService.database;
      if (db != null) {
        final userData = firebaseUser.toJson();
        await db.insert(
          'users',
          userData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      notifyListeners();
    } catch (e) {
    }
  }

  /// Restore a deleted user (for cross-device sync recovery)
  Future<void> restoreUser(User user) async {
    try {
      
      // Check if user already exists
      final existingUser = _users.where((u) => u.id == user.id).firstOrNull;
      if (existingUser != null) {
        await updateUser(user);
        return;
      }
      
      // Add the restored user
      await _saveUserToDatabase(user);
      _users.add(user);
      
      // Sync to Firebase
      try {
        final syncService = UnifiedSyncService.instance;
        if (syncService.isConnected) {
          await syncService.syncUserToFirebase(user, 'restored');
        }
      } catch (e) {
      }
      
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Get users that were recently deleted (for recovery purposes)
  Future<List<User>> getRecentlyDeletedUsers() async {
    try {
      // This would typically query a deletion log or backup
      // For now, return empty list - implement based on your backup strategy
      return [];
    } catch (e) {
      return [];
    }
  }
  
  /// Create a backup of all users before any destructive operation
  Future<void> createUserBackup() async {
    try {
      
      // Store current users in a backup location
      final backupData = _users.map((user) => user.toJson()).toList();
      
      // Save to backup storage (could be SharedPreferences, separate table, or file)
      await _prefs.setString('users_backup_${DateTime.now().millisecondsSinceEpoch}', 
                            jsonEncode(backupData));
      
    } catch (e) {
    }
  }
  
  /// Restore users from backup
  Future<void> restoreUsersFromBackup() async {
    try {
      
      // Get the most recent backup
      final keys = _prefs.getKeys().where((key) => key.startsWith('users_backup_')).toList();
      if (keys.isEmpty) {
        return;
      }
      
      // Sort by timestamp and get the most recent
      keys.sort((a, b) {
        final aTime = int.tryParse(a.replaceFirst('users_backup_', '')) ?? 0;
        final bTime = int.tryParse(b.replaceFirst('users_backup_', '')) ?? 0;
        return bTime.compareTo(aTime);
      });
      
      final latestBackupKey = keys.first;
      final backupData = _prefs.getString(latestBackupKey);
      
      if (backupData != null) {
        final backupUsers = (jsonDecode(backupData) as List)
            .map((userData) => User.fromJson(userData))
            .toList();
        
        
        // Clear current users and restore from backup
        _users.clear();
        for (final user in backupUsers) {
          await _saveUserToDatabase(user);
          _users.add(user);
        }
        
        notifyListeners();
      }
    } catch (e) {
    }
  }

  /// Sync users with Firebase (background operation)
  Future<void> syncUsersWithFirebase() async {
    // TODO: Implement user sync - for now just log
    await Future.delayed(const Duration(milliseconds: 100)); // Simulate async operation
  }
} 