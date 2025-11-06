import 'package:flutter/material.dart';
import 'dart:async';
import 'package:safe_device/safe_device.dart';

class DeveloperModeWarningScreen extends StatefulWidget {
  const DeveloperModeWarningScreen({super.key});

  @override
  State<DeveloperModeWarningScreen> createState() => _DeveloperModeWarningScreenState();
}

class _DeveloperModeWarningScreenState extends State<DeveloperModeWarningScreen> {
  Timer? _checkTimer;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    // Check every 2 seconds if developer mode is disabled
    _checkTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkDeveloperMode();
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkDeveloperMode() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    try {
      bool developerMode = await SafeDevice.isDevelopmentModeEnable;

      if (!developerMode) {
        // Developer mode is now disabled, restart the app
        if (mounted) {
          // ignore: use_build_context_synchronously
          Navigator.of(context).pushReplacementNamed('/');
        }
      }
    } catch (e) {
      // Handle error silently
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Warning Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.red.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.warning_rounded,
                        size: 80,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      'Developer Mode Detected',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Message
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1e2a3a).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Please disable Developer Mode to use this app',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 16),

                          // Instructions
                          const Text(
                            'How to disable Developer Mode:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInstructionStep('1', 'Open Settings on your device'),
                          const SizedBox(height: 8),
                          _buildInstructionStep('2', 'Go to System or About Phone'),
                          const SizedBox(height: 8),
                          _buildInstructionStep('3', 'Find Developer Options'),
                          const SizedBox(height: 8),
                          _buildInstructionStep('4', 'Toggle it OFF'),
                          const SizedBox(height: 24),

                          // Auto-check indicator
                          if (_isChecking)
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Checking...',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            )
                          else
                            const Text(
                              'App will automatically resume when disabled',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Manual Recheck Button
                    ElevatedButton.icon(
                      onPressed: _isChecking ? null : _checkDeveloperMode,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue, width: 1.5),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

