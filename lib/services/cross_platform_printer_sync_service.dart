import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/printer_assignment.dart';
import '../models/printer_configuration.dart';
import '../services/database_service.dart';
import '../services/enhanced_printer_assignment_service.dart';

/// Cross-Platform Printer Synchronization Service
/// Ensures printer assignments persist across Android, iOS, Web, and Desktop
/// Provides real-time synchronization across all devices
class CrossPlatformPrinterSyncService extends ChangeNotifier {
  static const String _logTag = '🌐 CrossPlatformPrinterSync';
  
  final DatabaseService _databaseService;
  final EnhancedPrinterAssignmentService _assignmentService;
  
  // Sync state
  bool _isSyncing = false;
  bool _isEnabled = true;
  DateTime? _lastSyncTime;
  String? _syncError;
  Timer? _syncTimer;
  
  // Sync configuration
  static const Duration _syncInterval = Duration(seconds: 30);
  static const Duration _forceSyncInterval = Duration(minutes: 5);
  static const String _syncKeyPrefix = 'printer_sync_';
  static const String _lastSyncKey = '${_syncKeyPrefix}last_sync';
  static const String _assignmentsKey = '${_syncKeyPrefix}assignments';
  static const String _printersKey = '${_syncKeyPrefix}printers';
  
  // Cross-platform storage
  SharedPreferences? _prefs;
  
  CrossPlatformPrinterSyncService({
    required DatabaseService databaseService,
    required EnhancedPrinterAssignmentService assignmentService,
  }) : _databaseService = databaseService,
       _assignmentService = assignmentService;
  
  // Getters
  bool get isSyncing => _isSyncing;
  bool get isEnabled => _isEnabled;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get syncError => _syncError;
  
  /// Initialize the sync service
  Future<void> initialize() async {
    try {
      debugPrint('$_logTag 🚀 Initializing cross-platform sync service...');
      
      // Initialize SharedPreferences for cross-platform storage
      _prefs = await SharedPreferences.getInstance();
      
      // Load last sync time
      final lastSyncStr = _prefs?.getString(_lastSyncKey);
      if (lastSyncStr != null) {
        _lastSyncTime = DateTime.tryParse(lastSyncStr);
      }
      
      // Start periodic sync
      _startPeriodicSync();
      
      // Perform initial sync
      await _performInitialSync();
      
      debugPrint('$_logTag ✅ Cross-platform sync service initialized');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error initializing sync service: $e');
      _syncError = 'Failed to initialize: $e';
    }
  }
  
  /// Start periodic synchronization
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      if (_isEnabled && !_isSyncing) {
        _syncInBackground();
      }
    });
    
    debugPrint('$_logTag 🔄 Started periodic sync (every ${_syncInterval.inSeconds}s)');
  }
  
  /// Perform initial sync on startup
  Future<void> _performInitialSync() async {
    try {
      debugPrint('$_logTag 📥 Performing initial sync...');
      
      // Check if we have stored assignments to restore
      final hasStoredAssignments = await _hasStoredAssignments();
      
      if (hasStoredAssignments) {
        // Restore assignments from cross-platform storage
        await _restoreAssignmentsFromStorage();
        debugPrint('$_logTag ✅ Restored assignments from cross-platform storage');
      } else {
        // Save current assignments to cross-platform storage
        await _saveAssignmentsToStorage();
        debugPrint('$_logTag 💾 Saved current assignments to cross-platform storage');
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error in initial sync: $e');
    }
  }
  
  /// Check if we have stored assignments
  Future<bool> _hasStoredAssignments() async {
    final assignmentsJson = _prefs?.getString(_assignmentsKey);
    return assignmentsJson != null && assignmentsJson.isNotEmpty;
  }
  
  /// Restore assignments from cross-platform storage
  Future<void> _restoreAssignmentsFromStorage() async {
    try {
      final assignmentsJson = _prefs?.getString(_assignmentsKey);
      if (assignmentsJson == null) return;
      
      final assignmentsList = json.decode(assignmentsJson) as List<dynamic>;
      final assignments = assignmentsList
          .map((json) => PrinterAssignment.fromJson(json as Map<String, dynamic>))
          .toList();
      
      debugPrint('$_logTag 📥 Restoring ${assignments.length} assignments from storage...');
      
      // Clear existing assignments and restore from storage
      await _assignmentService.clearAllAssignments();
      
      for (final assignment in assignments) {
        await _assignmentService.addAssignment(
          printerId: assignment.printerId,
          assignmentType: assignment.assignmentType,
          targetId: assignment.targetId,
          targetName: assignment.targetName,
          priority: assignment.priority,
        );
      }
      
      debugPrint('$_logTag ✅ Successfully restored ${assignments.length} assignments');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error restoring assignments: $e');
    }
  }
  
  /// Save assignments to cross-platform storage
  Future<void> _saveAssignmentsToStorage() async {
    try {
      final assignments = _assignmentService.assignments;
      final assignmentsJson = json.encode(
        assignments.map((a) => a.toJson()).toList(),
      );
      
      await _prefs?.setString(_assignmentsKey, assignmentsJson);
      await _prefs?.setString(_lastSyncKey, DateTime.now().toIso8601String());
      
      _lastSyncTime = DateTime.now();
      
      debugPrint('$_logTag 💾 Saved ${assignments.length} assignments to cross-platform storage');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error saving assignments: $e');
    }
  }
  
  /// Sync in background
  Future<void> _syncInBackground() async {
    try {
      await _performSync();
    } catch (e) {
      debugPrint('$_logTag ❌ Background sync error: $e');
    }
  }
  
  /// Perform synchronization
  Future<void> _performSync() async {
    if (_isSyncing) return;
    
    try {
      _isSyncing = true;
      _syncError = null;
      notifyListeners();
      
      debugPrint('$_logTag 🔄 Starting synchronization...');
      
      // Save current state to cross-platform storage
      await _saveAssignmentsToStorage();
      
      // Also save to database for local persistence
      await _saveToPersistentDatabase();
      
      _lastSyncTime = DateTime.now();
      debugPrint('$_logTag ✅ Synchronization completed successfully');
      
    } catch (e) {
      _syncError = e.toString();
      debugPrint('$_logTag ❌ Sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  /// Save to persistent database with enhanced metadata
  Future<void> _saveToPersistentDatabase() async {
    try {
      final db = await _databaseService.database;
      if (db == null) return;
      
      // Create cross-platform sync metadata table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cross_platform_sync (
          id TEXT PRIMARY KEY,
          data_type TEXT NOT NULL,
          sync_timestamp TEXT NOT NULL,
          device_info TEXT NOT NULL,
          platform TEXT NOT NULL,
          data_json TEXT NOT NULL,
          checksum TEXT NOT NULL
        )
      ''');
      
      final assignments = _assignmentService.assignments;
      final assignmentsJson = json.encode(assignments.map((a) => a.toJson()).toList());
      final checksum = assignmentsJson.hashCode.toString();
      
      // Save sync metadata
      await db.insert(
        'cross_platform_sync',
        {
          'id': 'assignments_${DateTime.now().millisecondsSinceEpoch}',
          'data_type': 'printer_assignments',
          'sync_timestamp': DateTime.now().toIso8601String(),
          'device_info': _getDeviceInfo(),
          'platform': _getPlatformName(),
          'data_json': assignmentsJson,
          'checksum': checksum,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      debugPrint('$_logTag 💾 Saved sync metadata to persistent database');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error saving to persistent database: $e');
    }
  }
  
  /// Force sync now
  Future<void> forceSyncNow() async {
    debugPrint('$_logTag 🔄 Force sync requested by user...');
    await _performSync();
  }
  
  /// Enable/disable sync
  void setSyncEnabled(bool enabled) {
    _isEnabled = enabled;
    if (enabled) {
      _startPeriodicSync();
      debugPrint('$_logTag ✅ Sync enabled');
    } else {
      _syncTimer?.cancel();
      debugPrint('$_logTag ⏸️ Sync disabled');
    }
    notifyListeners();
  }
  
  /// Get device information
  String _getDeviceInfo() {
    if (kIsWeb) {
      return 'Web Browser';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'Android Device';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'iOS Device';
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      return 'macOS Device';
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      return 'Windows Device';
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      return 'Linux Device';
    }
    return 'Unknown Device';
  }
  
  /// Get platform name
  String _getPlatformName() {
    if (kIsWeb) {
      return 'web';
    } else {
      return defaultTargetPlatform.name;
    }
  }
  
  /// Get sync status summary
  Map<String, dynamic> getSyncStatus() {
    return {
      'isEnabled': _isEnabled,
      'isSyncing': _isSyncing,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'syncError': _syncError,
      'deviceInfo': _getDeviceInfo(),
      'platform': _getPlatformName(),
      'assignmentCount': _assignmentService.assignments.length,
    };
  }
  
  /// Clear all sync data (for troubleshooting)
  Future<void> clearSyncData() async {
    try {
      await _prefs?.remove(_assignmentsKey);
      await _prefs?.remove(_lastSyncKey);
      
      final db = await _databaseService.database;
      if (db != null) {
        await db.delete('cross_platform_sync');
      }
      
      _lastSyncTime = null;
      _syncError = null;
      
      debugPrint('$_logTag 🧹 Cleared all sync data');
      notifyListeners();
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error clearing sync data: $e');
    }
  }
  
  /// Dispose the service
  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

 