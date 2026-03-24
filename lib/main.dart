import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_size/window_size.dart';

import 'app.dart';

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
        url: 'https://ikkfdwjmqujgkokpqhez.supabase.co',
        anonKey: 'sb_publishable_V_ZkAzVmYbRAt3t2GQFdwg_46pY42yZ',
      );
      _supabaseInitialized = true;
    } on AssertionError catch (_) {
      _supabaseInitialized = true; // Already initialized (hot restart).
    }
  }
  runApp(const SaasApp());
}
