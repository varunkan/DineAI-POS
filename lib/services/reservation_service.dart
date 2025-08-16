import 'package:ai_pos_system/models/reservation.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

/// Service for managing table reservations
class ReservationService extends ChangeNotifier {
  final DatabaseService _databaseService;
  List<Reservation> _reservations = [];
  List<Reservation> _todaysReservations = [];
  bool _isLoading = false;

  ReservationService(this._databaseService);

  /// Get all reservations
  List<Reservation> get reservations => List.unmodifiable(_reservations);

  /// Get today's reservations
  List<Reservation> get todaysReservations => List.unmodifiable(_todaysReservations);

  /// Loading state
  bool get isLoading => _isLoading;

  /// Load all reservations from database
  Future<void> loadReservations() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await _databaseService.database;
      if (db != null) {
        final List<Map<String, dynamic>> maps = await db.query(
          'reservations',
          orderBy: 'reservationDate ASC, reservationTimeHour ASC, reservationTimeMinute ASC',
        );

        _reservations = maps.map((map) => Reservation.fromJson(map)).toList();
        _updateTodaysReservations();
      }
    } catch (e) {
      debugPrint('Error loading reservations: $e');
      _reservations = [];
      _todaysReservations = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load reservations for a specific date
  Future<List<Reservation>> getReservationsForDate(DateTime date) async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final List<Map<String, dynamic>> maps = await db.query(
          'reservations',
          where: 'reservationDate >= ? AND reservationDate < ?',
          whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
          orderBy: 'reservationTimeHour ASC, reservationTimeMinute ASC',
        );

        return maps.map((map) => Reservation.fromJson(map)).toList();
      }
    } catch (e) {
      debugPrint('Error loading reservations for date: $e');
    }
    return [];
  }

  /// Create a new reservation
  Future<bool> createReservation(Reservation reservation) async {
    try {
      final db = await _databaseService.database;
      if (db == null) return false;
      
      // Create a clean reservation with validated foreign keys
      String? validTableId;
      String? validUserId;
      
      // Validate and clean table ID
      if (reservation.tableId != null) {
        final tableExists = await _validateTableExists(reservation.tableId!);
        if (tableExists) {
          validTableId = reservation.tableId;
          debugPrint('Table ID ${reservation.tableId} validated successfully');
        } else {
          debugPrint('Table ID ${reservation.tableId} does not exist - removing table assignment');
          validTableId = null;
        }
      }
      
      // Validate and clean user ID
      if (reservation.createdBy != null) {
        final userExists = await _validateUserExists(reservation.createdBy!);
        if (userExists) {
          validUserId = reservation.createdBy;
          debugPrint('User ID ${reservation.createdBy} validated successfully');
        } else {
          debugPrint('User ID ${reservation.createdBy} does not exist - finding valid user');
          validUserId = await _findAdminUser();
          if (validUserId == null) {
            debugPrint('No valid users found - creating reservation without user assignment');
          }
        }
      } else {
        // Try to find a valid user if none provided
        validUserId = await _findAdminUser();
      }
      
      // Create clean reservation with validated foreign keys
      final cleanReservation = reservation.copyWith(
        tableId: validTableId,
        createdBy: validUserId,
        clearTableId: validTableId == null && reservation.tableId != null,
        clearCreatedBy: validUserId == null && reservation.createdBy != null,
      );
      
      return await _insertReservation(db, cleanReservation);
    } catch (e) {
      debugPrint('Error creating reservation: $e');
      return false;
    }
  }

  /// Helper method to insert reservation after validation
  Future<bool> _insertReservation(Database db, Reservation reservation) async {
    try {
      // Check for conflicts
      final conflicts = await _checkReservationConflicts(reservation);
      if (conflicts.isNotEmpty) {
        debugPrint('Reservation conflicts found: ${conflicts.length}');
        return false;
      }

      await db.insert('reservations', reservation.toJson());
      
      // Add to local list
      _reservations.add(reservation);
      _reservations.sort((a, b) {
        final dateComparison = a.reservationDate.compareTo(b.reservationDate);
        if (dateComparison != 0) return dateComparison;
        
        final aMinutes = a.reservationTime.hour * 60 + a.reservationTime.minute;
        final bMinutes = b.reservationTime.hour * 60 + b.reservationTime.minute;
        return aMinutes.compareTo(bMinutes);
      });
      
      _updateTodaysReservations();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error inserting reservation: $e');
      return false;
    }
  }

  /// Validate if table exists
  Future<bool> _validateTableExists(String tableId) async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        final result = await db.query(
          'tables',
          where: 'id = ?',
          whereArgs: [tableId],
          limit: 1,
        );
        return result.isNotEmpty;
      }
    } catch (e) {
      debugPrint('Error validating table: $e');
    }
    return false;
  }

  /// Validate if user exists
  Future<bool> _validateUserExists(String userId) async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        final result = await db.query(
          'users',
          where: 'id = ?',
          whereArgs: [userId],
          limit: 1,
        );
        return result.isNotEmpty;
      }
    } catch (e) {
      debugPrint('Error validating user: $e');
    }
    return false;
  }

  /// Find an admin user or return null
  Future<String?> _findAdminUser() async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        final result = await db.query(
          'users',
          where: 'role = ?',
          whereArgs: ['admin'],
          limit: 1,
        );
        if (result.isNotEmpty) {
          return result.first['id'] as String;
        }
        
        // If no admin user found, try to get any user
        final anyUser = await db.query('users', limit: 1);
        if (anyUser.isNotEmpty) {
          return anyUser.first['id'] as String;
        }
        
        return null;
      }
      return null; // Add explicit return for when db is null
    } catch (e) {
      debugPrint('Error finding admin user: $e');
      return null;
    }
  }

  /// Update an existing reservation
  Future<bool> updateReservation(Reservation reservation) async {
    try {
      final db = await _databaseService.database;
      if (db == null) return false;
      
      // Check for conflicts (excluding current reservation)
      final conflicts = await _checkReservationConflicts(reservation, excludeId: reservation.id);
      if (conflicts.isNotEmpty) {
        debugPrint('Reservation conflicts found: ${conflicts.length}');
        return false;
      }

      await db.update(
        'reservations',
        reservation.toJson(),
        where: 'id = ?',
        whereArgs: [reservation.id],
      );

      // Update local list
      final index = _reservations.indexWhere((r) => r.id == reservation.id);
      if (index != -1) {
        _reservations[index] = reservation;
        _updateTodaysReservations();
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      debugPrint('Error updating reservation: $e');
      return false;
    }
  }

  /// Update reservation status
  Future<bool> updateReservationStatus(String reservationId, ReservationStatus newStatus) async {
    try {
      final reservation = _reservations.firstWhere((r) => r.id == reservationId);
      final updatedReservation = reservation.copyWith(
        status: newStatus,
        confirmedAt: newStatus == ReservationStatus.confirmed ? DateTime.now() : reservation.confirmedAt,
        arrivedAt: newStatus == ReservationStatus.arrived ? DateTime.now() : reservation.arrivedAt,
        seatedAt: newStatus == ReservationStatus.seated ? DateTime.now() : reservation.seatedAt,
        completedAt: newStatus == ReservationStatus.completed ? DateTime.now() : reservation.completedAt,
      );

      return await updateReservation(updatedReservation);
    } catch (e) {
      debugPrint('Error updating reservation status: $e');
      return false;
    }
  }

  /// Delete a reservation
  Future<bool> deleteReservation(String reservationId) async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        await db.delete(
          'reservations',
          where: 'id = ?',
          whereArgs: [reservationId],
        );

        _reservations.removeWhere((r) => r.id == reservationId);
        _updateTodaysReservations();
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      debugPrint('Error deleting reservation: $e');
      return false;
    }
  }

  /// Check for reservation conflicts
  Future<List<Reservation>> _checkReservationConflicts(Reservation reservation, {String? excludeId}) async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        final reservationDate = DateTime(
          reservation.reservationDate.year,
          reservation.reservationDate.month,
          reservation.reservationDate.day,
        );
        
        // Get all reservations for the same date
        final List<Map<String, dynamic>> maps = await db.query(
          'reservations',
          where: 'reservationDate = ? AND status != ? AND status != ?${excludeId != null ? ' AND id != ?' : ''}',
          whereArgs: [
            reservationDate.toIso8601String(),
            ReservationStatus.cancelled.toString().split('.').last,
            ReservationStatus.noShow.toString().split('.').last,
            if (excludeId != null) excludeId,
          ],
        );

        final existingReservations = maps.map((map) => Reservation.fromJson(map)).toList();
        final conflicts = <Reservation>[];

        // Check for time conflicts (2-hour window)
        for (final existing in existingReservations) {
          if (_reservationsConflict(reservation, existing)) {
            conflicts.add(existing);
          }
        }

        return conflicts;
      }
    } catch (e) {
      debugPrint('Error checking reservation conflicts: $e');
    }
    return [];
  }

  /// Check if two reservations conflict
  bool _reservationsConflict(Reservation a, Reservation b) {
    final aMinutes = a.reservationTime.hour * 60 + a.reservationTime.minute;
    final bMinutes = b.reservationTime.hour * 60 + b.reservationTime.minute;
    
    // If same table is specified, check for stricter overlap
    if (a.tableId != null && b.tableId != null && a.tableId == b.tableId) {
      return (aMinutes - bMinutes).abs() < 120; // 2-hour buffer for same table
    }
    
    // For party size conflicts (restaurant capacity)
    return (aMinutes - bMinutes).abs() < 30; // 30-minute buffer for different tables
  }

  /// Update today's reservations list
  void _updateTodaysReservations() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    _todaysReservations = _reservations.where((reservation) {
      final reservationDate = DateTime(
        reservation.reservationDate.year,
        reservation.reservationDate.month,
        reservation.reservationDate.day,
      );
      return reservationDate.isAtSameMomentAs(today);
    }).toList();
  }

  /// Get upcoming reservations (next 7 days)
  List<Reservation> getUpcomingReservations() {
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));
    
    return _reservations.where((reservation) {
      return reservation.reservationDate.isAfter(now) &&
             reservation.reservationDate.isBefore(nextWeek) &&
             reservation.status != ReservationStatus.cancelled &&
             reservation.status != ReservationStatus.noShow;
    }).toList();
  }

  /// Get reservations by status
  List<Reservation> getReservationsByStatus(ReservationStatus status) {
    return _reservations.where((r) => r.status == status).toList();
  }

  /// Initialize database tables
  Future<void> initializeDatabase() async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        // Drop existing table if it exists to apply schema changes
        await db.execute('DROP TABLE IF EXISTS reservations');
        
        await db.execute('''
          CREATE TABLE reservations (
            id TEXT PRIMARY KEY,
            customerName TEXT NOT NULL,
            customerPhone TEXT,
            customerEmail TEXT,
            reservationDate TEXT NOT NULL,
            reservationTimeHour INTEGER NOT NULL,
            reservationTimeMinute INTEGER NOT NULL,
            partySize INTEGER NOT NULL,
            tableId TEXT,
            status TEXT NOT NULL DEFAULT 'pending',
            specialRequests TEXT,
            createdAt TEXT NOT NULL,
            createdBy TEXT,
            confirmedAt TEXT,
            arrivedAt TEXT,
            seatedAt TEXT,
            completedAt TEXT,
            notes TEXT
          )
        ''');

        debugPrint('Reservations table initialized successfully');
      }
    } catch (e) {
      debugPrint('Error initializing reservations database: $e');
    }
  }
} 