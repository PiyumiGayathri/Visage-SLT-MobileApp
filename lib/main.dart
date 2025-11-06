import 'package:flutter/material.dart';
import 'location_verified_screen.dart';
import 'developer_mode_warning_screen.dart';
import 'package:safe_device/safe_device.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visage App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DeveloperModeChecker(),
    );
  }
}

class DeveloperModeChecker extends StatefulWidget {
  const DeveloperModeChecker({super.key});

  @override
  State<DeveloperModeChecker> createState() => _DeveloperModeCheckerState();
}

class _DeveloperModeCheckerState extends State<DeveloperModeChecker> {
  bool _isChecking = true;
  bool _developerModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkDeveloperMode();
  }

  Future<void> _checkDeveloperMode() async {
    try {
      bool developerMode = await SafeDevice.isDevelopmentModeEnable;

      if (mounted) {
        setState(() {
          _developerModeEnabled = developerMode;
          _isChecking = false;
        });
      }
    } catch (e) {
      // If detection fails, allow app to continue
      if (mounted) {
        setState(() {
          _developerModeEnabled = false;
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_developerModeEnabled) {
      return const DeveloperModeWarningScreen();
    }

    return const LocationVerifiedScreen();
  }
}

