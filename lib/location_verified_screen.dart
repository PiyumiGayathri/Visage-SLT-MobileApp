import 'package:flutter/material.dart';
import 'face_verification_screen.dart';
import 'attendance_history_screen.dart';
import 'package:visage_app/services/attendance_history_service.dart';

class LocationVerifiedScreen extends StatelessWidget {
  const LocationVerifiedScreen({super.key});

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
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: const VerificationCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VerificationCard extends StatefulWidget {
  const VerificationCard({super.key});

  @override
  State<VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends State<VerificationCard> {
  String? _savedEmployeeId;

  @override
  void initState() {
    super.initState();
    _loadSavedEmployeeId();
    AttendanceHistoryService.savedEmployeeIdNotifier.addListener(_onEmployeeIdChanged);
  }

  @override
  void dispose() {
    AttendanceHistoryService.savedEmployeeIdNotifier.removeListener(_onEmployeeIdChanged);
    super.dispose();
  }

  void _onEmployeeIdChanged() {
    setState(() {
      _savedEmployeeId = AttendanceHistoryService.savedEmployeeIdNotifier.value;
    });
  }

  Future<void> _loadSavedEmployeeId() async {
    try {
      final savedId = await AttendanceHistoryService.getSavedEmployeeId();
      if (mounted) {
        setState(() {
          _savedEmployeeId = savedId;
        });
      }
      // Keep the notifier in sync so other listeners pick it up too
      AttendanceHistoryService.savedEmployeeIdNotifier.value = savedId;
      print('Loaded saved employee ID: $savedId');
    } catch (e) {
      print('Error loading saved employee ID: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1e2a3a).withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppTitle(),
          const SizedBox(height: 32),
          const VerificationStatus(),
          const SizedBox(height: 24),
          const StatusMessage(),
          const SizedBox(height: 40),
          ActionButton(
            label: 'Clock In',
            color: const Color(0xFF4CAF50),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FaceVerificationScreen(action: 'in'),
                ),
              );
              _loadSavedEmployeeId();
            },
          ),
          const SizedBox(height: 16),
          ActionButton(
            label: 'Clock Out',
            color: const Color(0xFFE53935),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FaceVerificationScreen(action: 'out'),
                ),
              );
              _loadSavedEmployeeId();
            },
          ),
          const SizedBox(height: 16),
          ActionButton(
            label: 'Attendance History',
            color: const Color(0xFF5865F2),
            onPressed: _savedEmployeeId != null
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AttendanceHistoryScreen(
                          employeeId: _savedEmployeeId!,
                        ),
                      ),
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class AppTitle extends StatelessWidget {
  const AppTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/icon/app_icon.png',
          width: 80,
          height: 80,
        ),
        const SizedBox(height: 16),
        Text(
          'VISAGE',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width > 400 ? 48 : 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 8,
          ),
        ),
      ],
    );
  }
}

class VerificationStatus extends StatelessWidget {
  const VerificationStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.check,
        color: Colors.white,
        size: 48,
      ),
    );
  }
}

class StatusMessage extends StatelessWidget {
  const StatusMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Location verified. Please select\nan action.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: MediaQuery.of(context).size.width > 400 ? 18 : 16,
        color: Colors.white.withOpacity(0.9),
        height: 1.5,
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const ActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? color : Colors.white.withOpacity(0.08),
          foregroundColor: isEnabled ? Colors.white : Colors.white38,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isEnabled ? 4 : 0,
          shadowColor: isEnabled ? color.withOpacity(0.5) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width > 400 ? 20 : 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}