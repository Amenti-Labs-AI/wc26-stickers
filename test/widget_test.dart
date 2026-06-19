import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:panini_wc26_tracker/main.dart';

void main() {
  testWidgets('App shell renders navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PaniniApp()));
    await tester.pump();
    expect(find.text('Collection'), findsOneWidget);
  });
}
