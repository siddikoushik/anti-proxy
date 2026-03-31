import '../../services/auth_service.dart';
import 'package:flutter/material.dart';
import '../../widgets/glass_auth_layout.dart';

class StudentOtpLogin extends StatefulWidget {
  const StudentOtpLogin({super.key});

  @override
  State<StudentOtpLogin> createState() => _StudentOtpLoginState();
}

class _StudentOtpLoginState extends State<StudentOtpLogin> {
  final _userIdController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpRequested = false;
  bool _isLoading = false;

  Future<void> _requestOtp() async {
    setState(() => _isLoading = true);
    bool success = await AuthService().requestOTP(_userIdController.text);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (success) _otpRequested = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'OTP Requested' : 'User not found')));
    }
  }

  Future<void> _verifyAndLogin() async {
    setState(() => _isLoading = true);
    try {
      bool success = await AuthService()
          .verifyOTP(_userIdController.text, _otpController.text);
      if (success) {
        // Anonymous join
        final authService = AuthService();
        final userCred = await authService.signInAnonymously();

        setState(() => _isLoading = true);

        // Link the student ID to this anonymous Auth UID
        await authService.linkStudentAuth(
            _userIdController.text.trim().toUpperCase(), userCred.user!.uid);

        // Small delay to ensure Firestore write propagates to query indexes
        await Future.delayed(const Duration(milliseconds: 1000));

        if (mounted) {
          Navigator.pop(context); // Close the OTP dialog/screen
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Invalid OTP'),
                ],
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassAuthLayout(
      title: 'Student Portal',
      subtitle: 'Enter your ID to receive an OTP',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _userIdController,
            decoration: const InputDecoration(
              labelText: 'Student Roll No / ID',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            enabled: !_otpRequested,
          ),
          if (_otpRequested) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              decoration: const InputDecoration(
                labelText: 'Enter OTP',
                hintText: '6-digit OTP from Admin',
                prefixIcon: Icon(Icons.password_outlined),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 32),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  onPressed: _otpRequested ? _verifyAndLogin : _requestOtp,
                  icon: Icon(_otpRequested ? Icons.login : Icons.send_rounded),
                  label: Text(_otpRequested ? 'Verify & Login' : 'Request OTP'),
                ),
        ],
      ),
    );
  }
}
