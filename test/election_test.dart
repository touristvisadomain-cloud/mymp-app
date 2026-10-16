// The election and statistics screens, with answers saved from the API in
// test/fixtures/election (both languages) and the map's outlines: parsed,
// then drawn on a small phone with a large font and scrolled end to end. Any
// overflow or exception fails.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymp/data/election.dart';
import 'package:mymp/i18n.dart';
import 'package:mymp/screens/election_screen.dart';
import 'package:mymp/screens/statistics_screen.dart';
import 'package:mymp/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dir = 'test/fixtures/election';

String _read(String name) => File('$_dir/$name').readAsStringSync();

Map<String, dynamic> _json(String name) =>
    jsonDecode(_read(name)) as Map<String, dynamic>;

final _client = MockClient((req) async {
  final path = req.url.path;
  String? body;
  if (path.endsWith('/api/app/v1/election')) {
    body = _read(
      req.url.queryParameters['lang'] == 'en'
          ? 'election_en.json'
          : 'election_bn.json',
    );
  } else if (path == '/geo/overview.json') {
    body = _read('overview.json');
  }
  if (body == null) return http.Response('{"error":"not found"}', 404);
  return http.Response.bytes(
    utf8.encode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
});

Future<void> _loadFonts() async {
  final loader = FontLoader('NotoSansBengali');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/NotoSansBengali-$w.ttf'));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });
  tearDown(() => appLang.value = Lang.bn);

  group('parsing', () {
    test('Bangla answer', () {
      final e = ElectionData.fromJson(_json('election_bn.json'));
      expect(e.seats, hasLength(300));
      expect(e.publishedSeats, e.seatsCounted);
      expect(e.house.majority, 176);
      expect(e.house.parties.first.abbr, 'BNP');
      expect(
        e.house.parties.fold<int>(0, (n, p) => n + p.seats),
        e.house.total,
      );
      expect(e.members.youngest, isNotNull);
      expect(e.members.mostTerms, isNotEmpty);
      expect(e.earlier.first.no, e.parliamentNo);
      expect(e.districtNames, hasLength(64));
      // Every seat has a place on the map.
      final o = GeoOverview.fromJson(_json('overview.json'));
      expect(o.districts, hasLength(64));
      for (final s in e.seats) {
        expect(o.seats[s.slug], isNotNull, reason: s.slug);
      }
    });

    test('English answer: English names, Bangla kept for search', () {
      final e = ElectionData.fromJson(_json('election_en.json'));
      final dhaka17 = e.seats.firstWhere((s) => s.slug == 'dhaka-17');
      expect(dhaka17.name, 'Dhaka-17');
      expect(dhaka17.matches('ঢাকা-১৭'), isTrue);
      expect(dhaka17.matches('dhaka-17'), isTrue);
      expect(e.districtNames['dhaka'], 'Dhaka');
      expect(
        e.members.ageBands.map((b) => b.label),
        everyElement(isNot(matches(RegExp('[ঀ-৿]')))),
      );
    });

    test('a broken answer is not an error', () {
      final e = ElectionData.fromJson({
        'house': 'x',
        'seats': [
          {'no': 'one'},
          {'slug': 'a-1', 'member': 3, 'runnerUp': {}},
        ],
        'earlier': [null, 4],
      });
      expect(e.seats, hasLength(1));
      expect(e.seats.single.member, isNull);
      expect(e.seats.single.runnerUp, isNull);
      expect(e.earlier, isEmpty);
    });
  });

  for (final lang in Lang.values) {
    final tr = T.of(lang);
    for (final (label, size, scale) in [
      ('small phone, large font', const Size(320, 640), 1.3),
      ('common phone', const Size(393, 851), 1.0),
    ]) {
      group('${lang.name}, $label', () {
        Future<List<String>> run(
          WidgetTester tester,
          Widget screen, {
          required String shows,
          int flings = 40,
          Future<void> Function(WidgetTester, void Function(String))? actions,
        }) async {
          SharedPreferences.setMockInitialValues({});
          appLang.value = lang;
          tester.view.physicalSize = size * 3;
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);

          final problems = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) {
            final text = details.exceptionAsString();
            if (text.contains('MissingPluginException') ||
                text.contains('HTTP request failed') ||
                text.contains('NetworkImageLoadException') ||
                text.contains('SocketException')) {
              return;
            }
            // The message, and where the widget that failed was made.
            final made = details
                .toString()
                .split('\n')
                .where((l) => l.contains('file:///'))
                .take(1)
                .join();
            problems.add('${text.split('\n').first} $made'.trim());
          };
          await http.runWithClient(() async {
            await tester.pumpWidget(
              MaterialApp(
                theme: buildTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: screen,
              ),
            );
            for (var i = 0; i < 10; i++) {
              await tester.pump(const Duration(milliseconds: 200));
            }
            if (actions != null) {
              try {
                await actions(tester, problems.add);
              } catch (e) {
                problems.add('$e'.split('\n').first);
              }
            }
            var seen = find.textContaining(shows).evaluate().isNotEmpty;
            if (find
                .text(tr('তথ্য আনা গেল না', 'Could not fetch the information'))
                .evaluate()
                .isNotEmpty) {
              problems.add('showed the error page');
            }
            final page = find.byType(SingleChildScrollView).first;
            for (var i = 0; i < flings; i++) {
              await tester.drag(
                page,
                Offset(0, -size.height * 0.7),
                warnIfMissed: false,
              );
              await tester.pump(const Duration(milliseconds: 300));
              seen = seen || find.textContaining(shows).evaluate().isNotEmpty;
            }
            if (!seen) problems.add('did not show "$shows"');
          }, () => _client);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          FlutterError.onError = previous;
          final taken = tester.takeException();
          if (taken != null) problems.add('$taken');
          for (final p in problems) {
            // ignore: avoid_print
            print('PROBLEM: $p');
          }
          return problems;
        }

        testWidgets('election', (t) async {
          expect(
            await run(
              t,
              const ElectionScreen(),
              shows: tr('জেলা অনুযায়ী আসন', 'Seats by district'),
            ),
            isEmpty,
          );
        });

        testWidgets('election: search, a seat, the party chips', (t) async {
          expect(
            await run(
              t,
              const ElectionScreen(),
              flings: 3,
              shows: tr('প্রাপ্ত ভোট', 'Votes received'),
              actions: (t, fail) async {
                Future<void> settle([int frames = 10]) async {
                  for (var i = 0; i < frames; i++) {
                    await t.pump(const Duration(milliseconds: 100));
                  }
                }

                Future<void> tapOn(Finder f) async {
                  if (f.evaluate().isEmpty) return fail('no $f');
                  await t.ensureVisible(f);
                  await settle(3);
                  await t.tap(f);
                  await settle();
                }

                Future<void> search(String q) async {
                  final field = find.byType(TextField);
                  await t.ensureVisible(field);
                  await t.enterText(field, q);
                  await settle(2);
                  // The hit under the field, not the seat's name elsewhere.
                  await tapOn(
                    find
                        .descendant(
                          of: find.byType(InkWell),
                          matching: find.text(q),
                        )
                        .first,
                  );
                }

                await search(tr('ঢাকা-১৭', 'Dhaka-17'));
                if (find.text(tr('প্রোফাইল', 'Profile')).evaluate().isEmpty) {
                  fail('the seat card did not open');
                }
                // One party: only its seats show, and the count says so.
                await tapOn(find.text(tr('এনসিপি', 'NCP')).first);
                if (find
                    .textContaining(tr('টি আসন দেখানো হচ্ছে', 'Showing'))
                    .evaluate()
                    .isEmpty) {
                  fail('the party chip did not pick');
                }
                await tapOn(find.text(tr('সব দল', 'All parties')));
                await tapOn(find.text(tr('জেলার রং', 'District colours')));
                // A tap in the middle of the country lists that district.
                final map = find.byType(InteractiveViewer);
                await t.ensureVisible(map);
                await settle(3);
                await t.tapAt(t.getRect(map).center);
                await settle();
                if (find
                    .textContaining(tr('টি আসন: ', ' seats: '))
                    .evaluate()
                    .isEmpty) {
                  fail('the district card did not open');
                }
                await tapOn(find.text(tr('আসন ও প্রতীক', 'Seats and symbols')));
                await search(tr('ঢাকা-১৭', 'Dhaka-17'));
              },
            ),
            isEmpty,
          );
        });

        testWidgets('statistics', (t) async {
          expect(
            await run(
              t,
              const StatisticsScreen(),
              shows: tr('যেসব হিসাব এখানে নেই', 'Figures not shown here'),
            ),
            isEmpty,
          );
        });
      });
    }
  }
}
