import 'package:flutter/services.dart';
import 'package:safe_device/safe_device.dart';

class MockLocationService {
  static const mockLocationChannel = MethodChannel('com.example.visage_app/mockLocation');

  /// Check if mock location is enabled using SafeDevice plugin
  static Future<bool> isMockLocationEnabled() async {
    try {
      bool isMockLocation = await SafeDevice.isMockLocation;
      return isMockLocation;
    } catch (e) {
      print('Error checking for mock location with SafeDevice: $e');
      return false;
    }
  }

  /// Check if a mock location app is currently set via AppOpsManager
  /// More reliable than SafeDevice for detecting mock location apps
  static Future<bool> isMockLocationAppSet() async {
    try {
      final bool result = await mockLocationChannel.invokeMethod<bool>('isMockLocationAppSet') ?? false;
      print('[MockLocationService] Mock location app set check: $result');
      return result;
    } catch (e) {
      print('Error checking if mock location app is set: $e');
      return false;
    }
  }

  /// Verify if a specific location is mocked (per-fix detection)
  /// This checks the Location.isFromMockProvider flag on Android
  static Future<bool> isLocationMocked({
    required double latitude,
    required double longitude,
    required double accuracy,
    String provider = 'fused',
  }) async {
    try {
      final bool result = await mockLocationChannel.invokeMethod<bool>(
        'isLocationMocked',
        {
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'provider': provider,
        },
      ) ?? false;
      print('[MockLocationService] Location mock check (lat: $latitude, lng: $longitude): $result');
      return result;
    } catch (e) {
      print('Error checking if location is mocked: $e');
      return false;
    }
  }

  /// Check if any location provider is currently mocked
  static Future<bool> isAnyProviderMocked() async {
    try {
      final bool result = await mockLocationChannel.invokeMethod<bool>('isAnyProviderMocked') ?? false;
      print('[MockLocationService] Any provider mocked check: $result');
      return result;
    } catch (e) {
      print('Error checking if any provider is mocked: $e');
      return false;
    }
  }

  /// Perform comprehensive mock location check with multiple detection methods
  /// Returns a detailed result map with findings from all detection layers
  static Future<MockDetectionResult> performComprehensiveCheck({
    required double latitude,
    required double longitude,
    required double accuracy,
    String provider = 'fused',
  }) async {
    try {
      final result = await mockLocationChannel.invokeMethod<Map<dynamic, dynamic>>(
        'performComprehensiveCheck',
        {
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'provider': provider,
        },
      );

      if (result == null) {
        return MockDetectionResult(
          isMocked: false,
          details: ['No result from native code'],
          timestamp: DateTime.now(),
        );
      }

      final details = (result['details'] as List?)?.cast<String>() ?? [];
      print('[MockLocationService] Comprehensive check results:');
      for (var detail in details) {
        print('  - $detail');
      }

      return MockDetectionResult(
        isMocked: result['isMocked'] == true,
        details: details,
        timestamp: DateTime.fromMillisecondsSinceEpoch(result['timestamp'] as int? ?? 0),
        latitude: result['latitude'] as double?,
        longitude: result['longitude'] as double?,
        accuracy: result['accuracy'] as double?,
      );
    } catch (e) {
      print('Error performing comprehensive mock location check: $e');
      return MockDetectionResult(
        isMocked: false,
        details: ['Error during check: $e'],
        timestamp: DateTime.now(),
      );
    }
  }
}

/// Result class for comprehensive mock detection
class MockDetectionResult {
  final bool isMocked;
  final List<String> details;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final double? accuracy;

  MockDetectionResult({
    required this.isMocked,
    required this.details,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.accuracy,
  });

  @override
  String toString() => 'MockDetectionResult(isMocked: $isMocked, details: $details)';
}

