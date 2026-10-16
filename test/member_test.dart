// The member's page, in both languages, from answers saved from the site's
// API (test/fixtures/member): what it parses, what it shows, and that it lays
// out on a small phone with a large font with no overflow or exception.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymp/api.dart';
import 'package:mymp/data/member.dart';
import 'package:mymp/i18n.dart';
import 'package:mymp/maps/seat_map.dart';
import 'package:mymp/models.dart';
import 'package:mymp/screens/member_screen.dart';
import 'package:mymp/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dir = 'test/fixtures/member';

String? _read(String name, bool en) {
  final e = File('$_dir/$name.en.json');
  if (en && e.existsSync()) return e.readAsStringSync();
  final f = File('$_dir/$name.json');
  return f.existsSync() ? f.readAsStringSync() : null;
}

final _client = MockClient((req) async {
  final path = req.url.path;
  final en = req.url.queryParameters['lang'] == 'en';
  String? body;
  if (path.endsWith('/bootstrap')) {
    body = _read('bootstrap', en);
  } else if (path.startsWith('/api/app/v1/mp/')) {
    body = _read('mp-${path.split('/').last}', en);
  } else if (path.startsWith('/geo/')) {
    body = _read('geo-${path.split('/').last.replaceAll('.json', '')}', false);
  } else if (path.startsWith('/api/feed/')) {
    body = '{"pinned":[],"items":[]}';
  }
  if (body == null) return http.Response('{"error":"not found"}', 404);
  return http.Response.bytes(
    utf8.encode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
});

MemberProfile _profile(String slug, {bool en = false}) =>
    MemberProfile.fromJson(
      jsonDecode(_read('mp-$slug', en)!) as Map<String, dynamic>,
    );

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

  group('parsing', () {
    test('the prime minister: offices, Wikipedia facts, links', () {
      final p = _profile('tarique-rahman');
      expect(p.rolesBn, ['প্রধানমন্ত্রী', 'সংসদ নেতা']);
      expect(p.bioFromWiki, {'educationBn', 'birthPlaceBn', 'professionBn'});
      expect(p.bioSource, hasLength(2));
      expect(p.bioSources.first.label, 'উইকিপিডিয়া (বাংলা)');
      expect(p.socials.map((s) => s.key), ['facebook', 'website']);
      expect(p.seat?.districtSlug, 'dhaka');
      expect(p.termStart, '2026-02-17');
      expect(p.committeesTotal, greaterThan(0));
    });

    test('a resigned member: the API answers, with an introduction', () {
      final p = _profile('mirza-fakhrul-islam-alamgir', en: true);
      expect(p.resignedOn, '2026-08-21');
      expect(p.introBn, hasLength(2));
      expect(p.nameAlt, 'মির্জা ফখরুল ইসলাম আলমগীর');
      expect(p.seat?.vacantSince, '2026-08-21');
      expect(p.seat?.boundaryTranslated, isTrue);
    });

    test('whips, posts, notices, earlier terms, a result not won', () {
      expect(_profile('nurul-islam-moni').rolesBn, contains('চিফ হুইপ'));
      expect(
        _profile('forhad-hossain-azad').postBadgesBn,
        contains('প্রতিমন্ত্রী, পানি সম্পদ মন্ত্রণালয়'),
      );
      expect(_profile('md-sadique-reaz').notices.first.pdfUrl, isNotNull);
      final prior = _profile('md-jahidur-rahaman', en: true).priorTerms;
      expect(prior.first.labelBn, '11th Parliament, 2018');
      final r = _profile('dr-abdul-moyeen-khan').result!;
      expect(r.won, isFalse);
      expect(r.candidates.first.votes, greaterThan(r.candidates[1].votes));
      expect(_profile('md-salim-bhuiyan').facebookNotice, isNotNull);
      expect(_profile('selima-rahman').seat?.reserved, isTrue);
    });

    test('a district map: places, kinds and the seats they lie in', () {
      final j = jsonDecode(_read('geo-dhaka', false)!) as Map<String, dynamic>;
      final places = [
        for (final f in (j['features'] as List).cast<Map<String, dynamic>>())
          ?GeoPlace.fromJson(f),
      ];
      expect(places, isNotEmpty);
      final mine = places.where((p) => p.seats['dhaka-17'] != null);
      expect(mine.every((p) => p.kind == 'ward'), isTrue);
      expect(mine.first.city, 'ঢাকা উত্তর সিটি কর্পোরেশন');
    });

    test('names in capitals are written as names', () {
      expect(titleCaseName('TARIQUE RAHMAN'), 'Tarique Rahman');
      expect(titleCaseName('Md. Abdus Salam'), 'Md. Abdus Salam');
    });
  });

  for (final lang in Lang.values) {
    final en = lang == Lang.en;
    final tr = T.of(lang);

    group('on a small phone, ${lang.name}', () {
      Future<List<String>> show(
        WidgetTester tester,
        Widget screen, {
        required List<String> expects,
        int drags = 30,
      }) async {
        SharedPreferences.setMockInitialValues({
          'flutter.not_official_notice_v1': true,
          // The English list as the app keeps it, for the map's upazila names.
          'flutter.bootstrap_v4_en': _read('bootstrap', true)!,
        });
        tester.view.physicalSize = const Size(320, 640) * 3;
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
          problems.add(
            text.contains('overflowed')
                ? details.toString().split('\n').take(40).join('\n')
                : text.split('\n').take(3).join(' '),
          );
        };
        final seen = <String>{};
        void look() {
          for (final e in expects) {
            if (find.textContaining(e).evaluate().isNotEmpty) seen.add(e);
          }
        }

        await http.runWithClient(() async {
          // Switched inside the mock client: the list is fetched again on a switch.
          appLang.value = lang;
          await Api.instance.loadBootstrap();
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: screen,
            ),
          );
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          look();
          for (var i = 0; i < drags; i++) {
            await tester.dragFrom(
              const Offset(160, 560),
              const Offset(0, -380),
            );
            await tester.pump(const Duration(milliseconds: 250));
            look();
          }
        }, () => _client);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        FlutterError.onError = previous;
        final taken = tester.takeException();
        if (taken != null) problems.add('$taken');
        for (final e in expects) {
          if (!seen.contains(e)) problems.add('did not show "$e"');
        }
        for (final p in problems) {
          // ignore: avoid_print
          print('PROBLEM: $p');
        }
        return problems;
      }

      MemberBrief brief(String slug) {
        final p = _profile(slug, en: en);
        return p.brief;
      }

      testWidgets('the prime minister', (t) async {
        expect(
          await show(
            t,
            MemberScreen(member: brief('tarique-rahman')),
            drags: 50,
            expects: [
              tr('সংসদ নেতা', 'Leader of the House'),
              tr('Tarique Rahman', 'তারেক রহমান'),
              tr(
                'বর্তমান সদস্য, ত্রয়োদশ সংসদ',
                'Current member, 13th Parliament',
              ),
              tr('সরকারি পদ সর্বশেষ যাচাই', 'Government posts last checked'),
              tr('উইকিপিডিয়া নিবন্ধ (বাংলা)', 'Bangla Wikipedia article'),
              tr('নির্বাচনী এলাকা', 'Constituency'),
              tr(
                'ঢাকা উত্তর সিটির ওয়ার্ড ১৫, ১৮, ১৯, ২০',
                'wards 15, 18, 19, 20',
              ),
              tr('সংসদে মেয়াদ', 'Terms in Parliament'),
              tr(
                '২০২৬ নির্বাচনে প্রাপ্ত ভোট',
                'Votes won in the 2026 election',
              ),
              tr('কার্য উপদেষ্টা কমিটি', 'Business Advisory Committee'),
              tr('অফিসিয়াল ওয়েবসাইট', 'Official website'),
              tr('একই দলের', 'Same party'),
              tr('ঢাকা জেলার অন্য আসন', 'Other seats in Dhaka district'),
            ],
          ),
          isEmpty,
        );
      });

      testWidgets('a member who resigned, known only by the slug', (t) async {
        expect(
          await show(
            t,
            MemberScreen.slug('mirza-fakhrul-islam-alamgir'),
            expects: [
              tr('মির্জা ফখরুল ইসলাম আলমগীর', 'Mirza Fakhrul Islam Alamgir'),
              tr('পদত্যাগ করেছেন, ২১ আগস্ট ২০২৬', 'Resigned, 21 August 2026'),
              tr(
                'তারিখে সংসদ সদস্য পদ থেকে পদত্যাগ করেছেন।',
                'Resigned as a Member of Parliament on 21 August 2026.',
              ),
              tr('মোট ৩ বার নির্বাচিত', 'Elected 3 times'),
              tr(
                'এই পরিচিতি এই পাতার তথ্য থেকে সাজানো',
                'This introduction is put together',
              ),
              tr(
                'হালনাগাদ কোনো কমিটিতে',
                'This member is not on any committee',
              ),
              tr('কোনো প্রজ্ঞাপন নেই', 'There are no Parliament Secretariat'),
            ],
          ),
          isEmpty,
        );
      });

      testWidgets('the chief whip, with notices and an earlier term', (
        t,
      ) async {
        expect(
          await show(
            t,
            MemberScreen(member: brief('nurul-islam-moni')),
            expects: [
              tr('চিফ হুইপ', 'Chief Whip'),
              tr(
                'সংসদ সচিবালয়ের প্রজ্ঞাপন',
                'Parliament Secretariat notifications',
              ),
              'PDF',
              tr('এলাকা', 'Area'),
            ],
          ),
          isEmpty,
        );
      });

      testWidgets('a state minister with a page still being checked', (
        t,
      ) async {
        expect(
          await show(
            t,
            MemberScreen(member: brief('forhad-hossain-azad')),
            expects: [
              tr(
                'প্রতিমন্ত্রী, পানি সম্পদ মন্ত্রণালয়',
                'State Minister, Ministry of Water Resources',
              ),
              tr('যাচাই করা হয়নি', 'Not verified'),
              if (en) 'Translated from Bangla.',
            ],
          ),
          isEmpty,
        );
      });

      testWidgets('a seat whose general election another won', (t) async {
        expect(
          await show(
            t,
            MemberScreen(member: brief('dr-abdul-moyeen-khan')),
            expects: [
              tr(
                '২০২৬ সালের সাধারণ নির্বাচনে এই আসনের ফল',
                'Result for this seat in the 2026 general election',
              ),
              tr('বর্তমান সংসদ সদস্যের নাম আলাদা', 'have different names'),
              tr('মূল পাতা', 'Original page'),
            ],
          ),
          isEmpty,
        );
      });

      testWidgets('a reserved seat with no email', (t) async {
        expect(
          await show(
            t,
            MemberScreen(member: brief('selima-rahman')),
            expects: [
              tr('সংরক্ষিত নারী আসন', 'Reserved seat for women'),
              tr(
                'সংরক্ষিত আসনের সদস্যদের ক্ষেত্রে এটি সাধারণ',
                'This is common for members in reserved seats',
              ),
            ],
          ),
          isEmpty,
        );
      });

      testWidgets('a Facebook page in dispute', (t) async {
        expect(
          await show(
            t,
            MemberScreen(member: brief('md-salim-bhuiyan')),
            expects: [
              tr('ফেসবুক পেজ যাচাই করা হয়নি', 'Facebook page not verified'),
            ],
          ),
          isEmpty,
        );
      });

      testWidgets('the speaker, with a summary', (t) async {
        expect(
          await show(
            t,
            MemberScreen(member: brief('hafiz-uddin-ahmad-bir-bikram')),
            expects: [tr('স্পিকার', 'Speaker')],
          ),
          isEmpty,
        );
      });

      testWidgets('the longest office and the longest name', (t) async {
        for (final slug in [
          'ariful-haque-choudhury',
          'kazi-shah-mofazzal-houssain-kaikobad',
        ]) {
          expect(
            await show(
              t,
              MemberScreen(member: brief(slug)),
              expects: [tr('তথ্য', 'Details')],
            ),
            isEmpty,
          );
        }
      });

      testWidgets('a seat that holds part of an upazila, on its own map', (
        t,
      ) async {
        expect(
          await show(
            t,
            Scaffold(
              body: ListView(
                children: [
                  SeatMap(
                    districtSlug: 'thakurgaon',
                    seatSlug: 'thakurgaon-3',
                    color: AppColors.party('BNP'),
                    districtName: tr('ঠাকুরগাঁও', 'Thakurgaon'),
                    note: 'Election Commission words',
                  ),
                ],
              ),
            ),
            drags: 2,
            expects: [
              tr('ঠাকুরগাঁও-৩', 'Thakurgaon-3'),
              tr(
                'পীরগঞ্জ উপজেলা, রাণীশংকৈল উপজেলা-এর একাংশ',
                'Pirganj upazila, part of Ranishankail upazila',
              ),
              tr(
                'নির্বাচন কমিশনের বর্ণনা:',
                "The Election Commission's description:",
              ),
              'OpenStreetMap',
            ],
          ),
          isEmpty,
        );
      });
    });
  }
}
