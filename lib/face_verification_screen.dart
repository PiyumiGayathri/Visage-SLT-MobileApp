import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'location_verified_success_screen.dart';

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
  String _statusMessage = 'Requesting permissions...';
  Timer? _captureTimer;
  bool _faceDetected = false;
  String? _detectedEmpID;
  // Hardcoded location for F_HQ
  final double _fixedLatitude = 6.93485;
  final double _fixedLongitude = 79.84680;
  FaceDetector? _faceDetector;
  bool _isFaceSubmissionLocked = false;

  // Frame state: 'idle', 'scanning', 'success', 'error'
  String _frameState = 'idle';

  // Track if image stream is active
  bool _isStreamingStarted = false;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableLandmarks: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _initializeApp();
  }

  @override
  void dispose() {
    _faceDetector?.close();
    _controller?.dispose();
    _captureTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Using hardcoded location for F_HQ, directly initialize camera
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _statusMessage = 'Requesting camera permission...';
    });

    // Request camera permission - check if already granted first
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }

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

    // Permission granted, initialize camera with Samsung-specific error handling
    try {
      setState(() {
        _statusMessage = 'Initializing camera...';
      });

      // FIX: Wrap camera access in try-catch for Samsung devices
      _cameras = await availableCameras().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Camera initialization timeout - device may be in restricted mode');
        },
      );

      if (_cameras == null || _cameras!.isEmpty) {
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

      // FIX: Use medium resolution for better Samsung compatibility
      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium, // Safe resolution for Samsung devices
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420, // Use YUV420 for streaming
      );

      // FIX: Add timeout to initialization
      await _controller!.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Camera initialization timeout - Samsung may be blocking camera during kiosk mode');
        },
      );

      print('Camera initialized successfully');

      // Start image stream to ensure camera is actively streaming
      await _startImageStream();

      // Additional delay to ensure streaming is fully active
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _frameState = 'idle';
          _statusMessage = 'Position your face in the frame';
        });
        _startAutomaticCapture();
      }
    } on CameraException catch (e) {
      // Samsung-specific camera errors
      print('CameraException: ${e.code} - ${e.description}');
      if (mounted) {
        setState(() {
          _statusMessage = 'Camera error: ${e.description ?? e.code}\nTry restarting the app';
        });
      }
    } on Exception catch (e) {
      print('Camera initialization error: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Camera error: ${e.toString()}\nThis may occur if permissions were granted during kiosk mode';
        });
      }
    } catch (e) {
      print('Unexpected camera error: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Unexpected error: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _startImageStream() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      print('Cannot start image stream - controller not ready');
      return;
    }

    // FIX: Add comprehensive error handling for Samsung devices
    try {
      await _controller!.startImageStream((CameraImage image) async {
        if (!_isStreamingStarted) {
          _isStreamingStarted = true;
          print('Image stream started successfully');
        }
        if (_isProcessing || _isFaceSubmissionLocked) return;
        _isProcessing = true;
        try {
          // Convert CameraImage to InputImage (Android only, YUV420 format)
          if (image.format.group != ImageFormatGroup.yuv420) {
            print('Unsupported image format for ML Kit');
            _isProcessing = false;
            return;
          }
          // Concatenate all planes' bytes
          final int totalBytes = image.planes.fold(0, (sum, plane) => sum + plane.bytes.length);
          final Uint8List bytes = Uint8List(totalBytes);
          int offset = 0;
          for (final Plane plane in image.planes) {
            bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
            offset += plane.bytes.length;
          }
          final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
          final camera = _controller!.description;
          final rotation = _rotationIntToImageRotation(camera.sensorOrientation);
          final inputImage = InputImage.fromBytes(
            bytes: bytes,
            metadata: InputImageMetadata(
              size: imageSize,
              rotation: rotation,
              format: InputImageFormat.yuv420,
              bytesPerRow: image.planes[0].bytesPerRow,
            ),
          );
          final faces = await _faceDetector!.processImage(inputImage);
          if (faces.isNotEmpty) {
            print('Face detected! Sending to backend...');
            _isFaceSubmissionLocked = true;
            _faceDetected = true;
            setState(() {
              _frameState = 'scanning';
              _statusMessage = 'Face detected! Sending for verification...';
            });
            await _sendFaceDetailsToBackend();
            await Future.delayed(const Duration(seconds: 5));
            _isFaceSubmissionLocked = false;
            _isProcessing = false;
            return;
          } else {
            _faceDetected = false;
            _isProcessing = false;
            return;
          }
        } catch (e) {
          print('Face detection error: $e');
          _isProcessing = false;
          return;
        }
      });
      print('Called startImageStream');
    } on CameraException catch (e) {
      // Samsung-specific camera exceptions
      print('CameraException starting image stream: ${e.code} - ${e.description}');
      if (mounted) {
        setState(() {
          _statusMessage = 'Camera stream error: ${e.description ?? e.code}';
        });
      }
    } catch (e) {
      print('Error starting image stream: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Error starting camera stream. Please restart the app.';
        });
      }
    }
    return;
  }

  InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _sendFaceDetailsToBackend() async {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) {
      _isFaceSubmissionLocked = false;
      _isProcessing = false;
      return;
    }

    try {
      // Stop the stream and wait a bit longer for camera to stabilize
      if (_isStreamingStarted) {
        await _controller!.stopImageStream();
        _isStreamingStarted = false;
        print('Image stream stopped for face detection capture');
        // Increased delay to let camera settle
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Check again if controller is still valid
      if (!mounted || _controller == null || !_controller!.value.isInitialized) {
        _isFaceSubmissionLocked = false;
        _isProcessing = false;
        return;
      }

      final image = await _controller!.takePicture();
      print('Image captured from face detection: ${image.path}');

      // Restart stream before API call
      if (mounted && _controller != null) {
        await _startImageStream();
      }

      final result = await _verifyFaceWithUnifiedAPI(image.path);

      if (!mounted) return;

      if (result['success'] == true) {
        String displayInfo = _formatDateTime(result);
        String userId = result['user']?.toString() ?? 'Unknown';

        setState(() {
          _frameState = 'success';
          _statusMessage = (result['sp_msg']?.toString().isNotEmpty == true && result['sp_msg'] != 'None')
              ? result['sp_msg']
              : (result['msg2']?.toString().isNotEmpty == true ? result['msg2'] : 'Face verified!');
          _detectedEmpID = result['user'];
          _faceDetected = true;
        });

        // Stop timer and navigate
        _captureTimer?.cancel();
        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LocationVerifiedSuccessScreen(
                action: widget.action,
                userId: userId,
                dateTime: displayInfo.split(' | ').last, // Extract "DD/MM/YYYY at HH:MM:SS AM"
                message: result['msg2']?.toString() ?? "Let's make it a great day.",
              ),
            ),
          );
        }
      } else {
        setState(() {
          _frameState = 'error';
          _statusMessage = (result['message']?.toString().isNotEmpty == true && result['message'] != 'None')
              ? result['message']
              : 'Verification failed';
          _detectedEmpID = null;
          _faceDetected = false;
        });

        // Reset to idle after showing error
        await Future.delayed(const Duration(seconds: 3));
        if (mounted && !_faceDetected) {
          setState(() {
            _frameState = 'idle';
            _statusMessage = 'Position your face in the frame';
          });
        }
      }
    } catch (e) {
      print('Error in _sendFaceDetailsToBackend: $e');
      if (mounted) {
        setState(() {
          _frameState = 'error';
          _statusMessage = 'Error: ${e.toString()}';
        });

        // Try to restart stream
        try {
          if (!_isStreamingStarted && _controller != null) {
            await _startImageStream();
          }
        } catch (streamError) {
          print('Error restarting stream: $streamError');
        }

        await Future.delayed(const Duration(seconds: 2));
        if (mounted && !_faceDetected) {
          setState(() {
            _frameState = 'idle';
            _statusMessage = 'Position your face in the frame';
          });
        }
      }
    } finally {
      _isFaceSubmissionLocked = false;
      _isProcessing = false;
    }
  }

  Future<void> _startAutomaticCapture() async {
    print('Starting automatic capture timer');
    _captureTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      print('Timer tick - isInitialized: $_isInitialized, isProcessing: $_isProcessing, faceDetected: $_faceDetected, isStreaming: $_isStreamingStarted');
      if (_isInitialized && !_isProcessing && mounted && !_faceDetected && _isStreamingStarted) {
        print('Calling _captureAndVerifyAutomatic');
        _captureAndVerifyAutomatic();
      }
    });
    return;
  }

  Future<void> _captureAndVerifyAutomatic() async {
    print('_captureAndVerifyAutomatic called');

    if (_controller == null) {
      print('Controller is null');
      return;
    }

    if (!_controller!.value.isInitialized) {
      print('Controller not initialized');
      return;
    }

    if (!_isStreamingStarted) {
      print('Camera not streaming images (checked in _captureAndVerifyAutomatic)');
      return;
    }

    if (_isProcessing) {
      print('Already processing');
      return;
    }

    print('Starting capture process');

    setState(() {
      _isProcessing = true;
      _frameState = 'scanning'; // Blue frame
      _statusMessage = 'Scanning...';
    });

    try {
      // Stop image stream temporarily for capture
      if (_isStreamingStarted) {
        await _controller!.stopImageStream();
        _isStreamingStarted = false;
        print('Image stream stopped for capture');
        await Future.delayed(const Duration(milliseconds: 300));
      }

      print('Taking picture...');
      final image = await _controller!.takePicture();
      print('Image captured successfully: ${image.path}');

      // Restart image stream
      await _startImageStream();

      print('Calling unified API...');
      final result = await _verifyFaceWithUnifiedAPI(image.path);
      print('API Response received');
        String userId = result['user']?.toString() ?? 'Unknown';
      print('Verification result: $result');

      if (result['success'] == true) {
        print('Verification successful! User: ${result['user']}');

        String displayInfo = _formatDateTime(result);

        setState(() {
          _faceDetected = true;
          _detectedEmpID = result['user'];
          _frameState = 'success'; // Green frame
          _statusMessage = (result['sp_msg']?.toString().isNotEmpty == true && result['sp_msg'] != 'None')
              ? result['sp_msg']
              : (result['msg2']?.toString().isNotEmpty == true ? result['msg2'] : 'Face verified!');
        });

        // Stop the timer
        _captureTimer?.cancel();

        // Wait a moment to show the success message
        await Future.delayed(const Duration(milliseconds: 1500));

        // Navigate back with success
        if (mounted) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LocationVerifiedSuccessScreen(
                action: widget.action,
                userId: userId,
                dateTime: displayInfo.split(' | ').last, // Extract "DD/MM/YYYY at HH:MM:SS AM"
                message: result['msg2']?.toString() ?? "Let's make it a great day.",
              ),
            ),
          );
        }
      } else {
        // Verification failed
        print('Verification failed. Message: ${result['message']}');
        setState(() {
          _faceDetected = false;
          _detectedEmpID = null;
          _isProcessing = false;
          _frameState = 'error'; // Red frame
          _statusMessage = (result['message']?.toString().isNotEmpty == true && result['message'] != 'None')
              ? result['message']
              : 'Verification failed';
        });

        // Reset to idle state after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && !_faceDetected) {
            setState(() {
              _frameState = 'idle';
              _statusMessage = 'Position your face in the frame';
            });
          }
        });
      }
    } catch (e, stackTrace) {
      print('ERROR in capture: $e');
      print('Stack trace: $stackTrace');

      // Try to restart image stream
      try {
        if (!_isStreamingStarted) {
          await _startImageStream();
        }
      } catch (streamError) {
        print('Error restarting stream: $streamError');
      }

      setState(() {
        _faceDetected = false;
        _isProcessing = false;
        _frameState = 'error'; // Red frame
        _statusMessage = 'Error: ${e.toString()}';
      });

      // Reset to idle state after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_faceDetected) {
          setState(() {
            _frameState = 'idle';
            _statusMessage = 'Position your face in the frame';
          });
        }
      });
    }
  }

  Future<Map<String, dynamic>> _verifyFaceWithUnifiedAPI(String imagePath) async {
    const apiUrl = 'https://visage.sltdigitallab.lk/api/verify_face';

    try {
      print('Sending request to: $apiUrl');

      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Add headers
      request.headers['api'] = 'Up8FPhVfYi';
      request.headers['user'] = 'slt';
      request.headers['other'] = widget.action == 'in' ? 'I' : 'O';
      request.headers['userlat'] = _fixedLatitude.toString();
      request.headers['userlon'] = _fixedLongitude.toString();

      // Add image file
      var imageFile = await http.MultipartFile.fromPath('image', imagePath);
      request.files.add(imageFile);

      print('Request headers: ${request.headers}');
      print('Sending image: $imagePath');
      print('Location (F_HQ): $_fixedLatitude, $_fixedLongitude');

      // Send request with timeout
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );

      print('Response status code: ${streamedResponse.statusCode}');

      var responseData = await streamedResponse.stream.bytesToString();
      print('Response body: $responseData');

      if (streamedResponse.statusCode == 200) {
        var jsonResponse = json.decode(responseData);

        // Print all available fields in the response
        print('=== Full API Response ===');
        print('Available fields: ${jsonResponse.keys.toList()}');
        jsonResponse.forEach((key, value) {
          print('$key: $value');
        });
        print('========================');

        // Check if verification was successful
        if (jsonResponse['msg'] != null &&
            jsonResponse['msg'].toString().toLowerCase().contains('success')) {
          return {
            'success': true,
            'user': jsonResponse['user'],
            'username': jsonResponse['username'], // Client's username
            'date': jsonResponse['date'], // Date field
            'time': jsonResponse['time'], // Time field
            'datetime': jsonResponse['datetime'], // Combined datetime field if available
            'msg2': jsonResponse['msg2'], // Attendance message
            'sp_msg': jsonResponse['sp_msg'], // Special message
            'message': jsonResponse['msg']
          };
        } else {
          // Failed verification (location, spoof, not found, etc.)
          return {
            'success': false,
            'message': jsonResponse['msg'] ?? 'Verification failed'
          };
        }
      } else if (streamedResponse.statusCode == 400) {
        // Bad request (spoof detected, user not found, etc.)
        var jsonResponse = json.decode(responseData);
        print('=== API Error Response ===');
        print('Available fields: ${jsonResponse.keys.toList()}');
        jsonResponse.forEach((key, value) {
          print('$key: $value');
        });
        print('=========================');
        return {
          'success': false,
          'message': jsonResponse['msg'] ?? 'Verification failed'
        };
      } else {
        return {
          'success': false,
          'message': 'Server error: ${streamedResponse.statusCode}'
        };
      }
    } on TimeoutException catch (e) {
      print('Timeout error: $e');
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      print('Network error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  String _formatDateTime(Map<String, dynamic> result) {
    // Get username from API response (use 'user' field)
    String username = result['user']?.toString() ?? 'User';

    // Since API doesn't provide date/time, generate them locally
    DateTime now = DateTime.now();

    // Format date as DD/MM/YYYY
    String dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    // Format time as HH:MM:SS AM/PM
    int hour = now.hour;
    String period = hour >= 12 ? 'PM' : 'AM';
    int hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    String timeStr = '${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} $period';

    return '$username | $dateStr at $timeStr';
  }

  Color _getFrameColor() {
    switch (_frameState) {
      case 'scanning':
        return Colors.blue.withOpacity(0.9);
      case 'success':
        return Colors.green.withOpacity(0.9);
      case 'error':
        return Colors.red.withOpacity(0.9);
      case 'idle':
      default:
        return Colors.white.withOpacity(0.8);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () {
              _captureTimer?.cancel();
              Navigator.pop(context);
            },
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            widget.action == 'in' ? 'Entrance' : 'Exit',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      body: _isInitialized
          ? Stack(
        children: [
          // Camera preview - full screen
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize!.height,
                height: _controller!.value.previewSize!.width,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          // Face frame overlay with dimmed background and cutout
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: CustomPaint(
              key: ValueKey(_frameState),
              painter: FaceOverlayPainter(
                topCornerRadius: 100.0,    // Large rounded top corners
                bottomChamfer: 70.0,      // Very aggressive inward-curving bottom corners (140px radius)
                holeSize: Size(
                  MediaQuery.of(context).size.width * 0.7,
                  MediaQuery.of(context).size.width * 0.7 * 1.25,
                ),
                borderColor: _getFrameColor(),
                borderWidth: 6.0,
                overlayColor: Colors.black.withOpacity(0.6),
              ),
              child: Container(),
            ),
          ),
          // Status indicator icon
          if (_frameState == 'scanning')
            Positioned(
              top: MediaQuery.of(context).size.height * 0.2 - 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
            ),
          if (_frameState == 'success')
            Positioned(
              top: MediaQuery.of(context).size.height * 0.2 - 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          if (_frameState == 'error')
            Positioned(
              top: MediaQuery.of(context).size.height * 0.2 - 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 32,
                  ),
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
              onPressed: _isProcessing || _faceDetected
                  ? null
                  : () async {
                _captureTimer?.cancel();
                if (_isStreamingStarted) {
                  await _controller?.stopImageStream();
                }
                await _controller?.dispose();
                setState(() {
                  _isInitialized = false;
                  _isStreamingStarted = false;
                  _statusMessage = 'Requesting permissions...';
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
              onPressed: _isProcessing || _faceDetected
                  ? null
                  : () async {
                _captureTimer?.cancel();
                if (_isStreamingStarted) {
                  await _controller?.stopImageStream();
                }
                await _controller?.dispose();
                setState(() {
                  _isInitialized = false;
                  _isStreamingStarted = false;
                  _statusMessage = 'Requesting permissions...';
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
                      _statusMessage = 'Requesting permissions...';
                    });
                    _initializeApp();
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
    );
  }
}

/// A CustomClipper that creates the desired shape.
/// This shape has large rounded top corners and small chamfered bottom corners.
class ShapeClipper extends CustomClipper<Path> {
  final double topCornerRadius;
  final double bottomChamfer;

  ShapeClipper({
    required this.topCornerRadius,
    required this.bottomChamfer,
  });

  @override
  Path getClip(Size size) {
    final Path path = Path();
    final double w = size.width;
    final double h = size.height;

    // Ensure radii are not larger than half the width/height
    final double topRadius = topCornerRadius > w / 2 ? w / 2 : topCornerRadius;

    // Bottom corners curve MUCH more aggressively inward
    // Using an even larger radius and making it curve higher into the shape
    final double bottomRadius = bottomChamfer * 2.5; // Even larger radius for very aggressive curve
    final double bottomCurveHeight = bottomChamfer * 2.0; // Curves extend much higher up

    // Start at the top-left, just after the curve
    path.moveTo(0, topRadius);

    // Top-left rounded corner (large smooth curve)
    path.arcToPoint(
      Offset(topRadius, 0),
      radius: Radius.circular(topRadius),
      clockwise: true,
    );

    // Top edge (straight line)
    path.lineTo(w - topRadius, 0);

    // Top-right rounded corner (large smooth curve)
    path.arcToPoint(
      Offset(w, topRadius),
      radius: Radius.circular(topRadius),
      clockwise: true,
    );

    // Right edge (much shorter - straight line down to bottom curve)
    path.lineTo(w, h - bottomCurveHeight);

    // Bottom-right rounded corner (very aggressive inward curve)
    path.arcToPoint(
      Offset(w / 2 + bottomRadius / 4, h), // Curves even more aggressively toward center
      radius: Radius.circular(bottomRadius),
      clockwise: true,
    );

    // Bottom edge (very short straight line - quarter of the width)
    path.lineTo(w / 2 - bottomRadius / 4, h);

    // Bottom-left rounded corner (very aggressive inward curve)
    path.arcToPoint(
      Offset(0, h - bottomCurveHeight),
      radius: Radius.circular(bottomRadius),
      clockwise: true,
    );

    // Left edge (much shorter - straight line back to start)
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    // Reclip if the parameters change
    if (oldClipper is ShapeClipper) {
      return oldClipper.topCornerRadius != topCornerRadius ||
          oldClipper.bottomChamfer != bottomChamfer;
    }
    return true;
  }
}

/// A CustomPainter that creates a full-screen overlay with a cutout hole for the face.
class FaceOverlayPainter extends CustomPainter {
  final double topCornerRadius;
  final double bottomChamfer;
  final Size holeSize; // The width and height of the face cut-out
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;

  FaceOverlayPainter({
    required this.topCornerRadius,
    required this.bottomChamfer,
    required this.holeSize,
    this.borderColor = Colors.blue,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 0.5),
  });

  @override
  void paint(Canvas canvas, Size size) {
    // --- Define the paints ---
    final Paint overlayPaint = Paint()..color = overlayColor;

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // --- Calculate the hole's position ---
    // This will center the hole in the screen
    final double left = (size.width - holeSize.width) / 2;
    // A bit higher than true center (80% of the way to the top)
    final double top = (size.height - holeSize.height) / 2 * 0.8;

    // --- Define the paths ---

    // This is the path for the full-screen rectangle
    final Path outerPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // This is the path for the "hole", using your ShapeClipper
    // We create the path for the hole's size...
    final Path holePath = ShapeClipper(
      topCornerRadius: topCornerRadius,
      bottomChamfer: bottomChamfer,
    ).getClip(holeSize);

    // ...and then we move it to the center of the screen
    final Path centeredHolePath = holePath.shift(Offset(left, top));

    // --- Combine the paths ---
    // This creates a new path that is the (outerPath - centeredHolePath)
    final Path overlayPath = Path.combine(
      PathOperation.difference,
      outerPath,
      centeredHolePath,
    );

    // --- Draw on canvas ---
    // 1. Draw the semi-transparent overlay
    canvas.drawPath(overlayPath, overlayPaint);

    // 2. Draw the border *around* the hole
    canvas.drawPath(centeredHolePath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // Repaint if any properties change
    if (oldDelegate is FaceOverlayPainter) {
      return oldDelegate.topCornerRadius != topCornerRadius ||
          oldDelegate.bottomChamfer != bottomChamfer ||
          oldDelegate.holeSize != holeSize ||
          oldDelegate.borderColor != borderColor ||
          oldDelegate.borderWidth != borderWidth ||
          oldDelegate.overlayColor != overlayColor;
    }
    return true;
  }
}
