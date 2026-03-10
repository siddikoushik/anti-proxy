import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'dart:typed_data';

class UserRegistration extends StatefulWidget {
  const UserRegistration({super.key});

  @override
  State<UserRegistration> createState() => _UserRegistrationState();
}

class _UserRegistrationState extends State<UserRegistration> {
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _sectionController = TextEditingController();
  UserRole _selectedRole = UserRole.student;
  XFile? _pickedFile;
  Uint8List? _webImage;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _pickedFile = pickedFile;
          _webImage = bytes;
        });
      } else {
        setState(() => _pickedFile = pickedFile);
      }
    }
  }

  Future<void> _register() async {
    if (_pickedFile == null && _selectedRole == UserRole.student) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student photo required')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? photoUrl;

      if (!AuthService.isPrototypeMode) {
        if (_pickedFile != null) {
          final bytes = await _pickedFile!.readAsBytes();
          final ref = FirebaseStorage.instance
              .ref()
              .child('user_photos/${_idController.text}.jpg');

          final metadata = SettableMetadata(contentType: 'image/jpeg');
          await ref.putData(bytes, metadata);
          photoUrl = await ref.getDownloadURL();
        }

        final user = UserModel(
          userId: _idController.text,
          name: _nameController.text,
          role: _selectedRole,
          section: _selectedRole == UserRole.student
              ? _sectionController.text
              : null,
          photoUrl: photoUrl,
          createdAt: DateTime.now(),
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.userId)
            .set(user.toMap());
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('User registered successfully in Firebase'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Registration error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register New User')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: _pickedFile != null
                    ? (kIsWeb
                        ? MemoryImage(_webImage!)
                        : NetworkImage(_pickedFile!.path) as ImageProvider)
                    : null,
                child: _pickedFile == null
                    ? const Icon(Icons.camera_alt, size: 40)
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
                controller: _idController,
                decoration:
                    const InputDecoration(labelText: 'Roll No / Employee ID')),
            const SizedBox(height: 16),
            TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name')),
            const SizedBox(height: 16),
            DropdownButtonFormField<UserRole>(
              initialValue: _selectedRole,
              items: UserRole.values
                  .map((role) => DropdownMenuItem(
                      value: role, child: Text(role.name.toUpperCase())))
                  .toList(),
              onChanged: (val) => setState(() => _selectedRole = val!),
              decoration: const InputDecoration(labelText: 'Role'),
            ),
            if (_selectedRole == UserRole.student) ...[
              const SizedBox(height: 16),
              TextField(
                  controller: _sectionController,
                  decoration:
                      const InputDecoration(labelText: 'Section (e.g. CSE-A)')),
            ],
            const SizedBox(height: 32),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _register, child: const Text('Register User')),
          ],
        ),
      ),
    );
  }
}
