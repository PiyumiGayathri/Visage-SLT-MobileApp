import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';

class FaceVerificationScreen extends StatefulWidget {
  final String action; // 'in' or 'out'

  const FaceVerificationScreen({
    super.key,
    required this.action,
  });

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String _statusMessage = 'Requesting camera permission...';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Request camera permission
    final status = await Permission.camera.request();

    if (status.isDenied) {
      setState(() {
        _statusMessage = 'Camera permission denied. Tap below to grant permission.';
      });
      return;
    }

    if (status.isPermanentlyDenied) {
      setState(() {
        _statusMessage = 'Camera permission permanently denied. Please enable in settings.';
      });
      return;
    }

    // Permission granted, initialize camera
    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        setState(() {
          _statusMessage = 'No camera found on this device';
        });
        return;
      }

      // Use front camera
      final frontCamera = _cameras!.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _statusMessage = 'Position your face in the frame';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Camera error: ${e.toString()}';
      });
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1e2a3a),
        title: const Text(
          'Camera Permission Required',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Camera access is required for face verification. Please enable it in app settings.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings', style: TextStyle(color: Color(0xFF4CAF50))),
          ),
        ],
      ),
    );
  }

  Future<void> _captureAndVerify() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Capturing and verifying...';
    });

    try {
      final image = await _controller!.takePicture();

      // Call your backend API
      final result = await _verifyFaceWithBackend(image.path);

      if (result['success'] == true) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully clocked ${widget.action}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _statusMessage = result['message'] ?? 'Verification failed. Please try again.';
          _isProcessing = false;
        });

        // Reset message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _statusMessage = 'Position your face in the frame';
            });
          }
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
        _isProcessing = false;
      });

      // Reset message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _statusMessage = 'Position your face in the frame';
          });
        }
      });
    }
  }

  Future<Map<String, dynamic>> _verifyFaceWithBackend(String imagePath) async {
    // Replace with your actual API endpoint
    const apiUrl = 'https://your-api-endpoint.com/verify-face';

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
      request.fields['action'] = widget.action;

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      return json.decode(responseData);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.action == 'in' ? 'Entrance' : 'Exit',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isInitialized
          ? Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),
          // Face frame overlay
          Positioned(
            top: MediaQuery.of(context).size.height * 0.2,
            left: MediaQuery.of(context).size.width * 0.5 - 140,
            child: Container(
              width: 280,
              height: 380,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isProcessing
                      ? Colors.blue.withOpacity(0.8)
                      : Colors.white.withOpacity(0.8),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(200),
              ),
            ),
          ),
          // Bottom instruction
          Positioned(
            bottom: 160,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1e2a3a).withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Switch action button
          Positioned(
            bottom: 90,
            right: 20,
            child: widget.action == 'in'
                ? TextButton(
              onPressed: _isProcessing ? null : () async {
                await _controller?.dispose();
                setState(() {
                  _isInitialized = false;
                  _statusMessage = 'Requesting camera permission...';
                });
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const FaceVerificationScreen(action: 'out'),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Switch to Out',
                style: TextStyle(color: Colors.white),
              ),
            )
                : TextButton(
              onPressed: _isProcessing ? null : () async {
                await _controller?.dispose();
                setState(() {
                  _isInitialized = false;
                  _statusMessage = 'Requesting camera permission...';
                });
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const FaceVerificationScreen(action: 'in'),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Switch to In',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      )
          : Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_statusMessage.contains('permission'))
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 80,
                  color: Colors.white54,
                )
              else
                const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              const SizedBox(height: 24),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              if (_statusMessage.contains('permanently denied'))
                ElevatedButton.icon(
                  onPressed: () {
                    openAppSettings();
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              if (_statusMessage.contains('permission denied') &&
                  !_statusMessage.contains('permanently'))
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _statusMessage = 'Requesting camera permission...';
                    });
                    _initializeCamera();
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Grant Permission'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
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
      floatingActionButton: _isInitialized && !_isProcessing
          ? FloatingActionButton.large(
        onPressed: _captureAndVerify,
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(
          Icons.camera_alt,
          size: 36,
          color: Colors.white,
        ),
      )
          : _isProcessing
          ? FloatingActionButton.large(
        onPressed: null,
        backgroundColor: Colors.grey,
        child: const CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 3,
        ),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}