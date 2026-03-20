import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_size/window_size.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';

bool _supabaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('SaaS App');
    setWindowMinSize(const Size(375, 812));
    setWindowMaxSize(const Size(375, 812));
  }
  if (!_supabaseInitialized) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      _supabaseInitialized = true;
    } on AssertionError catch (_) {
      _supabaseInitialized = true; // Already initialized (hot restart).
    }
  }
  runApp(const SaasApp());
}
