import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/glass_auth_layout.dart';

class FacultyLoginScreen extends ConsumerStatefulWidget {
  const FacultyLoginScreen({super.key});

  @override
  ConsumerState<FacultyLoginScreen> createState() => _FacultyLoginScreenState();
}

class _FacultyLoginScreenState extends ConsumerState<FacultyLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    debugPrint('FacultyLogin: Attempting login for ${_emailController.text}');

    try {
      await ref
          .read(authServiceProvider)
          .signInWithEmail(_emailController.text, _passwordController.text);

      debugPrint('FacultyLogin: Login success');
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('FacultyLogin: Login error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Login Failed: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your institutional email first to receive a reset link.')),
      );
      return;
    }

    try {
      // Security Check: Manually query Firestore to ensure this email is actually an active Faculty.
      // Firebase Auth obscures "user-not-found" by default to prevent enumeration attacks.
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: 'faculty')
          .limit(1)
          .get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception('No active faculty account found for this email address.');
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset link sent! Check your inbox.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        // Strip the raw Exception text to look cleaner
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassAuthLayout(
      title: 'Faculty Portal',
      subtitle: 'Sign in to manage classes and attendance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Institutional Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _resetPassword,
              child: const Text('Forgot Password?', style: TextStyle(color: Colors.blue)),
            ),
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  onPressed: _login,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In'),
                ),
        ],
      ),
    );
  }
}
