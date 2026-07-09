import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model representing a single attendance record
class AttendanceRecord {
  final String date;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final String status;

  AttendanceRecord({
    required this.date,
    this.clockIn,
    this.clockOut,
    required this.status,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      date: json['date'] as String,
      clockIn: json['clockIn'] != null
          ? DateTime.parse(json['clockIn'] as String).toLocal()
          : null,
      clockOut: json['clockOut'] != null
          ? DateTime.parse(json['clockOut'] as String).toLocal()
          : null,
      status: json['status'] as String,
    );
  }

  /// Returns hours worked as a formatted string, or '--' if incomplete
  String get hoursWorked {
    if (clockIn == null || clockOut == null) return '--';
    final diff = clockOut!.difference(clockIn!);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return '${h}h ${m}m';
  }
}

/// Service to fetch attendance history from the Visage API
class AttendanceHistoryService {
  // Reactive notifier – updated whenever attendance is successfully marked so
  // the Attendance History button on the home screen enables immediately.
  static final ValueNotifier<String?> savedEmployeeIdNotifier =
      ValueNotifier<String?>(null);

  static const String _baseUrl =
      'https://visage.sltdigitallab.lk/api/v1/attendance/history/slt';

      // The same SecretKey used during device activation.
  static const String _secretKey = 'EYtpDMnJ4aLgPZjKElzUpZ0I';

  // SharedPreferences keys (must match what ActivationService writes)
  static const String _prefClientKey  = 'client_key';
  static const String _prefEmployeeId = 'saved_employee_id';

  // ── Credential helpers ────────────────────────────────────────────────────

  /// Reads the stored ClientKey (= activation code entered by the user).
  static Future<String?> getClientKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefClientKey);
  }

  /// Reads the last-marked employee ID from local storage.
  static Future<String?> getSavedEmployeeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefEmployeeId);
  }

  /// Persists the employee ID and fires the reactive notifier.
  /// Called every time attendance is successfully marked so that the
  /// most-recent user's ID is always available for history lookups.
  static Future<void> saveEmployeeId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefEmployeeId, userId);
    savedEmployeeIdNotifier.value = userId;
  }

  // ── History fetch ─────────────────────────────────────────────────────────

  /// Fetches attendance history for [employeeId] within the given date range.
  ///
  /// [startDate] and [endDate] must be in 'yyyy-MM-dd' format.
  /// [ClientKey] (the stored activation code) and [SecretKey] are appended
  /// automatically as query parameters so no caller needs to supply them.
  static Future<List<AttendanceRecord>> fetchHistory({
    required String employeeId,
    required String startDate,
    required String endDate,
    int limit = 50,
  }) async {
    // 1. Clean the employee ID (strip optional " - Name" suffix)
    String cleanId = employeeId;
    if (cleanId.contains(' - ')) {
      cleanId = cleanId.split(' - ')[0].trim();
    } else {
      cleanId = cleanId.trim();
    }

    // 2. Load ClientKey from local storage (written at activation time)
    final prefs     = await SharedPreferences.getInstance();
    final clientKey = prefs.getString(_prefClientKey) ?? '';

    // 3. Build URI with all required query parameters

    final encodedId = Uri.encodeComponent(cleanId);
    final uri = Uri.parse('$_baseUrl/$encodedId').replace(
      queryParameters: {
        'startDate': startDate,
        'endDate':   endDate,
        'limit':     limit.toString(),
        'ClientKey': clientKey,
        'SecretKey': _secretKey,
      },
    );

    // 4. Execute request
    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load attendance history (HTTP ${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (body['success'] != true) {
      throw Exception(
          body['message']?.toString() ?? 'Unknown error from server');
    }

    final historyJson = (body['data']?['history'] as List<dynamic>?) ?? [];

    return historyJson
        .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
