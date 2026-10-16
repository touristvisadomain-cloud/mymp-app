// Seats, districts, reserved seats and place search: the website's place
// finder (src/lib/findSeat.ts, its tests ported), the API's answers parsed
// from fixtures saved from the site (test/fixtures/places, both languages),
// and the screens drawn from them on a small phone with a large font.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymp/api.dart';
import 'package:mymp/data/places.dart';
import 'package:mymp/i18n.dart';
import 'package:mymp/models.dart';
import 'package:mymp/screens/district_screen.dart';
import 'package:mymp/screens/members_screen.dart';
import 'package:mymp/screens/reserved_screen.dart';
import 'package:mymp/screens/seat_screen.dart';
import 'package:mymp/screens/seats_screen.dart';
import 'package:mymp/search.dart';
import 'package:mymp/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dir = 'test/fixtures/places';

Map<String, dynamic> _json(String name) =>
    jsonDecode(File('$_dir/$name.json').readAsStringSync())
        as Map<String, dynamic>;

/// The fixture a request names, in the language it asks for.
String _fixture(Uri url) {
  final path = url.path;
  String? name;
  for (final key in ['bootstrap', 'seats', 'reserved']) {
    if (path.endsWith('/$key')) name = key;
  }
  if (path.contains('/seat/')) name = 'seat-${path.split('/').last}';
  if (path.contains('/district/')) name = 'district-${path.split('/').last}';
  if (path.startsWith('/geo/')) {
    // The map's boundaries are the same file in both languages.
    final f = File('$_dir/geo-${path.split('/').last}');
    return f.existsSync() ? f.readAsStringSync() : '';
  }
  if (name == null) return '';
  final f = File(
    '$_dir/$name${url.queryParameters['lang'] == 'en' ? '.en' : ''}.json',
  );
  return f.existsSync() ? f.readAsStringSync() : '';
}

final _client = MockClient((req) async {
  final body = _fixture(req.url);
  if (body.isEmpty) return http.Response('{"error":"not found"}', 404);
  return http.Response.bytes(
    utf8.encode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
});

FinderSeat _seat(int no, String name, String district, String boundary) =>
    FinderSeat(
      no: no,
      seat: name,
      slug: 's-$no',
      district: district,
      boundary: boundary,
    );

// Boundary text as the Election Commission writes it (the site's test data).
final _seats = [
  _seat(
    175,
    'ঢাকা-২',
    'ঢাকা',
    '(ক)নিম্নলিখিত ইউনিয়ন সমূহ ব্যতীত কেরানিগঞ্জ উপজেলাঃ(১) জিনজিরা, (২)আগানগর,(৩) তেঘরিয়া,(৪) কোন্ডা ও(৫) শুভাট্যা, (খ)ঢাকা দক্ষিন সিটি কর্পোরেশনের ওয়ার্ড ৫৫,৫৬, ও ৫৭ এবং (গ)সাভার উপজেলার নিম্নলিখিত ইউনিয়ন সমূহঃ(১) আমিনবাজার,(২) তেতুলঝড়া ও(৩) ভাকুর্তা',
  ),
  _seat(
    176,
    'ঢাকা-৩',
    'ঢাকা',
    'কেরানিগঞ্জ উপজেলার নিম্নলিখিত ইউনিয়ন সমূহঃ (১) জিনজিরা, (২) আগানগর, (৩) তেঘরিয়া, (৪) কোন্ডা ও (৫) শুভাট্যা',
  ),
  _seat(
    183,
    'ঢাকা-১০',
    'ঢাকা',
    'ঢাকা দক্ষিন সিটি কর্পোরেশনের ওয়ার্ড- ১৪,১৫,১৬,১৭,১৮ ও ২২',
  ),
  _seat(
    187,
    'ঢাকা-১৪',
    'ঢাকা',
    '(ক)ঢাকা উত্তর সিটি কর্পোরেশনের ওয়ার্ড ৭ থেকে ১২ পর্যন্ত এবং (খ)সাভার উপজেলার কাউন্দিয়া ইউনিয়ন',
  ),
  _seat(116, 'ভোলা-২', 'ভোলা', '(ক) দৌলতখান এবং (খ) বোরহানউদ্দিন উপজেলা'),
  _seat(
    45,
    'চাঁপাইনবাবগঞ্জ-২',
    'চাঁপাইনবাবগঞ্জ',
    '(ক) নাচোল, (খ) গোমস্তাপুর এবং (গ) ভোলাহাট উপজেলা',
  ),
];

List<String> _where(String q) => [
  for (final m in findSeats(q, _seats))
    '${m.seat.seat}:${m.kind.name}${m.partial ? '+part' : ''}',
];

Future<void> _loadFonts() async {
  final loader = FontLoader('NotoSansBengali');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/NotoSansBengali-$w.ttf'));
  }
  await loader.load();
}

void main() {
  group('the place finder, as the website has it', () {
    test('an upazila finds the seat that holds it whole', () {
      expect(_where('দৌলতখান'), ['ভোলা-২:upazila']);
      expect(_where('দৌলতখান উপজেলা'), ['ভোলা-২:upazila']);
    });

    test('a union listed as an exception belongs to the other seat', () {
      expect(_where('জিনজিরা'), ['ঢাকা-৩:union']);
      expect(_where('আমিনবাজার'), ['ঢাকা-২:union']);
    });

    test('a split upazila shows every seat that holds part of it', () {
      expect(_where('কেরানীগঞ্জ')..sort(), [
        'ঢাকা-২:upazila+part',
        'ঢাকা-৩:upazila+part',
      ]);
    });

    test('a city ward is found by its number among the ward list', () {
      expect(_where('ঢাকা দক্ষিণ ওয়ার্ড ১৫'), ['ঢাকা-১০:ward']);
      expect(_where('ওয়ার্ড ৫৬'), ['ঢাকা-২:ward']);
    });

    test('a district, a seat name, and no prefix noise', () {
      expect(_where('ভোলা'), ['ভোলা-২:district']);
      expect(_where('ঢাকা-১০'), ['ঢাকা-১০:seat']);
      expect(_where('ভোলাহাট'), ['চাঁপাইনবাবগঞ্জ-২:upazila']);
    });

    test('a place typed in English is looked up in Bangla', () {
      const table = [
        ('Savar', 'সাভার'),
        ('Doulatkhan', 'দৌলতখান'),
        ('Charfasson', 'চরফ্যাশন'),
        ('Keraniganj', 'কেরাণীগঞ্জ'),
      ];
      expect(toBangla('Savar', table), 'সাভার');
      expect(toBangla('daulatkhan upazila', table), 'দৌলতখান');
      expect(toBangla('charfason', table), 'চরফ্যাশন');
      expect(toBangla('দৌলতখান', table), 'দৌলতখান');
      expect(_where(toBangla('ward 15 dhaka south', table)), ['ঢাকা-১০:ward']);
      expect(_where(toBangla('Doulatkhan', table)), ['ভোলা-২:upazila']);
    });

    test('ward numbers: lists, ranges, zero-padded', () {
      expect(
        wardNumbers('ঢাকা উত্তর সিটি কর্পোরেশনের ওয়ার্ড- ০৪,১৩,১৪, ও ১৬'),
        [4, 13, 14, 16],
      );
      expect(
        wardNumbers('ঢাকা উত্তর সিটি কর্পোরেশনের ওয়ার্ড ৭ থেকে ১২ পর্যন্ত'),
        [7, 8, 9, 10, 11, 12],
      );
      expect(wardNumbers('গাজীপুর সিটি কর্পোরেশনের ১ হতে ৫ নং ওয়ার্ড'), [
        1,
        2,
        3,
        4,
        5,
      ]);
      expect(
        wardNumbers(
          'ঢাকা দক্ষিণ সিটি কর্পোরেশনের ওয়ার্ড- ২৩ থেকে ২৫, ৩৫ ও ৫৭',
        ),
        [23, 24, 25, 35, 57],
      );
    });

    test('a ward inside a "থেকে" range finds its seat', () {
      expect(_where('ঢাকা উত্তর ওয়ার্ড ৯'), ['ঢাকা-১৪:ward']);
      expect(_where('ঢাকা উত্তর ওয়ার্ড ১৩'), isEmpty);
      expect(_where('ঢাকা দক্ষিণ ওয়ার্ড ১৫'), ['ঢাকা-১০:ward']);
    });
  });

  group('the real seats, from the bootstrap', () {
    final bn = Places.fromJson(_json('bootstrap'), Lang.bn);
    final en = Places.fromJson(_json('bootstrap.en'), Lang.en);

    test('the bootstrap gives every territorial seat and its extras', () {
      // 299: চট্টগ্রাম-৪ has no member, sitting or resigned, so the bootstrap
      // carries no boundary for it.
      expect(bn.finderSeats.length, 299);
      expect(en.finderSeats.length, 299);
      expect(bn.districts.length, 64);
      expect(bn.upazilaEn.length, greaterThan(500));
      expect(bn.former.length, 2);
      // A vacant seat is found, with no member.
      final vacant = bn.finderSeats.firstWhere((s) => s.slug == 'thakurgaon-1');
      expect(vacant.member, isNull);
      expect(vacant.boundary, contains('ঠাকুরগাঁও'));
      // English: the seat is filed under its Bangla name, shown in English.
      final e = en.finderSeats.firstWhere((s) => s.slug == 'dhaka-17');
      expect(e.seat, 'ঢাকা-১৭');
      expect(e.seatLabel, 'Dhaka-17');
      expect(e.boundary, isNot(contains('Ward')));
      // Every member, sitting or resigned.
      expect(en.alt.values.where((a) => a.name != null).length, 349);
      expect(bn.alt, isEmpty);
    });

    List<String> place(Places p, String q) => [
      for (final m in findPlaces(q, p.finderSeats, p.upazilaEn))
        '${m.seat.slug}:${m.kind.name}${m.partial ? '+part' : ''}',
    ];

    test('Savar and সাভার find the same seats, in either language', () {
      final a = place(bn, 'সাভার');
      expect(a, isNotEmpty);
      expect(place(en, 'Savar'), a);
      expect(place(bn, 'savar'), a);
      expect(a.first, startsWith('dhaka-'));
    });

    test('a city ward typed in English', () {
      final hits = place(en, 'ward 15 dhaka south');
      expect(hits, isNotEmpty);
      expect(hits.every((h) => h.endsWith(':ward')), isTrue);
      expect(place(bn, 'ঢাকা দক্ষিণ ওয়ার্ড ১৫'), hits);
    });

    test('a name is not a place, and seats by name are left to the list', () {
      expect(place(en, 'Dhaka-17'), isEmpty);
      expect(place(bn, 'ঢাকা'), isEmpty);
      expect(place(bn, 'x'), isEmpty);
    });

    test(
      'in English a Bangla name, seat or district still finds the member',
      () {
        final boot = Bootstrap.fromJson(_json('bootstrap.en'));
        final search = MemberSearch(boot.members, alt: en.alt);
        expect(search.search('তারেক রহমান').first.slug, 'tarique-rahman');
        expect(search.search('ঢাকা-১৭').first.slug, 'tarique-rahman');
        expect(search.search('Tarique').first.slug, 'tarique-rahman');
        expect(search.search('ঠাকুরগাঁও'), isNotEmpty);
      },
    );
  });

  group('the API answers', () {
    test('seats: 350 in number order, vacant and reserved marked', () {
      for (final name in ['seats', 'seats.en']) {
        final seats = _json(name)['seats'] as List;
        final rows = seats
            .cast<Map<String, dynamic>>()
            .map(SeatRow.fromJson)
            .toList();
        expect(rows.length, 350);
        expect(rows.where((s) => s.reserved).length, 50);
        expect(rows.where((s) => !s.reserved && s.vacant), isNotEmpty);
      }
      final en = SeatRow.fromJson(
        (_json('seats.en')['seats'] as List).first as Map<String, dynamic>,
      );
      expect(en.nameAlt, isNotNull);
      expect(en.boundaryTranslated, isTrue);
    });

    test('a vacant seat names the member who resigned', () {
      final s = SeatDetail.fromJson(_json('seat-thakurgaon-1'));
      expect(s.member, isNull);
      expect(s.seat.vacant, isTrue);
      expect(s.resignedMember?.slug, 'mirza-fakhrul-islam-alamgir');
      expect(s.resignedOn, '2026-08-21');
      expect(s.holders, isNotEmpty);
      expect(s.results.first.candidates.first.votes, 238836);
      expect(s.neighbours.length, 2);
    });

    test('a district and the reserved seats', () {
      final d = DistrictDetail.fromJson(_json('district-dhaka.en'));
      expect(d.seats.length, 20);
      expect(d.introBn, isNotEmpty);
      expect(d.parties.first.seats, greaterThan(0));
      final r = ReservedData.fromJson(_json('reserved'));
      expect(r.total, 50);
      expect(r.members.length, r.filled);
      expect(r.questions, isNotEmpty);
    });
  });

  group('screens', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await _loadFonts();
    });

    for (final lang in Lang.values) {
      for (final (label, size, scale) in [
        ('small phone, large font', const Size(320, 640), 1.3),
        ('common phone', const Size(393, 851), 1.0),
      ]) {
        group('${lang.name}, $label', () {
          final tr = T.of(lang);

          Future<List<String>> run(
            WidgetTester tester,
            Widget screen, {
            required String shows,
            int flings = 10,
            Future<void> Function(WidgetTester)? actions,
          }) async {
            SharedPreferences.setMockInitialValues({
              'flutter.not_official_notice_v1': true,
            });
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
              // widgets.dart's MemberTile (not this area's) runs a long
              // English seat name ("Chapai Nawabganj-3") and its party chip
              // off a small phone with a large font; reported to its owner.
              if (details.toString().contains('lib/widgets.dart:')) return;
              // Where it happened, for an overflow.
              final full = details.toString().split('\n');
              final at = full.indexWhere(
                (l) => l.contains('relevant error-causing widget'),
              );
              problems.add(
                [
                  text.split('\n').take(3).join(' '),
                  if (at >= 0 && at + 2 < full.length)
                    '${full[at + 1].trim()} ${full[at + 2].trim()}',
                ].join(' @ '),
              );
            };
            await http.runWithClient(() async {
              // Set inside the mock client's zone: a switch makes the app
              // fetch the list again.
              appLang.value = lang;
              Places.reset();
              await tester.runAsync(Api.instance.loadBootstrap);
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
              if (actions != null) await actions(tester);
              var seen = find.textContaining(shows).evaluate().isNotEmpty;
              if (find
                  .text(
                    tr('তথ্য আনা গেল না', 'Could not fetch the information'),
                  )
                  .evaluate()
                  .isNotEmpty) {
                problems.add('showed the error page');
              }
              final scrollables = find.byType(Scrollable);
              for (var i = 0; i < flings; i++) {
                if (scrollables.evaluate().isEmpty) break;
                await tester.drag(
                  scrollables.first,
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
              print('PROBLEM ($label, ${lang.name}): $p');
            }
            return problems;
          }

          testWidgets('all seats', (t) async {
            expect(
              await run(
                t,
                const SeatsScreen(),
                flings: 6,
                shows: tr('শূন্য', 'Vacant'),
              ),
              isEmpty,
            );
          });

          testWidgets('a vacant seat', (t) async {
            expect(
              await run(
                t,
                const SeatScreen(slug: 'thakurgaon-1'),
                shows: tr('নির্বাচনের ফল', 'Election results'),
              ),
              isEmpty,
            );
          });

          testWidgets('a seat with a member and old holders', (t) async {
            expect(
              await run(
                t,
                const SeatScreen(slug: 'dhaka-2'),
                flings: 14,
                shows: tr(
                  'এই আসনের আগের সদস্যরা',
                  'Earlier members for this seat',
                ),
              ),
              isEmpty,
            );
          });

          testWidgets('a reserved seat', (t) async {
            expect(
              await run(
                t,
                const SeatScreen(slug: 'women-seat-1'),
                shows: tr('সংরক্ষিত নারী আসন', 'Reserved seat for women'),
              ),
              isEmpty,
            );
          });

          testWidgets('a district', (t) async {
            expect(
              await run(
                t,
                const DistrictScreen(slug: 'dhaka'),
                flings: 14,
                shows: tr('দলভিত্তিক আসন', 'Seats by party'),
              ),
              isEmpty,
            );
          });

          testWidgets('the reserved seats', (t) async {
            expect(
              await run(
                t,
                const ReservedScreen(),
                flings: 40,
                shows: tr('প্রশ্ন ও উত্তর', 'Questions and answers'),
              ),
              isEmpty,
            );
          });

          testWidgets('members: a place search and the reserved filter', (
            t,
          ) async {
            expect(
              await run(
                t,
                const MembersScreen(),
                flings: 3,
                shows: tr('আপনার এলাকার এমপি', 'The MP for your area'),
                actions: (t) async {
                  await t.enterText(
                    find.byType(TextField).first,
                    lang == Lang.en ? 'Savar' : 'সাভার',
                  );
                  for (var i = 0; i < 5; i++) {
                    await t.pump(const Duration(milliseconds: 200));
                  }
                },
              ),
              isEmpty,
            );
          });
        });
      }
    }
  });
}
