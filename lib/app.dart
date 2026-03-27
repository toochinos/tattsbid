import 'package:flutter/material.dart';

import 'core/navigation/link_handler.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';

class SaasApp extends StatefulWidget {
  const SaasApp({super.key});

  @override
  State<SaasApp> createState() => _SaasAppState();
}

class _SaasAppState extends State<SaasApp> {
  @override
  void initState() {
    super.initState();
    LinkHandler.init();
  }

  @override
  void dispose() {
    LinkHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, mode, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: LinkHandler.navigatorKey,
        title: 'SaaS App',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        initialRoute: AppRoutes.root,
        routes: AppRoutes.routes,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        builder: (context, child) => DefaultTextStyle(
          textAlign: TextAlign.center,
          style: DefaultTextStyle.of(context).style,
          child: child!,
        ),
      ),
    );
  }
}
