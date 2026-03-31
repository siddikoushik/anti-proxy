import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/glass_auth_layout.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
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
    debugPrint('AdminLogin: Attempting login for ${_emailController.text}');

    try {
      final auth = ref.read(authServiceProvider);
      await auth.signInWithEmail(
          _emailController.text, _passwordController.text);

      debugPrint('AdminLogin: Login successful');
      if (mounted) {
        Navigator.pop(context); // Go back, AuthWrapper will handle the rest
      }
    } catch (e) {
      debugPrint('AdminLogin: Login error: $e');
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

  @override
  Widget build(BuildContext context) {
    return GlassAuthLayout(
      title: 'Admin Access',
      subtitle: 'Sign in to manage the system',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
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
          const SizedBox(height: 32),
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
