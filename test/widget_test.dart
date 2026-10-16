import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymp/api.dart';
import 'package:mymp/bn.dart';
import 'package:mymp/i18n.dart';
import 'package:mymp/models.dart';
import 'package:mymp/screens/story_list.dart';
import 'package:mymp/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Every test starts in Bangla, the app's default, whatever the last one did.
  setUp(() => appLang.value = Lang.bn);
  tearDown(() => appLang.value = Lang.bn);

  group('Bengali text', () {
    test('numbers are written in Bengali digits', () {
      expect(bn(348), '৩৪৮');
      expect(bn(13), '১৩');
      expect(bn('2026-09-13'), '২০২৬-০৯-১৩');
    });

    test('a date reads the way a Bengali reader writes it', () {
      expect(dateBn('2026-09-13'), '১৩ সেপ্টেম্বর ২০২৬');
      expect(dateBn(null), isNull);
      expect(dateBn('not a date'), isNull);
    });

    test('a video length is minutes and seconds, zero-padded', () {
      expect(durationBn(125), '২:০৫');
      expect(durationBn(0), isNull);
      expect(durationBn(null), isNull);
    });

    test('the avatar letter skips an honorific and keeps the vowel sign', () {
      // "মোঃ আবুল হাসনাত" is filed under আ, not মো: the honorific is not part
      // of the name as a reader thinks of it.
      expect(initialOf('মোঃ আবুল হাসনাত'), 'আ');
      expect(initialOf('তারেক রহমান'), 'তা');
      expect(initialOf(''), '?');
    });

    // The helpers became language-aware; in Bangla they must write exactly
    // what they wrote before, character for character.
    test('the old helpers write the same Bangla as before', () {
      expect(bnGroup(127711899), '১২,৭৭,১১,৮৯৯');
      expect(bnGroup(999), '৯৯৯');
      expect(bnGroup(1000), '১,০০০');
      expect(bnGroup(-123456), '-১,২৩,৪৫৬');
      expect(pctBn(504, 1000), '৫০.৪%');
      expect(pctBn(1, 0), '০%');
      expect(parliamentBn(13), 'ত্রয়োদশ');
      expect(parliamentBn(16), '১৬তম');
      expect(monthsBn.first, 'জানুয়ারি');
      expect(weekdaysBn.first, 'সোমবার');
      expect(shortDateBn(null, label: 'শুক্রবার, ১৭ অক্টোবর'), '১৭ অক্টোবর');
      expect(shortDateBn(DateTime.now().toIso8601String()), 'আজ');
      expect(whenBn(DateTime.now().toIso8601String()), 'এইমাত্র');
      expect(
        const MemberBrief(id: '1', slug: 'x', nameBn: 'ক').seatLabel,
        'সংরক্ষিত আসন',
      );
    });

    test('the toolkit in Bangla agrees with the old helpers', () {
      expect(t('সব দল', 'All parties'), 'সব দল');
      expect(t.n(348), '৩৪৮');
      expect(t.group(127711899), '১২,৭৭,১১,৮৯৯');
      expect(t.fixed(12.345), '১২.৩');
      expect(t.date('2026-02-17'), '১৭ ফেব্রুয়ারি ২০২৬');
      expect(t.monthYear('2026-02-17'), 'ফেব্রুয়ারি ২০২৬');
      expect(t.count(5, 'টি আসন', 'seat', 'seats'), '৫টি আসন');
      expect(t.ord(13), '১৩');
      expect(t.weekday(0), 'রবিবার');
      expect(t.href('/mp/x'), '/mp/x');
      expect(Api.page('/mp/x'), '${Api.base}/mp/x');
      expect(Api.page('/'), Api.base);
    });
  });

  group('English text', () {
    setUp(() => appLang.value = Lang.en);

    test('digits are Latin and thousands take commas', () {
      expect(t('সব দল', 'All parties'), 'All parties');
      expect(t.n(348), '348');
      expect(t.n('১২৩'), '123');
      expect(t.group(127711899), '127,711,899');
      expect(t.group(999), '999');
      expect(t.group(-1234567), '-1,234,567');
      expect(t.fixed(12.345), '12.3');
      expect(t.fixed(2, 2), '2.00');
      expect(t.pct(504, 1000), '50.4%');
      expect(t.pct(1, 0), '0%');
      // The old helpers follow the language too.
      expect(bn(348), '348');
      expect(bnGroup(127711899), '127,711,899');
      expect(durationBn(125), '2:05');
    });

    test('dates are "17 February 2026"', () {
      expect(t.date('2026-02-17'), '17 February 2026');
      expect(dateBn('2026-09-13'), '13 September 2026');
      expect(t.monthYear('2026-02-17'), 'February 2026');
      expect(t.month(2), 'February');
      expect(t.month(13), '');
      // 0 and 7 are both Sunday: the website's count and Dart's DateTime.weekday.
      expect(t.weekday(0), 'Sunday');
      expect(t.weekday(7), 'Sunday');
      expect(t.weekday(1), 'Monday');
      expect(t.date(null), isNull);
      // A timestamp is read on the Bangladesh calendar: 20:00 UTC on the
      // 16th is 2 am on the 17th in Dhaka.
      expect(t.date('2026-10-16T20:00:00Z'), '17 October 2026');
    });

    test('counts take a plural and ordinals a suffix', () {
      expect(t.count(5, 'টি আসন', 'seat', 'seats'), '5 seats');
      expect(t.count(1, 'টি আসন', 'seat', 'seats'), '1 seat');
      expect(t.count(0, 'টি আসন', 'seat', 'seats'), '0 seats');
      for (final (n, want) in const [
        (1, '1st'),
        (2, '2nd'),
        (3, '3rd'),
        (4, '4th'),
        (11, '11th'),
        (12, '12th'),
        (13, '13th'),
        (21, '21st'),
        (22, '22nd'),
        (101, '101st'),
        (111, '111th'),
      ]) {
        expect(t.ord(n), want);
      }
      expect(parliamentBn(13), '13th');
      expect(t.pick(1, 2), 2);
    });

    test('links to the website go to its English pages', () {
      expect(t.href('/mp/x'), '/en/mp/x');
      expect(t.href('/'), '/en');
      expect(t.href('/en/mp/x'), '/en/mp/x');
      expect(t.href('https://example.com'), 'https://example.com');
      expect(Api.page('/mp/x'), '${Api.base}/en/mp/x');
      expect(Api.page('/'), '${Api.base}/en');
    });

    test('the avatar letter skips Md., Dr and the like', () {
      expect(initialOf('Md. Abul Hasnat'), 'A');
      expect(initialOf('MD Abul Hasnat'), 'A');
      expect(initialOf('Dr. Zahid Hossain'), 'Z');
      expect(initialOf('Advocate Ruhul Kabir'), 'R');
      expect(initialOf('Barrister Kayser Kamal'), 'K');
      expect(initialOf('tarique rahman'), 'T');
      // A Bangla name keeps its Bangla letter whatever the language.
      expect(initialOf('মোঃ আবুল হাসনাত'), 'আ');
    });

    test('fallbacks the app writes itself are English', () {
      expect(
        const MemberBrief(id: '1', slug: 'x', nameBn: 'A').seatLabel,
        'Reserved seat',
      );
      expect(
        AdviserDetail.fromJson(const {'slug': 'x'}).roleBn,
        'Adviser to the Prime Minister',
      );
    });
  });

  group('when a story was published', () {
    // 19:15 UTC on 16 October is 1:15 am on the 17th in Dhaka.
    final now = DateTime.utc(2026, 10, 16, 19, 15);
    String at(int hour, int minute, {int day = 17}) {
      // A Dhaka wall-clock time, as the UTC instant the site sends.
      final utc = DateTime.utc(
        2026,
        10,
        day,
        hour,
        minute,
      ).subtract(const Duration(hours: 6));
      return utc.toIso8601String();
    }

    test('date, time and how long ago, in Bangla', () {
      expect(
        t.when('2026-10-16T18:59:00Z', now: now),
        '১৭ অক্টোবর ২০২৬, রাত ১২:৫৯ · ১৬ মিনিট আগে',
      );
      // The same moment written with Dhaka's offset, or with none.
      expect(
        t.when('2026-10-17T00:59:00+06:00', now: now),
        '১৭ অক্টোবর ২০২৬, রাত ১২:৫৯ · ১৬ মিনিট আগে',
      );
      expect(
        t.when('2026-10-17T00:59:00', now: now),
        '১৭ অক্টোবর ২০২৬, রাত ১২:৫৯ · ১৬ মিনিট আগে',
      );
    });

    test('the parts of the day, as the newspapers name them', () {
      final later = DateTime.utc(2026, 10, 30);
      for (final (h, m, want) in const [
        (0, 0, 'রাত ১২:০০'),
        (3, 59, 'রাত ৩:৫৯'),
        (4, 0, 'ভোর ৪:০০'),
        (5, 59, 'ভোর ৫:৫৯'),
        (6, 0, 'সকাল ৬:০০'),
        (11, 59, 'সকাল ১১:৫৯'),
        (12, 0, 'দুপুর ১২:০০'),
        (14, 59, 'দুপুর ২:৫৯'),
        (15, 0, 'বিকেল ৩:০০'),
        (16, 59, 'বিকেল ৪:৫৯'),
        (17, 0, 'সন্ধ্যা ৫:০০'),
        (18, 59, 'সন্ধ্যা ৬:৫৯'),
        (19, 0, 'রাত ৭:০০'),
        (23, 59, 'রাত ১১:৫৯'),
      ]) {
        expect(t.time(at(h, m)), want, reason: '$h:$m');
        // More than a week old: the date and time, no "আগে".
        expect(t.when(at(h, m), now: later), '১৭ অক্টোবর ২০২৬, $want');
      }
    });

    test('ago within a week, then only the date', () {
      expect(t.ago('2026-10-16T19:15:00Z', now: now), 'এইমাত্র');
      expect(t.ago('2026-10-16T18:15:00Z', now: now), '১ ঘণ্টা আগে');
      expect(t.ago('2026-10-16T07:15:00Z', now: now), '১২ ঘণ্টা আগে');
      expect(t.ago('2026-10-15T18:00:00Z', now: now), 'গতকাল');
      expect(t.ago('2026-10-13T19:15:00Z', now: now), '৩ দিন আগে');
      expect(t.ago('2026-10-09T19:15:00Z', now: now), isNull);
    });

    test('a date still ahead is a date, not "just now"', () {
      // Two days ahead: date and time, nothing more.
      expect(
        t.when('2026-10-18T19:15:00Z', now: now),
        '১৯ অক্টোবর ২০২৬, রাত ১:১৫',
      );
      expect(t.ago('2026-10-18T19:15:00Z', now: now), isNull);
      // A clock a few minutes fast is still "just now".
      expect(t.ago('2026-10-16T19:20:00Z', now: now), 'এইমাত্র');
    });

    test('a date with no clock time is only the date', () {
      expect(t.when('2026-10-17', now: now), '১৭ অক্টোবর ২০২৬');
      expect(t.time('2026-10-17'), isNull);
      expect(t.ago('2026-10-17', now: now), isNull);
      expect(t.when('', now: now), '');
      expect(t.when('nonsense', now: now), '');
    });

    test('the same in English', () {
      appLang.value = Lang.en;
      expect(
        t.when('2026-10-16T18:59:00Z', now: now),
        '17 October 2026, 12:59 am · 16 minutes ago',
      );
      expect(t.time(at(12, 0)), '12:00 pm');
      expect(t.time(at(0, 5)), '12:05 am');
      expect(t.time(at(23, 59)), '11:59 pm');
      expect(t.ago('2026-10-16T19:14:00Z', now: now), '1 minute ago');
      expect(t.ago('2026-10-16T18:15:00Z', now: now), '1 hour ago');
      expect(t.ago('2026-10-16T16:15:00Z', now: now), '3 hours ago');
      expect(t.ago('2026-10-15T18:00:00Z', now: now), 'yesterday');
      expect(t.ago('2026-10-13T19:15:00Z', now: now), '3 days ago');
      expect(t.ago('2026-10-16T19:15:00Z', now: now), 'just now');
      expect(
        t.when('2026-10-18T19:15:00Z', now: now),
        '19 October 2026, 1:15 am',
      );
      expect(t.when('2026-10-17', now: now), '17 October 2026');
    });

    test('a card uses the publication time, then the day, then the label', () {
      Story story({String date = '', String? at, String label = ''}) => Story(
        id: 'x',
        date: date,
        publishedAt: at,
        dateLabel: label,
        lead: const StoryLink(title: 'শিরোনাম', source: 'সমকাল', url: ''),
      );
      expect(
        storyWhen(
          story(date: '2026-10-17', at: '2026-10-16T18:59:00Z'),
          now: now,
        ),
        ['১৭ অক্টোবর ২০২৬,', 'রাত ১২:৫৯', '· ১৬ মিনিট আগে'],
      );
      expect(storyWhen(story(date: '2026-10-17'), now: now), [
        '১৭ অক্টোবর ২০২৬',
      ]);
      expect(storyWhen(story(label: 'শুক্রবার, ১৭ অক্টোবর'), now: now), [
        '১৭ অক্টোবর',
      ]);
      expect(storyWhen(story(), now: now), isEmpty);
    });

    test('the site sends publishedAt and the story keeps it', () {
      final s = Story.fromJson(const {
        'id': 'a',
        'date': '2026-10-17',
        'publishedAt': '2026-10-16T18:59:00.000Z',
        'lead': {'title': 'শিরোনাম', 'source': 'সমকাল', 'url': ''},
      });
      expect(s.publishedAt, '2026-10-16T18:59:00.000Z');
      final f = Api.feedEntryToStory(const {
        'id': 7,
        'title': 'শিরোনাম',
        'publishedAt': '2026-10-16T18:59:00.000Z',
      });
      expect(f.publishedAt, '2026-10-16T18:59:00.000Z');
      expect(f.date, '2026-10-17');
    });
  });

  group('parsing what the site sends', () {
    test('a member survives missing fields', () {
      final m = MemberBrief.fromJson(const {
        'id': '1',
        'slug': 'x',
        'nameBn': 'ক খ',
      });
      expect(m.nameBn, 'ক খ');
      expect(m.photoUrl, isNull);
      expect(m.seatLabel, 'সংরক্ষিত আসন');
    });

    test('a story takes either one member or several', () {
      final one = Story.fromJson(const {
        'id': 'a',
        'lead': {
          'title': 'শিরোনাম',
          'source': 'প্রথম আলো',
          'url': 'https://example.com',
        },
        'member': {'slug': 's', 'name': 'ক খ'},
      });
      expect(one.members.single.name, 'ক খ');

      final many = Story.fromJson(const {
        'id': 'b',
        'lead': {
          'title': 'শিরোনাম',
          'source': 'সমকাল',
          'url': 'https://example.com',
        },
        'members': [
          {'slug': 's1', 'name': 'ক'},
          {'slug': 's2', 'name': 'খ'},
        ],
        'kind': 'video',
      });
      expect(many.members.length, 2);
      expect(many.isVideo, isTrue);
    });

    test('an unexpected shape does not throw', () {
      expect(() => Story.fromJson(const {'id': 'c'}), returnsNormally);
      expect(() => Bootstrap.fromJson(const {}), returnsNormally);
    });
  });

  testWidgets('a member tile shows the name, the seat and the office', (
    tester,
  ) async {
    const member = MemberBrief(
      id: '013025201',
      slug: 'hasnat-abdullah',
      nameBn: 'মোঃ আবুল হাসনাত',
      party: 'NCP',
      seatNo: 252,
      seatBn: 'কুমিল্লা-৪',
      officeBn: 'প্রধানমন্ত্রী',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemberTile(member: member, onTap: () {}),
        ),
      ),
    );

    expect(find.text('মোঃ আবুল হাসনাত'), findsOneWidget);
    expect(find.text('কুমিল্লা-৪'), findsOneWidget);
    expect(find.text('প্রধানমন্ত্রী'), findsOneWidget);
  });

  testWidgets('the language switch redraws in place and is remembered', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      LangRoot(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const LangSwitch(),
                // A widget that reads the global `t` without depending on
                // anything: it must redraw all the same.
                Builder(builder: (_) => Text(t('সব দল', 'All parties'))),
                const ErrorView(message: '', onRetry: _noop),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('সব দল'), findsOneWidget);
    expect(find.text('আবার চেষ্টা করুন'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(appLang.value, Lang.en);
    expect(find.text('All parties'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('lang'), 'en');

    // Read back on the next launch.
    appLang.value = Lang.bn;
    await appLang.load();
    expect(appLang.value, Lang.en);

    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();
    expect(find.text('সব দল'), findsOneWidget);
    expect(prefs.getString('lang'), 'bn');
  });
}

void _noop() {}
