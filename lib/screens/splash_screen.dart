import 'dart:async';

import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../core/services/auth_service.dart';

/// Shows the TATTSBID splash image on startup, then redirects based on auth.
/// Works on all platforms (including desktop where native splash is not supported).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration _minDisplayDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    final start = DateTime.now();

    // Wait for auth to be ready (Supabase restores session from storage).
    await AuthService.authStateChanges.first;

    // Ensure splash shows for at least _minDisplayDuration.
    final elapsed = DateTime.now().difference(start);
    if (elapsed < _minDisplayDuration) {
      await Future<void>.delayed(_minDisplayDuration - elapsed);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.auth);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ColoredBox(
        color: Colors.white,
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FittedBox(
              fit: BoxFit.contain,
              child: Image.asset(
                'assets/logo.png',
                errorBuilder: (_, __, ___) => const CircularProgressIndicator(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
