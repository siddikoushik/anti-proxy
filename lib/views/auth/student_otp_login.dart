import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

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
    bool success = await AuthService()
        .verifyOTP(_userIdController.text, _otpController.text);
    if (success) {
      // Anonymous join
      if (!AuthService.isPrototypeMode) {
        try {
          await AuthService().signInAnonymously();
          if (mounted) {
            Navigator.pop(context); // Close the OTP dialog/screen
          }
          // The AuthWrapper will detect the state change and automatically swap the screen
          // Do NOT call Navigator.pop(context) here, because the widget will be unmounted
          // instantly by Riverpod, causing an error that freezes the UI loop.
        } catch (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Login failed: $e')));
          }
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Invalid OTP')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student OTP Login')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _userIdController,
              decoration:
                  const InputDecoration(labelText: 'Student Roll No / User ID'),
              enabled: !_otpRequested,
            ),
            if (_otpRequested) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                decoration: const InputDecoration(
                  labelText: 'Enter OTP (from Admin)',
                  hintText: 'Enter 6-digit OTP provided by Admin',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 32),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _otpRequested ? _verifyAndLogin : _requestOtp,
                    child:
                        Text(_otpRequested ? 'Verify & Login' : 'Request OTP'),
                  ),
          ],
        ),
      ),
    );
  }
}
