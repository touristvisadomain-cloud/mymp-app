// The news area: the news tab and a member's news (MemberFeed), parsed from
// saved API answers (test/fixtures/news, both languages) and drawn on a small
// phone with a large font and on a common phone, scrolled end to end: any
// overflow or exception fails the test.
//
// The fixtures were saved from a local copy of the site and trimmed:
//   /api/app/v1/news?limit=400            news.json       (90 of 400 kept)
//   /api/app/v1/news/counts                counts.json
//   /api/app/v1/news?from=2026-10-01&to=2026-10-17   range.json (60 of 300)
//   /api/feed/tarique-rahman               feed.json       (75 items)
//   /api/feed/tarique-rahman?m=2026-09     feed-month.json (35)
//   /api/feed/tarique-rahman?from=…&to=…   feed-range.json (40)
// each also with &lang=en as <name>.en.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymp/data/news.dart';
import 'package:mymp/i18n.dart';
import 'package:mymp/models.dart';
import 'package:mymp/screens/member_feed.dart';
import 'package:mymp/screens/news_screen.dart';
import 'package:mymp/screens/story_list.dart';
import 'package:mymp/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dir = 'test/fixtures/news';

String _read(String name, bool en) {
  final f = File('$_dir/$name${en ? '.en' : ''}.json');
  return f.readAsStringSync();
}

Map<String, dynamic> _json(String name, {bool en = false}) =>
    jsonDecode(_read(name, en)) as Map<String, dynamic>;

/// Every request the screens made, for the tests to check.
final _asked = <Uri>[];

String? _fixture(Uri url) {
  final path = url.path;
  final q = url.queryParameters;
  final en = q['lang'] == 'en';
  if (path.endsWith('/news/counts')) return _read('counts', en);
  if (path.endsWith('/app/v1/news')) {
    if (q.containsKey('from')) {
      if (q.containsKey('before')) {
        // The next page: the same stories again, which must not be shown
        // twice, and no page after it.
        final j = _json('range', en: en);
        j['next'] = null;
        j['counts'] = null;
        return jsonEncode(j);
      }
      return _read('range', en);
    }
    return _read('news', en);
  }
  if (path.startsWith('/api/feed/')) {
    if (q.containsKey('m')) return _read('feed-month', en);
    if (q.containsKey('from')) return _read('feed-range', en);
    return _read('feed', en);
  }
  return null;
}

final _client = MockClient((req) async {
  _asked.add(req.url);
  final body = _fixture(req.url);
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
  setUp(() => appLang.value = Lang.bn);
  tearDown(() => appLang.value = Lang.bn);

  group('parsing', () {
    test('the figures, both languages', () {
      for (final en in [false, true]) {
        final c = NewsCounts.fromJson(_json('counts', en: en));
        expect(c.totalNews, greaterThan(0));
        expect(c.months, isNotEmpty);
        expect(
          c.months.first.total,
          c.months.first.news + c.months.first.video,
        );
        expect(c.outletCount, greaterThan(100));
      }
      // A field the site drops, or a new one, breaks nothing.
      final empty = NewsCounts.fromJson(const {'unavailable': true, 'x': 1});
      expect(empty.unavailable, isTrue);
      expect(empty.months, isEmpty);
    });

    test('a span page carries its cursor and totals', () {
      final p = NewsRangePage.fromJson(_json('range'));
      expect(p.stories, hasLength(60));
      expect(p.next, isNotNull);
      expect(p.counts!.news, greaterThan(0));
      final last = NewsRangePage.fromJson(const {
        'stories': [],
        'next': null,
        'counts': null,
      });
      expect(last.next, isNull);
      expect(last.counts, isNull);
    });

    test('a member feed, both languages', () {
      for (final en in [false, true]) {
        final f = MemberFeedData.fromJson(_json('feed', en: en));
        expect(f.month, matches(RegExp(r'^\d{4}-\d{2}$')));
        expect(f.items, isNotEmpty);
        expect(f.months.first.month, f.month);
        expect(f.outlets.length, greaterThan(1));
        expect(f.items.where((i) => i.summary != null), isNotEmpty);
      }
      final e = FeedEntry.fromJson(const {
        'id': 7,
        'type': 'press',
        'title': 'প্রজ্ঞাপন',
        'url': 'https://example.org',
        'summary': '  ',
        'publishedAt': '2026-10-16T19:18:29.915+00:00',
        'alsoIn': [
          {'outletName': null, 'url': 'https://a.example'},
        ],
        'pinned': true,
      });
      expect(e.type, 'press');
      expect(e.summary, isNull);
      expect(e.alsoIn.single.outletName, isNull);
      expect(e.pinned, isTrue);
    });
  });

  group('days and spans', () {
    test('today in Dhaka turns at midnight in Dhaka, not in UTC', () {
      expect(dhakaToday(now: DateTime.utc(2026, 10, 16, 17, 59)), '2026-10-16');
      expect(dhakaToday(now: DateTime.utc(2026, 10, 16, 18, 0)), '2026-10-17');
    });

    test('adding days crosses months and years', () {
      expect(addDays('2026-10-17', -6), '2026-10-11');
      expect(addDays('2026-03-01', -1), '2026-02-28');
      expect(addDays('2025-12-31', 1), '2026-01-01');
    });

    test('a month ends today while it is the current one', () {
      expect(monthSpan('2026-09', '2026-10-17'), '2026-09-01~2026-09-30');
      expect(monthSpan('2026-10', '2026-10-17'), '2026-10-01~2026-10-17');
      expect(monthSpan('2026-02', '2026-10-17'), '2026-02-01~2026-02-28');
    });

    test('a span reads earlier end first', () {
      expect(parseSpan('2026-10-15~2026-10-10'), (
        from: '2026-10-10',
        to: '2026-10-15',
      ));
      expect(parseSpan('2026-10-15'), (from: '2026-10-15', to: '2026-10-15'));
      expect(parseSpan('nonsense'), isNull);
    });

    test('labels in both languages, as the website writes them', () {
      expect(dayLabel('2026-10-15'), 'বৃহস্পতিবার, ১৫ অক্টোবর ২০২৬');
      expect(
        spanLabel('2026-10-10', '2026-10-15'),
        '১০ অক্টোবর থেকে ১৫ অক্টোবর ২০২৬',
      );
      expect(
        spanLabel('2025-12-30', '2026-01-02'),
        '৩০ ডিসেম্বর ২০২৫ থেকে ২ জানুয়ারি ২০২৬',
      );
      expect(monthLabel('2026-09'), 'সেপ্টেম্বর ২০২৬');
      expect(thousands(15934), '১৫,৯৩৪');
      expect(thousands(102450), '১০২,৪৫০');
      appLang.value = Lang.en;
      expect(dayLabel('2026-10-15'), 'Thursday, 15 October 2026');
      expect(
        spanLabel('2026-10-10', '2026-10-15'),
        '10 October to 15 October 2026',
      );
      expect(monthLabel('2026-09'), 'September 2026');
      expect(thousands(15934), '15,934');
    });
  });

  group('headline search', () {
    test('whole words, any order, joiners and hasanta ignored', () {
      final key = foldHeadline('বাক্‌স্বাধীনতা নিয়ে প্রধানমন্ত্রী: “সংবিধান”');
      expect(matchesQuery(key, 'প্রধানমন্ত্রী বাকস্বাধীনতা'), isTrue);
      expect(matchesQuery(key, 'সংবিধান'), isTrue);
      expect(matchesQuery(key, 'স্পিকার'), isFalse);
      expect(matchesQuery(key, '  '), isTrue);
    });

    test('a story is found by a member it names', () {
      const s = Story(
        id: 'a',
        date: '2026-10-16',
        dateLabel: '',
        lead: StoryLink(title: 'শিরোনাম', source: 'সমকাল', url: ''),
        members: [StoryMember(slug: 'x', name: 'Tarique Rahman')],
      );
      expect(matchesQuery(storySearchKey(s), 'tarique'), isTrue);
    });
  });

  group('the story card', () {
    test('an outlet with no name in English shows its address instead', () {
      expect(outletLabel('', 'https://www.jugantor.com/x'), 'jugantor.com');
      expect(outletLabel('Jugantor', 'https://www.jugantor.com/x'), 'Jugantor');
    });

    testWidgets('other outlets, members and the press mark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(
            body: StoryCard(
              story: Story(
                id: 'a',
                date: '2026-10-16',
                publishedAt: '2026-10-16T17:47:54+00:00',
                dateLabel: '',
                kind: 'press',
                lead: StoryLink(
                  title: 'শিরোনাম',
                  source: 'বার্তা বাজার',
                  url: '',
                ),
                also: [
                  StoryLink(title: 'শিরোনাম', source: 'যুগান্তর', url: 'u1'),
                  StoryLink(
                    title: 'শিরোনাম',
                    source: '',
                    url: 'https://www.x.com/1',
                  ),
                ],
                members: [
                  StoryMember(slug: 'a', name: 'ক', party: 'BNP'),
                  StoryMember(slug: 'b', name: 'খ', party: 'BNP'),
                  StoryMember(slug: 'c', name: 'গ'),
                  StoryMember(slug: 'd', name: 'ঘ'),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('প্রজ্ঞাপন'), findsOneWidget);
      expect(find.text('একই খবর আরও ২টি সংবাদমাধ্যমে'), findsOneWidget);
      expect(find.text('যুগান্তর'), findsOneWidget);
      expect(find.text('x.com'), findsOneWidget);
      expect(find.text('গ'), findsOneWidget);
      expect(find.text('ঘ'), findsNothing);
      expect(find.text('আরও ১ জন'), findsOneWidget);
      expect(find.textContaining('১৬ অক্টোবর ২০২৬'), findsOneWidget);
    });
  });

  group('screens', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await _loadFonts();
    });

    for (final lang in Lang.values) {
      final tr = T.of(lang);
      for (final (label, size, scale) in [
        ('small phone, large font', const Size(320, 640), 1.3),
        ('common phone, normal font', const Size(393, 851), 1.0),
      ]) {
        group('${lang.name}, $label', () {
          Future<List<String>> run(
            WidgetTester tester,
            Widget screen,
            Future<void> Function(WidgetTester) actions,
          ) async {
            appLang.value = lang;
            SharedPreferences.setMockInitialValues({});
            tester.view.physicalSize = size * 3;
            tester.view.devicePixelRatio = 3;
            addTearDown(tester.view.reset);
            final problems = <String>[];
            final previous = FlutterError.onError;
            FlutterError.onError = (details) {
              final text = details.exceptionAsString();
              // Pictures are network images; a test has no network.
              if (text.contains('MissingPluginException') ||
                  text.contains('HTTP request failed') ||
                  text.contains('NetworkImageLoadException') ||
                  text.contains('SocketException')) {
                return;
              }
              problems.add(text.split('\n').take(3).join(' '));
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
              await _settle(tester);
              await actions(tester);
            }, () => _client);
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 1));
            FlutterError.onError = previous;
            final taken = tester.takeException();
            if (taken != null) problems.add('$taken');
            return problems;
          }

          testWidgets('the news tab', (tester) async {
            final problems = await run(tester, const NewsScreen(), (
              tester,
            ) async {
              // Today's figures and the months.
              expect(find.text(tr('আজ খবর', 'News today')), findsOneWidget);
              expect(
                find.textContaining(tr('মোট ১৫,৯৩৪', '15,934 in total')),
                findsOneWidget,
              );
              expect(
                find.text(tr('তালিকায় ১২৫টি', '125 on the list')),
                findsOneWidget,
              );
              await _scrollTo(
                tester,
                find.text(tr('সেপ্টেম্বর ২০২৬', 'September 2026')),
              );
              // A month shows its stories, read a page at a time.
              _asked.clear();
              await tester.tap(
                find.text(tr('সেপ্টেম্বর ২০২৬', 'September 2026')),
              );
              await _settle(tester);
              expect(
                _asked.any(
                  (u) =>
                      u.queryParameters['from'] == '2026-09-01' &&
                      u.queryParameters['to'] == '2026-09-30',
                ),
                isTrue,
              );
              expect(
                find.text(
                  tr(
                    'দেখানো হচ্ছে · আবার চাপলে সব খবর',
                    'Showing · tap again for all news',
                  ),
                ),
                findsOneWidget,
              );
              expect(
                find.textContaining(
                  tr(
                    '২৯২৭টি (২৪৫২ সংবাদ, ৪৭৫ ভিডিও), ৬০টি দেখানো হচ্ছে',
                    '2,927 items (2,452 news, 475 videos), 60 shown',
                  ),
                ),
                findsOneWidget,
              );
              // To the end, with "আরও দেখুন" until the span is used up.
              await _scrollAll(tester, more: tr('আরও দেখুন', 'See more'));
              expect(
                find.text(
                  tr('সংবাদ কীভাবে যুক্ত হয়', 'How the news is added'),
                ),
                findsOneWidget,
              );
              expect(
                find.textContaining(
                  tr('দেশি-বিদেশি ১২৫টি', 'a list of 125 news outlets'),
                ),
                findsOneWidget,
              );
              expect(
                _asked.where((u) => u.queryParameters.containsKey('before')),
                isNotEmpty,
              );
            });
            expect(problems, isEmpty);
          });

          testWidgets('the news tab: search, kind and the span picker', (
            tester,
          ) async {
            final problems = await run(tester, const NewsScreen(), (
              tester,
            ) async {
              final videos = find.textContaining(tr('ভিডিও (', 'Videos ('));
              await _scrollTo(tester, videos);
              await tester.tap(videos);
              await _settle(tester);
              expect(
                find.textContaining(tr('টি ভিডিও', ' videos')),
                findsWidgets,
              );
              // A search for nothing says so, and offers everything again.
              await tester.enterText(find.byType(TextField), 'zzzqqq');
              await _settle(tester);
              expect(
                find.text(
                  tr(
                    'এই খোঁজে কোনো খবর পাওয়া যায়নি।',
                    'No news found for this search.',
                  ),
                ),
                findsOneWidget,
              );
              final all = find.text(tr('সব খবর দেখুন', 'See all news'));
              await _scrollTo(tester, all);
              await tester.tap(all);
              await _settle(tester);
              // The span picker: a quick choice.
              final open = find.text(tr('তারিখ দিয়ে খুঁজুন', 'Find by date'));
              await _scrollTo(tester, open);
              await tester.tap(open);
              await _settle(tester);
              expect(
                find.text(
                  tr('অথবা নির্দিষ্ট সময়', 'Or a period of your choice'),
                ),
                findsOneWidget,
              );
              _asked.clear();
              await tester.tap(find.text(tr('গত ৭ দিন', 'Last 7 days')));
              await _settle(tester);
              expect(
                _asked.where((u) => u.queryParameters['from'] != null),
                isNotEmpty,
              );
              expect(find.text(tr('বদলান', 'Change')), findsOneWidget);
              await _scrollAll(tester);
            });
            expect(problems, isEmpty);
          });

          testWidgets('a member\'s news', (tester) async {
            final problems = await run(
              tester,
              const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: MemberFeed(slug: 'tarique-rahman'),
                ),
              ),
              (tester) async {
                expect(
                  find.textContaining(tr('মোট ', ' in total, ')),
                  findsWidgets,
                );
                expect(
                  find.textContaining(tr('টি বাকি)', ' left)')),
                  findsOneWidget,
                );
                // An earlier month opens on a tap and is fetched then.
                final sep = find.text(tr('সেপ্টেম্বর ২০২৬', 'September 2026'));
                await _scrollTo(tester, sep);
                _asked.clear();
                await tester.tap(sep);
                await _settle(tester);
                expect(
                  _asked.any((u) => u.queryParameters['m'] == '2026-09'),
                  isTrue,
                );
                // A span from the picker.
                final open = find.text(
                  tr('তারিখ দিয়ে খুঁজুন', 'Find by date'),
                );
                await _scrollTo(tester, open, up: true);
                await tester.tap(open);
                await _settle(tester);
                await tester.tap(find.text(tr('গত ৭ দিন', 'Last 7 days')));
                await _settle(tester);
                expect(
                  _asked.any((u) => u.queryParameters['from'] != null),
                  isTrue,
                );
                // Only videos: asked of the site, not filtered here.
                _asked.clear();
                await _scrollTo(
                  tester,
                  find.text(tr('ভিডিও', 'Videos')),
                  up: true,
                );
                await tester.tap(find.text(tr('ভিডিও', 'Videos')).first);
                await _settle(tester);
                expect(
                  _asked.any((u) => u.queryParameters['type'] == 'video'),
                  isTrue,
                );
                await _scrollAll(tester);
              },
            );
            expect(problems, isEmpty);
          });
        });
      }
    }
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _scrollTo(
  WidgetTester tester,
  Finder finder, {
  bool up = false,
}) async {
  for (var i = 0; i < 40 && finder.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(
      find.byType(Scrollable).first,
      Offset(0, up ? 300 : -300),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder.hitTestable(), findsWidgets);
}

/// Scrolls to the end, pressing [more] on the way while it is there.
Future<void> _scrollAll(WidgetTester tester, {String? more}) async {
  for (var i = 0; i < 120; i++) {
    final button = more == null ? null : find.text(more).hitTestable();
    if (button != null && button.evaluate().isNotEmpty) {
      await tester.tap(button.first);
      await _settle(tester);
      continue;
    }
    final before = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -500),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 100));
    final after = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    if (after == before && more == null) break;
    if (after == before && find.text(more!).evaluate().isEmpty) break;
  }
}
