import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

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
  static final ValueNotifier<String?> savedEmployeeIdNotifier =
      ValueNotifier<String?>(null);

  static const String _baseUrl =
      'https://visage.sltdigitallab.lk/api/v1/attendance/history/slt';

  /// Fetches attendance history for [employeeId] within the given date range.
  /// [startDate] and [endDate] should be in 'yyyy-MM-dd' format.
  static Future<List<AttendanceRecord>> fetchHistory({
    required String employeeId,
    required String startDate,
    required String endDate,
    int limit = 50,
  }) async {
    // Clean and format the employee ID
    String cleanId = employeeId;
    if (cleanId.contains(' - ')) {
      cleanId = cleanId.split(' - ')[0].trim();
    } else {
      cleanId = cleanId.trim();
    }

    final encodedId = Uri.encodeComponent(cleanId);
    final uri = Uri.parse('$_baseUrl/$encodedId').replace(
      queryParameters: {
        'startDate': startDate,
        'endDate': endDate,
        'limit': limit.toString(),
      },
    );

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

    final historyJson =
        (body['data']?['history'] as List<dynamic>?) ?? [];

    return historyJson
        .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
