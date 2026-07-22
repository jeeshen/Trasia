import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trasia/main.dart';

void main() {
  testWidgets('Trasia user dashboard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TrasiaApp());

    expect(find.text('TRASIA'), findsOneWidget);

    expect(find.byKey(const Key('login-user')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('login-user')));
    await tester.tap(find.byKey(const Key('login-user')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Transit Matrix Router'), findsNothing);
    expect(find.text('Search and Navigate'), findsOneWidget);
    expect(find.byKey(const Key('feature-a-destination')), findsOneWidget);
  });

  testWidgets('Feature C shows map after generating results', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TrasiaApp());

    await tester.ensureVisible(find.byKey(const Key('login-user')));
    await tester.tap(find.byKey(const Key('login-user')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Plan'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('generate-route')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('feature-c-results-map')), findsOneWidget);
    expect(find.byKey(const Key('feature-c-results-toggle')), findsOneWidget);
    expect(find.byKey(const Key('feature-c-results-list')), findsNothing);

    await tester.tap(find.byKey(const Key('feature-c-results-toggle')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('feature-c-results-list')), findsOneWidget);
  });
}
