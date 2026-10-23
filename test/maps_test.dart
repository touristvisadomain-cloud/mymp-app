// The maps' two kinds (lib/maps/google.dart): Google's when the build has a
// key, the app's own drawing otherwise. A test has no key and no map
// service, so by default every map here is the drawing (the fallback a build
// without a key, or the web build, shows). The Google path is checked with a
// fake map platform in place of the real one, which cannot render in a test:
// what is checked is what the app hands Google (the districts, the seats,
// the picked seat's area) and what a tap on them does.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymp/disclaimer.dart';
import 'package:mymp/data/member.dart';
import 'package:mymp/i18n.dart';
import 'package:mymp/locate.dart';
import 'package:mymp/maps/election_map.dart' show tieHalves;
import 'package:mymp/maps/google.dart';
import 'package:mymp/maps/seat_map.dart';
import 'package:mymp/screens/district_map.dart';
import 'package:mymp/screens/election_screen.dart';
import 'package:mymp/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _file(String path) => File(path).readAsStringSync();

final _client = MockClient((req) async {
  final path = req.url.path;
  String? body;
  if (path.endsWith('/api/app/v1/election')) {
    body = _file(
      'test/fixtures/election/election_'
      '${req.url.queryParameters['lang'] == 'en' ? 'en' : 'bn'}.json',
    );
  } else if (path == '/geo/overview.json') {
    body = _file('test/fixtures/election/overview.json');
  } else if (path.startsWith('/geo/')) {
    final f = File('test/fixtures/places/geo-${path.split('/').last}');
    if (f.existsSync()) body = f.readAsStringSync();
  }
  if (body == null) return http.Response('{"error":"not found"}', 404);
  return http.Response.bytes(
    utf8.encode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
});

/// Google's map without Google: the map's contents are only recorded.
class _FakeMaps extends GoogleMapsFlutterPlatform {
  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) => const ColoredBox(color: Color(0xFFE8ECE6));
}

const _channel = MethodChannel('bd.mymp.app/maps');

void _answer(Object? hasKey) => TestDefaultBinaryMessengerBinding
    .instance
    .defaultBinaryMessenger
    .setMockMethodCallHandler(
      _channel,
      hasKey == null
          ? null
          : (call) async => call.method == 'hasKey' ? hasKey : null,
    );

/// Bangladesh's bounds in a box, in pixels at [p]'s zoom.
Size _span(LatLngBounds b, CameraPosition p) {
  double y(double lat) {
    final s = math.sin(lat * math.pi / 180);
    return 0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi);
  }

  final world = 256 * math.pow(2, p.zoom);
  return Size(
    (b.northeast.longitude - b.southwest.longitude) / 360 * world,
    (y(b.southwest.latitude) - y(b.northeast.latitude)) * world,
  );
}

/// Pictures are made by the engine, off the test's clock: each step of their
/// making needs a moment of real time and then a frame to hear of it.
Future<void> _letPicturesFinish(WidgetTester t) async {
  for (var i = 0; i < 60; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
  }
}

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  for (var i = 0; i < d.inMilliseconds ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The members' photos keep a cache on disk: a folder of the test's own.
  late Directory cache;
  setUpAll(() {
    cache = Directory.systemTemp.createTempSync('mymp_maps_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => cache.path,
        );
  });
  tearDownAll(() {
    try {
      cache.deleteSync(recursive: true);
    } catch (_) {}
  });

  tearDown(() {
    debugLocate = null;
    GoogleMaps.debugEnabled = false;
    _answer(null);
    debugDefaultTargetPlatformOverride = null;
    appLang.value = Lang.bn;
  });

  group('the switch', () {
    test('no channel (a test, the web, an old native side): drawn', () async {
      await GoogleMaps.init();
      expect(GoogleMaps.enabled, isFalse);
    });

    test('a build without a key: drawn', () async {
      _answer(false);
      await GoogleMaps.init();
      expect(GoogleMaps.enabled, isFalse);
    });

    test('a build with a key: Google', () async {
      _answer(true);
      await GoogleMaps.init();
      expect(GoogleMaps.enabled, isTrue);
    });

    test('a desktop platform: drawn, whatever the channel says', () async {
      _answer(true);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await GoogleMaps.init();
      expect(GoogleMaps.enabled, isFalse);
    });

    test('a broken answer: drawn', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            _channel,
            (call) async => throw PlatformException(code: 'x'),
          );
      await GoogleMaps.init();
      expect(GoogleMaps.enabled, isFalse);
    });
  });

  group('fitCamera', () {
    for (final size in const [Size(320, 380), Size(393, 510), Size(600, 560)]) {
      test('the country fills a $size box, whole', () {
        final p = fitCamera(GoogleMaps.bangladesh, size, pad: 8);
        final span = _span(GoogleMaps.bangladesh, p);
        // Inside the box with its padding, and touching it on one side:
        // the fractional zoom, not a whole step that leaves it small.
        expect(span.width, lessThanOrEqualTo(size.width - 16 + 0.01));
        expect(span.height, lessThanOrEqualTo(size.height - 16 + 0.01));
        expect(
          math.max(
            span.width / (size.width - 16),
            span.height / (size.height - 16),
          ),
          closeTo(1, 1e-6),
        );
        expect(p.zoom, isNot(p.zoom.roundToDouble()));
        expect(p.target.longitude, closeTo(90.35, 1e-9));
        // Mercator's middle is a little north of the latitudes' mean.
        expect(p.target.latitude, inInclusiveRange(23.625, 23.7));
      });
    }

    test('a small place is not zoomed past the limit', () {
      final b = boundsOf([(90.40, 23.80), (90.401, 23.801)])!;
      expect(fitCamera(b, const Size(400, 300), maxZoom: 14).zoom, 14);
    });

    test('no points, no bounds', () => expect(boundsOf(const []), isNull));
  });

  group('the election map', () {
    Future<void> pump(WidgetTester t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(393, 851) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await http.runWithClient(() async {
        await t.pumpWidget(
          MaterialApp(theme: buildTheme(), home: const ElectionScreen()),
        );
        await _pumpFor(t, const Duration(seconds: 2));
        // The party discs and the markers' pictures.
        await _letPicturesFinish(t);
      }, () => _client);
    }

    testWidgets('without a key: the drawn map', (t) async {
      await pump(t);
      expect(find.byType(GoogleMap), findsNothing);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      // Its hint, which Google's map does without.
      expect(find.textContaining('দুই আঙুলে'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('with a key: Google, with the same districts and seats', (
      t,
    ) async {
      GoogleMapsFlutterPlatform.instance = _FakeMaps();
      GoogleMaps.debugEnabled = true;
      await pump(t);

      expect(find.byType(InteractiveViewer), findsNothing);
      GoogleMap map() => t.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map().myLocationEnabled, isFalse);
      expect(map().gestureRecognizers, isNotEmpty);
      expect(map().initialCameraPosition.zoom, inInclusiveRange(5.0, 8.0));
      expect(find.textContaining('মানচিত্র: Google Maps'), findsOneWidget);

      final overview =
          jsonDecode(_file('test/fixtures/election/overview.json')) as Map;
      final rings = (overview['districts'] as List).fold<int>(
        0,
        (n, d) => n + ((d as Map)['polys'] as List).length,
      );
      expect(map().polygons, hasLength(rings));
      // Every seat that has a place, in its party's disc.
      final placed = (overview['seats'] as Map).length;
      expect(map().markers, hasLength(placed));
      expect(map().markers.every((m) => m.consumeTapEvents), isTrue);

      // A seat's marker opens its card and draws its area.
      final dhaka17 = map().markers.firstWhere(
        (m) => m.markerId.value == 'dhaka-17',
      );
      await http.runWithClient(() async {
        dhaka17.onTap!();
        await _pumpFor(t, const Duration(seconds: 1));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await _pumpFor(t, const Duration(seconds: 1));
      }, () => _client);
      expect(find.text('প্রোফাইল'), findsOneWidget);
      expect(map().polygons.length, greaterThan(rings));

      // One party's chip: only its markers.
      await t.ensureVisible(find.text('এনসিপি').first);
      await t.tap(find.text('এনসিপি').first);
      await t.pump();
      expect(map().markers.length, lessThan(placed));
      expect(map().markers, isNotEmpty);
      await t.ensureVisible(find.text('সব দল'));
      await t.tap(find.text('সব দল'));
      await t.pump();
      expect(map().markers, hasLength(placed));

      // The district view: no markers; a district's tap lists its seats.
      await t.ensureVisible(find.text('জেলার রং'));
      await t.tap(find.text('জেলার রং'));
      await t.pump();
      expect(map().markers, isEmpty);
      final dhaka = map().polygons.firstWhere(
        (p) => p.polygonId.value.startsWith('d/dhaka/'),
      );
      expect(dhaka.consumeTapEvents, isTrue);
      dhaka.onTap!();
      await _pumpFor(t, const Duration(milliseconds: 500));
      expect(find.textContaining('টি আসন: '), findsOneWidget);

      await t.pumpWidget(const SizedBox());
    });

    Future<void> tapLocate(WidgetTester t) async {
      await http.runWithClient(() async {
        await t.ensureVisible(find.text('আমার আসন কোনটি?'));
        await t.tap(find.text('আমার আসন কোনটি?'));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
        await _pumpFor(t, const Duration(seconds: 1));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await _pumpFor(t, const Duration(seconds: 1));
      }, () => _client);
    }

    testWidgets('আমার আসন কোনটি?: a ward wholly in a seat opens it', (t) async {
      // Ward 15 of Dhaka North, wholly in Dhaka-17.
      debugLocate = () async =>
          const LocateResult.found(Located(23.82616, 90.39231));
      await pump(t);
      await tapLocate(t);
      expect(find.textContaining('ওয়ার্ড ১৫'), findsWidgets);
      expect(find.textContaining('ঢাকা-১৭ আসনে'), findsOneWidget);
      // The seat's card, as a tap on its marker opens it.
      expect(find.text('প্রোফাইল'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('আমার আসন কোনটি?: a split upazila offers its seats', (t) async {
      // Keraniganj, split between Dhaka-2 and Dhaka-3.
      debugLocate = () async =>
          const LocateResult.found(Located(23.71265, 90.3331));
      await pump(t);
      await tapLocate(t);
      expect(find.textContaining('একাধিক আসনে ভাগ করা'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'ঢাকা-২'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'ঢাকা-৩'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('আমার আসন কোনটি?: outside Bangladesh, or refused', (t) async {
      debugLocate = () async =>
          const LocateResult.found(Located(51.5, -0.12)); // London
      await pump(t);
      await tapLocate(t);
      expect(find.textContaining('বাংলাদেশের বাইরে'), findsOneWidget);

      debugLocate = () async =>
          const LocateResult.failed('অনুমতি বন্ধ', needsSettings: true);
      await tapLocate(t);
      expect(find.text('অনুমতি বন্ধ'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'সেটিংস'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('the district and seat maps', () {
    Future<void> pump(WidgetTester t, Widget w) async {
      SharedPreferences.setMockInitialValues({});
      await http.runWithClient(() async {
        await t.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: Scaffold(body: SingleChildScrollView(child: w)),
          ),
        );
        await t.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 1)),
        );
        await _pumpFor(t, const Duration(seconds: 1));
      }, () => _client);
    }

    final district = DistrictMap(
      districtSlug: 'dhaka',
      colours: const {'dhaka-17': Color(0xFF1F7A4F)},
      seatNames: const {'dhaka-17': 'ঢাকা-১৭'},
      onSeat: (slug) => _opened.add(slug),
    );
    const seat = SeatMap(
      districtSlug: 'dhaka',
      seatSlug: 'dhaka-17',
      color: Color(0xFF1F7A4F),
      districtName: 'ঢাকা',
    );

    testWidgets('without a key: drawn', (t) async {
      await pump(t, Column(children: [district, seat]));
      expect(find.byType(GoogleMap), findsNothing);
      expect(find.byType(CustomPaint), findsWidgets);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('with a key: the district on Google, a tap opens a seat', (
      t,
    ) async {
      GoogleMapsFlutterPlatform.instance = _FakeMaps();
      GoogleMaps.debugEnabled = true;
      _opened.clear();
      await pump(t, district);
      final map = t.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.polygons, isNotEmpty);
      // On the page, one finger scrolls the page: the map claims nothing.
      expect(map.gestureRecognizers, isEmpty);
      map.polygons.firstWhere((p) => p.onTap != null).onTap!();
      expect(_opened, hasLength(1));
      expect(_opened.single, startsWith('dhaka-'));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('with a key: the seat on Google, a tap names the place', (
      t,
    ) async {
      GoogleMapsFlutterPlatform.instance = _FakeMaps();
      GoogleMaps.debugEnabled = true;
      await pump(t, seat);
      GoogleMap map() => t.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map().polygons, isNotEmpty);
      expect(map().myLocationEnabled, isFalse);
      // Opens on the seat, closer than the whole district.
      expect(map().initialCameraPosition.zoom, greaterThan(10));
      final mine = map().polygons.firstWhere((p) => p.strokeWidth == 2);
      mine.onTap!();
      await t.pump();
      expect(find.textContaining('পুরোটা এই আসনে'), findsOneWidget);
      expect(
        map().polygons.where((p) => p.strokeColor == AppColors.ink),
        isNotEmpty,
      );
      await t.pumpWidget(const SizedBox());
    });
  });
  group('আমি কি এই আসনে?', () {
    Future<void> pump(WidgetTester t, Widget w) async {
      SharedPreferences.setMockInitialValues({});
      await http.runWithClient(() async {
        await t.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: Scaffold(body: SingleChildScrollView(child: w)),
          ),
        );
        await t.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 1)),
        );
        await _pumpFor(t, const Duration(seconds: 1));
      }, () => _client);
    }

    const seat = SeatMap(
      districtSlug: 'dhaka',
      seatSlug: 'dhaka-17',
      color: Color(0xFF1F7A4F),
      districtName: 'ঢাকা',
    );

    Future<void> ask(WidgetTester t, Located at) async {
      debugLocate = () async => LocateResult.found(at);
      await t.tap(find.text('আমি কি এই আসনে?'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
    }

    test('a point is found in its place, a ward before its city', () {
      final places = [
        for (final f
            in (jsonDecode(_file('test/fixtures/places/geo-dhaka.json'))
                    as Map)['features']
                as List)
          ?GeoPlace.fromJson(Map<String, dynamic>.from(f as Map)),
      ];
      final ward = placeAt(places, 90.39231, 23.82616)!;
      expect(ward.kind, 'ward');
      expect(ward.seats.keys, ['dhaka-17']);
      expect(placeAt(places, 90.11636, 23.60497)!.name, 'দোহার');
      expect(placeAt(places, 91.8, 22.35), isNull); // Chattogram
    });

    testWidgets('drawn: yes, no, and outside the district', (t) async {
      await pump(t, seat);
      expect(find.text('আমি কি এই আসনে?'), findsOneWidget);

      await ask(t, const Located(23.82616, 90.39231)); // ward 15
      expect(find.textContaining('হ্যাঁ।'), findsOneWidget);
      expect(find.textContaining('ওয়ার্ড ১৫'), findsWidgets);

      await ask(t, const Located(23.60497, 90.11636)); // Dohar
      expect(
        find.textContaining('না। আপনার অবস্থান দোহার উপজেলা'),
        findsOneWidget,
      );
      expect(find.textContaining('ঢাকা-১ আসনে'), findsOneWidget);

      await ask(t, const Located(22.35, 91.8)); // Chattogram
      expect(find.textContaining('এই জেলার বাইরে'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('refused for good: the settings are offered', (t) async {
      await pump(t, seat);
      debugLocate = () async =>
          const LocateResult.failed('অনুমতি বন্ধ', needsSettings: true);
      await t.tap(find.text('আমি কি এই আসনে?'));
      await t.pump();
      expect(find.text('অনুমতি বন্ধ'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'সেটিংস'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('with a key: a marker on Google, not its location layer', (
      t,
    ) async {
      GoogleMapsFlutterPlatform.instance = _FakeMaps();
      GoogleMaps.debugEnabled = true;
      await pump(t, seat);
      GoogleMap map() => t.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map().markers, isEmpty);
      await ask(t, const Located(23.82616, 90.39231));
      expect(map().markers.single.markerId.value, 'here');
      expect(map().myLocationEnabled, isFalse);
      expect(find.textContaining('হ্যাঁ।'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('what the app says about the maps', () {
    for (final lang in Lang.values) {
      testWidgets('${lang.name}: Google named only when the maps are Google', (
        t,
      ) async {
        appLang.value = lang;
        Future<void> show() async {
          await t.pumpWidget(
            MaterialApp(
              theme: buildTheme(),
              home: const Scaffold(
                body: SingleChildScrollView(child: SourceList()),
              ),
            ),
          );
          await t.pump();
        }

        await show();
        expect(find.text(kMapsLine), findsNothing);
        // Settled before the first frame in the app; here, a fresh screen.
        GoogleMaps.debugEnabled = true;
        await t.pumpWidget(const SizedBox());
        await show();
        expect(find.text(kMapsLine), findsOneWidget);
        expect(kMapsLine, contains('Google'));
        expect(kGooglePrivacyUrl, startsWith('https://policies.google.com/'));
      });
    }
  });
  group('a tied district', () {
    test('is cut on the diagonal into two halves', () {
      double area(List<Offset> r) {
        var a = 0.0;
        for (var i = 0; i < r.length; i++) {
          final p = r[i], q = r[(i + 1) % r.length];
          a += p.dx * q.dy - q.dx * p.dy;
        }
        return a.abs() / 2;
      }

      // A square, lon 90..91, lat 23..24.
      const sq = [
        Offset(90, 23),
        Offset(91, 23),
        Offset(91, 24),
        Offset(90, 24),
      ];
      final (a, b) = tieHalves([sq]);
      expect(a, hasLength(1));
      expect(b, hasLength(1));
      expect(area(a.single), closeTo(0.5, 1e-9));
      expect(area(b.single), closeTo(0.5, 1e-9));
      // The first half is the top left: it holds the north-west corner.
      expect(a.single, contains(const Offset(90, 24)));
      expect(b.single, contains(const Offset(91, 23)));
    });
  });
}

final _opened = <String>[];
