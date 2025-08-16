import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/environment_config.dart';
import 'main.dart' as prod_main;

/// Development Environment Main Entry Point
/// 
/// This file is used for development builds with:
/// - Development environment configuration
/// - Enhanced debugging and logging
/// - Test data and experimental features
/// - Slower sync intervals for testing
/// - Printer simulation enabled
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set development environment
  EnvironmentConfig.setEnvironment(Environment.development);
  
  // Enable development-specific features
  debugPrint('🚀 Starting AI POS System in DEVELOPMENT mode');
  debugPrint('📊 Environment: ${EnvironmentConfig.environment.name}');
  debugPrint('🗄️ Database: ${EnvironmentConfig.databaseName}');
  debugPrint('🔧 Debug Logs: ${EnvironmentConfig.enableDebugLogs}');
  debugPrint('🧪 Test Data: ${EnvironmentConfig.enableTestData}');
  debugPrint('🖨️ Printer Simulation: ${EnvironmentConfig.enablePrinterSimulation}');
  
  // Set system UI overlay style for development
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Run the main application with development configuration
  await prod_main.main();
} 