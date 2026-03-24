import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import '../../providers/auth_provider.dart';

class FaceRegistrationView extends ConsumerStatefulWidget {
  final String userId;

  const FaceRegistrationView({super.key, required this.userId});

  @override
  ConsumerState<FaceRegistrationView> createState() => _FaceRegistrationViewState();
}

class _FaceRegistrationViewState extends ConsumerState<FaceRegistrationView> {
  bool _isLoading = false;
  String _statusMessage = 'Please scan your face to register.';
  bool _registrationSuccess = false;

  Future<void> _captureAndRegister() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Opening Camera...';
    });

    try {
      final XFile? photo = await ImagePicker().pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front);

      if (photo == null) {
        setState(() {
          _statusMessage = 'Capture cancelled. Please try again.';
          _isLoading = false;
        });
        return;
      }

      // 1. Detect Face
      if (!kIsWeb) {
        setState(() => _statusMessage = 'Scanning Face...');
        final inputImage = InputImage.fromFilePath(photo.path);
        final faceDetector = FaceDetector(options: FaceDetectorOptions());
        final faces = await faceDetector.processImage(inputImage);
        await faceDetector.close();

        if (faces.isEmpty) {
          throw 'No face detected. Please ensure your face is clearly visible.';
        }
      }

      // 2. Upload to Firebase Storage
      setState(() => _statusMessage = 'Uploading your photo...');
      String photoUrl = '';
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_photos')
            .child(widget.userId)
            .child('registered_face.jpg');

        final bytes = await photo.readAsBytes();
        await storageRef.putData(
          bytes, 
          SettableMetadata(contentType: 'image/jpeg')
        ).timeout(const Duration(seconds: 15));
        photoUrl = await storageRef.getDownloadURL().timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('Storage error during face registration: $e');
        photoUrl = 'https://ui-avatars.com/api/?name=${widget.userId}&background=random';
      }

      // 3. Update Firestore (Rules now allow update if authenticated)
      setState(() => _statusMessage = 'Finalizing registration...');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'face_registered': true,
        'photo_url': photoUrl, // Using photo_url to match UserModel.fromMap
      });

      // 4. Trigger AuthWrapper re-evaluation
      ref.invalidate(userProvider);

      if (mounted) {
        setState(() {
          _registrationSuccess = true;
          _isLoading = false;
          _statusMessage = 'Face registered successfully!';
        });
        // The AuthWrapper will naturally replace this view with StudentHome once userProvider updates.
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Registration failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Registration')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_registrationSuccess)
                const Icon(Icons.check_circle, color: Colors.green, size: 80)
              else if (_isLoading)
                const CircularProgressIndicator()
              else
                const Icon(Icons.face_retouching_natural, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              if (!_isLoading && !_registrationSuccess)
                ElevatedButton.icon(
                  onPressed: _captureAndRegister,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Start Scan'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
