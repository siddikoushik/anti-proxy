import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../models/session_model.dart';

class VerificationView extends ConsumerStatefulWidget {
  final SessionModel session;
  const VerificationView({super.key, required this.session});

  @override
  ConsumerState<VerificationView> createState() => _VerificationViewState();
}

class _VerificationViewState extends ConsumerState<VerificationView> {
  String _status = 'Initializing...';
  bool _isLoading = true;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _startVerification();
  }

  Future<void> _startVerification() async {
    try {
      // Layer 2: Geofencing
      setState(() => _status = 'Verifying Location...');
      Position pos = await Geolocator.getCurrentPosition();
      double distance = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, widget.session.lat, widget.session.lng);

      if (distance > widget.session.radius) {
        throw 'Out of classroom radius. Distance: ${distance.toInt()}m';
      }

      // Layer 3: Face Detection (Mocking similarity for simplicity, but doing detection)
      setState(() => _status = 'Capture Selfie for Verify');
      final XFile? photo = await ImagePicker().pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front);
      if (photo == null) throw 'Selfie required';

      if (!kIsWeb) {
        setState(() => _status = 'Analyzing Face...');
        final inputImage = InputImage.fromFilePath(photo.path);
        final faceDetector = FaceDetector(options: FaceDetectorOptions());
        final List<Face> faces = await faceDetector.processImage(inputImage);
        await faceDetector.close();

        if (faces.isEmpty) throw 'No face detected in selfie';
      } else {
        log('Web Platform detected: Bypassing ML Kit Face Detection pipeline.');
      }

      // Layer 4: Final Submit
      setState(() => _status = 'Marking Attendance...');
      final user = ref.read(userProvider).value;
      if (user == null) throw 'User data not loaded';

      await FirebaseFirestore.instance
          .collection('class_sessions')
          .doc(widget.session.sessionId)
          .collection('attendance')
          .doc(user.userId)
          .set({
        'name': user.name,
        'status': 'present',
        'timestamp': FieldValue.serverTimestamp(),
        'marked_by': 'student',
      }, SetOptions(merge: true));

      setState(() {
        _status = 'Attendance Marked Successfully!';
        _isLoading = false;
        _success = true;
      });
    } catch (e) {
      setState(() {
        _status = 'Verification Failed: $e';
        _isLoading = false;
        _success = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) const CircularProgressIndicator(),
              if (!_isLoading)
                Icon(_success ? Icons.check_circle : Icons.error,
                    size: 80, color: _success ? Colors.green : Colors.red),
              const SizedBox(height: 24),
              Text(_status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18)),
              if (!_isLoading) ...[
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Home'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
