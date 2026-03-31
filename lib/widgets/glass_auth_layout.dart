import 'dart:ui';
import 'package:flutter/material.dart';

class GlassAuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const GlassAuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // We extend backend behind the AppBar (if any screen tries to add one, though in this layout we won't need it)
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Gradient matching EduBridge aesthetics
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // Decorative blurry circles in the background
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF90CAF9).withOpacity(0.3),
              ),
            ),
          ),
          
          // Top Navigation / Back Button (optional, but handled inherently if pushed via Navigator usually.
          // Since it's a Scaffold, we can manually add a safe back button if needed, but not on root selection)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Navigator.canPop(context) ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0D47A1)),
                onPressed: () => Navigator.pop(context),
              ) : const SizedBox.shrink(),
            ),
          ),

          // Center Foreground Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(24.0),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.8),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo Row
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.security_rounded,
                              size: 32,
                              color: Color(0xFF0D47A1), // primaryBlue
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Smart Attendance',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Title & Subtitle
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF212121),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF757575),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Form / Buttons
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
