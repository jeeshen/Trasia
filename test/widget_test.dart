import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    await tester.tap(find.text('Start Trip'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.alt_route_rounded), findsNothing);
    await tester.tap(find.text('Arrived'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.drag(
      find.byKey(const Key('feature-c-results-list')),
      const Offset(0, -700),
    );
    await tester.pump();

    expect(find.text('Done'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('feature-c-results-list')),
      const Offset(0, 700),
    );
    await tester.pump();

    expect(find.text('Going'), findsOneWidget);

    await tester.ensureVisible(find.text('Going'));
    await tester.pump();
    await tester.tap(find.text('Going'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Search and Navigate'), findsOneWidget);
  });

  testWidgets('Profile shows the account and requested settings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TrasiaApp());

    await tester.ensureVisible(find.byKey(const Key('login-user')));
    await tester.tap(find.byKey(const Key('login-user')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Account'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('preview-user@trasia.local'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    final profileList = find.ancestor(
      of: find.text('Profile'),
      matching: find.byType(ListView),
    );
    await tester.drag(profileList, const Offset(0, -260));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Terms & Conditions'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Plan completion persists favorites and history', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TrasiaApp());

    await tester.ensureVisible(find.byKey(const Key('login-user')));
    await tester.tap(find.byKey(const Key('login-user')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Plan'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('generate-route')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('feature-c-results-toggle')));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Start Trip'));
    await tester.pump(const Duration(milliseconds: 300));
    for (var stop = 0; stop < 3; stop++) {
      await tester.tap(find.text('Arrived'));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('generate-route')), findsOneWidget);
    expect(find.byKey(const Key('feature-c-results-map')), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    final accountKey = base64Url
        .encode(utf8.encode('preview-user@trasia.local'))
        .replaceAll('=', '');
    final favorites =
        jsonDecode(preferences.getString('trasia.favorite.places.$accountKey')!)
            as List<dynamic>;
    final history =
        jsonDecode(preferences.getString('trasia.trip.history.$accountKey')!)
            as List<dynamic>;
    expect(favorites, hasLength(1));
    expect(history, hasLength(3));
    expect(
      history.every(
        (entry) => (entry as Map<String, dynamic>)['category'] == 'Plan',
      ),
      isTrue,
    );

    final favoriteName =
        (favorites.first as Map<String, dynamic>)['name'] as String;
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
        .clearSnackBars();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Account'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Favorites'));
    await tester.tap(find.text('Favorites'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text(favoriteName));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(favoriteName));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Go again?'), findsOneWidget);
    await tester.tap(find.text('Yes'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Search and Navigate'), findsOneWidget);
  });
}
