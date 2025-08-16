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
      print('✅ Firebase already initialized');
      return;
    }
    
    try {
      print('🔥 Starting bulletproof Firebase initialization...');
      
      // Check if Firebase is already initialized
      if (Firebase.apps.isNotEmpty) {
        print('✅ Firebase already initialized by main.dart');
        _isInitialized = true;
        _initializeServices();
        return;
      }
      
      print('🔧 Initializing Firebase with default options...');
      
      // Initialize Firebase with default options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      print('✅ Firebase core initialized successfully');
      
      // Initialize services
      _initializeServices();
      
      // CRITICAL FIX: Ensure anonymous authentication for POS operations
      await _ensureAnonymousAuthentication();
      
      _isInitialized = true;
      _lastError = null;
      print('✅ Firebase initialization completed successfully');
      
    } catch (e) {
      _lastError = e.toString();
      print('❌ Firebase initialization failed: $e');
      print('📱 App will continue in offline mode');
      
      // Don't rethrow - allow app to continue in offline mode
      _isInitialized = false;
    }
  }
  
  static void _initializeServices() {
    try {
      print('🔧 Initializing Firebase services...');
      
      // Initialize Firestore
      _firestore = FirebaseFirestore.instance;
      print('✅ Firestore initialized');
      
      // Enable offline persistence
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      print('✅ Firestore settings configured');
      
      // Initialize Auth
      _auth = FirebaseAuth.instance;
      print('✅ Firebase Auth initialized');
      
      // Initialize Storage
      _storage = FirebaseStorage.instance;
      print('✅ Firebase Storage initialized');
      
      // ENABLE FIREBASE EMULATOR FOR TESTING
      _enableEmulatorForTesting();
      
    } catch (e) {
      print('❌ Error initializing Firebase services: $e');
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
      
      print('✅ Firebase production mode enabled');
      print('📍 Firestore: Production (dineai-pos-system)');
      print('📍 Auth: Production (dineai-pos-system)');
      print('📍 Storage: Production (dineai-pos-system)');
    } catch (e) {
      print('⚠️ Failed to configure Firebase: $e');
      print('📱 Continuing with production Firebase');
    }
  }
  
  /// CRITICAL FIX: Ensure anonymous authentication for POS operations
  static Future<void> _ensureAnonymousAuthentication() async {
    try {
      if (_auth == null) {
        print('⚠️ Firebase Auth not available for anonymous authentication');
        return;
      }
      
      // Check if user is already signed in
      if (_auth!.currentUser != null) {
        print('✅ User already authenticated: ${_auth!.currentUser!.uid}');
        _isAnonymousAuthenticated = true;
        return;
      }
      
      // Sign in anonymously
      print('🔐 Signing in anonymously...');
      final userCredential = await _auth!.signInAnonymously();
      
      if (userCredential.user != null) {
        print('✅ Anonymous authentication successful: ${userCredential.user!.uid}');
        _isAnonymousAuthenticated = true;
      } else {
        print('❌ Anonymous authentication failed - no user returned');
        _isAnonymousAuthenticated = false;
      }
      
    } catch (e) {
      print('❌ Anonymous authentication failed: $e');
      _isAnonymousAuthenticated = false;
      
      // Don't rethrow - app can work in offline mode
      print('📱 App will continue in offline mode without Firebase authentication');
    }
  }
  
  /// Set current tenant ID for Firebase operations
  static void setCurrentTenantId(String tenantId) {
    _currentTenantId = tenantId;
    print('🏪 Set current tenant ID: $tenantId');
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
    print('✅ Current tenant set to: $tenantId');
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
      print('⚠️ Firebase or tenant ID not available');
      return null;
    }
    
    return _firestore!.collection('tenants').doc(_currentTenantId).collection(collection).doc(documentId);
  }
  
  /// Get tenant-specific collection reference
  static CollectionReference? getTenantCollection(String collection) {
    if (_firestore == null || _currentTenantId == null) {
      print('⚠️ Firebase or tenant ID not available');
      return null;
    }
    
    return _firestore!.collection('tenants').doc(_currentTenantId).collection(collection);
  }
  
  /// Get global document reference (not tenant-specific)
  static DocumentReference? getGlobalDocument(String collection, String documentId) {
    if (_firestore == null) {
      print('⚠️ Firebase not available');
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
        print('✅ User signed out successfully');
      }
    } catch (e) {
      print('❌ Failed to sign out: $e');
    }
  }
  
  /// Re-authenticate anonymously (useful for token refresh)
  static Future<bool> reAuthenticateAnonymously() async {
    try {
      print('🔄 Re-authenticating anonymously...');
      
      if (_auth == null) {
        print('⚠️ Firebase Auth not available');
        return false;
      }
      
      // Sign out first
      await _auth!.signOut();
      
      // Sign in again
      final userCredential = await _auth!.signInAnonymously();
      
      if (userCredential.user != null) {
        print('✅ Re-authentication successful: ${userCredential.user!.uid}');
        _isAnonymousAuthenticated = true;
        return true;
      } else {
        print('❌ Re-authentication failed - no user returned');
        _isAnonymousAuthenticated = false;
        return false;
      }
      
    } catch (e) {
      print('❌ Re-authentication failed: $e');
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