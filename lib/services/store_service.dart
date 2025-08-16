import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:ai_pos_system/models/store.dart';


/// Multi-tenant store management service
class StoreService with ChangeNotifier {
  static const String _storesKey = 'pos_stores';
  static const String _currentStoreKey = 'current_store';
  static const String _storeAuthKey = 'store_auth_';

  Store? _currentStore;
  List<Store> _availableStores = [];
  Map<String, StoreAuth> _storeCredentials = {};
  bool _isInitialized = false;

  // Getters
  Store? get currentStore => _currentStore;
  List<Store> get availableStores => List.unmodifiable(_availableStores);
  bool get isInitialized => _isInitialized;
  bool get hasStores => _availableStores.isNotEmpty;
  bool get isLoggedIn => _currentStore != null;

  /// Initialize the store service and load configurations
  Future<void> initialize() async {
    try {
      debugPrint('🏪 Initializing StoreService...');
      
      await _loadStoresFromStorage();
      await _loadCurrentStore();
      await _loadStoreCredentials();
      
      // Create demo stores if none exist
      // ENABLED: Demo stores creation for registration
      if (_availableStores.isEmpty) {
        await _createDemoStores();
      }
      
      _isInitialized = true;
      debugPrint('✅ StoreService initialized with ${_availableStores.length} stores');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error initializing StoreService: $e');
      rethrow;
    }
  }

  /// Authenticate user for specific store
  Future<bool> authenticateStore({
    required String storeCode,
    required String username,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Authenticating store: $storeCode, user: $username');
      
      // Find store by code
      final store = _availableStores.firstWhere(
        (s) => s.code.toLowerCase() == storeCode.toLowerCase(),
        orElse: () => throw Exception('Store not found: $storeCode'),
      );

      // Validate credentials (in production, this would be against a secure backend)
      final isValid = await _validateCredentials(store.id, username, password);
      
      if (isValid) {
        // Set current store
        await setCurrentStore(store);
        
        // Save credentials for quick login
        await _saveStoreCredentials(StoreAuth(
          storeId: store.id,
          storeCode: store.code,
          username: username,
          password: _hashPassword(password),
          lastLoginAt: DateTime.now(),
        ));
        
        debugPrint('✅ Authentication successful for store: ${store.name}');
        return true;
      } else {
        debugPrint('❌ Authentication failed for store: $storeCode');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Authentication error: $e');
      return false;
    }
  }

  /// Set current active store
  Future<void> setCurrentStore(Store store) async {
    try {
      _currentStore = store;
      
      // Save to storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentStoreKey, jsonEncode(store.toJson()));
      
      debugPrint('🏪 Current store set to: ${store.name} (${store.code})');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error setting current store: $e');
      rethrow;
    }
  }

  /// Logout from current store
  Future<void> logout() async {
    try {
      debugPrint('👋 Logging out from store: ${_currentStore?.name}');
      
      _currentStore = null;
      
      // Clear current store from storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentStoreKey);
      
      debugPrint('✅ Logged out successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error during logout: $e');
    }
  }

  /// Add new store configuration
  Future<void> addStore(Store store) async {
    try {
      // Check for duplicate codes
      final existingStore = _availableStores.where((s) => s.code == store.code);
      if (existingStore.isNotEmpty) {
        throw Exception('Store code already exists: ${store.code}');
      }
      
      _availableStores.add(store);
      await _saveStoresToStorage();
      
      debugPrint('✅ Added new store: ${store.name} (${store.code})');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error adding store: $e');
      rethrow;
    }
  }

  /// Update existing store
  Future<void> updateStore(Store updatedStore) async {
    try {
      final index = _availableStores.indexWhere((s) => s.id == updatedStore.id);
      if (index != -1) {
        _availableStores[index] = updatedStore;
        await _saveStoresToStorage();
        
        // Update current store if it's the one being updated
        if (_currentStore?.id == updatedStore.id) {
          _currentStore = updatedStore;
        }
        
        debugPrint('✅ Updated store: ${updatedStore.name}');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error updating store: $e');
      rethrow;
    }
  }

  /// Remove store
  Future<void> removeStore(String storeId) async {
    try {
      _availableStores.removeWhere((s) => s.id == storeId);
      await _saveStoresToStorage();
      
      // Clear current store if it's the one being removed
      if (_currentStore?.id == storeId) {
        await logout();
      }
      
      debugPrint('✅ Removed store: $storeId');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error removing store: $e');
      rethrow;
    }
  }

  /// Get store by ID
  Store? getStoreById(String storeId) {
    try {
      return _availableStores.firstWhere((s) => s.id == storeId);
    } catch (e) {
      return null;
    }
  }

  /// Get store by code
  Store? getStoreByCode(String storeCode) {
    try {
      return _availableStores.firstWhere(
        (s) => s.code.toLowerCase() == storeCode.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get saved credentials for quick login
  StoreAuth? getSavedCredentials(String storeCode) {
    final store = getStoreByCode(storeCode);
    if (store != null) {
      return _storeCredentials[store.id];
    }
    return null;
  }

  /// Check if user has saved credentials for a store
  bool hasSavedCredentials(String storeCode) {
    return getSavedCredentials(storeCode) != null;
  }

  /// Clear saved credentials for a store
  Future<void> clearSavedCredentials(String storeCode) async {
    try {
      final store = getStoreByCode(storeCode);
      if (store != null) {
        _storeCredentials.remove(store.id);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$_storeAuthKey${store.id}');
        
        debugPrint('✅ Cleared saved credentials for store: $storeCode');
      }
    } catch (e) {
      debugPrint('❌ Error clearing credentials: $e');
    }
  }

  /// Quick login with saved credentials
  Future<bool> quickLogin(String storeCode) async {
    try {
      final credentials = getSavedCredentials(storeCode);
      if (credentials != null) {
        final store = getStoreById(credentials.storeId);
        if (store != null) {
          await setCurrentStore(store);
          debugPrint('✅ Quick login successful for store: $storeCode');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Quick login failed: $e');
      return false;
    }
  }

  /// Get store-specific database path
  String getStoreDatabasePath(String storeId) {
    final store = getStoreById(storeId);
    return store?.databasePath ?? 'stores/$storeId/database.db';
  }

  /// Private Methods

  /// Load stores from local storage
  Future<void> _loadStoresFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storesJson = prefs.getString(_storesKey);
      
      if (storesJson != null) {
        final List<dynamic> storesList = jsonDecode(storesJson);
        _availableStores = storesList
            .map((json) => Store.fromJson(json))
            .toList();
        debugPrint('📂 Loaded ${_availableStores.length} stores from storage');
      }
    } catch (e) {
      debugPrint('⚠️ Error loading stores from storage: $e');
      _availableStores = [];
    }
  }

  /// Save stores to local storage
  Future<void> _saveStoresToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storesJson = jsonEncode(
        _availableStores.map((store) => store.toJson()).toList(),
      );
      await prefs.setString(_storesKey, storesJson);
      debugPrint('💾 Saved ${_availableStores.length} stores to storage');
    } catch (e) {
      debugPrint('❌ Error saving stores to storage: $e');
    }
  }

  /// Load current store from storage
  Future<void> _loadCurrentStore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentStoreJson = prefs.getString(_currentStoreKey);
      
      if (currentStoreJson != null) {
        final storeData = jsonDecode(currentStoreJson);
        _currentStore = Store.fromJson(storeData);
        debugPrint('📂 Loaded current store: ${_currentStore?.name}');
      }
    } catch (e) {
      debugPrint('⚠️ Error loading current store: $e');
      _currentStore = null;
    }
  }

  /// Load store credentials from storage
  Future<void> _loadStoreCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      for (final store in _availableStores) {
        final credentialsJson = prefs.getString('$_storeAuthKey${store.id}');
        if (credentialsJson != null) {
          final credentials = StoreAuth.fromJson(jsonDecode(credentialsJson));
          _storeCredentials[store.id] = credentials;
        }
      }
      
      debugPrint('🔑 Loaded credentials for ${_storeCredentials.length} stores');
    } catch (e) {
      debugPrint('⚠️ Error loading store credentials: $e');
    }
  }

  /// Save store credentials
  Future<void> _saveStoreCredentials(StoreAuth credentials) async {
    try {
      _storeCredentials[credentials.storeId] = credentials;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_storeAuthKey${credentials.storeId}',
        jsonEncode(credentials.toJson()),
      );
      
      debugPrint('💾 Saved credentials for store: ${credentials.storeCode}');
    } catch (e) {
      debugPrint('❌ Error saving credentials: $e');
    }
  }

  /// Validate user credentials (simplified for demo)
  Future<bool> _validateCredentials(String storeId, String username, String password) async {
    // In production, this would validate against a secure backend
    // For demo purposes, accept any username/password combination
    return username.isNotEmpty && password.isNotEmpty;
  }

  /// Hash password for storage
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Create demo stores for testing
  Future<void> _createDemoStores() async {
    try {
      debugPrint('🏪 Creating demo stores...');
      
      final demoStores = [
        _createDemoStore('REST001', 'Downtown Restaurant', '123 Main St, Toronto, ON'),
        _createDemoStore('REST002', 'Uptown Bistro', '456 King St, Toronto, ON'),
        _createDemoStore('REST003', 'Waterfront Grill', '789 Lake Shore Blvd, Toronto, ON'),
        _createDemoStore('REST004', 'Midtown Cafe', '321 Yonge St, Toronto, ON'),
        _createDemoStore('REST005', 'Eastside Kitchen', '654 Queen St E, Toronto, ON'),
        _createDemoStore('REST006', 'Westend Dining', '987 Bloor St W, Toronto, ON'),
        _createDemoStore('REST007', 'Northside Eatery', '147 Eglinton Ave N, Toronto, ON'),
        _createDemoStore('REST008', 'Southpoint Restaurant', '258 Lakeshore Blvd S, Toronto, ON'),
        _createDemoStore('REST009', 'Central Kitchen', '369 College St, Toronto, ON'),
        _createDemoStore('REST010', 'Harbor View Restaurant', '741 Harbourfront, Toronto, ON'),
      ];
      
      _availableStores.addAll(demoStores);
      await _saveStoresToStorage();
      
      debugPrint('✅ Created ${demoStores.length} demo stores');
    } catch (e) {
      debugPrint('❌ Error creating demo stores: $e');
    }
  }

  /// Create a single demo store
  Store _createDemoStore(String code, String name, String address) {
    final now = DateTime.now();
    return Store(
      id: 'store_${code.toLowerCase()}',
      name: name,
      code: code,
      address: address,
      phone: '+1 (416) 555-${code.substring(4)}',
      email: '${code.toLowerCase()}@restaurant.com',
      databasePath: 'stores/${code.toLowerCase()}/database.db',
      settings: StoreSettings(),
      branding: StoreBranding(),
      createdAt: now,
      updatedAt: now,
    );
  }
} 