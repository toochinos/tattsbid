import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../core/services/auth_service.dart';

/// Shows loading then redirects to Dashboard if logged in, Landing if not.
/// Used as the app's initial route so session is checked on startup.
class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // Wait for first auth state (Supabase restores session from storage).
    final state = await AuthService.authStateChanges.first;
    if (!mounted) return;
    final route = state.session != null ? AppRoutes.dashboard : AppRoutes.auth;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
