// English headlines: on `lang=en` the site sends a headline's machine
// translation in `title`, the outlet's own in `titleOriginal`, and
// `titleTranslated: true`; an older site sends neither. The app parses both,
// shows "Headlines translated automatically…" once under a list that has a
// translation (English only), and draws a headline still in Bangla in the
// Bangla font. Uses the saved answers in test/fixtures/news, the English ones
// with one headline turned into a translation as the new site sends it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymp/api.dart';
import 'package:mymp/data/news.dart';
import 'package:mymp/i18n.dart';
import 'package:mymp/models.dart';
import 'package:mymp/screens/member_feed.dart';
import 'package:mymp/screens/news_screen.dart';
import 'package:mymp/screens/story_list.dart';
import 'package:mymp/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dir = 'test/fixtures/news';

Map<String, dynamic> _json(String name) =>
    jsonDecode(File('$_dir/$name.json').readAsStringSync())
        as Map<String, dynamic>;

const _english = 'Chief Whip says no work in the union if the party loses';

/// The English news list as the new site sends it: the first headline
/// translated, the rest still in Bangla.
Map<String, dynamic> _translatedNews() {
  final j = _json('news.en');
  final first = (j['stories'] as List).first as Map<String, dynamic>;
  final lead = first['lead'] as Map<String, dynamic>;
  lead['titleOriginal'] = lead['title'];
  lead['title'] = _english;
  lead['titleEn'] = _english;
  lead['titleTranslated'] = true;
  return j;
}

Map<String, dynamic> _translatedFeed() {
  final j = _json('feed.en');
  final first = (j['items'] as List).first as Map<String, dynamic>;
  first['titleOriginal'] = first['title'];
  first['title'] = _english;
  first['titleTranslated'] = true;
  return j;
}

MockClient _client({required bool translated}) => MockClient((req) async {
  final path = req.url.path;
  final en = req.url.queryParameters['lang'] == 'en';
  Object? body;
  if (path.endsWith('/news/counts')) {
    body = _json(en ? 'counts.en' : 'counts');
  } else if (path.endsWith('/app/v1/news')) {
    body = en
        ? (translated ? _translatedNews() : _json('news.en'))
        : _json('news');
  } else if (path.startsWith('/api/feed/')) {
    body = en
        ? (translated ? _translatedFeed() : _json('feed.en'))
        : _json('feed');
  }
  if (body == null) return http.Response('{"error":"not found"}', 404);
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
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

final _bangla = RegExp('[ঀ-৿]');

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });
  tearDown(() => appLang.value = Lang.bn);

  group('parsing', () {
    test('a story from the new site', () {
      final s = Story.fromJson(
        (_translatedNews()['stories'] as List).first as Map<String, dynamic>,
      );
      expect(s.lead.title, _english);
      expect(s.lead.titleOriginal, contains('চিফ হুইপ'));
      expect(s.translated, isTrue);
      // A Bangla search still finds it by the outlet's words.
      expect(matchesQuery(storySearchKey(s), 'চিফ হুইপ'), isTrue);
      expect(matchesQuery(storySearchKey(s), 'chief whip'), isTrue);
    });

    test('a story from an older site, and odd values', () {
      final old = Story.fromJson(
        (_json('news.en')['stories'] as List).first as Map<String, dynamic>,
      );
      expect(old.translated, isFalse);
      expect(old.lead.titleOriginal, isNull);
      expect(_bangla.hasMatch(old.lead.title), isTrue);
      final odd = StoryLink.fromJson(const {
        'title': 'x',
        'titleOriginal': 5,
        'titleTranslated': 'yes',
      });
      expect(odd.titleTranslated, isFalse);
      expect(odd.titleOriginal, isNull);
    });

    test('a member feed item, new and old', () {
      final item = (_translatedFeed()['items'] as List).first;
      final e = FeedEntry.fromJson(item as Map<String, dynamic>);
      expect(e.title, _english);
      expect(e.titleTranslated, isTrue);
      expect(e.titleOriginal, isNotNull);
      final s = Api.feedEntryToStory(item);
      expect(s.translated, isTrue);
      expect(s.lead.titleOriginal, e.titleOriginal);
      final old = FeedEntry.fromJson(
        (_json('feed.en')['items'] as List).first as Map<String, dynamic>,
      );
      expect(old.titleTranslated, isFalse);
      expect(old.titleOriginal, isNull);
      expect(
        Api.feedEntryToStory(
          (_json('feed.en')['items'] as List).first as Map<String, dynamic>,
        ).translated,
        isFalse,
      );
    });
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    required Lang lang,
    required bool translated,
  }) async {
    SharedPreferences.setMockInitialValues({});
    appLang.value = lang;
    tester.view.physicalSize = const Size(360, 720) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
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
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }, () => _client(translated: translated));
  }

  final note = find.text(MachineNote.text);

  for (final (lang, translated, shows) in [
    (Lang.en, true, true),
    (Lang.en, false, false),
    (Lang.bn, true, false),
  ]) {
    final name =
        '${lang.name}, ${translated ? 'with' : 'without'} a translation';

    testWidgets('the news tab, $name', (t) async {
      await pump(t, const NewsScreen(), lang: lang, translated: translated);
      expect(note, shows ? findsOneWidget : findsNothing);
      if (lang == Lang.en) {
        // A headline not yet translated is drawn as it is, in Bangla.
        final bangla = find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data != null &&
              _bangla.hasMatch(w.data!) &&
              w.style?.fontFamily == 'NotoSansBengali',
        );
        expect(bangla, findsWidgets);
        if (translated) expect(find.text(_english), findsWidgets);
        // The note under "How the news is added", English only.
        expect(
          find.textContaining(
            'headlines are translated automatically from Bangla by Google Translate',
            findRichText: true,
          ),
          findsOneWidget,
        );
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a member\'s news, $name', (t) async {
      await pump(
        t,
        const Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: MemberFeed(slug: 'tarique-rahman'),
            ),
          ),
        ),
        lang: lang,
        translated: translated,
      );
      expect(note, shows ? findsOneWidget : findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a story list, $name', (t) async {
      final stories = [
        for (final s
            in ((lang == Lang.en
                        ? (translated ? _translatedNews() : _json('news.en'))
                        : _json('news'))['stories']
                    as List)
                .take(5))
          Story.fromJson(s as Map<String, dynamic>),
      ];
      await pump(
        t,
        Scaffold(
          body: StoryList(
            future: Future.value(stories),
            emptyTitle: '',
            emptyBody: '',
            onRetry: () {},
          ),
        ),
        lang: lang,
        translated: translated,
      );
      final list = find.byType(ListView);
      await t.scrollUntilVisible(
        find.byType(StoryCard).last,
        300,
        scrollable: find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        ),
      );
      await t.drag(list, const Offset(0, -2000));
      await t.pump(const Duration(milliseconds: 300));
      expect(note, shows ? findsOneWidget : findsNothing);
      expect(t.takeException(), isNull);
    });
  }
}
