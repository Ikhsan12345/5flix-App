import 'package:flutter/material.dart';
import 'package:five_flix/services/session_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Show loading animation for 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    try {
      final session = await SessionService.getSession();
      if (!mounted) return;

      if (session != null) {
        // Auto login jika ada session
        Navigator.pushReplacementNamed(context, '/home', arguments: {
          'role': session['user']['role'],
          'username': session['user']['username'],
          'token': session['token']
        });
      } else {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      // Jika ada error, redirect ke login
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'lib/images/bannerlogo1.png',
              height: 120,
              errorBuilder: (context, error, stackTrace) => const Text(
                '5FLIX',
                style: TextStyle(
                  color: Color(0xFFE50914),
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}