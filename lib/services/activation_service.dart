import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ActivationService {
  static const String _apiUrl =
      'https://visage.sltdigitallab.lk/api/v1/auth/validate-device';
  static const String _secretKey = 'EYtpDMnJ4aLgPZjKElzUpZ0I';
  static const String _prefKeyActivated  = 'device_activated';
  static const String _prefKeyGroupName  = 'group_name';
  static const String _prefKeyApiKey     = 'api_key';
  static const String _prefKeyClientKey  = 'client_key';

  /// Returns the SecretKey used by this app (same value that is sent during
  /// device activation and required by the attendance-history endpoint).
  static const String secretKey = _secretKey;

  /// Reads the ClientKey (= the activation code the user entered) from local
  /// storage. Returns null if the device has never been activated.
  static Future<String?> getClientKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyClientKey);
  }

  /// Returns true if this device has already been activated.
  static Future<bool> isDeviceActivated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyActivated) ?? false;
  }

  /// Calls the validate-device API with the provided [activationCode].
  /// Returns a [ActivationResult] with success/failure info.
  static Future<ActivationResult> validateDevice(String activationCode) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'activationCode': activationCode,
          'SecretKey': _secretKey,
        },
      );

      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final groupName = data['GroupName'] as String? ?? '';
        final apiKey = data['api key'] as String? ?? '';

        // Persist activation state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefKeyActivated, true);
        await prefs.setString(_prefKeyGroupName, groupName);
        await prefs.setString(_prefKeyApiKey, apiKey);
        // Save the activation code as the ClientKey for the history API
        await prefs.setString(_prefKeyClientKey, activationCode);

        return ActivationResult(
          success: true,
          message: body['message'] as String? ?? 'Device activated successfully.',
          groupName: groupName,
          apiKey: apiKey,
        );
      } else {
        final message = body['message'] as String? ?? 'Invalid activation code.';
        return ActivationResult(success: false, message: message);
      }
    } catch (e) {
      return ActivationResult(
        success: false,
        message: 'Network error. Please check your connection and try again.',
      );
    }
  }

  /// Clears stored activation data (for testing / reset purposes).
  static Future<void> clearActivation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyActivated);
    await prefs.remove(_prefKeyGroupName);
    await prefs.remove(_prefKeyApiKey);
    await prefs.remove(_prefKeyClientKey);
  }
}

class ActivationResult {
  final bool success;
  final String message;
  final String groupName;
  final String apiKey;

  ActivationResult({
    required this.success,
    required this.message,
    this.groupName = '',
    this.apiKey = '',
  });
}
