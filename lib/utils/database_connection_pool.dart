import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Database connection pool to manage SQLite connections efficiently
/// Prevents memory leaks and connection exhaustion in multi-tenant environment
class DatabaseConnectionPool {
  static final DatabaseConnectionPool _instance = DatabaseConnectionPool._internal();
  factory DatabaseConnectionPool() => _instance;
  DatabaseConnectionPool._internal();

  static DatabaseConnectionPool get instance => _instance;

  // Connection pool configuration
  static const int _maxConnections = 10;
  static const int _minConnections = 2;
  static const Duration _connectionTimeout = Duration(seconds: 30);
  static const Duration _idleTimeout = Duration(minutes: 15);
  static const Duration _healthCheckInterval = Duration(minutes: 5);

  // Connection pools by database name
  final Map<String, _ConnectionPool> _pools = {};
  final Map<String, Completer<Database>> _pendingConnections = {};
  
  // Health check timer
  Timer? _healthCheckTimer;
  bool _isInitialized = false;

  /// Initialize the connection pool
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('📊 Initializing Database Connection Pool...');
    
    // Start health check timer
    _startHealthCheck();
    
    _isInitialized = true;
    debugPrint('✅ Database Connection Pool initialized');
  }

  /// Get a database connection from the pool
  Future<Database> getConnection(String databaseName) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Check if there's a pending connection for this database
    if (_pendingConnections.containsKey(databaseName)) {
      debugPrint('⏳ Waiting for pending connection to $databaseName');
      return await _pendingConnections[databaseName]!.future;
    }

    // Get or create connection pool for this database
    final pool = _pools.putIfAbsent(databaseName, () => _ConnectionPool(databaseName));
    
    return await pool.getConnection();
  }

  /// Return a connection to the pool
  Future<void> returnConnection(String databaseName, Database database) async {
    final pool = _pools[databaseName];
    if (pool != null) {
      await pool.returnConnection(database);
    }
  }

  /// Close a specific database connection pool
  Future<void> closePool(String databaseName) async {
    final pool = _pools.remove(databaseName);
    if (pool != null) {
      await pool.close();
      debugPrint('🗑️ Closed connection pool for database: $databaseName');
    }
  }

  /// Close all connection pools
  Future<void> closeAllPools() async {
    debugPrint('🗑️ Closing all database connection pools...');
    
    final futures = <Future>[];
    for (final pool in _pools.values) {
      futures.add(pool.close());
    }
    
    await Future.wait(futures);
    _pools.clear();
    
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    
    _isInitialized = false;
    debugPrint('✅ All database connection pools closed');
  }

  /// Get connection pool statistics
  Map<String, Map<String, int>> getPoolStatistics() {
    final stats = <String, Map<String, int>>{};
    
    for (final entry in _pools.entries) {
      stats[entry.key] = {
        'active': entry.value._activeConnections.length,
        'idle': entry.value._idleConnections.length,
        'total': entry.value._activeConnections.length + entry.value._idleConnections.length,
        'created': entry.value._totalCreated,
        'max': _maxConnections,
      };
    }
    
    return stats;
  }

  /// Start health check timer
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) => _performHealthCheck());
  }

  /// Perform health check on all pools
  Future<void> _performHealthCheck() async {
    try {
      for (final pool in _pools.values) {
        await pool._performHealthCheck();
      }
    } catch (e) {
      debugPrint('❌ Health check failed: $e');
    }
  }
}

/// Individual connection pool for a specific database
class _ConnectionPool {
  final String databaseName;
  final Queue<Database> _idleConnections = Queue<Database>();
  final Set<Database> _activeConnections = <Database>{};
  final Map<Database, DateTime> _connectionLastUsed = {};
  final Queue<Completer<Database>> _waitingQueue = Queue<Completer<Database>>();
  
  int _totalCreated = 0;
  bool _isClosed = false;

  _ConnectionPool(this.databaseName);

  /// Get a connection from this pool
  Future<Database> getConnection() async {
    if (_isClosed) {
      throw DatabasePoolException('Connection pool for $databaseName is closed');
    }

    // Try to get an idle connection first
    if (_idleConnections.isNotEmpty) {
      final connection = _idleConnections.removeFirst();
      _activeConnections.add(connection);
      _connectionLastUsed[connection] = DateTime.now();
      
      debugPrint('♻️ Reusing connection for $databaseName (active: ${_activeConnections.length})');
      return connection;
    }

    // Create new connection if under limit
    if (_activeConnections.length < DatabaseConnectionPool._maxConnections) {
      final connection = await _createConnection();
      _activeConnections.add(connection);
      _connectionLastUsed[connection] = DateTime.now();
      _totalCreated++;
      
      debugPrint('🆕 Created new connection for $databaseName (active: ${_activeConnections.length})');
      return connection;
    }

    // Wait for a connection to become available
    debugPrint('⏳ Connection pool full for $databaseName, waiting...');
    final completer = Completer<Database>();
    _waitingQueue.add(completer);
    
    // Set a timeout for waiting
    Timer(DatabaseConnectionPool._connectionTimeout, () {
      if (!completer.isCompleted) {
        _waitingQueue.remove(completer);
        completer.completeError(
          DatabasePoolException('Timeout waiting for connection to $databaseName')
        );
      }
    });
    
    return await completer.future;
  }

  /// Return a connection to this pool
  Future<void> returnConnection(Database connection) async {
    if (_isClosed) {
      await connection.close();
      return;
    }

    if (!_activeConnections.remove(connection)) {
      // Connection not from this pool, close it
      await connection.close();
      return;
    }

    // If there are waiting requests, fulfill them immediately
    if (_waitingQueue.isNotEmpty) {
      final completer = _waitingQueue.removeFirst();
      _activeConnections.add(connection);
      _connectionLastUsed[connection] = DateTime.now();
      
      if (!completer.isCompleted) {
        completer.complete(connection);
      }
      return;
    }

    // Add to idle connections if under minimum or close if over
    if (_idleConnections.length < DatabaseConnectionPool._minConnections) {
      _idleConnections.add(connection);
      _connectionLastUsed[connection] = DateTime.now();
      debugPrint('💤 Returned connection to idle pool for $databaseName (idle: ${_idleConnections.length})');
    } else {
      await connection.close();
      _connectionLastUsed.remove(connection);
      debugPrint('🗑️ Closed excess connection for $databaseName');
    }
  }

  /// Create a new database connection
  Future<Database> _createConnection() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, databaseName);

      final database = await openDatabase(
        path,
        version: 3, // Match current database version
        onOpen: (db) async {
          // Enable foreign key constraints
          await db.execute('PRAGMA foreign_keys = ON');
          
          // Set WAL mode if supported
          try {
            await db.execute('PRAGMA journal_mode = WAL');
          } catch (e) {
            // WAL mode not supported, continue with default
          }
          
          // Set synchronous mode for performance
          try {
            await db.execute('PRAGMA synchronous = NORMAL');
          } catch (e) {
            // Continue if not supported
          }
        },
      );

      return database;
    } catch (e) {
      throw DatabasePoolException('Failed to create connection to $databaseName: $e');
    }
  }

  /// Perform health check on this pool
  Future<void> _performHealthCheck() async {
    final now = DateTime.now();
    final expiredConnections = <Database>[];

    // Check idle connections for expiration
    for (final connection in _idleConnections) {
      final lastUsed = _connectionLastUsed[connection];
      if (lastUsed != null && now.difference(lastUsed) > DatabaseConnectionPool._idleTimeout) {
        expiredConnections.add(connection);
      }
    }

    // Close expired connections
    for (final connection in expiredConnections) {
      _idleConnections.remove(connection);
      _connectionLastUsed.remove(connection);
      await connection.close();
      debugPrint('⏰ Closed expired connection for $databaseName');
    }

    // Log pool statistics
    if (kDebugMode) {
      developer.log(
        'Pool stats for $databaseName: Active: ${_activeConnections.length}, '
        'Idle: ${_idleConnections.length}, Total created: $_totalCreated',
        name: 'DatabasePool'
      );
    }
  }

  /// Close all connections in this pool
  Future<void> close() async {
    _isClosed = true;

    // Complete any waiting requests with error
    while (_waitingQueue.isNotEmpty) {
      final completer = _waitingQueue.removeFirst();
      if (!completer.isCompleted) {
        completer.completeError(
          DatabasePoolException('Connection pool for $databaseName is closing')
        );
      }
    }

    // Close all connections
    final allConnections = [..._activeConnections, ..._idleConnections];
    _activeConnections.clear();
    _idleConnections.clear();
    _connectionLastUsed.clear();

    final futures = allConnections.map((db) => db.close());
    await Future.wait(futures);

    debugPrint('🗑️ Closed all connections for pool: $databaseName');
  }
}

/// Exception for database pool operations
class DatabasePoolException implements Exception {
  final String message;
  
  DatabasePoolException(this.message);
  
  @override
  String toString() => 'DatabasePoolException: $message';
}

/// Database connection wrapper with automatic return to pool
class PooledDatabaseConnection {
  final Database _database;
  final String _databaseName;
  final DatabaseConnectionPool _pool;
  bool _isReturned = false;

  PooledDatabaseConnection._(this._database, this._databaseName, this._pool);

  /// Create a pooled connection
  static Future<PooledDatabaseConnection> create(String databaseName) async {
    final pool = DatabaseConnectionPool.instance;
    final database = await pool.getConnection(databaseName);
    return PooledDatabaseConnection._(database, databaseName, pool);
  }

  /// Get the underlying database
  Database get database => _database;

  /// Return connection to pool
  Future<void> close() async {
    if (!_isReturned) {
      await _pool.returnConnection(_databaseName, _database);
      _isReturned = true;
    }
  }

  /// Execute a transaction with automatic connection management
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    return await _database.transaction(action);
  }

  /// Execute a query with automatic connection management
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await _database.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// Execute an insert with automatic connection management
  Future<int> insert(String table, Map<String, Object?> values) async {
    return await _database.insert(table, values);
  }

  /// Execute an update with automatic connection management
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return await _database.update(table, values, where: where, whereArgs: whereArgs);
  }

  /// Execute a delete with automatic connection management
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    return await _database.delete(table, where: where, whereArgs: whereArgs);
  }
} 