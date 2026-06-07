import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/locale/app_locale_controller.dart';
import 'core/navigation/link_handler.dart';
import 'core/routes/app_routes.dart';
import 'core/services/auth_service.dart';
import 'core/services/online_heartbeat_service.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'screens/startup_router.dart';

class SaasApp extends StatefulWidget {
  const SaasApp({super.key, required this.startupSnapshot});

  final StartupSnapshot startupSnapshot;

  @override
  State<SaasApp> createState() => _SaasAppState();
}

class _SaasAppState extends State<SaasApp> with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSub;
  bool _supabaseReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LinkHandler.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initSupabaseAfterFirstFrame());
    });
  }

  Future<void> _initSupabaseAfterFirstFrame() async {
    await ensureSupabaseInitialized();
    await applyStartupTestingAfterSupabase();
    if (!mounted) return;

    _supabaseReady = true;
    _authSub = AuthService.authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedIn && state.session != null) {
        debugPrint(
          'SaasApp: auth signedIn user_id=${state.session!.user.id} — starting heartbeat',
        );
        OnlineHeartbeatService.start();
      } else if (state.event == AuthChangeEvent.signedOut) {
        debugPrint('SaasApp: auth signedOut — heartbeat already stopped');
        OnlineHeartbeatService.stop();
      }
    });

    if (readSupabaseSessionIfReady() != null) {
      debugPrint('SaasApp: restored session — starting heartbeat');
      OnlineHeartbeatService.start();
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_supabaseReady) return;
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('SaasApp: lifecycle resumed — starting heartbeat');
        OnlineHeartbeatService.start();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        debugPrint('SaasApp: lifecycle $state — going offline');
        unawaited(OnlineHeartbeatService.goOffline());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Transient on iOS — heartbeat keeps running until paused/detached.
        break;
    }
  }

  @override
  void dispose() {
    OnlineHeartbeatService.stop();
    _authSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
