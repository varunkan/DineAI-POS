import 'dart:core';

/// Validation result class
class ValidationResult {
  final bool isValid;
  final String message;

  ValidationResult(this.isValid, this.message);

  @override
  String toString() {
    return 'ValidationResult(isValid: $isValid, message: $message)';
  }
}

/// Comprehensive validation utilities for the POS system
class ValidationUtils {
  // Business Types
  static const List<String> validBusinessTypes = [
    'Restaurant',
    'Cafe',
    'Bar',
    'Pizzeria',
    'Bakery',
    'Food Truck',
    'Catering',
    'Fast Food',
    'Fine Dining',
    'Casual Dining',
    'Pub',
    'Bistro',
    'Diner',
    'Food Court',
    'Takeout',
    'Delivery',
    'Buffet',
    'Steakhouse',
    'Seafood',
    'Asian',
    'Italian',
    'Mexican',
    'Indian',
    'Chinese',
    'Japanese',
    'Thai',
    'Mediterranean',
    'American',
    'European',
    'Fusion',
    'Vegan',
    'Vegetarian',
    'Gluten-Free',
    'Kosher',
    'Halal',
    'Other'
  ];

  // Email validation pattern - simplified
  static final RegExp emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
  );

  /// Validate business type
  static ValidationResult validateBusinessType(String businessType) {
    if (businessType.isEmpty) {
      return ValidationResult(false, 'Business type is required');
    }
    
    if (!validBusinessTypes.contains(businessType)) {
      return ValidationResult(false, 'Invalid business type. Please select from the available options.');
    }
    
    return ValidationResult(true, 'Valid business type');
  }

  /// Validate email format
  static ValidationResult validateEmail(String email) {
    if (email.isEmpty) {
      return ValidationResult(false, 'Email is required');
    }
    
    if (!emailPattern.hasMatch(email)) {
      return ValidationResult(false, 'Please enter a valid email address');
    }
    
    return ValidationResult(true, 'Valid email address');
  }

  /// Validate and format phone number
  static ValidationResult validatePhone(String phone, {String countryCode = 'US'}) {
    if (phone.isEmpty) {
      return ValidationResult(false, 'Phone number is required');
    }
    
    // Simple phone validation
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.length < 10) {
      return ValidationResult(false, 'Please enter a valid phone number');
    }
    
    return ValidationResult(true, 'Valid phone number');
  }

  /// Validate address components
  static ValidationResult validateAddress({
    required String street,
    required String city,
    required String state,
    required String postalCode,
    String? country = 'US',
  }) {
    if (street.isEmpty) {
      return ValidationResult(false, 'Street address is required');
    }
    
    if (city.isEmpty) {
      return ValidationResult(false, 'City is required');
    }
    
    if (state.isEmpty) {
      return ValidationResult(false, 'State/Province is required');
    }
    
    if (postalCode.isEmpty) {
      return ValidationResult(false, 'Postal code is required');
    }
    
    return ValidationResult(true, 'Valid address');
  }

  /// Validate restaurant name
  static ValidationResult validateRestaurantName(String name) {
    if (name.isEmpty) {
      return ValidationResult(false, 'Restaurant name is required');
    }
    
    if (name.length < 2) {
      return ValidationResult(false, 'Restaurant name must be at least 2 characters long');
    }
    
    if (name.length > 100) {
      return ValidationResult(false, 'Restaurant name must be less than 100 characters');
    }
    
    return ValidationResult(true, 'Valid restaurant name');
  }

  /// Validate admin user ID
  static ValidationResult validateAdminUserId(String adminUserId) {
    if (adminUserId.isEmpty) {
      return ValidationResult(false, 'Admin user ID is required');
    }
    
    if (adminUserId.length < 3) {
      return ValidationResult(false, 'Admin user ID must be at least 3 characters long');
    }
    
    if (adminUserId.length > 50) {
      return ValidationResult(false, 'Admin user ID must be less than 50 characters');
    }
    
    return ValidationResult(true, 'Valid admin user ID');
  }

  /// Validate password strength
  static ValidationResult validatePassword(String password) {
    if (password.isEmpty) {
      return ValidationResult(false, 'Password is required');
    }
    
    if (password.length < 8) {
      return ValidationResult(false, 'Password must be at least 8 characters long');
    }
    
    if (password.length > 128) {
      return ValidationResult(false, 'Password must be less than 128 characters');
    }
    
    return ValidationResult(true, 'Strong password');
  }

  /// Get password strength score (0-100)
  static int getPasswordStrength(String password) {
    int score = 0;
    
    if (password.length >= 8) score += 20;
    if (password.length >= 12) score += 10;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 20;
    if (RegExp(r'[a-z]').hasMatch(password)) score += 20;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 20;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score += 10;
    
    return score;
  }

  /// Get password strength description
  static String getPasswordStrengthDescription(int score) {
    if (score >= 90) return 'Very Strong';
    if (score >= 80) return 'Strong';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    if (score >= 20) return 'Weak';
    return 'Very Weak';
  }

  /// Validate complete restaurant data
  static Map<String, ValidationResult> validateRestaurantData({
    required String name,
    required String businessType,
    required String email,
    required String phone,
    required String address,
    required String adminUserId,
    required String adminPassword,
    String countryCode = 'US',
  }) {
    return {
      'name': validateRestaurantName(name),
      'businessType': validateBusinessType(businessType),
      'email': validateEmail(email),
      'phone': validatePhone(phone, countryCode: countryCode),
      'address': validateSimpleAddress(address),
      'adminUserId': validateAdminUserId(adminUserId),
      'adminPassword': validatePassword(adminPassword),
    };
  }

  /// Validate simple address (single field)
  static ValidationResult validateSimpleAddress(String address) {
    if (address.isEmpty) {
      return ValidationResult(false, 'Address is required');
    }
    
    if (address.length < 5) {
      return ValidationResult(false, 'Address must be at least 5 characters long');
    }
    
    if (address.length > 200) {
      return ValidationResult(false, 'Address must be less than 200 characters');
    }
    
    return ValidationResult(true, 'Valid address');
  }

  /// Check if all validations passed
  static bool allValidationsPassed(Map<String, ValidationResult> validations) {
    return validations.values.every((result) => result.isValid);
  }

  /// Get all validation errors
  static List<String> getValidationErrors(Map<String, ValidationResult> validations) {
    return validations.values
        .where((result) => !result.isValid)
        .map((result) => result.message)
        .toList();
  }
} 