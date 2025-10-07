import 'package:flutter/foundation.dart';

class SmsConfig {
  // Read from Dart environment at build time (use --dart-define)
  static const String twilioAccountSid = String.fromEnvironment('TWILIO_ACCOUNT_SID', defaultValue: '');
  static const String twilioAuthToken = String.fromEnvironment('TWILIO_AUTH_TOKEN', defaultValue: '');
  static const String twilioFromNumber = String.fromEnvironment('TWILIO_FROM_NUMBER', defaultValue: '');

  static bool get isConfigured =>
      twilioAccountSid.isNotEmpty && twilioAuthToken.isNotEmpty && twilioFromNumber.isNotEmpty;

  static void logConfigStatus() {
  }
} 