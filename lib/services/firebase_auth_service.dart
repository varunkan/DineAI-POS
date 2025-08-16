import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/firebase_config.dart';
import '../models/user.dart' as app_user;

class FirebaseAuthService extends ChangeNotifier {
  static FirebaseAuthService? _instance;
  static FirebaseAuthService get instance => _instance ??= FirebaseAuthService._();
  
  FirebaseAuthService._();
  
  firebase_auth.User? _currentUser;
  app_user.User? _userProfile;
  bool _isLoading = false;
  
  // Getters
  firebase_auth.User? get currentUser => _currentUser;
  app_user.User? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  
  // Initialize auth service
  Future<void> initialize() async {
    try {
      // Check if Firebase is initialized
      if (!FirebaseConfig.isInitialized) {
        print('⚠️ Firebase not initialized - auth service will be limited');
        return;
      }
      
      // Listen to auth state changes
      FirebaseConfig.auth?.authStateChanges().listen(_onAuthStateChanged);
      
      // Get current user if already signed in
      _currentUser = FirebaseConfig.auth?.currentUser;
      if (_currentUser != null) {
        await _loadUserProfile();
      }
      
      print('✅ Firebase Auth Service initialized');
    } catch (e) {
      print('❌ Firebase Auth Service initialization failed: $e');
      // Don't rethrow - allow app to continue in offline mode
    }
  }
  
  // Handle authentication state changes
  void _onAuthStateChanged(firebase_auth.User? user) {
    _currentUser = user;
    if (user != null) {
      _loadUserProfile();
    } else {
      _userProfile = null;
    }
    notifyListeners();
  }
  
  // Load user profile from Firestore
  Future<void> _loadUserProfile() async {
    try {
      if (_currentUser == null) return;
      
      final usersCollection = FirebaseConfig.usersCollection;
      if (usersCollection == null) {
        print('⚠️ Users collection not available');
        return;
      }
      
      final doc = await usersCollection.doc(_currentUser!.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data is Map<String, dynamic>) {
          _userProfile = app_user.User.fromJson(data);
        }
      }
    } catch (e) {
      print('❌ Error loading user profile: $e');
    }
  }
  
  // Save user profile to Firestore
  Future<void> saveUserProfile() async {
    try {
      if (_userProfile == null) return;
      
      final usersCollection = FirebaseConfig.usersCollection;
      if (usersCollection == null) {
        print('⚠️ Users collection not available');
        return;
      }
      
      await usersCollection.doc(_userProfile!.id).set(_userProfile!.toJson());
    } catch (e) {
      print('❌ Error saving user profile: $e');
    }
  }
  
  // Sign in with email and password
  Future<firebase_auth.UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final auth = FirebaseConfig.auth;
      if (auth == null) {
        throw Exception('Firebase Auth not available');
      }
      
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _currentUser = credential.user;
      await _loadUserProfile();
      
      return credential;
    } catch (e) {
      print('❌ Error signing in: $e');
      rethrow;
    }
  }
  
  // Sign up with email and password
  Future<firebase_auth.UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final auth = FirebaseConfig.auth;
      if (auth == null) {
        throw Exception('Firebase Auth not available');
      }
      
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _currentUser = credential.user;
      await saveUserProfile();
      
      return credential;
    } catch (e) {
      print('❌ Error creating user: $e');
      rethrow;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      final auth = FirebaseConfig.auth;
      if (auth != null) {
        await auth.signOut();
      }
      _currentUser = null;
      _userProfile = null;
      notifyListeners();
    } catch (e) {
      print('❌ Error signing out: $e');
    }
  }
  
  // Update user profile
  Future<void> updateUserProfile(app_user.User user) async {
    try {
      _userProfile = user;
      await saveUserProfile();
      notifyListeners();
    } catch (e) {
      print('❌ Error updating user profile: $e');
    }
  }
  
  // Get user by ID
  Future<app_user.User?> getUserById(String userId) async {
    try {
      final usersCollection = FirebaseConfig.usersCollection;
      if (usersCollection == null) {
        print('⚠️ Users collection not available');
        return null;
      }
      
      final doc = await usersCollection.doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data is Map<String, dynamic>) {
          return app_user.User.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting user: $e');
      return null;
    }
  }
  
  // Get all users
  Future<List<app_user.User>> getAllUsers() async {
    try {
      final usersCollection = FirebaseConfig.usersCollection;
      if (usersCollection == null) {
        print('⚠️ Users collection not available');
        return [];
      }
      
      final snapshot = await usersCollection.get();
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            if (data != null && data is Map<String, dynamic>) {
              return app_user.User.fromJson(data);
            }
            return null;
          })
          .where((user) => user != null)
          .cast<app_user.User>()
          .toList();
    } catch (e) {
      print('❌ Error getting users: $e');
      return [];
    }
  }
  
  // Get users by restaurant ID
  Future<List<app_user.User>> getUsersByRestaurantId(String restaurantId) async {
    try {
      final usersCollection = FirebaseConfig.usersCollection;
      if (usersCollection == null) {
        print('⚠️ Users collection not available');
        return [];
      }
      
      final snapshot = await usersCollection
          .where('restaurant_id', isEqualTo: restaurantId)
          .get();
      
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            if (data != null && data is Map<String, dynamic>) {
              return app_user.User.fromJson(data);
            }
            return null;
          })
          .where((user) => user != null)
          .cast<app_user.User>()
          .toList();
    } catch (e) {
      print('❌ Error getting users by restaurant: $e');
      return [];
    }
  }
  
  // Save user to Firestore
  Future<void> saveUser(app_user.User user) async {
    try {
      final usersCollection = FirebaseConfig.usersCollection;
      if (usersCollection == null) {
        print('⚠️ Users collection not available');
        return;
      }
      
      await usersCollection.doc(user.id).set(user.toJson());
    } catch (e) {
      print('❌ Error saving user: $e');
    }
  }
  
  // Create user
  Future<bool> createUser(app_user.User user) async {
    try {
      final usersCollection = FirebaseConfig.usersCollection;
      if (usersCollection == null) {
        print('⚠️ Users collection not available');
        return false;
      }
      
      await usersCollection.doc(user.id).set(user.toJson());
      print('✅ User created successfully');
      return true;
    } catch (e) {
      print('❌ Error creating user: $e');
      return false;
    }
  }
  
  // Create user with PIN
  Future<void> createUserWithPin(String name, String pin, app_user.UserRole role, {bool adminAccess = false}) async {
    try {
      final usersCollection = FirebaseConfig.usersCollection;
      if (usersCollection == null) {
        print('⚠️ Users collection not available');
        return;
      }
      
      final user = app_user.User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        role: role,
        pin: pin,
        adminPanelAccess: adminAccess,
      );
      
      await usersCollection.doc(user.id).set(user.toJson());
      print('✅ User created successfully');
    } catch (e) {
      print('❌ Create user failed: $e');
      rethrow;
    }
  }
  
  // Sign in with PIN
  Future<app_user.User?> signInWithPin(String userId, String pin) async {
    try {
      final user = await getUserById(userId);
      if (user != null && user.pin == pin && user.isActive) {
        _userProfile = user.copyWith(lastLogin: DateTime.now());
        await saveUserProfile();
        notifyListeners();
        print('✅ PIN sign in successful');
        return user;
      }
      return null;
    } catch (e) {
      print('❌ PIN sign in failed: $e');
      return null;
    }
  }
  
  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
} 