import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trasia/main.dart';

void main() {
  testWidgets('Trasia user dashboard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TrasiaApp());

    expect(find.text('TRASIA'), findsOneWidget);

    await tester.tap(find.byKey(const Key('start-now')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-user')), findsOneWidget);
    await tester.tap(find.byKey(const Key('login-user')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Transit Matrix Router'), findsNothing);
    expect(find.text('Search and Navigate'), findsOneWidget);
    expect(find.byKey(const Key('feature-a-destination')), findsOneWidget);
  });
}
