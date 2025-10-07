import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Utility class to test admin user creation and access functionality
class AdminUserTest {
  static String get _testAdminId => 'test_admin_${DateTime.now().millisecondsSinceEpoch}';
  
  /// Test admin user creation and permissions
  static Future<Map<String, dynamic>> testAdminUserCreation() async {
    final results = <String, dynamic>{};
    
    try {
      
      // Test 1: Create test admin user
      results['test1_create_admin'] = await _testCreateAdminUser();
      
      // Test 2: Verify admin permissions
      results['test2_verify_permissions'] = await _testVerifyAdminPermissions();
      
      // Test 3: Test admin panel access
      results['test3_admin_panel_access'] = await _testAdminPanelAccess();
      
      // Test 4: Test order creation access
      results['test4_order_creation_access'] = await _testOrderCreationAccess();
      
      // Test 5: Cleanup test data
      results['test5_cleanup'] = await _testCleanup();
      
      
    } catch (e) {
      results['error'] = e.toString();
    }
    
    return results;
  }
  
  /// Test 1: Create admin user
  static Future<bool> _testCreateAdminUser() async {
    try {
      
      final prefs = await SharedPreferences.getInstance();
      final dbService = DatabaseService();
      await dbService.initialize();
      
      final userService = UserService(prefs, dbService);
      
      // Create test admin user
      final testAdmin = User(
        id: _testAdminId,
        name: 'Test Admin',
        role: UserRole.admin,
        pin: '1234',
        isActive: true,
        adminPanelAccess: true,
        createdAt: DateTime.now(),
      );
      
      await userService.addUser(testAdmin);
      
      // Verify user was created
      final users = await userService.getUsers();
      final createdUser = users.firstWhere(
        (user) => user.id == _testAdminId,
        orElse: () => User(id: '', name: '', role: UserRole.server, pin: ''),
      );
      
      if (createdUser.id == _testAdminId) {
        return true;
      } else {
        return false;
      }
      
    } catch (e) {
      return false;
    }
  }
  
  /// Test 2: Verify admin permissions
  static Future<bool> _testVerifyAdminPermissions() async {
    try {
      
      final prefs = await SharedPreferences.getInstance();
      final dbService = DatabaseService();
      await dbService.initialize();
      
      final userService = UserService(prefs, dbService);
      
      final users = await userService.getUsers();
      final adminUser = users.firstWhere(
        (user) => user.id == _testAdminId,
        orElse: () => User(id: '', name: '', role: UserRole.server, pin: ''),
      );
      
      if (adminUser.id.isEmpty) {
        return false;
      }
      
      // Check role
      if (adminUser.role != UserRole.admin) {
        return false;
      }
      
      // Check admin panel access
      if (!adminUser.adminPanelAccess) {
        return false;
      }
      
      // Check if user is active
      if (!adminUser.isActive) {
        return false;
      }
      
      return true;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Test 3: Test admin panel access
  static Future<bool> _testAdminPanelAccess() async {
    try {
      
      final prefs = await SharedPreferences.getInstance();
      final dbService = DatabaseService();
      await dbService.initialize();
      
      final userService = UserService(prefs, dbService);
      
      final users = await userService.getUsers();
      final adminUser = users.firstWhere(
        (user) => user.id == _testAdminId,
        orElse: () => User(id: '', name: '', role: UserRole.server, pin: ''),
      );
      
      if (adminUser.id.isEmpty) {
        return false;
      }
      
      // Test admin panel access methods
      final canAccessAdminPanel = adminUser.canAccessAdminPanel;
      final isAdmin = adminUser.isAdmin;
      
      if (!canAccessAdminPanel || !isAdmin) {
        return false;
      }
      
      return true;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Test 4: Test order creation access
  static Future<bool> _testOrderCreationAccess() async {
    try {
      
      final prefs = await SharedPreferences.getInstance();
      final dbService = DatabaseService();
      await dbService.initialize();
      
      final userService = UserService(prefs, dbService);
      
      final users = await userService.getUsers();
      final adminUser = users.firstWhere(
        (user) => user.id == _testAdminId,
        orElse: () => User(id: '', name: '', role: UserRole.server, pin: ''),
      );
      
      if (adminUser.id.isEmpty) {
        return false;
      }
      
      // Admin users should always have access to create orders
      if (adminUser.isActive) {
        return true;
      } else {
        return false;
      }
      
    } catch (e) {
      return false;
    }
  }
  
  /// Test 5: Cleanup test data
  static Future<bool> _testCleanup() async {
    try {
      
      final prefs = await SharedPreferences.getInstance();
      final dbService = DatabaseService();
      await dbService.initialize();
      
      final userService = UserService(prefs, dbService);
      
      // Remove test admin user
      final users = await userService.getUsers();
      final testUser = users.firstWhere(
        (user) => user.id == _testAdminId,
        orElse: () => User(id: '', name: '', role: UserRole.server, pin: ''),
      );
      
      if (testUser.id.isNotEmpty) {
        // Note: UserService doesn't have a delete method, so we'll just mark as inactive
        final updatedUser = testUser.copyWith(isActive: false);
        await userService.updateUser(updatedUser);
      } else {
      }
      
      return true;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Print test results summary
  static void printTestResults(Map<String, dynamic> results) {
    
    int passedTests = 0;
    int totalTests = 0;
    
    for (final entry in results.entries) {
      if (entry.key != 'error') {
        totalTests++;
        if (entry.value == true) {
          passedTests++;
        } else {
        }
      }
    }
    
    if (results.containsKey('error')) {
    }
    
    
    if (passedTests == totalTests) {
    } else {
    }
  }
} 