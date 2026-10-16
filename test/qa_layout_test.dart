// Layout QA: every screen, rendered with real API data in the real Bengali
// font, on a small phone with a large system font, scrolled end to end.
// Any overflow or exception fails the test. Needs saved API responses:
//   MYMP_FIXTURES=<dir> flutter test test/qa_layout_test.dart
// In English (MYMP_LANG=en), a request with lang=en reads <name>.en.json
// when there is one, and the Bangla response otherwise.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymp/api.dart';
import 'package:mymp/i18n.dart';
import 'package:mymp/models.dart';
import 'package:mymp/screens/adviser_screen.dart';
import 'package:mymp/screens/cabinet_screen.dart';
import 'package:mymp/screens/election_screen.dart';
import 'package:mymp/screens/member_screen.dart';
import 'package:mymp/screens/members_screen.dart';
import 'package:mymp/screens/more_screen.dart';
import 'package:mymp/screens/news_screen.dart';
import 'package:mymp/screens/party_screen.dart';
import 'package:mymp/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _dir = Platform.environment['MYMP_FIXTURES'];

final _lang = Platform.environment['MYMP_LANG'] == 'en' ? Lang.en : Lang.bn;

/// The screens' own words in the language under test. (Not `t`: the tests
/// name their WidgetTester that.)
final _tr = T.of(_lang);

String _fixture(Uri url) {
  final path = url.path;
  String name;
  if (path.endsWith('/bootstrap')) {
    name = 'bootstrap';
  } else if (path.endsWith('/election')) {
    name = 'election';
  } else if (path.endsWith('/cabinet')) {
    name = 'cabinet';
  } else if (path.endsWith('/news')) {
    final type = url.queryParameters['type'];
    name = type == null ? 'news' : 'news-$type';
  } else if (path.contains('/mp/')) {
    name = 'mp-${path.split('/').last}';
  } else if (path.contains('/adviser/')) {
    name = 'adviser-${path.split('/').last}';
  } else if (path.contains('/api/feed/')) {
    name = 'feed-${path.split('/').last}';
  } else {
    return '';
  }
  final en = File('$_dir/$name.en.json');
  if (url.queryParameters['lang'] == 'en' && en.existsSync()) {
    return en.readAsStringSync();
  }
  final f = File('$_dir/$name.json');
  return f.existsSync() ? f.readAsStringSync() : '';
}

Future<void> _loadFonts() async {
  final loader = FontLoader('NotoSansBengali');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/NotoSansBengali-$w.ttf'));
  }
  await loader.load();
}

void main() {
  if (_dir == null) {
    test('layout QA needs MYMP_FIXTURES', () {}, skip: true);
    return;
  }

  final client = MockClient((req) async {
    final body = _fixture(req.url);
    if (body.isEmpty) return http.Response('{}', 404);
    return http.Response.bytes(
      utf8.encode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  late Bootstrap boot;

  setUpAll(() async {
    appLang.value = _lang;
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
    boot = Bootstrap.fromJson(
      jsonDecode(File('$_dir/bootstrap.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  testWidgets('a pull with no signal keeps the list and says so', (t) async {
    SharedPreferences.setMockInitialValues({
      'flutter.not_official_notice_v1': true,
    });
    var offline = false;
    final flaky = MockClient((req) async {
      if (offline) throw http.ClientException('no network');
      return client
          .send(http.Request(req.method, req.url))
          .then(http.Response.fromStream);
    });
    await http.runWithClient(() async {
      await t.pumpWidget(
        MaterialApp(theme: buildTheme(), home: const MembersScreen()),
      );
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(find.text(_tr('শীর্ষ নেতৃত্ব', 'Leadership')), findsOneWidget);
      offline = true;
      await t.fling(find.byType(CustomScrollView), const Offset(0, 500), 1500);
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(find.text(_tr('শীর্ষ নেতৃত্ব', 'Leadership')), findsOneWidget);
      expect(
        find.textContaining(_tr('হালনাগাদ করা গেল না', 'Could not update')),
        findsOneWidget,
      );
      expect(
        find.text(_tr('তথ্য আনা গেল না', 'Could not fetch the information')),
        findsNothing,
      );
    }, () => flaky);
  });

  for (final (label, size, scale) in [
    ('small phone, large font', const Size(320, 640), 1.3),
    ('common phone, normal font', const Size(393, 851), 1.0),
  ]) {
    group(label, () {
      Future<List<String>> run(
        WidgetTester tester,
        Widget screen, {
        int flings = 12,
        Future<void> Function(WidgetTester)? actions,
        required String shows,
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
          // Photos are network images; a test has no network and no cache dir.
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
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          if (actions != null) await actions(tester);
          // The screen must show its data, not a spinner or an error page;
          // the text may be further down, so it is looked for while scrolling.
          var seen = find.textContaining(shows).evaluate().isNotEmpty;
          final failed = _tr(
            'তথ্য আনা গেল না',
            'Could not fetch the information',
          );
          if (find.text(failed).evaluate().isNotEmpty) {
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
        }, () => client);
        // Let pending image and network work finish, then hand errors back
        // to the binding before any expect() runs.
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

      testWidgets('members list', (t) async {
        expect(
          await run(
            t,
            const MembersScreen(),
            flings: 8,
            shows: _tr('শীর্ষ নেতৃত্ব', 'Leadership'),
          ),
          isEmpty,
        );
      });

      testWidgets('member with the longest office', (t) async {
        final m = boot.members.firstWhere(
          (x) => x.slug == 'ariful-haque-choudhury',
        );
        expect(
          await run(
            t,
            MemberScreen(member: m),
            flings: 14,
            shows: _tr('তথ্য', 'Details'),
          ),
          isEmpty,
        );
      });

      testWidgets('member with the longest name', (t) async {
        final m = boot.members.firstWhere(
          (x) => x.slug == 'kazi-shah-mofazzal-houssain-kaikobad',
        );
        expect(
          await run(
            t,
            MemberScreen(member: m),
            flings: 14,
            shows: _tr('তথ্য', 'Details'),
          ),
          isEmpty,
        );
      });

      testWidgets('prime minister, news tab', (t) async {
        final m = boot.members.firstWhere((x) => x.slug == 'tarique-rahman');
        expect(
          await run(
            t,
            MemberScreen(member: m),
            flings: 6,
            shows: _tr('সংবাদ ও ভিডিও', 'News and videos'),
            actions: (t) async {
              await t.tap(find.text(_tr('সংবাদ ও ভিডিও', 'News and videos')));
              for (var i = 0; i < 10; i++) {
                await t.pump(const Duration(milliseconds: 200));
              }
            },
          ),
          isEmpty,
        );
      });

      testWidgets('election figures', (t) async {
        expect(
          await run(
            t,
            const ElectionScreen(),
            flings: 20,
            shows: _tr('সংসদের গঠন', 'Make-up of Parliament'),
          ),
          isEmpty,
        );
      });

      testWidgets('news', (t) async {
        expect(
          await run(
            t,
            const NewsScreen(),
            flings: 10,
            shows: _tr('ভিডিওতে সংসদ সদস্যরা', 'MPs on video'),
          ),
          isEmpty,
        );
      });

      testWidgets('cabinet', (t) async {
        expect(
          await run(
            t,
            const CabinetScreen(),
            flings: 30,
            shows: _tr('মোট', 'in office'),
          ),
          isEmpty,
        );
      });

      testWidgets('adviser', (t) async {
        expect(
          await run(
            t,
            const AdviserScreen(
              slug: 'khalilur-rahman',
              nameBn: 'ড. খলিলুর রহমান',
            ),
            flings: 8,
            shows: _tr('খলিলুর', 'Not an MP'),
          ),
          isEmpty,
        );
      });

      testWidgets('more', (t) async {
        expect(
          await run(
            t,
            const MoreScreen(),
            flings: 8,
            shows: _tr('জামায়াতে ইসলামী', 'About My MP'),
          ),
          isEmpty,
        );
      });

      testWidgets('party', (t) async {
        await t.runAsync(
          () => http.runWithClient(Api.instance.loadBootstrap, () => client),
        );
        expect(
          await run(
            t,
            PartyScreen(party: boot.parties[4]),
            flings: 3,
            shows: _tr('জন সংসদ সদস্য', 'Members of Parliament'),
          ),
          isEmpty,
        );
      });
    });
  }
}
