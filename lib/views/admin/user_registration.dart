import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../models/class_model.dart';
import '../../services/auth_service.dart';
import '../../services/class_service.dart';

class UserRegistration extends ConsumerStatefulWidget {
  const UserRegistration({super.key});

  @override
  ConsumerState<UserRegistration> createState() => _UserRegistrationState();
}

class _UserRegistrationState extends ConsumerState<UserRegistration> {
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _selectedRole = UserRole.student;
  XFile? _pickedFile;
  Uint8List? _webImage;
  bool _isLoading = false;

  String? _selectedYear;
  String? _selectedBranch;
  String? _selectedSection;

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

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    // Student photo is now optional due to billing issues, but we will still warn if other fields are missing.
    if (_selectedRole == UserRole.student && _selectedSection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Year, Branch and Section required for Student')));
      return;
    }
    if (_selectedRole != UserRole.student &&
        (_emailController.text.isEmpty || _passwordController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Email and Password required for Faculty/Admin')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? photoUrl;

      if (!AuthService.isPrototypeMode) {
        if (_pickedFile != null) {
          debugPrint('Registration: Uploading photo...');
          try {
            final bytes = await _pickedFile!.readAsBytes();
            final ref = FirebaseStorage.instance
                .ref()
                .child('user_photos/${_idController.text}.jpg');

            final metadata = SettableMetadata(contentType: 'image/jpeg');
            await ref.putData(bytes, metadata).timeout(
                const Duration(seconds: 15),
                onTimeout: () =>
                    throw 'Photo upload timed out (CORS or Permissions?)');

            debugPrint('Registration: Getting photo URL...');
            photoUrl = await ref.getDownloadURL().timeout(
                const Duration(seconds: 15),
                onTimeout: () => throw 'Getting photo URL timed out');
          } catch (e) {
            debugPrint('Storage error: $e. Using fallback image.');
            photoUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_nameController.text.trim())}&background=random';
          }
        } else if (_selectedRole == UserRole.student) {
           // Provide a fallback avatar if no image was selected but they are a student
           photoUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_nameController.text.trim())}&background=random';
        }

        String? authUid;
        if (!AuthService.isPrototypeMode && _selectedRole != UserRole.student) {
          debugPrint('Registration: Creating Auth account...');
          final cred = await AuthService().createUserWithEmail(
              _emailController.text, _passwordController.text);
          authUid = cred.user?.uid;
        }

        debugPrint('Registration: Creating Firestore document...');
        final cleanUserId = _idController.text.trim().toUpperCase();
        
        final combinedSection = _selectedRole == UserRole.student
            ? '$_selectedYear-$_selectedBranch-$_selectedSection'
            : null;

        final user = UserModel(
          userId: cleanUserId,
          name: _nameController.text.trim(),
          role: _selectedRole,
          section: combinedSection,
          photoUrl: photoUrl,
          email: _selectedRole != UserRole.student
              ? _emailController.text.trim()
              : null,
          authUid: authUid,
          createdAt: DateTime.now(),
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.userId)
            .set(user.toMap())
            .timeout(const Duration(seconds: 15),
                onTimeout: () =>
                    throw 'Firestore write timed out (Check Rules)');
        debugPrint('Registration: Success!');
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

  Widget _buildTextField(TextEditingController controller, String label, {bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue.shade600, width: 2), borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classService = ref.watch(classServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Register New User', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 64,
                            backgroundColor: Colors.blue.shade50,
                            backgroundImage: _pickedFile != null
                                ? (kIsWeb ? MemoryImage(_webImage!) : NetworkImage(_pickedFile!.path) as ImageProvider)
                                : null,
                            child: _pickedFile == null ? Icon(Icons.person, size: 64, color: Colors.blue.shade200) : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('User Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildTextField(_idController, 'Roll No / Employee ID'),
                  const SizedBox(height: 16),
                  _buildTextField(_nameController, 'Full Name'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserRole>(
                    initialValue: _selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.name.toUpperCase()))).toList(),
                    onChanged: (val) => setState(() => _selectedRole = val!),
                  ),
                  
                  if (_selectedRole == UserRole.student) ...[
                    const SizedBox(height: 24),
                    const Text('Class Assignment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    StreamBuilder<List<ClassModel>>(
                      stream: classService.getClasses(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final classes = snapshot.data!;
                        
                        final years = classes.map((c) => c.year).toSet().toList()..sort();
                        if (!years.contains(_selectedYear)) {
                          _selectedYear = null; _selectedBranch = null; _selectedSection = null;
                        }
                        
                        List<String> branches = [];
                        if (_selectedYear != null) {
                          branches = classes.where((c) => c.year == _selectedYear).map((c) => c.branch).toSet().toList()..sort();
                        }
                        if (!branches.contains(_selectedBranch)) {
                          _selectedBranch = null; _selectedSection = null;
                        }

                        List<String> sections = [];
                        if (_selectedYear != null && _selectedBranch != null) {
                          sections = classes.where((c) => c.year == _selectedYear && c.branch == _selectedBranch).map((c) => c.section).toSet().toList()..sort();
                        }
                        if (!sections.contains(_selectedSection)) {
                          _selectedSection = null;
                        }

                        return Row(
                          children: [
                            Expanded(child: DropdownButtonFormField<String>(
                              isExpanded: true, initialValue: _selectedYear,
                              decoration: InputDecoration(labelText: 'Year', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12))),
                              items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                              onChanged: (val) => setState(() => _selectedYear = val),
                            )),
                            const SizedBox(width: 8),
                            Expanded(flex: 2, child: DropdownButtonFormField<String>(
                              isExpanded: true, initialValue: _selectedBranch,
                              decoration: InputDecoration(labelText: 'Branch', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12))),
                              items: branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                              onChanged: _selectedYear != null ? (val) => setState(() => _selectedBranch = val) : null,
                            )),
                            const SizedBox(width: 8),
                            Expanded(child: DropdownButtonFormField<String>(
                              isExpanded: true, initialValue: _selectedSection,
                              decoration: InputDecoration(labelText: 'Sec', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12))),
                              items: sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: _selectedBranch != null ? (val) => setState(() => _selectedSection = val) : null,
                            )),
                          ],
                        );
                      },
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    const Text('Authentication', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildTextField(_emailController, 'Email Address'),
                    const SizedBox(height: 16),
                    _buildTextField(_passwordController, 'Password', obscureText: true),
                  ],
                  const SizedBox(height: 48),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: _register,
                          icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                          label: const Text('Register User', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
