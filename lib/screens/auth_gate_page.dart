import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/routes/app_routes.dart';

/// **After login only** (e.g. [AuthScreen] → [AppRoutes.root]): session → Explore ([AppRoutes.dashboard]), else Login.
class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirect();
    });
  }

  void _redirect() {
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (kDebugMode) {
      debugPrint(
        '[Startup] AuthGate: session=${session != null} → '
        '${session != null ? AppRoutes.dashboard : AppRoutes.auth}',
      );
    }
    if (session != null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
