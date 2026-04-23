import 'package:safe_device/safe_device.dart';

class MockLocationService {
  static Future<bool> isMockLocationEnabled() async {
    try {
      bool isMockLocation = await SafeDevice.isMockLocation;
      return isMockLocation;
    } catch (e) {
      print('Error checking for mock location: $e');
      return false;
    }
  }
}

