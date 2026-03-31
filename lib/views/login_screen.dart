import 'package:flutter/material.dart';
import '../widgets/large_button.dart';
import '../widgets/glass_auth_layout.dart';
import 'auth/admin_login_screen.dart';
import 'auth/faculty_login_screen.dart';
import 'auth/student_otp_login.dart';

class LoginSelectionScreen extends StatelessWidget {
  const LoginSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassAuthLayout(
      title: 'Welcome Back',
      subtitle: 'Select your role to continue securely',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LargeButton(
            title: 'Administrator',
            icon: Icons.admin_panel_settings_rounded,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
            ),
          ),
          const SizedBox(height: 16),
          LargeButton(
            title: 'Faculty Member',
            icon: Icons.school_rounded,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FacultyLoginScreen()),
            ),
          ),
          const SizedBox(height: 16),
          LargeButton(
            title: 'Student',
            icon: Icons.person_rounded,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudentOtpLogin()),
            ),
          ),
        ],
      ),
    );
  }
}
