import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/sms_config.dart';

class SmsService {
  /// Normalize to E.164 with +1 default country code
  static String normalize(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('1') && digits.length == 11) return '+$digits';
    if (digits.length == 10) return '+1$digits';
    if (phone.startsWith('+')) return phone; // best-effort
    return '+$digits';
  }

  static Future<bool> sendSms(String to, String message) async {
    try {
      if (!SmsConfig.isConfigured) {
        return false;
      }
      final uri = Uri.parse('https://api.twilio.com/2010-04-01/Accounts/${SmsConfig.twilioAccountSid}/Messages.json');
      final body = {
        'To': to,
        'From': SmsConfig.twilioFromNumber,
        'Body': message,
      };
      final auth = 'Basic ' + base64Encode(utf8.encode('${SmsConfig.twilioAccountSid}:${SmsConfig.twilioAuthToken}'));
      final res = await http.post(
        uri,
        headers: {
          'Authorization': auth,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<int> sendBulk(List<String> phones, String message) async {
    int success = 0;
    for (final p in phones) {
      final normalized = normalize(p);
      final ok = await sendSms(normalized, message);
      if (ok) success++;
    }
    return success;
  }
} 