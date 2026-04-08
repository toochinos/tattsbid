import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_size/window_size.dart';

import 'app.dart';
import 'core/locale/app_locale_controller.dart';
import 'screens/startup_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('SaaS App');
    setWindowMinSize(const Size(375, 812));
    setWindowMaxSize(const Size(375, 812));
  }

  // UI is not blocked on Supabase — [SaasApp] initializes it after the first frame.
  final startupSnapshot = await StartupSnapshot.load();
  final localeController = AppLocaleController();
  await localeController.hydrate();
  runApp(
    ChangeNotifierProvider<AppLocaleController>.value(
      value: localeController,
      child: SaasApp(startupSnapshot: startupSnapshot),
    ),
  );
}
