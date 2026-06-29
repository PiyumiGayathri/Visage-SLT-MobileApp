import 'package:flutter/material.dart';
import 'location_verified_screen.dart';
import 'package:visage_app/services/mock_location_service.dart';
import 'package:visage_app/mock_location_warning_screen.dart';
import 'package:visage_app/services/activation_service.dart';
import 'package:visage_app/activation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const AppEntryPoint(),
    );
  }
}

/// Decides whether to show [ActivationScreen] or go straight to [InitialCheckScreen].
class AppEntryPoint extends StatelessWidget {
  const AppEntryPoint({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ActivationService.isDeviceActivated(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isActivated = snapshot.data ?? false;
        if (isActivated) {
          return const InitialCheckScreen();
        } else {
          return const ActivationScreen();
        }
      },
    );
  }
}

class InitialCheckScreen extends StatelessWidget {
  const InitialCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: MockLocationService.isMockLocationEnabled(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Verifying location settings...',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data == true) {
          // Mock location is enabled, show warning screen.
          return const MockLocationWarningScreen();
        } else {
          // No mock location or check failed, proceed to the app.
          return const LocationVerifiedScreen();
        }
      },
    );
  }
}
