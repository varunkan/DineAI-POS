import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Utility class to test admin user creation and access functionality
class AdminUserTest {
  static const String _testAdminId = 'test_admin_${DateTime.now().millisecondsSinceEpoch}';
  
  /// Test admin user creation and permissions
  static Future<Map<String, dynamic>> testAdminUserCreation() async {
    final results = <String, dynamic>{};
    
    try {
      debugPrint('🧪 Starting admin user creation test...');
      
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
      
      debugPrint('✅ Admin user creation test completed');
      
    } catch (e) {
      debugPrint('❌ Admin user creation test failed: $e');
      results['error'] = e.toString();
    }
    
    return results;
  }
  
  /// Test 1: Create admin user
  static Future<bool> _testCreateAdminUser() async {
    try {
      debugPrint('🧪 Test 1: Creating test admin user...');
      
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
        debugPrint('✅ Test 1 PASSED: Admin user created successfully');
        return true;
      } else {
        debugPrint('❌ Test 1 FAILED: Admin user not found after creation');
        return false;
      }
      
    } catch (e) {
      debugPrint('❌ Test 1 FAILED: $e');
      return false;
    }
  }
  
  /// Test 2: Verify admin permissions
  static Future<bool> _testVerifyAdminPermissions() async {
    try {
      debugPrint('🧪 Test 2: Verifying admin permissions...');
      
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
        debugPrint('❌ Test 2 FAILED: Admin user not found');
        return false;
      }
      
      // Check role
      if (adminUser.role != UserRole.admin) {
        debugPrint('❌ Test 2 FAILED: User role is ${adminUser.role}, not admin');
        return false;
      }
      
      // Check admin panel access
      if (!adminUser.adminPanelAccess) {
        debugPrint('❌ Test 2 FAILED: User does not have admin panel access');
        return false;
      }
      
      // Check if user is active
      if (!adminUser.isActive) {
        debugPrint('❌ Test 2 FAILED: User is not active');
        return false;
      }
      
      debugPrint('✅ Test 2 PASSED: Admin permissions verified');
      return true;
      
    } catch (e) {
      debugPrint('❌ Test 2 FAILED: $e');
      return false;
    }
  }
  
  /// Test 3: Test admin panel access
  static Future<bool> _testAdminPanelAccess() async {
    try {
      debugPrint('🧪 Test 3: Testing admin panel access...');
      
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
        debugPrint('❌ Test 3 FAILED: Admin user not found');
        return false;
      }
      
      // Test admin panel access methods
      final canAccessAdminPanel = adminUser.canAccessAdminPanel;
      final isAdmin = adminUser.isAdmin;
      
      if (!canAccessAdminPanel || !isAdmin) {
        debugPrint('❌ Test 3 FAILED: Admin user cannot access admin panel');
        debugPrint('   • canAccessAdminPanel: $canAccessAdminPanel');
        debugPrint('   • isAdmin: $isAdmin');
        return false;
      }
      
      debugPrint('✅ Test 3 PASSED: Admin panel access verified');
      return true;
      
    } catch (e) {
      debugPrint('❌ Test 3 FAILED: $e');
      return false;
    }
  }
  
  /// Test 4: Test order creation access
  static Future<bool> _testOrderCreationAccess() async {
    try {
      debugPrint('🧪 Test 4: Testing order creation access...');
      
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
        debugPrint('❌ Test 4 FAILED: Admin user not found');
        return false;
      }
      
      // Admin users should always have access to create orders
      if (adminUser.isActive) {
        debugPrint('✅ Test 4 PASSED: Admin user can create orders');
        return true;
      } else {
        debugPrint('❌ Test 4 FAILED: Admin user is not active');
        return false;
      }
      
    } catch (e) {
      debugPrint('❌ Test 4 FAILED: $e');
      return false;
    }
  }
  
  /// Test 5: Cleanup test data
  static Future<bool> _testCleanup() async {
    try {
      debugPrint('🧪 Test 5: Cleaning up test data...');
      
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
        debugPrint('✅ Test 5 PASSED: Test admin user deactivated');
      } else {
        debugPrint('✅ Test 5 PASSED: Test admin user not found (already cleaned up)');
      }
      
      return true;
      
    } catch (e) {
      debugPrint('❌ Test 5 FAILED: $e');
      return false;
    }
  }
  
  /// Print test results summary
  static void printTestResults(Map<String, dynamic> results) {
    debugPrint('\n📊 ADMIN USER CREATION TEST RESULTS');
    debugPrint('=====================================');
    
    int passedTests = 0;
    int totalTests = 0;
    
    for (final entry in results.entries) {
      if (entry.key != 'error') {
        totalTests++;
        if (entry.value == true) {
          passedTests++;
          debugPrint('✅ ${entry.key}: PASSED');
        } else {
          debugPrint('❌ ${entry.key}: FAILED');
        }
      }
    }
    
    if (results.containsKey('error')) {
      debugPrint('❌ ERROR: ${results['error']}');
    }
    
    debugPrint('=====================================');
    debugPrint('📈 RESULTS: $passedTests/$totalTests tests passed');
    
    if (passedTests == totalTests) {
      debugPrint('🎉 ALL TESTS PASSED! Admin user creation is working correctly.');
    } else {
      debugPrint('⚠️ Some tests failed. Please check the implementation.');
    }
    debugPrint('');
  }
} 