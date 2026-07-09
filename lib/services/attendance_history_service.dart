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

      // The same SecretKey used during device activation.
  static const String _secretKey = 'EYtpDMnJ4aLgPZjKElzUpZ0I';

  // SharedPreferences keys (must match what ActivationService writes)
  static const String _prefClientKey  = 'client_key';
  static const String _prefEmployeeId = 'saved_employee_id';
  static const String _prefGroupName  = 'group_name';

  // ── Credential / data helpers ─────────────────────────────────────────────

  /// Reads the stored ClientKey (= activation code entered by the user).
  static Future<String?> getClientKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefClientKey);
  }

  /// Reads the stored employee group (e.g. 'slt' or 'slt_interns').
  static Future<String?> getGroupName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefGroupName);
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
  ///
  /// The URL shape is determined by the group stored at activation time:
  ///   • slt         → .../history/slt/019918?...
  ///   • slt_interns → .../history/slt_interns/InSP%2F2025%2F6025%2F199%20-%20Adithya?...
  ///
  /// [ClientKey] and [SecretKey] are appended automatically as query params.
  static Future<List<AttendanceRecord>> fetchHistory({
    required String employeeId,
    required String startDate,
    required String endDate,
    int limit = 50,
  }) async {
    // 1. Load credentials and group from local storage
    final prefs     = await SharedPreferences.getInstance();
    final clientKey = prefs.getString(_prefClientKey) ?? '';

    // 3. Build URI with all required query parameters

    final groupName = prefs.getString(_prefGroupName) ?? 'slt';

    // 2. Determine the ID to embed in the URL path based on the group.
    //
    //    slt:         Strip the " - Name" suffix; IDs are plain numbers like
    //                 "019918" that need no special encoding.
    //
    //    slt_interns: Keep the FULL raw string (e.g. "InSP/2025/6025/199 - Adithya")
    //                 and pass it as a single Uri path-segment so Dart
    //                 automatically percent-encodes slashes → %2F and
    //                 spaces → %20, producing the required URL shape.
    final String idForPath;
    if (groupName == 'slt_interns') {
      idForPath = employeeId.trim(); // full raw ID; Uri will encode it
    } else {
      // slt (or any unknown group): strip optional " - Name" suffix
      if (employeeId.contains(' - ')) {
        idForPath = employeeId.split(' - ')[0].trim();
      } else {
        idForPath = employeeId.trim();
      }
    }

    // 3. Build the URI using pathSegments so each segment is individually
    //    percent-encoded by Dart (critical for slt_interns where the ID
    //    contains literal slashes and spaces that must become %2F/%20).
    final uri = Uri(
      scheme: 'https',
      host: 'visage.sltdigitallab.lk',
      pathSegments: [
        'api', 'v1', 'attendance', 'history', groupName, idForPath,
      ],
    ).replace(
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
