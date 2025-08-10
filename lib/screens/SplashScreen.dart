import 'HomeScreen.dart';
import 'package:five_flix/services/session_service.dart';

class SplashScreen extends StatefulWidget {
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
    await Future.delayed(Duration(seconds: 2)); // Loading animation
    
    final session = await SessionService.getSession();
    if (session != null) {
      // Auto login jika ada session
      Navigator.pushReplacementNamed(context, '/home', 
        arguments: session['user']);
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}