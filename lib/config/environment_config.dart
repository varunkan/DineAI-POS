import 'package:flutter/foundation.dart';

/// Environment Configuration
/// Manages different settings for development and production environments
enum Environment {
  development,
  production,
}

class EnvironmentConfig {
  static Environment _environment = Environment.development;
  
  // Environment detection
  static Environment get environment => _environment;
  static bool get isDevelopment => _environment == Environment.development;
  static bool get isProduction => _environment == Environment.production;
  
  // Set environment (call this in main.dart)
  static void setEnvironment(Environment env) {
    _environment = env;
  }
  
  // Database configuration
  static String get databaseName {
    switch (_environment) {
      case Environment.development:
        return 'ai_pos_dev.db';
      case Environment.production:
        return 'ai_pos_prod.db';
    }
  }
  
  // API endpoints
  static String get baseApiUrl {
    switch (_environment) {
      case Environment.development:
        return 'https://dev-api.yourrestaurant.com';
      case Environment.production:
        return 'https://api.yourrestaurant.com';
    }
  }
  
  // Cloud printing configuration
  static String get cloudPrintingUrl {
    switch (_environment) {
      case Environment.development:
        return 'https://dev-cloud-print.yourrestaurant.com';
      case Environment.production:
        return 'https://cloud-print.yourrestaurant.com';
    }
  }
  
  // Logging configuration
  static bool get enableDebugLogs {
    switch (_environment) {
      case Environment.development:
        return true;
      case Environment.production:
        return false;
    }
  }
  
  static bool get enableVerboseLogs {
    switch (_environment) {
      case Environment.development:
        return true;
      case Environment.production:
        return false;
    }
  }
  
  // Feature flags
  static bool get enableExperimentalFeatures {
    switch (_environment) {
      case Environment.development:
        return true;
      case Environment.production:
        return false;
    }
  }
  
  static bool get enableTestData {
    switch (_environment) {
      case Environment.development:
        return true; // ENABLED: Test data creation for registration
      case Environment.production:
        return false;
    }
  }
  
  // App metadata
  static String get appName {
    switch (_environment) {
      case Environment.development:
        return 'AI POS System (DEV)';
      case Environment.production:
        return 'AI POS System';
    }
  }
  
  static String get appVersion {
    switch (_environment) {
      case Environment.development:
        return '2.0.0-dev';
      case Environment.production:
        return '2.0.0';
    }
  }
  
  // Printer configuration
  static int get printerTimeoutSeconds {
    switch (_environment) {
      case Environment.development:
        return 30; // Longer timeout for dev testing
      case Environment.production:
        return 15; // Standard timeout for production
    }
  }
  
  static bool get enablePrinterSimulation {
    switch (_environment) {
      case Environment.development:
        return true; // Enable printer simulation in dev
      case Environment.production:
        return false; // Real printers only in production
    }
  }
  
  // Sync configuration
  static int get syncIntervalSeconds {
    switch (_environment) {
      case Environment.development:
        return 60; // Slower sync for dev
      case Environment.production:
        return 30; // Faster sync for production
    }
  }
  
  // Error reporting
  static bool get enableCrashReporting {
    switch (_environment) {
      case Environment.development:
        return false; // Disable in dev to avoid noise
      case Environment.production:
        return true; // Enable in production
    }
  }
  
  // Performance monitoring
  static bool get enablePerformanceMonitoring {
    switch (_environment) {
      case Environment.development:
        return false;
      case Environment.production:
        return true;
    }
  }
} 