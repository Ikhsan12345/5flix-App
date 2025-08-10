import 'package:flutter/material.dart';
import 'package:five_flix/services/api_service.dart';
import 'package:five_flix/services/session_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String username = '';
  String password = '';
  bool _obscureText = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  // Check if user already has valid session
  Future<void> _checkExistingSession() async {
    try {
      final session = await SessionService.getSession();
      if (session != null && session['token'] != null) {
        // Set token to ApiService
        ApiService.setAuthToken(session['token']);
        
        // Test if token is still valid
        final videos = await ApiService.getVideos();
        if (videos.isNotEmpty || await ApiService.checkConnection()) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home', arguments: {
              'role': session['user']['role'] ?? 'user',
              'username': session['user']['username'] ?? '',
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Session check error: $e');
      // Continue to login screen
    }
  }

  Future<void> _onLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        debugPrint('Login attempt for user: $username');
        
        // Gunakan API untuk login - token akan di-set otomatis di ApiService.login()
        final result = await ApiService.login(username, password);
        
        debugPrint('Login result: $result');

        if (result['success'] == true) {
          final userRole = result['user']['role'];
          final userToken = result['token'];
          final userUsername = result['user']['username'];

          debugPrint('Login successful - Role: $userRole, Token available: ${userToken != null}');

          // Simpan session
          await SessionService.saveSession(userToken, result['user']);
          
          // Verify token is set in ApiService (should be automatic from login)
          final currentToken = ApiService.getCurrentToken();
          debugPrint('Current token in ApiService: ${currentToken != null ? '${currentToken.substring(0, 10)}...' : 'null'}');

          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home', arguments: {
              'role': userRole,
              'username': userUsername,
            });
          }
        } else {
          debugPrint('Login failed: ${result['message']}');
          _showErrorDialog(result['message'] ?? 'Login gagal');
        }
      } catch (e) {
        debugPrint('Login error: $e');
        _showErrorDialog('Network error: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: const Text('Login Gagal', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Color(0xFFB3B3B3))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFFE50914))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 1),
                      // Logo
                      Container(
                        constraints: const BoxConstraints(maxHeight: 120, maxWidth: 200),
                        child: Image.asset(
                          'lib/images/bannerlogo1.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.movie, color: Colors.white, size: 80),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Log In',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Username
                            TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Username',
                                labelStyle: const TextStyle(color: Color(0xFFB3B3B3)),
                                prefixIcon: const Icon(Icons.person, color: Color(0xFFB3B3B3)),
                                filled: true,
                                fillColor: const Color(0xFF181818),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, 
                                  vertical: 16
                                ),
                              ),
                              onChanged: (val) => username = val.trim(),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Username wajib diisi' : null,
                            ),
                            const SizedBox(height: 18),
                            // Password
                            TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: const TextStyle(color: Color(0xFFB3B3B3)),
                                prefixIcon: const Icon(Icons.lock, color: Color(0xFFB3B3B3)),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureText ? Icons.visibility_off : Icons.visibility,
                                    color: const Color(0xFFB3B3B3),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureText = !_obscureText;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: const Color(0xFF181818),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, 
                                  vertical: 16
                                ),
                              ),
                              obscureText: _obscureText,
                              onChanged: (val) => password = val,
                              validator: (val) =>
                                  val == null || val.isEmpty ? 'Password wajib diisi' : null,
                            ),
                            const SizedBox(height: 24),
                            // Tombol Login
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE50914),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: _isLoading ? null : _onLogin,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : const Text(
                                        'Login',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextButton(
                        onPressed: _isLoading ? null : () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: const Text(
                          "Belum punya akun? Daftar",
                          style: TextStyle(color: Color(0xFFB3B3B3)),
                        ),
                      ),
                      const Spacer(flex: 1),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}