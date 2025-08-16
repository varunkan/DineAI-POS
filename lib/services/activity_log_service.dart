import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_pos_system/models/activity_log.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/services/database_service.dart';

/// Service for comprehensive system-wide activity logging and monitoring
class ActivityLogService extends ChangeNotifier {
  final DatabaseService _databaseService;
  final List<ActivityLog> _logs = [];
  final Map<String, List<ActivityLog>> _userLogsCache = {};
  bool _isInitialized = false;
  String? _currentSessionId;
  String? _currentDeviceId;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserRole;
  String? _currentRestaurantId;

  ActivityLogService(this._databaseService) {
    initialize();
  }

  /// Gets all logs
  List<ActivityLog> get allLogs => List.unmodifiable(_logs);

  /// Gets recent logs (last 500)
  List<ActivityLog> get recentLogs {
    final sorted = List<ActivityLog>.from(_logs);
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(500).toList();
  }

  /// Gets logs for a specific user
  List<ActivityLog> getLogsForUser(String userId) {
    return _userLogsCache[userId] ?? [];
  }

  /// Gets logs by action type
  List<ActivityLog> getLogsByAction(ActivityAction action) {
    return _logs.where((log) => log.action == action).toList();
  }

  /// Gets logs by category
  List<ActivityLog> getLogsByCategory(ActivityCategory category) {
    return _logs.where((log) => log.category == category).toList();
  }

  /// Gets logs by level
  List<ActivityLog> getLogsByLevel(ActivityLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  /// Gets logs within date range
  List<ActivityLog> getLogsByDateRange(DateTime start, DateTime end) {
    return _logs.where((log) => 
      log.timestamp.isAfter(start) && log.timestamp.isBefore(end)
    ).toList();
  }

  /// Gets financial operation logs
  List<ActivityLog> get financialLogs {
    return _logs.where((log) => log.isFinancialOperation).toList();
  }

  /// Gets sensitive operation logs
  List<ActivityLog> get sensitiveOperationLogs {
    return _logs.where((log) => log.isSensitiveOperation).toList();
  }

  /// Gets authentication logs
  List<ActivityLog> get authenticationLogs {
    return getLogsByCategory(ActivityCategory.authentication);
  }

  /// Gets today's logs
  List<ActivityLog> get todaysLogs {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getLogsByDateRange(startOfDay, endOfDay);
  }

  /// Initialize the service
  Future<void> initialize() async {
    try {
      await _createActivityLogsTable();
      await _generateSessionId();
      await _detectDeviceId();
      await _loadRecentLogs();
      _isInitialized = true;
      debugPrint('✅ ActivityLogService initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize ActivityLogService: $e');
    }
  }

  /// Set current user context for logging
  void setCurrentUser(String userId, String userName, String userRole, {String? restaurantId}) {
    _currentUserId = userId;
    _currentUserName = userName;
    _currentUserRole = userRole;
    _currentRestaurantId = restaurantId;
    debugPrint('📝 ActivityLogService: Current user set to $userName ($userRole)');
  }

  /// Create the activity logs table
  Future<void> _createActivityLogsTable() async {
    if (_databaseService.isWeb) {
      debugPrint('✅ Activity logs table created (web storage)');
      return;
    }
    
    final db = await _databaseService.database;
    if (db == null) return;
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_logs (
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        level TEXT NOT NULL DEFAULT 'info',
        category TEXT NOT NULL,
        performed_by TEXT NOT NULL,
        performed_by_name TEXT NOT NULL,
        performed_by_role TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        description TEXT NOT NULL,
        target_id TEXT,
        target_type TEXT,
        target_name TEXT,
        before_data TEXT,
        after_data TEXT,
        metadata TEXT,
        notes TEXT,
        device_id TEXT,
        session_id TEXT,
        ip_address TEXT,
        screen_name TEXT,
        is_system_action INTEGER NOT NULL DEFAULT 0,
        error_message TEXT,
        financial_amount REAL,
        restaurant_id TEXT,
        execution_time INTEGER,
        created_at TEXT NOT NULL
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_activity_logs_performed_by ON activity_logs(performed_by)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_activity_logs_timestamp ON activity_logs(timestamp DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_activity_logs_action ON activity_logs(action)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_activity_logs_category ON activity_logs(category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_activity_logs_level ON activity_logs(level)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_activity_logs_restaurant ON activity_logs(restaurant_id)');

    debugPrint('✅ Activity logs table created with indexes');
  }

  /// Generate unique session ID
  Future<void> _generateSessionId() async {
    try {
      _currentSessionId = '${DateTime.now().millisecondsSinceEpoch}_${Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : Platform.isMacOS ? 'macos' : 'web'}';
    } catch (e) {
      _currentSessionId = '${DateTime.now().millisecondsSinceEpoch}_unknown';
    }
  }

  /// Detect device ID
  Future<void> _detectDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentDeviceId = prefs.getString('device_id');
      if (_currentDeviceId == null) {
        _currentDeviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('device_id', _currentDeviceId!);
      }
    } catch (e) {
      _currentDeviceId = 'device_unknown';
    }
  }

  /// Load recent logs from database
  Future<void> _loadRecentLogs() async {
    try {
      if (_databaseService.isWeb) {
        // Load from web storage
        await _loadWebLogs();
      } else {
        // Load from SQLite
        await _loadSQLiteLogs();
      }
      debugPrint('✅ Loaded ${_logs.length} activity logs from database');
    } catch (e) {
      debugPrint('⚠️ Failed to load activity logs: $e');
    }
  }

  /// Load logs from web storage
  Future<void> _loadWebLogs() async {
    // Implementation would depend on your web storage setup
    // For now, start with empty logs
  }

  /// Load logs from SQLite
  Future<void> _loadSQLiteLogs() async {
    final db = await _databaseService.database;
    if (db == null) return;
    
    final results = await db.query(
      'activity_logs',
      orderBy: 'timestamp DESC',
      limit: 500,
    );

    _logs.clear();
    _userLogsCache.clear();

    for (final row in results) {
      try {
        final log = ActivityLog.fromJson({
          'id': row['id'],
          'action': row['action'],
          'level': row['level'],
          'category': row['category'],
          'performed_by': row['performed_by'],
          'performed_by_name': row['performed_by_name'],
          'performed_by_role': row['performed_by_role'],
          'timestamp': row['timestamp'],
          'description': row['description'],
          'target_id': row['target_id'],
          'target_type': row['target_type'],
          'target_name': row['target_name'],
          'before_data': _safeJsonDecode(row['before_data']),
          'after_data': _safeJsonDecode(row['after_data']),
          'metadata': _safeJsonDecode(row['metadata']),
          'notes': row['notes'],
          'device_id': row['device_id'],
          'session_id': row['session_id'],
          'ip_address': row['ip_address'],
          'screen_name': row['screen_name'],
          'is_system_action': row['is_system_action'] == 1,
          'error_message': row['error_message'],
          'financial_amount': row['financial_amount'],
          'restaurant_id': row['restaurant_id'],
          'execution_time': row['execution_time'],
        });
        _addLogToCache(log);
      } catch (e) {
        debugPrint('⚠️ Failed to parse activity log: $e');
      }
    }
  }

  /// Safely decode JSON with fallback for malformed data
  Map<String, dynamic> _safeJsonDecode(dynamic data) {
    if (data == null) return {};
    
    try {
      final dataStr = data.toString();
      if (dataStr.isEmpty) return {};
      
      // Try normal JSON decode first
      return jsonDecode(dataStr) as Map<String, dynamic>;
    } catch (e) {
      // If JSON decode fails, it might be an old Map string format
      // Skip malformed records silently
      return {};
    }
  }

  /// Log an activity
  Future<ActivityLog> logActivity({
    required ActivityAction action,
    String? performedBy,
    String? performedByName,
    String? performedByRole,
    ActivityLevel level = ActivityLevel.info,
    String? description,
    String? targetId,
    String? targetType,
    String? targetName,
    Map<String, dynamic>? beforeData,
    Map<String, dynamic>? afterData,
    Map<String, dynamic>? metadata,
    String? notes,
    String? screenName,
    bool isSystemAction = false,
    String? errorMessage,
    double? financialAmount,
    Duration? executionTime,
  }) async {
    final log = ActivityLog(
      action: action,
      level: level,
      performedBy: performedBy ?? _currentUserId ?? 'system',
      performedByName: performedByName ?? _currentUserName ?? 'System',
      performedByRole: performedByRole ?? _currentUserRole ?? 'system',
      description: description ?? action.toString().split('.').last,
      targetId: targetId,
      targetType: targetType,
      targetName: targetName,
      beforeData: beforeData ?? {},
      afterData: afterData ?? {},
      metadata: {
        ...metadata ?? {},
        'session_id': _currentSessionId,
        'device_id': _currentDeviceId,
      },
      notes: notes,
      deviceId: _currentDeviceId,
      sessionId: _currentSessionId,
      screenName: screenName,
      isSystemAction: isSystemAction,
      errorMessage: errorMessage,
      financialAmount: financialAmount,
      restaurantId: _currentRestaurantId,
      executionTime: executionTime,
    );

    try {
      await _saveLogToDatabase(log);
      _addLogToCache(log);
      notifyListeners();
      
      // Trigger haptic feedback for important actions
      if (log.isSensitiveOperation || log.level == ActivityLevel.error) {
        _triggerHapticFeedback();
      }

      debugPrint('✅ Activity logged: ${log.actionDescription} by ${log.performedByName} (${log.performedByRole})');
      return log;
    } catch (e) {
      debugPrint('❌ Failed to log activity: $e');
      rethrow;
    }
  }

  /// Save log to database
  Future<void> _saveLogToDatabase(ActivityLog log) async {
    if (_databaseService.isWeb) {
      // Save to web storage
      await _saveWebLog(log);
    } else {
      // Save to SQLite
      await _saveSQLiteLog(log);
    }
  }

  /// Save log to web storage
  Future<void> _saveWebLog(ActivityLog log) async {
    // Implementation would depend on your web storage setup
    // For now, just add to cache
  }

  /// Save log to SQLite
  Future<void> _saveSQLiteLog(ActivityLog log) async {
    final db = await _databaseService.database;
    if (db == null) return;
    
    final logMap = log.toSQLiteMap();
    await db.insert('activity_logs', logMap);
  }

  /// Add log to cache
  void _addLogToCache(ActivityLog log) {
    _logs.insert(0, log); // Add to beginning for newest first
    
    // Maintain cache size
    if (_logs.length > 2000) {
      _logs.removeLast();
    }

    // Add to user-specific cache
    if (!_userLogsCache.containsKey(log.performedBy)) {
      _userLogsCache[log.performedBy] = [];
    }
    _userLogsCache[log.performedBy]!.add(log);
  }

  /// Trigger haptic feedback
  void _triggerHapticFeedback() {
    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      // Ignore haptic feedback errors
    }
  }

  // Convenience methods for common operations

  /// Log user login
  Future<ActivityLog> logLogin({
    required String userId,
    required String userName,
    required String userRole,
    String? screenName,
    Map<String, dynamic>? metadata,
  }) async {
    return logActivity(
      action: ActivityAction.login,
      performedBy: userId,
      performedByName: userName,
      performedByRole: userRole,
      description: '$userName logged in',
      screenName: screenName ?? 'Login',
      metadata: metadata,
    );
  }

  /// Log user logout
  Future<ActivityLog> logLogout({
    required String userId,
    required String userName,
    required String userRole,
    String? reason,
    String? screenName,
  }) async {
    return logActivity(
      action: ActivityAction.logout,
      performedBy: userId,
      performedByName: userName,
      performedByRole: userRole,
      description: '$userName logged out',
      notes: reason,
      screenName: screenName ?? 'Logout',
    );
  }

  /// Log screen access
  Future<ActivityLog> logScreenAccess({
    required String screenName,
    String? userId,
    String? userName,
    String? userRole,
    Map<String, dynamic>? metadata,
  }) async {
    return logActivity(
      action: ActivityAction.screenAccessed,
      performedBy: userId,
      performedByName: userName,
      performedByRole: userRole,
      description: '${userName ?? 'User'} accessed $screenName',
      screenName: screenName,
      metadata: metadata,
    );
  }

  /// Log admin panel access
  Future<ActivityLog> logAdminPanelAccess({
    required String userId,
    required String userName,
    required String userRole,
    String? tabName,
  }) async {
    return logActivity(
      action: ActivityAction.adminPanelAccessed,
      level: ActivityLevel.security,
      performedBy: userId,
      performedByName: userName,
      performedByRole: userRole,
      description: '$userName accessed admin panel${tabName != null ? ' - $tabName' : ''}',
      screenName: 'Admin Panel',
      notes: tabName,
    );
  }

  /// Log user management action
  Future<ActivityLog> logUserManagement({
    required ActivityAction action,
    required String performedBy,
    required String performedByName,
    required String performedByRole,
    required String targetUserId,
    required String targetUserName,
    Map<String, dynamic>? beforeData,
    Map<String, dynamic>? afterData,
    String? notes,
    String? screenName,
  }) async {
    return logActivity(
      action: action,
      level: ActivityLevel.security,
      performedBy: performedBy,
      performedByName: performedByName,
      performedByRole: performedByRole,
      description: '$performedByName ${action.toString().split('.').last} user: $targetUserName',
      targetId: targetUserId,
      targetType: 'user',
      targetName: targetUserName,
      beforeData: beforeData,
      afterData: afterData,
      notes: notes,
      screenName: screenName ?? 'User Management',
    );
  }

  /// Log menu management action
  Future<ActivityLog> logMenuManagement({
    required ActivityAction action,
    required String performedBy,
    required String performedByName,
    required String performedByRole,
    required String targetId,
    required String targetName,
    String? targetType,
    Map<String, dynamic>? beforeData,
    Map<String, dynamic>? afterData,
    String? notes,
    String? screenName,
  }) async {
    return logActivity(
      action: action,
      performedBy: performedBy,
      performedByName: performedByName,
      performedByRole: performedByRole,
      description: '$performedByName ${action.toString().split('.').last}: $targetName',
      targetId: targetId,
      targetType: targetType ?? 'menu_item',
      targetName: targetName,
      beforeData: beforeData,
      afterData: afterData,
      notes: notes,
      screenName: screenName ?? 'Menu Management',
    );
  }

  /// Log financial operation
  Future<ActivityLog> logFinancialOperation({
    required ActivityAction action,
    required String performedBy,
    required String performedByName,
    required String performedByRole,
    required double amount,
    String? orderId,
    String? orderNumber,
    String? notes,
    String? screenName,
  }) async {
    return logActivity(
      action: action,
      level: ActivityLevel.warning, // Financial operations are important
      performedBy: performedBy,
      performedByName: performedByName,
      performedByRole: performedByRole,
      description: '$performedByName ${action.toString().split('.').last} \$${amount.toStringAsFixed(2)}',
      targetId: orderId,
      targetType: 'order',
      targetName: orderNumber,
      financialAmount: amount,
      notes: notes,
      screenName: screenName,
    );
  }

  /// Log system error
  Future<ActivityLog> logError({
    required String errorMessage,
    String? performedBy,
    String? performedByName,
    String? performedByRole,
    String? screenName,
    Map<String, dynamic>? metadata,
  }) async {
    return logActivity(
      action: ActivityAction.systemError,
      level: ActivityLevel.error,
      performedBy: performedBy,
      performedByName: performedByName,
      performedByRole: performedByRole,
      description: 'System error occurred',
      errorMessage: errorMessage,
      screenName: screenName,
      metadata: metadata,
      isSystemAction: true,
    );
  }

  /// Get analytics data
  Map<String, dynamic> getAnalytics({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) {
    var filteredLogs = _logs.where((log) {
      if (startDate != null && log.timestamp.isBefore(startDate)) return false;
      if (endDate != null && log.timestamp.isAfter(endDate)) return false;
      if (userId != null && log.performedBy != userId) return false;
      return true;
    }).toList();

    final actionCounts = <String, int>{};
    final categoryCounts = <String, int>{};
    final userCounts = <String, int>{};
    final hourlyActivity = <int, int>{};
    final dailyActivity = <String, int>{};
    double totalFinancialImpact = 0.0;

    for (final log in filteredLogs) {
      // Count actions
      final actionKey = log.action.toString().split('.').last;
      actionCounts[actionKey] = (actionCounts[actionKey] ?? 0) + 1;

      // Count categories
      final categoryKey = log.category.toString().split('.').last;
      categoryCounts[categoryKey] = (categoryCounts[categoryKey] ?? 0) + 1;

      // Count by user
      final userKey = log.performedByName;
      userCounts[userKey] = (userCounts[userKey] ?? 0) + 1;

      // Hourly activity
      final hour = log.timestamp.hour;
      hourlyActivity[hour] = (hourlyActivity[hour] ?? 0) + 1;

      // Daily activity
      final day = '${log.timestamp.year}-${log.timestamp.month.toString().padLeft(2, '0')}-${log.timestamp.day.toString().padLeft(2, '0')}';
      dailyActivity[day] = (dailyActivity[day] ?? 0) + 1;

      // Financial impact
      if (log.financialImpact != null) {
        totalFinancialImpact += log.financialImpact!;
      }
    }

    return {
      'total_logs': filteredLogs.length,
      'action_counts': actionCounts,
      'category_counts': categoryCounts,
      'user_counts': userCounts,
      'hourly_activity': hourlyActivity,
      'daily_activity': dailyActivity,
      'total_financial_impact': totalFinancialImpact,
      'financial_operations': filteredLogs.where((log) => log.isFinancialOperation).length,
      'sensitive_operations': filteredLogs.where((log) => log.isSensitiveOperation).length,
      'error_count': filteredLogs.where((log) => log.level == ActivityLevel.error).length,
      'warning_count': filteredLogs.where((log) => log.level == ActivityLevel.warning).length,
      'security_count': filteredLogs.where((log) => log.level == ActivityLevel.security).length,
      'unique_users': userCounts.keys.length,
      'unique_screens': filteredLogs.map((log) => log.screenName).where((s) => s != null).toSet().length,
    };
  }

  /// Clean up old logs (keep last 30 days)
  Future<void> cleanupOldLogs({int daysToKeep = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      
      if (_databaseService.isWeb) {
        // Clean up web storage
        await _cleanupWebLogs(cutoffDate);
      } else {
        // Clean up SQLite
        await _cleanupSQLiteLogs(cutoffDate);
      }

      // Clean up cache
      _logs.removeWhere((log) => log.timestamp.isBefore(cutoffDate));
      _userLogsCache.clear();
      
      // Rebuild user cache
      for (final log in _logs) {
        if (!_userLogsCache.containsKey(log.performedBy)) {
          _userLogsCache[log.performedBy] = [];
        }
        _userLogsCache[log.performedBy]!.add(log);
      }

      debugPrint('✅ Cleaned up activity logs older than $daysToKeep days');
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Failed to cleanup old activity logs: $e');
    }
  }

  /// Clean up web logs
  Future<void> _cleanupWebLogs(DateTime cutoffDate) async {
    // Implementation would depend on your web storage setup
  }

  /// Clean up SQLite logs
  Future<void> _cleanupSQLiteLogs(DateTime cutoffDate) async {
    final db = await _databaseService.database;
    if (db == null) return;
    
    await db.delete(
      'activity_logs',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  /// Export logs to JSON
  Future<String> exportLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) async {
    var logsToExport = _logs.where((log) {
      if (startDate != null && log.timestamp.isBefore(startDate)) return false;
      if (endDate != null && log.timestamp.isAfter(endDate)) return false;
      if (userId != null && log.performedBy != userId) return false;
      return true;
    }).toList();

    final exportData = {
      'export_timestamp': DateTime.now().toIso8601String(),
      'total_logs': logsToExport.length,
      'filters': {
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'user_id': userId,
      },
      'logs': logsToExport.map((log) => log.toJson()).toList(),
    };

    return jsonEncode(exportData);
  }

  /// Get user activity summary
  Map<String, dynamic> getUserActivitySummary(String userId, {DateTime? startDate, DateTime? endDate}) {
    final userLogs = _logs.where((log) {
      if (log.performedBy != userId) return false;
      if (startDate != null && log.timestamp.isBefore(startDate)) return false;
      if (endDate != null && log.timestamp.isAfter(endDate)) return false;
      return true;
    }).toList();

    final actionCounts = <String, int>{};
    final categoryCounts = <String, int>{};
    final screenCounts = <String, int>{};
    var totalFinancialImpact = 0.0;
    var sensitiveOperations = 0;
    var errorCount = 0;

    for (final log in userLogs) {
      // Count actions
      final actionKey = log.action.toString().split('.').last;
      actionCounts[actionKey] = (actionCounts[actionKey] ?? 0) + 1;

      // Count categories
      final categoryKey = log.category.toString().split('.').last;
      categoryCounts[categoryKey] = (categoryCounts[categoryKey] ?? 0) + 1;

      // Count screens
      if (log.screenName != null) {
        screenCounts[log.screenName!] = (screenCounts[log.screenName!] ?? 0) + 1;
      }

      // Financial impact
      if (log.financialImpact != null) {
        totalFinancialImpact += log.financialImpact!;
      }

      // Sensitive operations
      if (log.isSensitiveOperation) {
        sensitiveOperations++;
      }

      // Error count
      if (log.level == ActivityLevel.error) {
        errorCount++;
      }
    }

    return {
      'user_id': userId,
      'total_activities': userLogs.length,
      'action_counts': actionCounts,
      'category_counts': categoryCounts,
      'screen_counts': screenCounts,
      'total_financial_impact': totalFinancialImpact,
      'sensitive_operations': sensitiveOperations,
      'error_count': errorCount,
      'first_activity': userLogs.isNotEmpty ? userLogs.last.timestamp.toIso8601String() : null,
      'last_activity': userLogs.isNotEmpty ? userLogs.first.timestamp.toIso8601String() : null,
    };
  }
} 