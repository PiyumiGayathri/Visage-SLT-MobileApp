import 'package:flutter/material.dart';
import 'location_verified_screen.dart';
import 'package:safe_device/safe_device.dart';
import 'services/kiosk_mode_service.dart';
import 'widgets/exit_kiosk_dialog.dart';

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
  bool _kioskModeActive = false;

  @override
  void initState() {
    super.initState();
    _initializeKioskMode();
  }

  Future<void> _initializeKioskMode() async {
    // Start kiosk mode when app launches
    bool success = await KioskModeService.startKioskMode();
    if (mounted) {
      setState(() {
        _kioskModeActive = success;
        _isChecking = false;
      });
    }

    // Enable immersive mode (hide system bars)
    await KioskModeService.enableImmersiveMode();
  }


  Future<void> _handleExitRequest() async {
    // Show password dialog
    bool? shouldExit = await showExitKioskDialog(context);

    if (shouldExit == true && mounted) {
      setState(() {
        _kioskModeActive = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _kioskModeActive ? 'Kiosk Mode Active' : 'Initializing...',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Wrap the screen with WillPopScope to intercept back button
    return WillPopScope(
      onWillPop: () async {
        // Show exit dialog when back button is pressed
        await _handleExitRequest();
        return false; // Prevent default back navigation
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Main content
            const LocationVerifiedScreen(),

            // Floating exit button (top-right corner)
            Positioned(
              top: 40,
              right: 16,
              child: SafeArea(
                child: FloatingActionButton.small(
                  onPressed: _handleExitRequest,
                  backgroundColor: Colors.red.withOpacity(0.7),
                  child: const Icon(Icons.exit_to_app, size: 20),
                ),
              ),
            ),

            // Kiosk mode indicator
            if (_kioskModeActive)
              Positioned(
                top: 40,
                left: 16,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Kiosk Mode',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

