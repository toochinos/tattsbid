import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_size/window_size.dart';

import 'app.dart';

bool _supabaseInitialized = false;

/// Supabase project URL (Dashboard → Settings → API).
const String _supabaseUrl = 'https://ikkfdwjmqujgkokpqhez.supabase.co';

/// Supabase anon key (JWT). Keep in sync with Dashboard → Settings → API.
const String _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlra2Zkd2ptcXVqZ2tva3BxaGV6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzNDczMTEsImV4cCI6MjA4NzkyMzMxMX0.R55-7QT3xUC5lhhtOYwz5g1u23gpusJsSNjbvbXIzDY';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('SaaS App');
    setWindowMinSize(const Size(375, 812));
    setWindowMaxSize(const Size(375, 812));
  }

  if (!_supabaseInitialized) {
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseAnonKey,
      );
      _supabaseInitialized = true;
    } on AssertionError {
      _supabaseInitialized = true;
    }
  }

  // Startup routing (onboarding + session) lives in [StartupRouter] — [MaterialApp.home] in [SaasApp].
  runApp(const SaasApp());
}
