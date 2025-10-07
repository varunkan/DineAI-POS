import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'config/environment_config.dart';
import 'main.dart' as prod_main;

/// Production Environment Main Entry Point
/// 
/// This file is used for production builds with:
/// - Production environment configuration
/// - Optimized performance settings
/// - Disabled debug features
/// - Real printer connections only
/// - Faster sync intervals
/// - Error reporting enabled
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set production environment
  EnvironmentConfig.setEnvironment(Environment.production);
  
  // Enable production-specific features
  if (kDebugMode) {
  }
  
  // Set system UI overlay style for production
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Run the main application with production configuration
  prod_main.main();
} 