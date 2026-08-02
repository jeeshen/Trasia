import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trasia/loading_compass.dart';
import 'package:trasia/main.dart';

void main() {
  testWidgets('shared loader uses the Trasia compass animation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TrasiaLoadingCompass(
          key: Key('test-loading-compass'),
          semanticLabel: 'Loading map',
        ),
      ),
    );

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('test-loading-compass')),
        matching: find.byType(Image),
      ),
    );
    expect(
      image.image,
      isA<AssetImage>().having(
        (asset) => asset.assetName,
        'assetName',
        'assets/branding/logo_loading.gif',
      ),
    );
    expect(find.bySemanticsLabel('Loading map'), findsOneWidget);
  });

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
    expect(find.byKey(const Key('kl-check-in-button')), findsOneWidget);

    final checkInButton = tester.widget<FilledButton>(
      find.byKey(const Key('kl-check-in-button')),
    );
    expect(checkInButton.onPressed, isNotNull);
    checkInButton.onPressed!();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kl-check-in-scanner')), findsNothing);

    await tester.tap(find.byKey(const Key('nav-dashboard')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('nav-account')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('nav-plan')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Arrived'), findsOneWidget);
    await tester.tap(find.text('Arrived'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.scrollUntilVisible(
      find.text('Done'),
      260,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('feature-c-results-list')),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.pump();

    expect(find.text('Done'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Going'),
      -260,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('feature-c-results-list')),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.pump();

    expect(find.text('Going'), findsOneWidget);

    await tester.ensureVisible(find.text('Going'));
    await tester.pump();
    await tester.tap(find.text('Going'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Search and Navigate'), findsOneWidget);
  });

  testWidgets('KL Blind Box reward redeems a KFC voucher code', (
    WidgetTester tester,
  ) async {
    final accountKey = base64Url
        .encode(utf8.encode('preview-user@trasia.local'))
        .replaceAll('=', '');
    SharedPreferences.setMockInitialValues({
      'trasia.reward.points.$accountKey': 40,
    });
    await tester.pumpWidget(const TrasiaApp());

    await tester.ensureVisible(find.byKey(const Key('login-user')));
    await tester.tap(find.byKey(const Key('login-user')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byKey(const Key('nav-plan')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.byKey(const Key('blind-box-rewards')),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('blind-box-rewards')));
    await tester.pumpAndSettle();

    expect(find.text('Rewards'), findsWidgets);
    expect(find.byKey(const Key('reward-points-balance')), findsOneWidget);
    expect(find.text('600'), findsOneWidget);
    expect(find.text('RM5 HubPool Credit'), findsOneWidget);
    expect(find.text('RM10 HubPool Credit'), findsOneWidget);
    expect(find.text('RM5 KFC Voucher'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reward-kfc-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reward-redeem-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reward-voucher-saved')), findsOneWidget);
    expect(
      find.text('Your KFC voucher has been added to My Vouchers.'),
      findsOneWidget,
    );
    expect(find.text('TRASIA-KFC-RM5'), findsNothing);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(RewardsPage))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-account')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-vouchers')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('profile-vouchers')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('voucher-wallet-page')), findsOneWidget);
    expect(find.text('My Vouchers'), findsOneWidget);
    expect(find.text('Available (1)'), findsOneWidget);
    expect(find.text('History (0)'), findsOneWidget);
    expect(find.byKey(const Key('saved-voucher-kfc-image')), findsOneWidget);
    expect(find.byKey(const Key('saved-voucher-code')), findsNothing);
    expect(find.text('TRASIA-KFC-RM5'), findsNothing);

    await tester.tap(find.text('RM5 KFC Voucher'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('saved-voucher-code')), findsOneWidget);
    expect(find.text('TRASIA-KFC-RM5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mark-voucher-used')));
    await tester.pumpAndSettle();
    expect(find.text('Available (0)'), findsOneWidget);
    expect(find.text('History (1)'), findsOneWidget);
    expect(find.byKey(const Key('confirm-voucher-used')), findsNothing);

    await tester.tap(find.text('History (1)'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('saved-voucher-code')), findsNothing);
    expect(find.text('TRASIA-KFC-RM5'), findsNothing);
    expect(find.byKey(const Key('saved-voucher-used-stamp')), findsOneWidget);

    await tester.tap(find.text('RM5 KFC Voucher'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('saved-voucher-code')), findsOneWidget);
    expect(find.text('TRASIA-KFC-RM5'), findsOneWidget);
    expect(find.byKey(const Key('mark-voucher-used')), findsNothing);
  });

  testWidgets('HubPool rewards exchange points for app credit', (
    WidgetTester tester,
  ) async {
    var redeemedPoints = 0;
    var addedCredit = 0.0;
    await tester.pumpWidget(
      MaterialApp(
        home: RewardsPage(
          initialPoints: 500,
          onRedeem: (voucherId, pointCost, hubPoolCredit) {
            redeemedPoints += pointCost;
            addedCredit += hubPoolCredit;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('reward-hubpool-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reward-redeem-button')));
    await tester.pumpAndSettle();

    expect(redeemedPoints, 100);
    expect(addedCredit, 5);
    expect(
      find.text('RM5 has been added to your HubPool credit.'),
      findsOneWidget,
    );
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
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-favorites')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('profile-favorites')));
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
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-favorites')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('profile-favorites')));
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
