import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../firebase_options.dart';

class FirebaseConfig {
  static FirebaseFirestore? _firestore;
  static FirebaseAuth? _auth;
  static FirebaseStorage? _storage;
  static String? _currentTenantId;
  static bool _isInitialized = false;
  static String? _lastError;
  static bool _isAnonymousAuthenticated = false;
  
  // Initialize Firebase with bulletproof error handling
  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    
    try {
      
      // Check if Firebase is already initialized
      if (Firebase.apps.isNotEmpty) {
        _isInitialized = true;
        _initializeServices();
        return;
      }
      
      
      // Initialize Firebase with default options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      
      // Initialize services
      _initializeServices();
      
      // CRITICAL FIX: Ensure anonymous authentication for POS operations
      await _ensureAnonymousAuthentication();
      
      _isInitialized = true;
      _lastError = null;
      
    } catch (e) {
      _lastError = e.toString();
      
      // Don't rethrow - allow app to continue in offline mode
      _isInitialized = false;
    }
  }
  
  static void _initializeServices() {
    try {
      
      // Initialize Firestore
      _firestore = FirebaseFirestore.instance;
      
      // Enable offline persistence
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      // Initialize Auth
      _auth = FirebaseAuth.instance;
      
      // Initialize Storage
      _storage = FirebaseStorage.instance;
      
      // ENABLE FIREBASE EMULATOR FOR TESTING
      _enableEmulatorForTesting();
      
    } catch (e) {
      _lastError = e.toString();
    }
  }
  
  /// Enable Firebase emulator for testing
  static void _enableEmulatorForTesting() {
    try {
      // DISABLED: Use Firebase emulator for testing (localhost)
      // _firestore?.useFirestoreEmulator('127.0.0.1', 8080);
      // _auth?.useAuthEmulator('127.0.0.1', 9099);
      // _storage?.useStorageEmulator('127.0.0.1', 9199);
      
    } catch (e) {
    }
  }
  
  /// CRITICAL FIX: Ensure anonymous authentication for POS operations
  static Future<void> _ensureAnonymousAuthentication() async {
    try {
      if (_auth == null) {
        return;
      }
      
      // Check if user is already signed in
      if (_auth!.currentUser != null) {
        _isAnonymousAuthenticated = true;
        return;
      }
      
      // Sign in anonymously
      final userCredential = await _auth!.signInAnonymously();
      
      if (userCredential.user != null) {
        _isAnonymousAuthenticated = true;
      } else {
        _isAnonymousAuthenticated = false;
      }
      
    } catch (e) {
      _isAnonymousAuthenticated = false;
      
      // Don't rethrow - app can work in offline mode
    }
  }
  
  /// Set current tenant ID for Firebase operations
  static void setCurrentTenantId(String tenantId) {
    _currentTenantId = tenantId;
  }
  
  /// Get current tenant ID
  static String? getCurrentTenantId() => _currentTenantId;
  
  /// Get users collection for current tenant
  static CollectionReference? get usersCollection {
    if (_firestore == null || _currentTenantId == null) return null;
    return _firestore!.collection('tenants').doc(_currentTenantId).collection('users');
  }
  
  /// Get global collection (for tenant management)
  static CollectionReference? getGlobalCollection(String collectionName) {
    if (_firestore == null) return null;
    return _firestore!.collection(collectionName);
  }
  
  /// Set current tenant ID
  static void setCurrentTenant(String tenantId) {
    _currentTenantId = tenantId;
  }
  
  /// Get Firestore instance
  static FirebaseFirestore? get firestore => _firestore;
  
  /// Get Auth instance
  static FirebaseAuth? get auth => _auth;
  
  /// Get Storage instance
  static FirebaseStorage? get storage => _storage;
  
  /// Check if Firebase is initialized
  static bool get isInitialized => _isInitialized;
  
  /// Check if anonymous authentication is successful
  static bool get isAnonymousAuthenticated => _isAnonymousAuthenticated;
  
  /// Get last error
  static String? get lastError => _lastError;
  
  /// Get tenant-specific Firestore reference
  static DocumentReference? getTenantDocument(String collection, String documentId) {
    if (_firestore == null || _currentTenantId == null) {
      return null;
    }
    
    return _firestore!.collection('tenants').doc(_currentTenantId).collection(collection).doc(documentId);
  }
  
  /// Get tenant-specific collection reference
  static CollectionReference? getTenantCollection(String collection) {
    if (_firestore == null || _currentTenantId == null) {
      return null;
    }
    
    return _firestore!.collection('tenants').doc(_currentTenantId).collection(collection);
  }
  
  /// Get global document reference (not tenant-specific)
  static DocumentReference? getGlobalDocument(String collection, String documentId) {
    if (_firestore == null) {
      return null;
    }
    
    return _firestore!.collection(collection).doc(documentId);
  }
  
  /// Check if user is authenticated (anonymous or otherwise)
  static bool isUserAuthenticated() {
    return _auth?.currentUser != null;
  }
  
  /// Get current user ID
  static String? getCurrentUserId() {
    return _auth?.currentUser?.uid;
  }
  
  /// Sign out current user
  static Future<void> signOut() async {
    try {
      if (_auth != null) {
        await _auth!.signOut();
        _isAnonymousAuthenticated = false;
      }
    } catch (e) {
    }
  }
  
  /// Re-authenticate anonymously (useful for token refresh)
  static Future<bool> reAuthenticateAnonymously() async {
    try {
      
      if (_auth == null) {
        return false;
      }
      
      // Sign out first
      await _auth!.signOut();
      
      // Sign in again
      final userCredential = await _auth!.signInAnonymously();
      
      if (userCredential.user != null) {
        _isAnonymousAuthenticated = true;
        return true;
      } else {
        _isAnonymousAuthenticated = false;
        return false;
      }
      
    } catch (e) {
      _isAnonymousAuthenticated = false;
      return false;
    }
  }
  
  /// Get authentication status summary
  static Map<String, dynamic> getAuthStatus() {
    return {
      'isInitialized': _isInitialized,
      'isAnonymousAuthenticated': _isAnonymousAuthenticated,
      'currentUserId': _auth?.currentUser?.uid,
      'currentTenantId': _currentTenantId,
      'lastError': _lastError,
      'firestoreAvailable': _firestore != null,
      'authAvailable': _auth != null,
      'storageAvailable': _storage != null,
    };
  }
} 