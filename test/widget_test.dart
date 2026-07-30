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

    await tester.enterText(
      find.byKey(const Key('feature-a-destination')),
      'Keep this transit trip',
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('nav-dashboard')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('nav-account')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('nav-transit')));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Keep this transit trip'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('feature-a-destination')), '');
    await tester.pump();
  });

  testWidgets('Feature C shows map after generating results', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TrasiaApp());

    await tester.ensureVisible(find.byKey(const Key('login-user')));
    await tester.tap(find.byKey(const Key('login-user')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byKey(const Key('nav-plan')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('generate-route')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('feature-c-results-map')), findsOneWidget);
    expect(find.byKey(const Key('feature-c-results-toggle')), findsOneWidget);
    expect(find.byKey(const Key('feature-c-results-list')), findsNothing);

    globalMapViewNotifier.value.extraMarkers.first.onTap?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('feature-c-stop-details')), findsOneWidget);
    expect(find.textContaining('Opening hours:'), findsOneWidget);
    expect(find.textContaining('Distance:'), findsOneWidget);
    expect(find.textContaining('Cost: RM'), findsOneWidget);
    expect(find.text('Going'), findsOneWidget);
    expect(find.text('Continue itinerary'), findsNothing);
    Navigator.of(
      tester.element(find.byKey(const Key('feature-c-stop-details'))),
    ).pop();
    await tester.pump(const Duration(milliseconds: 300));

    globalMapViewNotifier.value.extraMarkers.elementAt(1).onTap?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Queue'), findsOneWidget);
    final queueButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Queue'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(queueButton.onPressed, isNull);
    Navigator.of(
      tester.element(find.byKey(const Key('feature-c-stop-details'))),
    ).pop();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('feature-c-results-toggle')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('feature-c-results-list')), findsOneWidget);
    await tester.tap(find.text('Start Trip'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.alt_route_rounded), findsNothing);
    expect(find.text('Arrived'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-dashboard')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('nav-account')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('nav-plan')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Arrived'), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('nav-account')));
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

  testWidgets('Plan can end before starting and persists history', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TrasiaApp());

    await tester.ensureVisible(find.byKey(const Key('login-user')));
    await tester.tap(find.byKey(const Key('login-user')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byKey(const Key('nav-plan')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('generate-route')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('feature-c-results-toggle')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('demo-arrival')));
    await tester.pump();
    expect(
      tester
          .widget<TransitRouterScreen>(
            find.byType(TransitRouterScreen, skipOffstage: false),
          )
          .demoArrivalRequest,
      0,
    );
    expect(
      tester
          .widget<HubPoolScreen>(
            find.byType(HubPoolScreen, skipOffstage: false),
          )
          .demoArrivalRequest,
      0,
    );
    expect(
      tester
          .widget<PelancongPlanScreen>(find.byType(PelancongPlanScreen))
          .demoArrivalRequest,
      1,
    );
    await tester.pump(const Duration(seconds: 2));

    final preferences = await SharedPreferences.getInstance();
    final accountKey = base64Url
        .encode(utf8.encode('preview-user@trasia.local'))
        .replaceAll('=', '');
    final history =
        jsonDecode(preferences.getString('trasia.trip.history.$accountKey')!)
            as List<dynamic>;
    expect(preferences.getString('trasia.favorite.places.$accountKey'), isNull);
    expect(history, hasLength(3));
    expect(
      history.every(
        (entry) => (entry as Map<String, dynamic>)['category'] == 'Plan',
      ),
      isTrue,
    );
  });

  testWidgets('Revisiting a favorite includes a Drive option', (
    WidgetTester tester,
  ) async {
    final accountKey = base64Url
        .encode(utf8.encode('preview-user@trasia.local'))
        .replaceAll('=', '');
    SharedPreferences.setMockInitialValues({
      'trasia.favorite.places.$accountKey': jsonEncode([
        {
          'name': 'Suria KLCC',
          'address': 'Kuala Lumpur City Centre',
          'hours': '10:00 - 22:00',
          'baseCost': 0,
          'suggestedDistanceKm': 0,
          'priceTier': 'midRange',
          'imageAsset': '',
          'color': 0xFF0B7CFF,
          'latitude': 3.1579,
          'longitude': 101.7123,
        },
      ]),
    });
    await tester.pumpWidget(const TrasiaApp());
    await tester.tap(find.byKey(const Key('login-user')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byKey(const Key('nav-account')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Favorites'));
    await tester.tap(find.text('Favorites'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('Suria KLCC'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Suria KLCC'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Yes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final transitScreen = tester.widget<TransitRouterScreen>(
      find.byType(TransitRouterScreen),
    );
    expect(transitScreen.destination, 'Suria KLCC');
    expect(transitScreen.requestedMode, isNull);
  });

  testWidgets('Revisiting a favorite from Hub-Pool stays in Hub-Pool', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final accountKey = base64Url
        .encode(utf8.encode('preview-user@trasia.local'))
        .replaceAll('=', '');
    SharedPreferences.setMockInitialValues({
      'trasia.favorite.places.$accountKey': jsonEncode([
        {
          'name': 'Suria KLCC',
          'address': 'Kuala Lumpur City Centre',
          'hours': '10:00 - 22:00',
          'baseCost': 0,
          'suggestedDistanceKm': 0,
          'priceTier': 'midRange',
          'imageAsset': '',
          'color': 0xFF0B7CFF,
          'latitude': 3.1579,
          'longitude': 101.7123,
        },
      ]),
    });
    await tester.pumpWidget(const TrasiaApp());
    await tester.tap(find.byKey(const Key('login-user')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byKey(const Key('nav-ride')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('nav-account')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Favorites'));
    await tester.tap(find.text('Favorites'));
    await tester.pump(const Duration(milliseconds: 300));
    final favoriteCard = tester.widget<InkWell>(
      find
          .ancestor(of: find.text('Suria KLCC'), matching: find.byType(InkWell))
          .last,
    );
    favoriteCard.onTap!();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Yes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final hubPoolScreen = tester.widget<HubPoolScreen>(
      find.byType(HubPoolScreen),
    );
    expect(hubPoolScreen.active, isTrue);
    expect(hubPoolScreen.requestedDestination?.name, 'Suria KLCC');

    await tester.tap(find.byKey(const Key('book-ride')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Finding a driver'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-dashboard')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('nav-account')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('nav-ride')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Finding a driver'), findsOneWidget);
    expect(find.text('Cancel Ride'), findsOneWidget);
  });
}
