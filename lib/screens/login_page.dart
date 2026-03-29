import 'package:flutter/material.dart';

import 'auth_screen.dart';

/// Same UI as [AuthScreen]: **Login** and **Sign up** in one screen (tab bar).
///
/// Used after onboarding and from [AppRoutes.login]; cold start unauthenticated
/// flow uses [AppRoutes.auth] which is also [AuthScreen].
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => const AuthScreen();
}
