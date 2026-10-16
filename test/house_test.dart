// The House screens: sessions, committees, one committee, one party. Parsed
// from saved API answers (test/fixtures/house, both languages) and drawn on a
// small phone with a large font and on a common phone, scrolled end to end:
// any overflow or exception fails the test.
//
// The fixtures were saved from a local copy of the site:
//   curl http://localhost:3000/api/app/v1/sessions?lang=en > sessions.en.json
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymp/api.dart';
import 'package:mymp/data/house.dart';
import 'package:mymp/i18n.dart';
import 'package:mymp/models.dart';
import 'package:mymp/screens/committee_screen.dart';
import 'package:mymp/screens/committees_screen.dart';
import 'package:mymp/screens/member_screen.dart';
import 'package:mymp/screens/house_widgets.dart';
import 'package:mymp/screens/party_screen.dart';
import 'package:mymp/screens/sessions_screen.dart';
import 'package:mymp/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dir = 'test/fixtures/house';

Map<String, dynamic> _json(String name) =>
    jsonDecode(File('$_dir/$name.json').readAsStringSync())
        as Map<String, dynamic>;

String _fixture(Uri url) {
  final path = url.path;
  final last = path.split('/').last;
  String name;
  if (path.endsWith('/bootstrap')) {
    name = 'bootstrap';
  } else if (path.endsWith('/sessions')) {
    name = 'sessions';
  } else if (path.endsWith('/committees')) {
    name = 'committees';
  } else if (path.contains('/committee/')) {
    name = 'committee-$last';
  } else if (path.contains('/party/')) {
    name = 'party-$last';
  } else if (path.contains('/mp/')) {
    name = 'mp-$last';
  } else if (path.contains('/api/feed/')) {
    name = 'feed-$last';
  } else {
    return '';
  }
  final en = url.queryParameters['lang'] == 'en';
  final f = File('$_dir/$name${en ? '.en' : ''}.json');
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

Future<void> _loadFonts() async {
  final loader = FontLoader('NotoSansBengali');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/NotoSansBengali-$w.ttf'));
  }
  await loader.load();
}

/// Dhaka wall-clock time as an instant.
DateTime _dhaka(int y, int m, int d, [int h = 0, int min = 0]) =>
    DateTime.utc(y, m, d, h, min).subtract(const Duration(hours: 6));

void main() {
  group('parsing', () {
    test('sessions, both languages', () {
      final bn = SessionsData.fromJson(_json('sessions'));
      final en = SessionsData.fromJson(_json('sessions.en'));
      for (final d in [bn, en]) {
        expect(d.sessions, isNotEmpty);
        expect(d.sessionCount, d.sessions.length);
        expect(
          d.sittingCount,
          d.sessions.fold<int>(0, (n, s) => n + s.sittings.length),
        );
        expect(d.parliament.no, 13);
        expect(d.parliament.oathDate, '2026-02-17');
        expect(d.officers.map((o) => o.role), contains('WHIP'));
        // The officers the source links to a member open that member.
        expect(d.officers.where((o) => o.member != null), isNotEmpty);
        expect(d.generalNotices, isNotEmpty);
      }
      expect(bn.sessions.first.title, 'তৃতীয় অধিবেশন');
      expect(en.sessions.first.title, '3rd session');
      expect(bn.sessions.first.firstCircular?.title, 'পরিপত্র-১');
      // English has no Bangla anywhere a title is shown.
      final bangla = RegExp('[ঀ-৿]');
      for (final s in en.sessions) {
        expect(s.title, isNot(matches(bangla)));
        for (final o in s.sittings) {
          expect(o.title ?? '', isNot(matches(bangla)));
          expect(o.weekday ?? '', isNot(matches(bangla)));
        }
      }
      for (final o in en.officers) {
        expect(o.roleName, isNot(matches(bangla)));
      }
    });

    test('committees and a committee, both languages', () {
      for (final suffix in ['', '.en']) {
        final list = CommitteesData.fromJson(_json('committees$suffix'));
        expect(list.committees.length, list.total);
        expect(
          list.committees.where((c) => c.rosterCurrent).length,
          list.current,
        );
        // Up-to-date committees come first.
        final firstPending = list.committees.indexWhere(
          (c) => !c.rosterCurrent,
        );
        expect(
          list.committees.skip(firstPending).every((c) => !c.rosterCurrent),
          isTrue,
        );
        // A committee awaiting its new list names no chair.
        expect(
          list.committees.where((c) => !c.rosterCurrent && c.chair != null),
          isEmpty,
        );

        final pac = CommitteeDetail.fromJson(
          _json('committee-standing-committee-on-public-accounts$suffix'),
        );
        expect(pac.rosterCurrent, isTrue);
        expect(pac.chair, isNotNull);
        expect(pac.members.first.isChair, isTrue);
        expect(pac.duty?.duties, isNotEmpty);
        expect(pac.duty?.rulesUrl, startsWith('https://'));
        expect(pac.notices, isNotEmpty);

        final old = CommitteeDetail.fromJson(
          _json('committee-public-accounts-committee-pac$suffix'),
        );
        expect(old.rosterCurrent, isFalse);
        expect(old.members, isEmpty);

        final sub = CommitteeDetail.fromJson(
          _json('committee-sub-committee-no-1-of-library-committee$suffix'),
        );
        expect(sub.duty?.parent?.slug, 'library-committee');
      }
    });

    test('a party, both languages', () {
      final bn = PartyDetail.fromJson(_json('party-bnp'));
      final en = PartyDetail.fromJson(_json('party-bnp.en'));
      for (final p in [bn, en]) {
        expect(p.abbr, 'BNP');
        expect(p.seats, p.seatsTerritorial + p.seatsReserved);
        expect(p.territorial.length, p.seatsTerritorial);
        expect(p.reservedMembers.length, p.seatsReserved);
        // Elected members first, then those for reserved seats.
        expect(p.members.indexWhere((m) => m.reserved), p.seatsTerritorial);
        expect(p.profile?.origin, isNotEmpty);
        expect(p.profile?.leader?.slug, 'tarique-rahman');
        expect(p.logo?.licence, 'CC0');
      }
      expect(bn.profile?.symbol, 'ধানের শীষ');
      expect(en.profile?.symbol, 'Sheaf of paddy');
      final ind = PartyDetail.fromJson(_json('party-ind'));
      expect(ind.profile, isNull);
      expect(ind.logo, isNull);
    });

    test('a broken answer parses to empty, not a crash', () {
      expect(
        SessionsData.fromJson({
          'sessions': 'x',
          'officers': [1],
        }).sessions,
        isEmpty,
      );
      expect(
        CommitteeDetail.fromJson({
          'members': [{}],
        }).members,
        isEmpty,
      );
      expect(PartyDetail.fromJson({'profile': 3}).profile, isNull);
    });
  });

  group('the session clock', () {
    // The 3rd session began on 27 August 2026; its last sitting was on 10
    // September, and the source has not closed it.
    const start = '2026-08-27';
    const last = '2026-09-10';

    test('before the first day: what is left to midnight in Dhaka', () {
      final st = sessionClockAt(_dhaka(2026, 8, 25, 21, 30), start, null, null);
      expect(st, isA<ClockBefore>());
      st as ClockBefore;
      expect([st.days, st.hours, st.minutes, st.seconds], [1, 2, 30, 0]);
    });

    test('while it sits: which day of the session', () {
      expect(
        (sessionClockAt(_dhaka(2026, 8, 27, 0, 1), start, null, null)
                as ClockSitting)
            .day,
        1,
      );
      expect(
        (sessionClockAt(_dhaka(2026, 9, 3, 23), start, null, '2026-09-02')
                as ClockSitting)
            .day,
        8,
      );
    });

    test('after: days since the last sitting', () {
      final st = sessionClockAt(_dhaka(2026, 10, 17, 9), start, null, last);
      expect(st, isA<ClockAfter>());
      expect((st as ClockAfter).days, 37);
      // A closing date closes it the day after.
      expect(
        sessionClockAt(_dhaka(2026, 9, 11, 1), start, '2026-09-10', last),
        isA<ClockAfter>(),
      );
    });

    test('days since a day, on the Dhaka calendar', () {
      expect(daysSinceDay(last, _dhaka(2026, 9, 10, 23, 59)), 0);
      expect(daysSinceDay(last, _dhaka(2026, 9, 11, 0, 1)), 1);
      expect(weekdayOfDay('2026-09-10'), DateTime.thursday);
    });
  });

  group('screens', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      // Set once: resetting the store while a language switch's background
      // load is waiting for it breaks shared_preferences.
      SharedPreferences.setMockInitialValues({
        'flutter.not_official_notice_v1': true,
      });
      await _loadFonts();
    });

    for (final lang in Lang.values) {
      for (final (label, size, scale) in [
        ('small phone, large font', const Size(320, 640), 1.3),
        ('common phone, normal font', const Size(393, 851), 1.0),
      ]) {
        group('${lang.name}, $label', () {
          final tr = T.of(lang);

          Future<List<String>> run(
            WidgetTester tester,
            Widget screen, {
            required String shows,
            int flings = 12,
            Future<void> Function(WidgetTester)? actions,
          }) async {
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
              problems.add(text.split('\n').take(3).join(' '));
            };

            await http.runWithClient(() async {
              // Switched in the mock's zone: a switch starts a load at once.
              appLang.value = lang;
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
              for (var i = 0; i < flings; i++) {
                final scrollables = find.byType(Scrollable);
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

          testWidgets('sessions, after the last sitting', (t) async {
            expect(
              await run(
                t,
                SessionsScreen(clock: () => _dhaka(2026, 10, 17, 9)),
                shows: tr('সংসদ পরিচালনায়', 'Running the House'),
                flings: 30,
              ),
              isEmpty,
            );
          });

          testWidgets('sessions, the countdown band in each state', (t) async {
            for (final (at, says) in [
              (
                _dhaka(2026, 10, 17, 9),
                tr(
                  'পরের অধিবেশনের তারিখ এখনো ঘোষণা হয়নি',
                  'the date of the next session has not yet been announced',
                ),
              ),
              (
                _dhaka(2026, 8, 25, 21, 30),
                tr('শুরুর দিন পর্যন্ত বাকি', 'Left until the first day'),
              ),
              (_dhaka(2026, 9, 1, 10), tr('অধিবেশন চলছে', 'In session')),
            ]) {
              expect(
                await run(
                  t,
                  SessionsScreen(clock: () => at),
                  shows: says,
                  flings: 0,
                ),
                isEmpty,
              );
            }
          });

          testWidgets('committees', (t) async {
            expect(
              await run(
                t,
                const CommitteesScreen(),
                shows: tr(
                  'সদস্য তালিকা হালনাগাদের অপেক্ষায়',
                  'Member list awaiting update',
                ),
                flings: 160,
              ),
              isEmpty,
            );
          });

          for (final (slug, shows) in [
            (
              'standing-committee-on-public-accounts',
              tr('কমিটি তথ্য', 'About the committee'),
            ),
            (
              'public-accounts-committee-pac',
              tr('এখনো হালনাগাদ হয়নি', 'not yet been updated'),
            ),
            (
              'sub-committee-no-1-of-library-committee',
              tr('মূল কমিটি', 'Parent committee'),
            ),
          ]) {
            testWidgets('committee $slug', (t) async {
              expect(
                await run(
                  t,
                  CommitteeScreen(slug: slug),
                  shows: shows,
                  flings: 20,
                ),
                isEmpty,
              );
            });
          }

          for (final (slug, shows) in [
            ('bnp', tr('এক নজরে', 'At a glance')),
            ('ncp', tr('প্রতিষ্ঠাতা', 'Founders')),
            (
              'ind',
              tr('স্বতন্ত্র কোনো রাজনৈতিক দল নয়', 'Independents are not'),
            ),
          ]) {
            testWidgets('party $slug', (t) async {
              final boot = Bootstrap.fromJson(
                _json(lang == Lang.en ? 'bootstrap.en' : 'bootstrap'),
              );
              final party = boot.parties.firstWhere((p) => p.slug == slug);
              expect(
                await run(
                  t,
                  PartyScreen(party: party),
                  shows: shows,
                  flings: 14,
                ),
                isEmpty,
              );
            });
          }
        });
      }
    }

    testWidgets('a party opens from the list on the phone with no signal', (
      tester,
    ) async {
      final offline = MockClient((req) async {
        if (req.url.path.contains('/party/')) {
          throw http.ClientException('no network');
        }
        return _client
            .send(http.Request(req.method, req.url))
            .then(http.Response.fromStream);
      });
      await http.runWithClient(() async {
        appLang.value = Lang.bn;
        await tester.runAsync(Api.instance.loadBootstrap);
        final boot = Api.instance.cached!;
        // A party no other test has opened, so nothing of it is held.
        final party = boot.parties.firstWhere((p) => p.slug == 'bjei');
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: PartyScreen(party: party),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.byType(HouseMemberRow), findsWidgets);
        expect(find.textContaining('জন সংসদ সদস্য'), findsOneWidget);
        expect(find.text('দলের পরিচিতি এখন আনা গেল না।'), findsOneWidget);
        expect(find.text('তথ্য আনা গেল না'), findsNothing);
      }, () => offline);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a committee member opens the member page', (tester) async {
      tester.view.physicalSize = const Size(393, 851) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await http.runWithClient(() async {
        appLang.value = Lang.bn;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: const CommitteeScreen(
              slug: 'sub-committee-no-1-of-library-committee',
            ),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        final row = find.byType(HouseMemberRow).first;
        await tester.ensureVisible(row);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(row);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(MemberScreen), findsOneWidget);
      }, () => _client);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      tester.takeException();
    });
  });
}
