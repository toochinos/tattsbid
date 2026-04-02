// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify the values of widget properties.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:saas_app/app.dart';
import 'package:saas_app/screens/startup_router.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'seenOnboarding': true,
    });
    await Supabase.initialize(
      url: 'https://ikkfdwjmqujgkokpqhez.supabase.co',
      anonKey: 'sb_publishable_V_ZkAzVmYbRAt3t2GQFdwg_46pY42yZ',
    );
  });

  testWidgets('App routes to login when unauthenticated after startup',
      (WidgetTester tester) async {
    final snapshot = await StartupSnapshot.load();
    await tester.pumpWidget(SaasApp(startupSnapshot: snapshot));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Login'), findsWidgets);
  });
}
