import 'package:flutter/material.dart';
import 'package:five_flix/database/user_db_helper.dart';
import 'package:five_flix/models/user_model.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String username = '';
  String password = '';
  String confirmPassword = '';
  bool _obscureText = true;
  bool _isLoading = false;

  Future<void> _onRegister() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (username.trim().toLowerCase() == 'admin') {
        // Cegah pembuatan akun admin
        showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('Pendaftaran Ditolak'),
            content: Text('Username "admin" tidak diizinkan!'),
          ),
        );
        return;
      }

      setState(() => _isLoading = true);
      // Cek username sudah ada atau belum
      final db = await UserDbHelper.db;
      
      
      final res = await db.query('users', where: 'username = ?', whereArgs: [username]);
      if (res.isNotEmpty) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('Username sudah terdaftar'),
          ),
        );
        return;
      }

      // Simpan user ke SQLite
      await UserDbHelper.insertUser(UserModel(username: username, password: password));
      setState(() => _isLoading = false);
      if (!mounted) return;
      // Info berhasil, kembali ke login
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Registrasi Berhasil'),
          content: const Text('Silakan login dengan akun yang baru.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // tutup dialog
                Navigator.pop(context); // kembali ke login
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'lib/images/bannerlogo1.png',
                  fit: BoxFit.fill,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.movie, color: Colors.white, size: 80),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Sign Up',
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
                        ),
                        onChanged: (val) => username = val,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Username wajib diisi' : null,
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
                        ),
                        obscureText: _obscureText,
                        onChanged: (val) => password = val,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Password wajib diisi' : null,
                      ),
                      const SizedBox(height: 18),
                      // Konfirmasi Password
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Konfirmasi Password',
                          labelStyle: const TextStyle(color: Color(0xFFB3B3B3)),
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFB3B3B3)),
                          filled: true,
                          fillColor: const Color(0xFF181818),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        obscureText: true,
                        onChanged: (val) => confirmPassword = val,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Konfirmasi password wajib diisi';
                          } else if (val != password) {
                            return 'Konfirmasi password tidak cocok';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      // Tombol Daftar
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE50914),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoading ? null : _onRegister,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text(
                                  'Daftar',
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
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Sudah punya akun? Login",
                    style: TextStyle(color: Color(0xFFB3B3B3)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
