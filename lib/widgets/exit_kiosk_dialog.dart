import 'package:flutter/material.dart';
import '../services/kiosk_mode_service.dart';

class ExitKioskDialog extends StatefulWidget {
  const ExitKioskDialog({super.key});

  @override
  State<ExitKioskDialog> createState() => _ExitKioskDialogState();
}

class _ExitKioskDialogState extends State<ExitKioskDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  // Change this to your desired password
  static const String _correctPassword = '1234';

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndExit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    if (_passwordController.text == _correctPassword) {
      // Correct password - exit kiosk mode
      bool success = await KioskModeService.stopKioskMode();

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true); // Return true to indicate success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kiosk mode disabled. You can now exit the app.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to disable kiosk mode';
          });
        }
      }
    } else {
      // Incorrect password
      setState(() {
        _isLoading = false;
        _errorMessage = 'Incorrect password';
        _passwordController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Exit Kiosk Mode'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Enter password to exit kiosk mode and allow navigation:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              errorText: _errorMessage.isEmpty ? null : _errorMessage,
            ),
            onSubmitted: (_) => _verifyAndExit(),
          ),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyAndExit,
          child: const Text('Exit'),
        ),
      ],
    );
  }
}

/// Helper function to show the exit dialog
Future<bool?> showExitKioskDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const ExitKioskDialog(),
  );
}

