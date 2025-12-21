// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:one_room/firebase_options.dart';

import 'package:one_room/main.dart' as app;

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    // Ensure bindings and initialize Firebase for tests.
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(const app.RootApp());
    await tester.pump();

    // The root widget should include a MaterialApp via MyApp inside RootApp.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
