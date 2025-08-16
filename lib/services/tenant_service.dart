import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/firebase_config.dart';

class Tenant {
  final String id;
  final String name;
  final String restaurantName;
  final String ownerEmail;
  final DateTime createdAt;
  final bool isActive;
  final Map<String, dynamic> settings;

  Tenant({
    required this.id,
    required this.name,
    required this.restaurantName,
    required this.ownerEmail,
    required this.createdAt,
    this.isActive = true,
    this.settings = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'restaurantName': restaurantName,
      'ownerEmail': ownerEmail,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'settings': settings,
    };
  }

  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      restaurantName: json['restaurantName'] ?? '',
      ownerEmail: json['ownerEmail'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      isActive: json['isActive'] ?? true,
      settings: json['settings'] ?? {},
    );
  }

  Tenant copyWith({
    String? id,
    String? name,
    String? restaurantName,
    String? ownerEmail,
    DateTime? createdAt,
    bool? isActive,
    Map<String, dynamic>? settings,
  }) {
    return Tenant(
      id: id ?? this.id,
      name: name ?? this.name,
      restaurantName: restaurantName ?? this.restaurantName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      settings: settings ?? this.settings,
    );
  }
}

class TenantService extends ChangeNotifier {
  static TenantService? _instance;
  static TenantService get instance => _instance ??= TenantService._();
  
  TenantService._();
  
  Tenant? _currentTenant;
  bool _isInitialized = false;

  Tenant? get currentTenant => _currentTenant;
  bool get isInitialized => _isInitialized;

  // Initialize tenant service
  Future<void> initialize() async {
    try {
      // Check if user is authenticated
      final auth = FirebaseConfig.auth;
      if (auth != null) {
        final user = auth.currentUser;
        if (user != null) {
          // Try to get user's tenant
          await _loadUserTenant(user.email!);
        }
      }
      _isInitialized = true;
      print('✅ Tenant Service initialized');
    } catch (e) {
      print('❌ Tenant Service initialization failed: $e');
      rethrow;
    }
  }

  // Load user's tenant
  Future<void> _loadUserTenant(String userEmail) async {
    try {
      final globalUsersCollection = FirebaseConfig.getGlobalCollection('users');
      if (globalUsersCollection == null) {
        print('⚠️ Global users collection not available');
        return;
      }
      
      final userDoc = await globalUsersCollection
          .where('email', isEqualTo: userEmail)
          .get();
      
      if (userDoc.docs.isNotEmpty) {
        final userData = userDoc.docs.first.data() as Map<String, dynamic>?;
        final tenantId = userData?['tenantId'];
        
        if (tenantId != null && tenantId is String) {
          await setCurrentTenant(tenantId);
        }
      }
    } catch (e) {
      print('❌ Error loading user tenant: $e');
    }
  }

  // Get current tenant
  Future<Tenant?> getCurrentTenant() async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null || tenantId.isEmpty) return null;
      
      final doc = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          return Tenant.fromJson(data);
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting current tenant: $e');
      return null;
    }
  }

  // Get all tenants
  Future<List<Tenant>> getTenants() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('tenants')
          .get();
      
      return snapshot.docs
          .map((doc) => Tenant.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error getting tenants: $e');
      return [];
    }
  }

  // Update tenant
  Future<void> updateTenant(Tenant tenant) async {
    try {
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenant.id)
          .update(tenant.toJson());
      
      print('✅ Tenant updated successfully');
    } catch (e) {
      print('❌ Error updating tenant: $e');
      rethrow;
    }
  }

  // Set current tenant
  Future<void> setCurrentTenant(String tenantId) async {
    try {
      // Store the current tenant ID in shared preferences or local storage
      // For now, we'll use a simple approach
      FirebaseConfig.setCurrentTenant(tenantId);
      
      print('✅ Current tenant set to: $tenantId');
    } catch (e) {
      print('❌ Error setting current tenant: $e');
      rethrow;
    }
  }

  // Create new tenant
  Future<String> createTenant(Tenant tenant) async {
    try {
      final tenantsCollection = FirebaseConfig.getGlobalCollection('tenants');
      if (tenantsCollection == null) {
        print('⚠️ Tenants collection not available');
        return '';
      }
      
      final tenantId = tenantsCollection.doc().id;
      tenant = tenant.copyWith(id: tenantId);
      
      await tenantsCollection.doc(tenantId).set(tenant.toJson());
      
      // Add to global users collection
      final globalUsersCollection = FirebaseConfig.getGlobalCollection('users');
      if (globalUsersCollection != null) {
        await globalUsersCollection.add({
          'tenantId': tenantId,
          'email': tenant.ownerEmail,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      
      print('✅ Tenant created successfully: $tenantId');
      return tenantId;
    } catch (e) {
      print('❌ Error creating tenant: $e');
      rethrow;
    }
  }

  // Clear current tenant (for logout)
  void clearCurrentTenant() {
    _currentTenant = null;
    notifyListeners();
    print('✅ Current tenant cleared');
  }
} 