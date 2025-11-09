import 'package:flutter/services.dart';

class KioskModeService {
  static const MethodChannel _channel = MethodChannel('com.example.visage_app/kiosk');

  /// Start Kiosk Mode (Lock Task Mode)
  static Future<bool> startKioskMode() async {
    try {
      final bool result = await _channel.invokeMethod('startKioskMode');
      return result;
    } on PlatformException catch (e) {
      print('Failed to start kiosk mode: ${e.message}');
      return false;
    }
  }

  /// Stop Kiosk Mode (Lock Task Mode)
  static Future<bool> stopKioskMode() async {
    try {
      final bool result = await _channel.invokeMethod('stopKioskMode');
      return result;
    } on PlatformException catch (e) {
      print('Failed to stop kiosk mode: ${e.message}');
      return false;
    }
  }

  /// Check if currently in Kiosk Mode
  static Future<bool> isInKioskMode() async {
    try {
      final bool result = await _channel.invokeMethod('isInKioskMode');
      return result;
    } on PlatformException catch (e) {
      print('Failed to check kiosk mode: ${e.message}');
      return false;
    }
  }

  /// Enable immersive mode (hide status bar and navigation bar)
  static Future<void> enableImmersiveMode() async {
    try {
      await _channel.invokeMethod('enableImmersiveMode');
    } on PlatformException catch (e) {
      print('Failed to enable immersive mode: ${e.message}');
    }
  }
}

