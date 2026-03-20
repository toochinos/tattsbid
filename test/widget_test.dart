// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify the values of widget properties.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:saas_app/app.dart';

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('App loads and shows landing page when unauthenticated',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SaasApp());
    await tester.pumpAndSettle();

    expect(find.text('Landing Page'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
