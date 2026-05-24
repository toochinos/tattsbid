import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/supabase_config.dart';
import 'core/locale/app_locale_controller.dart';
import 'core/navigation/link_handler.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'screens/startup_router.dart';

class SaasApp extends StatefulWidget {
  const SaasApp({super.key, required this.startupSnapshot});

  final StartupSnapshot startupSnapshot;

  @override
  State<SaasApp> createState() => _SaasAppState();
}

class _SaasAppState extends State<SaasApp> {
  @override
  void initState() {
    super.initState();
    LinkHandler.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initSupabaseAfterFirstFrame());
    });
  }

  Future<void> _initSupabaseAfterFirstFrame() async {
    await ensureSupabaseInitialized();
    await applyStartupTestingAfterSupabase();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LinkHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppLocaleController>(
      builder: (context, languageProvider, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: AppTheme.themeModeNotifier,
          builder: (context, mode, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: LinkHandler.navigatorKey,
            title: 'TattsBid',
            locale: languageProvider.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [
              Locale('en'),
              Locale('km'),
              Locale('id'),
            ],
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            home: StartupRouter(snapshot: widget.startupSnapshot),
            routes: AppRoutes.routes,
            onGenerateRoute: AppRoutes.onGenerateRoute,
            builder: (context, child) => DefaultTextStyle(
              // Start alignment so message fields and chat don’t inherit centered /
              // stretched line layout from a global default.
              textAlign: TextAlign.start,
              style: DefaultTextStyle.of(context).style,
              child: child!,
            ),
          ),
        );
      },
    );
  }
}
