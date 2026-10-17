// The cabinet and adviser screens, against API answers saved in
// test/fixtures/cabinet/ (both languages): the grouping the website does, and
// the screens drawn on a small phone with a large font and on a common phone,
// scrolled end to end with no overflow.
//
// To refresh the fixtures from a local site:
//   curl localhost:3000/api/app/v1/cabinet > test/fixtures/cabinet/cabinet.json
//   curl "localhost:3000/api/app/v1/cabinet?lang=en" > test/fixtures/cabinet/cabinet.en.json
//   (and adviser/<slug> as adviser-<slug>.json / .en.json)
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymp/data/cabinet.dart';
import 'package:mymp/i18n.dart';
import 'package:mymp/screens/adviser_screen.dart';
import 'package:mymp/screens/cabinet_screen.dart';
import 'package:mymp/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dir = 'test/fixtures/cabinet';

Map<String, dynamic> _json(String name) =>
    jsonDecode(File('$_dir/$name.json').readAsStringSync())
        as Map<String, dynamic>;

/// Answers the app's requests from the fixtures; [cabinet] replaces the
/// cabinet answer, for a list with people still being checked.
MockClient _client({Map<String, dynamic>? cabinet}) => MockClient((req) async {
  final en = req.url.queryParameters['lang'] == 'en';
  final path = req.url.path;
  String? name;
  if (path.endsWith('/cabinet')) {
    if (cabinet != null) {
      return http.Response.bytes(utf8.encode(jsonEncode(cabinet)), 200);
    }
    name = 'cabinet';
  } else if (path.contains('/adviser/')) {
    name = 'adviser-${path.split('/').last}';
  }
  final f = File('$_dir/$name${en ? '.en' : ''}.json');
  if (name == null || !f.existsSync()) return http.Response('{}', 404);
  return http.Response.bytes(
    f.readAsBytesSync(),
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
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
  });
  tearDown(() => appLang.value = Lang.bn);

  group('the cabinet, grouped as the website groups it', () {
    for (final lang in Lang.values) {
      test('ranks in the page order, one card a person (${lang.name})', () {
        appLang.value = lang;
        final data = CabinetData.fromJson(
          _json(lang == Lang.en ? 'cabinet.en' : 'cabinet'),
        );
        final c = Cabinet.of(data);
        // The five ranks, each one even when empty, in the page's order.
        expect(
          c.groups.take(5).map((g) => g.rank),
          orderedEquals(cabinetRanks),
        );
        expect(
          c.groups.take(5).map((g) => g.label),
          lang == Lang.en
              ? [
                  'Prime Minister',
                  'Ministers',
                  'State Ministers',
                  'Deputy Ministers',
                  'Advisers',
                ]
              : [
                  'প্রধানমন্ত্রী',
                  'মন্ত্রী',
                  'প্রতিমন্ত্রী',
                  'উপমন্ত্রী',
                  'উপদেষ্টা',
                ],
        );
        // Every row the API gave lands in a known rank.
        expect(c.groups.length, 5);
        // The Prime Minister holds three ministries: one person, three rows.
        final pm = c.groups.first.people;
        expect(pm, hasLength(1));
        expect(pm.single.ministries, hasLength(3));
        expect(pm.single.isMp, isTrue);
        // No deputy ministers on this list: the page says so.
        expect(c.count(cabinetRanks[3]), 0);
        // The rows add up.
        final rows = c.everyone.fold(0, (n, p) => n + p.ministries.length);
        expect(rows, data.posts.length);
        // An adviser from outside Parliament with four ministries is one card.
        final mahdi = c.everyone.where((p) => p.adviserSlug == 'mahdi-amin');
        expect(mahdi, hasLength(1));
        expect(mahdi.single.ministries, hasLength(4));
        expect(mahdi.single.isMp, isFalse);
        expect(mahdi.single.rankNote, isNotNull);
        // The filter offers each ministry once, with how many hold it.
        expect(c.ministries, isNotEmpty);
        expect(
          c.ministries.map((m) => m.key).toSet(),
          hasLength(c.ministries.length),
        );
        // The make-up: parties largest first, those not MPs last.
        final shares = compositionOf(c.everyone);
        expect(shares.first.party, 'BNP');
        expect(shares.last.outside, isTrue);
        expect(shares.fold(0, (n, s) => n + s.count), c.everyone.length);
      });
    }

    test('both languages give the same counts', () {
      appLang.value = Lang.bn;
      final bn = Cabinet.of(CabinetData.fromJson(_json('cabinet')));
      appLang.value = Lang.en;
      final en = Cabinet.of(CabinetData.fromJson(_json('cabinet.en')));
      for (final r in cabinetRanks) {
        expect(en.count(r), bn.count(r), reason: r.bn);
      }
      expect(en.ministries.length, bn.ministries.length);
    });

    test('a rank is known by either spelling', () {
      expect(rankOf('প্রতিমন্ত্রী'), same(cabinetRanks[2]));
      expect(rankOf('State Minister'), same(cabinetRanks[2]));
      expect(rankOf('Minister of State'), same(cabinetRanks[2]));
      expect(rankOf('Adviser'), same(cabinetRanks[4]));
      expect(rankOf('Political Adviser'), isNull);
      expect(rankOf(null), isNull);
    });

    test("the list's typing slips are not a second ministry", () {
      expect(
        ministryKey('বিজ্ঞানও প্রযুক্তি মন্ত্রণালয়'),
        ministryKey('বিজ্ঞান ও প্রযুক্তি মন্ত্রণালয়'),
      );
      expect(
        ministryKey('প্রবাসী কল্যাণ ও বৈদেশিক কর্মসংংস্থান মন্ত্রণালয়'),
        ministryKey('প্রবাসী কল্যাণ ও বৈদেশিক কর্মসংস্থান মন্ত্রণালয়'),
      );
      expect(ministryKey('Ministry of Finance'), 'ministry of finance');
    });

    test('an unknown title follows the known ranks', () {
      appLang.value = Lang.en;
      final c = Cabinet.of(
        CabinetData.fromJson({
          'posts': [
            {'title': 'Adviser to the Prime Minister', 'holderBn': 'A B'},
            {'title': 'Minister', 'holderBn': 'C D', 'ministryBn': null},
          ],
        }),
      );
      expect(c.groups, hasLength(6));
      expect(c.groups.last.label, 'Adviser to the Prime Minister');
      // A ministry with no English is counted, not shown and not offered.
      expect(c.groups[1].people.single.ministries.single.name, isNull);
      expect(c.ministries, isEmpty);
    });

    test(
      'search finds a name, a ministry or a seat, and the Bangla on English',
      () {
        appLang.value = Lang.en;
        final c = Cabinet.of(CabinetData.fromJson(_json('cabinet.en')));
        final pm = c.groups.first.people.single;
        expect(pm.matches(pm.name!.toLowerCase().substring(0, 5)), isTrue);
        expect(pm.matches(pm.seat!.toLowerCase()), isTrue);
        expect(pm.matches('তারেক'), isTrue);
        expect(pm.matches('zzzz'), isFalse);
      },
    );

    test('adviser profiles parse in both languages', () {
      final bn = AdviserProfile.fromJson(_json('adviser-mahdi-amin'));
      expect(bn.posts, hasLength(4));
      expect(bn.bioTranslated, isFalse);
      expect(bn.sources, isNotEmpty);
      expect(bn.postNameBn, isNotNull);
      final en = AdviserProfile.fromJson(_json('adviser-mahdi-amin.en'));
      expect(en.postNameBn, isNull);
      expect(en.bioTranslated, isTrue);
      expect(en.sources.first.label, 'Wikipedia (Bangla)');
      expect(en.birthPlaceBn, isNull);
    });
  });

  for (final (label, size, scale) in [
    ('small phone, large font', const Size(320, 640), 1.3),
    ('common phone, normal font', const Size(393, 851), 1.0),
  ]) {
    for (final lang in Lang.values) {
      group('$label, ${lang.name}', () {
        final tr = T.of(lang);

        /// Draws [screen], runs [actions], scrolls it end to end and
        /// returns every layout problem met on the way.
        Future<List<String>> run(
          WidgetTester tester,
          Widget screen, {
          http.Client? client,
          int flings = 30,
          List<String> shows = const [],
          Future<void> Function(WidgetTester)? actions,
        }) async {
          appLang.value = lang;
          tester.view.physicalSize = size * 3;
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          final problems = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) {
            final text = details.exceptionAsString();
            // Photos are network images; a test has no network or cache dir.
            if (text.contains('MissingPluginException') ||
                text.contains('HTTP request failed') ||
                text.contains('NetworkImageLoadException') ||
                text.contains('SocketException')) {
              return;
            }
            problems.add(text.split('\n').take(3).join(' '));
          };
          final seen = <String>{};
          void look() {
            for (final s in shows) {
              if (find.textContaining(s).evaluate().isNotEmpty ||
                  find
                      .byWidgetPredicate(
                        (w) =>
                            w is RichText && w.text.toPlainText().contains(s),
                      )
                      .evaluate()
                      .isNotEmpty) {
                seen.add(s);
              }
            }
          }

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
            if (find
                .text(tr('তথ্য আনা গেল না', 'Could not fetch the information'))
                .evaluate()
                .isNotEmpty) {
              problems.add('showed the error page');
            }
            look();
            if (actions != null) {
              // A failed expectation is a problem to report, not a throw past
              // the error handler set above.
              try {
                await actions(tester);
              } catch (e) {
                problems.add('$e'.split('\n').take(4).join(' '));
              }
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
              look();
            }
          }, () => client ?? _client());
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          FlutterError.onError = previous;
          final taken = tester.takeException();
          if (taken != null) problems.add('$taken');
          for (final s in shows) {
            if (!seen.contains(s)) problems.add('did not show "$s"');
          }
          for (final p in problems) {
            // ignore: avoid_print
            print('PROBLEM: $p');
          }
          return problems;
        }

        testWidgets('cabinet, end to end', (t) async {
          expect(
            await run(
              t,
              const CabinetScreen(),
              shows: [
                tr('সর্বশেষ যাচাই', 'Last checked'),
                tr('মন্ত্রিসভায় মোট', 'In the Cabinet'),
                tr('সব সংসদ সদস্য', 'All MPs'),
                tr('এখন কেউ নেই', 'none at present'),
                tr('মন্ত্রিসভা দল অনুযায়ী', 'The Cabinet by party'),
                tr('সংসদ সদস্য নন', 'Not an MP'),
                tr('টি দায়িত্ব', 'responsibilities'),
                tr(
                  'পুরো পরিচিতি, সংবাদ ও ভিডিও',
                  'Full profile, news and videos',
                ),
                tr(
                  'প্রতিমন্ত্রীর পরের ধাপ।',
                  'The step below a state minister.',
                ),
                tr(
                  'মন্ত্রিপরিষদ বিভাগের তালিকায় এখন কোনো উপমন্ত্রী নেই।',
                  'The Cabinet Division’s list has no deputy ministers at present.',
                ),
                tr('থেকে', 'Since '),
                tr('পরিবর্তন', 'Changes'),
                tr('দায়িত্ব পেলেন', 'took office'),
              ],
            ),
            isEmpty,
          );
        });

        testWidgets('cabinet: search, no match, show everyone', (t) async {
          expect(
            await run(
              t,
              const CabinetScreen(),
              flings: 3,
              actions: (t) async {
                await t.enterText(find.byType(TextField), 'zzzz');
                await t.pump();
                expect(
                  find.textContaining(
                    tr('দিয়ে কাউকে পাওয়া যায়নি', 'Nobody found for'),
                  ),
                  findsOneWidget,
                );
                // Filtering hides the party bar and shows the way back.
                expect(
                  find.text(
                    tr('মন্ত্রিসভা দল অনুযায়ী', 'The Cabinet by party'),
                  ),
                  findsNothing,
                );
                final everyone = find.text(tr('সবাইকে দেখুন', 'Show everyone'));
                await t.ensureVisible(everyone);
                await t.pump();
                await t.tap(everyone);
                await t.pump();
                expect(
                  find.text(
                    tr('মন্ত্রিসভা দল অনুযায়ী', 'The Cabinet by party'),
                  ),
                  findsOneWidget,
                );
                // A rank's tile jumps to its list.
                final tile = find.text(tr('উপদেষ্টা', 'Advisers')).first;
                await t.ensureVisible(tile);
                await t.pump();
                await t.tap(tile);
                await t.pumpAndSettle(const Duration(milliseconds: 100));
                final note = find.text(
                  tr(
                    'নির্দিষ্ট বিষয়ে প্রধানমন্ত্রীকে পরামর্শ দেন; বেশিরভাগ উপদেষ্টা সংসদ সদস্য নন।',
                    'Advises the Prime Minister on particular matters; most advisers are not Members of Parliament.',
                  ),
                );
                expect(note, findsOneWidget);
                expect(t.getTopLeft(note).dy, inInclusiveRange(0, size.height));
              },
            ),
            isEmpty,
          );
        });

        testWidgets('cabinet with people still being checked', (t) async {
          final j = _json(lang == Lang.en ? 'cabinet.en' : 'cabinet');
          j['pending'] = [
            {
              'titleBn': tr('প্রতিমন্ত্রী', 'State Minister'),
              'nameBn': lang == Lang.en ? null : 'জনাব নতুন নাম',
              'ministries': [
                tr('পানি সম্পদ মন্ত্রণালয়', 'Ministry of Water Resources'),
              ],
            },
          ];
          expect(
            await run(
              t,
              const CabinetScreen(),
              client: _client(cabinet: j),
              shows: [
                tr(
                  'জন সংসদ সদস্য কিনা যাচাই হচ্ছে',
                  'being checked for whether they are MPs',
                ),
                tr('সংসদ সদস্য কিনা যাচাই হচ্ছে', 'Being checked: MP or not'),
                tr('নতুন নাম', 'Name given only in Bangla'),
              ],
            ),
            isEmpty,
          );
        });

        for (final slug in ['khalilur-rahman', 'humayun-kabir', 'mahdi-amin']) {
          testWidgets('adviser $slug', (t) async {
            expect(
              await run(
                t,
                AdviserScreen(slug: slug),
                flings: 20,
                shows: [
                  tr('সংসদ সদস্য নন', 'Not an MP'),
                  tr('পরিচিতি', 'Profile'),
                  tr('পর্যন্ত মিলিয়ে দেখা', 'Checked up to'),
                  tr('জানান', 'let us know'),
                  tr('দায়িত্ব', 'Responsibilities'),
                  tr('পুরো মন্ত্রিসভা', 'The whole Cabinet'),
                  if (lang == Lang.en) 'Read the original',
                ],
              ),
              isEmpty,
            );
          });
        }
      });
    }
  }
}
