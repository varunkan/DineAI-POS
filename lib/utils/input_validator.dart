import 'dart:convert';

/// Comprehensive input validation utility for security
/// Prevents XSS, SQL injection, and data corruption attacks
class InputValidator {
  // Email validation regex (RFC 5322 compliant)
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
  );

  // Strong password regex (at least 8 chars, uppercase, lowercase, number, special char)
  static final RegExp _strongPasswordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$'
  );

  // Restaurant name regex (alphanumeric, spaces, common punctuation)
  static final RegExp _restaurantNameRegex = RegExp(
    r'^[a-zA-Z0-9\s\-\.\,\&\(\)]+$'
  );

  // Phone number regex (international format)
  static final RegExp _phoneRegex = RegExp(
    r'^\+?[1-9]\d{1,14}$'
  );

  // SQL injection patterns to detect
  static final List<String> _sqlInjectionPatterns = [
    r'(\bselect\b|\binsert\b|\bupdate\b|\bdelete\b|\bdrop\b|\bcreate\b|\balter\b)',
    r'(\bunion\b|\band\b|\bor\b|\bwhere\b)',
    r"[\'\"";]",
    r'--',
    r'/\*',
    r'\*/',
    r'@@',
    r'char\(',
    r'nchar\(',
    r'varchar\(',
    r'nvarchar\(',
    r'alter\(',
    r'begin\(',
    r'cast\(',
    r'create\(',
    r'cursor\(',
    r'declare\(',
    r'delete\(',
    r'drop\(',
    r'end\(',
    r'exec\(',
    r'execute\(',
    r'fetch\(',
    r'insert\(',
    r'kill\(',
    r'open\(',
    r'select\(',
    r'sys\(',
    r'sysobjects\(',
    r'syscolumns\(',
    r'table\(',
    r'update\('
  ];

  // XSS patterns to detect
  static final List<String> _xssPatterns = [
    r'<script',
    r'</script>',
    r'<iframe',
    r'</iframe>',
    r'javascript:',
    r'onload=',
    r'onerror=',
    r'onclick=',
    r'onmouseover=',
    r'<img[^>]*src[^>]*>',
    r'<object',
    r'<embed',
    r'<link',
    r'<meta',
    r'<style',
    r'</style>',
    r'expression\(',
    r'vbscript:',
    r'data:text/html',
    r'data:text/javascript'
  ];

  /// Validate email address
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }

    // Check length limits
    if (email.length > 254) {
      return 'Email is too long (max 254 characters)';
    }

    // Check for dangerous patterns
    if (_containsDangerousPatterns(email)) {
      return 'Email contains invalid characters';
    }

    // Validate format
    if (!_emailRegex.hasMatch(email)) {
      return 'Invalid email format';
    }

    return null;
  }

  /// Validate password strength
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    // Check length limits
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (password.length > 128) {
      return 'Password is too long (max 128 characters)';
    }

    // Check for dangerous patterns
    if (_containsDangerousPatterns(password)) {
      return 'Password contains invalid characters';
    }

    // Check strength requirements
    if (!_strongPasswordRegex.hasMatch(password)) {
      return 'Password must contain uppercase, lowercase, number, and special character';
    }

    // Check for common weak passwords
    if (_isCommonPassword(password)) {
      return 'Password is too common, please choose a stronger password';
    }

    return null;
  }

  /// Validate restaurant name
  static String? validateRestaurantName(String? name) {
    if (name == null || name.isEmpty) {
      return 'Restaurant name is required';
    }

    // Check length limits
    if (name.length < 2) {
      return 'Restaurant name must be at least 2 characters';
    }

    if (name.length > 100) {
      return 'Restaurant name is too long (max 100 characters)';
    }

    // Check for dangerous patterns
    if (_containsDangerousPatterns(name)) {
      return 'Restaurant name contains invalid characters';
    }

    // Validate characters
    if (!_restaurantNameRegex.hasMatch(name)) {
      return 'Restaurant name can only contain letters, numbers, spaces, and common punctuation';
    }

    // Check for excessive whitespace
    if (name.trim() != name || name.contains(RegExp(r'\s{2,}'))) {
      return 'Restaurant name has invalid spacing';
    }

    return null;
  }

  /// Validate admin name
  static String? validateAdminName(String? name) {
    if (name == null || name.isEmpty) {
      return 'Admin name is required';
    }

    // Check length limits
    if (name.length < 2) {
      return 'Admin name must be at least 2 characters';
    }

    if (name.length > 50) {
      return 'Admin name is too long (max 50 characters)';
    }

    // Check for dangerous patterns
    if (_containsDangerousPatterns(name)) {
      return 'Admin name contains invalid characters';
    }

    // Validate characters (letters, spaces, hyphens, apostrophes)
    if (!RegExp(r"^[a-zA-Z\s\-\']+$").hasMatch(name)) {
      return 'Admin name can only contain letters, spaces, hyphens, and apostrophes';
    }

    // Check for excessive whitespace
    if (name.trim() != name || name.contains(RegExp(r'\s{2,}'))) {
      return 'Admin name has invalid spacing';
    }

    return null;
  }

  /// Validate phone number
  static String? validatePhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) {
      return null; // Phone is optional
    }

    // Remove common formatting characters
    final cleanedPhone = phone.replaceAll(RegExp(r'[\s\-\(\)\.]+'), '');

    // Check for dangerous patterns
    if (_containsDangerousPatterns(cleanedPhone)) {
      return 'Phone number contains invalid characters';
    }

    // Validate format
    if (!_phoneRegex.hasMatch(cleanedPhone)) {
      return 'Invalid phone number format';
    }

    return null;
  }

  /// Validate PIN (4-6 digits)
  static String? validatePIN(String? pin) {
    if (pin == null || pin.isEmpty) {
      return 'PIN is required';
    }

    // Check length
    if (pin.length < 4 || pin.length > 6) {
      return 'PIN must be 4-6 digits';
    }

    // Check for digits only
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      return 'PIN must contain only digits';
    }

    // Check for weak PINs
    if (_isWeakPIN(pin)) {
      return 'PIN is too weak (avoid sequences like 1234 or repeated digits)';
    }

    return null;
  }

  /// Sanitize string input for safe storage and display
  static String sanitizeString(String input) {
    // Remove null bytes
    String sanitized = input.replaceAll('\x00', '');

    // Escape HTML entities
    sanitized = sanitized
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');

    // Remove control characters except tab, newline, carriage return
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    return sanitized.trim();
  }

  /// Check if string contains SQL injection patterns
  static bool containsSQLInjection(String input) {
    final lowerInput = input.toLowerCase();
    
    for (final pattern in _sqlInjectionPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerInput)) {
        return true;
      }
    }
    
    return false;
  }

  /// Check if string contains XSS patterns
  static bool containsXSS(String input) {
    final lowerInput = input.toLowerCase();
    
    for (final pattern in _xssPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerInput)) {
        return true;
      }
    }
    
    return false;
  }

  /// Check if input contains dangerous patterns
  static bool _containsDangerousPatterns(String input) {
    return containsSQLInjection(input) || containsXSS(input);
  }

  /// Check if password is commonly used (weak)
  static bool _isCommonPassword(String password) {
    final commonPasswords = [
      'password', 'password123', '12345678', 'qwerty', 'abc123',
      'password1', '123456789', 'welcome', 'admin', 'letmein',
      'monkey', '1234567890', 'dragon', 'master', 'hello',
      'freedom', 'whatever', 'qazwsx', 'trustno1', 'hunter2'
    ];
    
    return commonPasswords.contains(password.toLowerCase());
  }

  /// Check if PIN is weak (sequences, repeated digits)
  static bool _isWeakPIN(String pin) {
    // Check for repeated digits
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) {
      return true;
    }

    // Check for ascending sequences
    bool isAscending = true;
    bool isDescending = true;
    
    for (int i = 1; i < pin.length; i++) {
      int current = int.parse(pin[i]);
      int previous = int.parse(pin[i - 1]);
      
      if (current != previous + 1) {
        isAscending = false;
      }
      
      if (current != previous - 1) {
        isDescending = false;
      }
    }
    
    return isAscending || isDescending;
  }

  /// Validate business type
  static String? validateBusinessType(String? type) {
    if (type == null || type.isEmpty) {
      return 'Business type is required';
    }

    final validTypes = [
      'Restaurant', 'Cafe', 'Bar', 'Fast Food', 'Fine Dining',
      'Bakery', 'Pizza', 'Asian', 'Mexican', 'Italian',
      'American', 'Food Truck', 'Catering', 'Other'
    ];

    if (!validTypes.contains(type)) {
      return 'Invalid business type';
    }

    return null;
  }

  /// Validate JSON input for API endpoints
  static String? validateJSON(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      return 'JSON data is required';
    }

    try {
      json.decode(jsonString);
      return null;
    } catch (e) {
      return 'Invalid JSON format';
    }
  }

  /// Comprehensive validation for restaurant registration
  static Map<String, String> validateRestaurantRegistration({
    required String restaurantName,
    required String restaurantEmail,
    required String adminName,
    required String adminPassword,
    String? adminPin,
    String? businessType,
    String? phone,
  }) {
    final errors = <String, String>{};

    final nameError = validateRestaurantName(restaurantName);
    if (nameError != null) errors['restaurantName'] = nameError;

    final emailError = validateEmail(restaurantEmail);
    if (emailError != null) errors['restaurantEmail'] = emailError;

    final adminNameError = validateAdminName(adminName);
    if (adminNameError != null) errors['adminName'] = adminNameError;

    final passwordError = validatePassword(adminPassword);
    if (passwordError != null) errors['adminPassword'] = passwordError;

    if (adminPin != null) {
      final pinError = validatePIN(adminPin);
      if (pinError != null) errors['adminPin'] = pinError;
    }

    if (businessType != null) {
      final typeError = validateBusinessType(businessType);
      if (typeError != null) errors['businessType'] = typeError;
    }

    if (phone != null && phone.isNotEmpty) {
      final phoneError = validatePhoneNumber(phone);
      if (phoneError != null) errors['phone'] = phoneError;
    }

    return errors;
  }

  /// Rate limiting helper - check if too many attempts
  static bool isRateLimited(String identifier, int maxAttempts, Duration window) {
    // This would typically use a cache or database to track attempts
    // For now, return false (no rate limiting implemented)
    // TODO: Implement proper rate limiting with Redis or similar
    return false;
  }
} 