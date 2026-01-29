import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:scrobbler/main.dart';
import 'package:scrobbler/pages/login_page.dart';
import 'package:scrobbler/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    _checkAuthAndNavigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Minimum display time for logo
    await Future.delayed(const Duration(seconds: 2));

    // Get local token
    final token = await AuthService.getToken();
    bool isValid = false;

    if (token != null) {
      try {
        final baseUrl = dotenv.env["API_BASE_URL"]!;

        final response = await http
            .get(
              Uri.parse('$baseUrl/users/me'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          isValid = true;
        } else {
          print("Token expired or invalid: ${response.statusCode}");
          await AuthService.logout();
        }
      } catch (e) {
        print("Network error or timeout during auth check: $e");
      }
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            isValid ? const ScrobblerHome() : const LoginPage(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Image.asset(
            'assets/images/logo_cue.png',
            width: 180,
            height: 180,
          ),
        ),
      ),
    );
  }
}
