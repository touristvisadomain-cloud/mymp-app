// The top of the members tab: four facts and the House's composition, as the
// website's home page has them. Counted from saved API answers (the member
// list in test/fixtures/house, /election in test/fixtures/election, /cabinet
// in test/fixtures/cabinet, all from the same data snapshot), then drawn on
// a 360dp phone with a large font, a small one and a common one, in both
// languages: any overflow or exception fails, and Bangla shows Bangla
// numerals only.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymp/data/cabinet.dart';
import 'package:mymp/i18n.dart';
import 'package:mymp/models.dart';
import 'package:mymp/screens/house_overview.dart';
import 'package:mymp/screens/member_screen.dart';
import 'package:mymp/screens/members_screen.dart';
import 'package:mymp/screens/statistics_screen.dart';
import 'package:mymp/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _read(String path) => File('test/fixtures/$path').readAsStringSync();

Map<String, dynamic> _json(String path) =>
    jsonDecode(_read(path)) as Map<String, dynamic>;

Bootstrap _boot(Lang lang) => Bootstrap.fromJson(
  _json('house/bootstrap${lang == Lang.en ? '.en' : ''}.json'),
);

/// Answers the members tab's requests from the fixtures; [election] and
/// [cabinet] false answer those with a 404, as an old or failing site might.
MockClient _client({bool election = true, bool cabinet = true}) =>
    MockClient((req) async {
      final en = req.url.queryParameters['lang'] == 'en';
      final path = req.url.path;
      String? body;
      if (path.endsWith('/api/app/v1/bootstrap')) {
        body = _read('house/bootstrap${en ? '.en' : ''}.json');
      } else if (path.endsWith('/api/app/v1/election') && election) {
        body = _read('election/election_${en ? 'en' : 'bn'}.json');
      } else if (path.endsWith('/api/app/v1/cabinet') && cabinet) {
        body = _read('cabinet/cabinet${en ? '.en' : ''}.json');
      } else if (path.contains('/api/app/v1/mp/')) {
        // A member's page: the list's brief is enough for it to draw.
        final slug = path.split('/').last;
        final list = _json('house/bootstrap${en ? '.en' : ''}.json')['members'];
        final brief = (list as List).cast<Map<String, dynamic>>().where(
          (m) => m['slug'] == slug,
        );
        if (brief.isNotEmpty) body = jsonEncode(brief.first);
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

/// Every piece of text drawn under [of].
List<String> _texts(WidgetTester tester, Finder of) => [
  for (final e
      in find.descendant(of: of, matching: find.byType(RichText)).evaluate())
    (e.widget as RichText).text.toPlainText(),
];

/// Pumps [screen] in [lang] on a [size] phone with text at [scale], runs
/// [actions], and returns every problem seen: an overflow, an exception.
Future<List<String>> _run(
  WidgetTester tester,
  Widget screen, {
  required Lang lang,
  required Size size,
  required double scale,
  MockClient? client,
  Future<void> Function(WidgetTester)? actions,
}) async {
  SharedPreferences.setMockInitialValues({
    'flutter.not_official_notice_v1': true,
  });
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
        .take(2)
        .join(' ');
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
    // A failed expectation is reported as a problem, so the error handler
    // above is always put back.
    if (actions != null) {
      try {
        await actions(tester);
      } catch (e, st) {
        final at = '$st'
            .split('\n')
            .where((l) => l.contains('overview_test.dart'))
            .take(1)
            .join();
        problems.add('${'$e'.trim().split('\n').take(6).join(' | ')} $at');
      }
    }
  }, () => client ?? _client());
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  FlutterError.onError = previous;
  final taken = tester.takeException();
  if (taken != null) problems.add('$taken');
  return problems;
}

Future<void> _settle(WidgetTester t, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapOn(WidgetTester t, Finder f) async {
  expect(f, findsOneWidget);
  await t.ensureVisible(f);
  await _settle(t, 3);
  await t.tap(f);
  await _settle(t);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });
  tearDown(() => appLang.value = Lang.bn);

  group('the figures', () {
    test('the House from the member list, as the website counts it', () {
      final election = _json('election/election_bn.json');
      final members = election['members'] as Map<String, dynamic>;
      for (final lang in Lang.values) {
        final m = HouseMakeup.of(_boot(lang));
        expect(m.total, 347);
        expect(m.territorial, 298);
        expect(m.reserved, 49);
        // The same figures the statistics screen shows.
        expect(m.women, members['women']);
        expect(m.womenTerritorial, members['womenTerritorial']);
        expect(m.womenReserved, members['womenReserved']);
        expect(HouseMakeup.houseSeats, 350);
        expect(HouseMakeup.majority, 176);
        expect(m.parties.fold<int>(0, (n, p) => n + p.seats), m.total);
        expect(m.top.map((p) => p.abbr), ['BNP', 'BJEI', 'Ind', 'NCP']);
        expect(m.rest, hasLength(7));
        expect(m.restSeats, 9);
        // The Prime Minister's party leads: 245 of 347, 69 past 176.
        expect(m.lead?.abbr, 'BNP');
        expect(m.lead?.territorial, 210);
        expect(m.lead?.reserved, 35);
        expect(m.leadShare, 71);
        expect(m.leadOver, 69);
        // The list's leaders leave the Speaker out; the office finds him.
        expect(m.speaker?.slug, 'hafiz-uddin-ahmad-bir-bikram');
      }
      expect(HouseMakeup.of(_boot(Lang.bn)).lead?.short, 'বিএনপি');
      expect(HouseMakeup.of(_boot(Lang.en)).lead?.short, 'BNP');
    });

    test('a list with no leaders and no offices still has a lead', () {
      final b = Bootstrap(
        version: '',
        parliamentNo: 13,
        districts: const [],
        parties: const [
          PartyBrief(
            abbr: 'A',
            slug: 'a',
            nameBn: 'A',
            shortBn: 'A',
            colorHex: '',
            seats: 1,
          ),
        ],
        members: const [
          MemberBrief(id: '1', slug: 'x', nameBn: 'X', party: 'A'),
          MemberBrief(id: '2', slug: 'y', nameBn: 'Y', party: 'B'),
          MemberBrief(
            id: '3',
            slug: 'z',
            nameBn: 'Z',
            party: 'B',
            reserved: true,
            gender: 'Female',
          ),
        ],
      );
      final m = HouseMakeup.of(b);
      expect(m.lead?.abbr, 'B');
      expect(m.speaker, isNull);
      expect(m.parties.map((p) => p.abbr), ['B', 'A']);
      expect(m.parties.first.short, 'B');
      expect(m.women, 1);
      expect(m.womenReserved, 1);
    });

    test('the cabinet: each person once, under their first post', () {
      appLang.value = Lang.bn;
      final bn = CabinetSummary.of(
        CabinetData.fromJson(_json('cabinet/cabinet.json')),
      );
      expect(bn.size, 61);
      expect(
        bn.note,
        'প্রধানমন্ত্রী, ২৬ মন্ত্রী, ২৪ প্রতিমন্ত্রী, ১০ উপদেষ্টা',
      );
      appLang.value = Lang.en;
      final en = CabinetSummary.of(
        CabinetData.fromJson(_json('cabinet/cabinet.en.json')),
      );
      expect(en.size, 61);
      expect(
        en.note,
        'Prime Minister, 26 ministers, 24 state ministers, 10 advisers',
      );
    });
  });

  // First, before any test has fetched /election: the app keeps it once read.
  group('a site without /election or /cabinet', () {
    for (final lang in Lang.values) {
      final tr = T.of(lang);
      testWidgets('leaves those facts out, ${lang.name}', (t) async {
        final boot = _boot(lang);
        final problems = await _run(
          t,
          Scaffold(
            body: SingleChildScrollView(child: HouseOverview(data: boot)),
          ),
          lang: lang,
          size: const Size(360, 640),
          scale: 1.3,
          client: _client(election: false, cabinet: false),
          actions: (t) async {
            expect(find.byType(FactTile), findsOneWidget);
            expect(find.text(tr('নারী সদস্য', 'Women MPs')), findsOneWidget);
            expect(find.text('…'), findsNothing);
            expect(find.byType(HouseCompositionCard), findsOneWidget);
          },
        );
        expect(problems, isEmpty);
      });
    }
  });

  for (final lang in Lang.values) {
    final tr = T.of(lang);
    for (final (label, size, scale) in [
      ('360dp phone, large font', const Size(360, 640), 1.3),
      ('small phone, large font', const Size(320, 640), 1.3),
      ('common phone', const Size(393, 851), 1.0),
    ]) {
      group('${lang.name}, $label', () {
        testWidgets('the members tab opens with the card and the facts', (
          t,
        ) async {
          var cabinetTapped = false;
          final problems = await _run(
            t,
            MembersScreen(onShowCabinet: () => cabinetTapped = true),
            lang: lang,
            size: size,
            scale: scale,
            actions: (t) async {
              final overview = find.byType(HouseOverview);
              expect(overview, findsOneWidget);
              await t.ensureVisible(find.byType(HouseCompositionCard));
              await _settle(t, 3);

              final texts = _texts(t, overview).join('\n');
              expect(
                texts,
                contains(tr('সংসদের গঠন', 'Composition of Parliament')),
              );
              expect(
                texts,
                contains(
                  tr(
                    '৩৫০ আসনের ৩৪৭টি পূর্ণ: ২৯৮ আসনভিত্তিক, ৪৯ সংরক্ষিত নারী আসন',
                    '347 of 350 seats filled: 298 elected from constituencies, 49 reserved seats for women',
                  ),
                ),
              );
              expect(
                texts,
                contains(
                  tr(
                    'সরকারি দল বিএনপি: ২৪৫টি আসন',
                    'Governing party BNP: 245 seats',
                  ),
                ),
              );
              expect(
                texts,
                contains(
                  tr(
                    'সংখ্যাগরিষ্ঠতার (১৭৬) চেয়ে ৬৯টি বেশি',
                    '69 more than a majority (176)',
                  ),
                ),
              );
              expect(texts, contains(tr('৭১%', '71%')));
              expect(texts, contains(tr('সংখ্যাগরিষ্ঠতা ১৭৬', 'Majority 176')));
              expect(
                texts,
                contains(tr('২১০ + ৩৫ সংরক্ষিত', '210 + 35 reserved')),
              );
              expect(texts, contains(tr('অন্য ৭ দল', '7 other parties')));
              // The four facts.
              expect(texts, contains(tr('নারী সদস্য', 'Women MPs')));
              expect(
                texts,
                contains(
                  tr(
                    '৭ জন সরাসরি নির্বাচিত, ৪৯ জন সংরক্ষিত আসনে',
                    '7 directly elected, 49 in reserved seats',
                  ),
                ),
              );
              expect(texts, contains(tr('২৫৯', '259')));
              expect(
                texts,
                contains(
                  tr('নতুন মুখ, সংসদের ৭৫%', 'New faces: 75% of the House'),
                ),
              );
              expect(texts, contains(tr('৬১', '61')));
              expect(texts, contains(tr('২৫ বছর', '25 years')));
              // Numerals in the reader's script only.
              if (lang == Lang.bn) {
                expect(RegExp('[0-9]').hasMatch(texts), isFalse, reason: texts);
              } else {
                expect(RegExp('[০-৯]').hasMatch(texts), isFalse, reason: texts);
              }

              // The other parties open and close.
              await _tapOn(t, find.text(tr('দেখুন', 'Show')));
              expect(find.text(tr('লুকান', 'Hide')), findsOneWidget);
              expect(
                find.textContaining(tr('জাগপা ১', 'JAGPA 1')),
                findsOneWidget,
              );

              // The cabinet fact switches tabs.
              await _tapOn(t, find.text(tr('মন্ত্রিসভায়', 'In the Cabinet')));
              expect(cabinetTapped, isTrue);

              // A search hides the overview and shows the list.
              await t.drag(
                find.byType(CustomScrollView),
                const Offset(0, 4000),
              );
              await _settle(t, 3);
              await t.enterText(find.byType(TextField).first, 'xyz');
              await _settle(t, 3);
              expect(find.byType(HouseOverview), findsNothing);
            },
          );
          expect(problems, isEmpty);
        });

        testWidgets('the facts open their screens', (t) async {
          final boot = _boot(lang);
          final problems = await _run(
            t,
            Scaffold(
              body: SingleChildScrollView(child: HouseOverview(data: boot)),
            ),
            lang: lang,
            size: size,
            scale: scale,
            actions: (t) async {
              await _tapOn(t, find.text(tr('নারী সদস্য', 'Women MPs')));
              await _settle(t, 10);
              expect(find.byType(StatisticsScreen), findsOneWidget);
              await t.pageBack();
              await _settle(t);

              await _tapOn(t, find.text(tr('সর্বকনিষ্ঠ এমপি', 'Youngest MP')));
              expect(find.byType(MemberScreen), findsOneWidget);
              await t.pageBack();
              await _settle(t);

              // The Speaker's line was taken off the card (owner, 2026-10-17).
              expect(
                find.textContaining(
                  tr('স্পিকার: ', 'Speaker: '),
                  findRichText: true,
                ),
                findsNothing,
              );
            },
          );
          expect(problems, isEmpty);
        });
      });
    }
  }
}
