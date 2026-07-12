import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/features/collection/collection_providers.dart';
import 'package:panini_wc26_tracker/features/settings/settings_screen.dart';
import 'package:panini_wc26_tracker/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App shell renders navigation', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PaniniApp(initialSetupComplete: true),
      ),
    );
    await tester.pump();
    expect(find.text('Collection'), findsWidgets);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('Settings shows Instructions tiles', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pump();

    expect(find.text('INSTRUCTIONS'), findsOneWidget);
    expect(find.text('Collection modes'), findsOneWidget);
    expect(find.text('Scanning'), findsOneWidget);
    expect(find.textContaining('not affiliated'), findsOneWidget);
    expect(find.text('DATA'), findsOneWidget);
  });

  testWidgets('shell tab index provider defaults to Home', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(shellTabIndexProvider), 0);
    container.read(shellTabIndexProvider.notifier).state = 3;
    expect(container.read(shellTabIndexProvider), 3);
  });
}
