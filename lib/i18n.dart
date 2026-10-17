/// The app's two languages. Bangla is the default and looks exactly as it
/// always has; a reader can switch to English on the "আরও" tab (and on the
/// first-run notice), and the whole app redraws in place, no restart.
///
/// Everything a screen shows in one language or the other goes through [t],
/// the same toolkit the website uses (src/i18n/core.ts in the mymp repo), so
/// text, digits, dates and links always agree with the chosen language:
///
///   t('সব দল', 'All parties')            the text in this language
///   t.n(12)                              "১২" | "12"
///   t.group(127711899)                   "১২,৭৭,১১,৮৯৯" | "127,711,899"
///   t.date('2026-02-17')                 "১৭ ফেব্রুয়ারি ২০২৬" | "17 February 2026"
///   t.count(5, 'টি আসন', 'seat', 'seats') "৫টি আসন" | "5 seats"
///   t.when(iso)                          "১৭ অক্টোবর ২০২৬, রাত ১২:৫৯ · ১৬ মিনিট আগে"
///
/// English style follows the website's src/i18n/README.md: British spelling,
/// sentence case, Latin digits, thousands commas, "17 February 2026". News
/// headlines are the outlets' own words and stay in Bangla.
///
/// The choice is kept on the phone (shared_preferences) and nowhere else.
library;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Lang { bn, en }

/// The reader's language, for the whole app. Listen to it to refetch data;
/// [LangRoot] redraws every screen when it changes.
class LangController extends ValueNotifier<Lang> {
  LangController() : super(Lang.bn);

  static const _key = 'lang';

  /// Reads the stored choice; called once before the first frame.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_key) == Lang.en.name) value = Lang.en;
    } catch (_) {
      // No storage (a test, a locked-down device): Bangla, as before.
    }
  }

  /// Switches and remembers the choice on the phone.
  Future<void> choose(Lang lang) async {
    if (lang == value) return;
    value = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, lang.name);
    } catch (_) {}
  }
}

final appLang = LangController();

/// The toolkit in the current language.
T get t => T.of(appLang.value);

const _bnDigits = '০১২৩৪৫৬৭৮৯';
String _toBn(String s) =>
    s.replaceAllMapped(RegExp(r'\d'), (m) => _bnDigits[int.parse(m[0]!)]);
String _toLatin(String s) =>
    s.replaceAllMapped(RegExp('[০-৯]'), (m) => '${_bnDigits.indexOf(m[0]!)}');

const monthsBnList = [
  'জানুয়ারি',
  'ফেব্রুয়ারি',
  'মার্চ',
  'এপ্রিল',
  'মে',
  'জুন',
  'জুলাই',
  'আগস্ট',
  'সেপ্টেম্বর',
  'অক্টোবর',
  'নভেম্বর',
  'ডিসেম্বর',
];
const monthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Sunday first, so both 0 (the website's convention) and 7 (Dart's
/// DateTime.weekday) name Sunday.
const _weekdaysBnSun = [
  'রবিবার',
  'সোমবার',
  'মঙ্গলবার',
  'বুধবার',
  'বৃহস্পতিবার',
  'শুক্রবার',
  'শনিবার',
];
const _weekdaysEnSun = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

/// English singular or plural by count.
String plural(num n, String one, String many) => n == 1 ? one : many;

String _ordinalEn(int n) {
  final s = n % 100;
  if (s >= 11 && s <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

/// Bangladesh is UTC+6 all year: no daylight saving to account for.
const _dhakaOffset = Duration(hours: 6);
final _plainDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _clock = RegExp(r'T\d\d:\d\d');
final _zone = RegExp(r'(Z|[+-]\d\d:?\d\d)$', caseSensitive: false);

/// True when the value carries a clock time; a bare "2026-09-10" does not.
bool hasClock(String iso) => _clock.hasMatch(iso);

/// The instant an ISO value names. One with no zone is read as Dhaka time,
/// which is what a phone in Bangladesh would make of it.
DateTime? _instant(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return null;
  if (_zone.hasMatch(iso)) return d.toUtc();
  return DateTime.utc(
    d.year,
    d.month,
    d.day,
    d.hour,
    d.minute,
    d.second,
  ).subtract(_dhakaOffset);
}

/// Year, month, day, hour and minute on the Bangladesh clock. A bare date is
/// that calendar day, at no particular hour.
({int y, int m, int d, int hour, int minute})? _dhaka(String? iso) {
  if (iso == null || iso.length < 10) return null;
  final plain = _plainDate.firstMatch(iso);
  if (plain != null) {
    final d = DateTime.tryParse(iso);
    if (d == null) return null;
    return (y: d.year, m: d.month, d: d.day, hour: 0, minute: 0);
  }
  final at = _instant(iso);
  if (at == null) return null;
  final x = at.add(_dhakaOffset);
  return (y: x.year, m: x.month, d: x.day, hour: x.hour, minute: x.minute);
}

/// The newspapers' parts of the day: রাত until four, ভোর to six, সকাল to
/// noon, দুপুর to three, বিকেল to five, সন্ধ্যা to seven, then রাত.
String _partOfDay(int hour) {
  if (hour < 4) return 'রাত';
  if (hour < 6) return 'ভোর';
  if (hour < 12) return 'সকাল';
  if (hour < 15) return 'দুপুর';
  if (hour < 17) return 'বিকেল';
  if (hour < 19) return 'সন্ধ্যা';
  return 'রাত';
}

/// The language as a function and a toolkit. Get it from [t] (the current
/// language) or [T.of] (a given one, for tests and pure code).
class T {
  final Lang lang;
  const T._(this.lang);

  static const bangla = T._(Lang.bn);
  static const english = T._(Lang.en);
  static T of(Lang lang) => lang == Lang.en ? english : bangla;

  /// The language a widget is drawn in, registering it to redraw on a switch.
  /// The global [t] works too: [LangRoot] redraws everything on a switch.
  static T watch(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<LangScope>();
    return t;
  }

  bool get en => lang == Lang.en;

  /// The text in this language.
  String call(String bn, String en) => this.en ? en : bn;

  /// Either of two values of any kind, by language.
  X pick<X>(X bn, X en) => this.en ? en : bn;

  /// Digits in this language's script; anything else in the value is kept.
  String n(Object? v) {
    if (v == null) return '';
    final s = v.toString();
    return en ? _toLatin(s) : _toBn(s);
  }

  /// A whole number grouped as the language counts: lakh and crore in Bangla
  /// ("১২,৭৭,১১,৮৯৯"), thousands in English ("127,711,899").
  String group(num v) {
    final i = v.round();
    final neg = i < 0;
    var digits = i.abs().toString();
    String out;
    if (en) {
      out = digits.replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );
    } else if (digits.length > 3) {
      out = ',${digits.substring(digits.length - 3)}';
      digits = digits.substring(0, digits.length - 3);
      while (digits.length > 2) {
        out = ',${digits.substring(digits.length - 2)}$out';
        digits = digits.substring(0, digits.length - 2);
      }
      out = '$digits$out';
    } else {
      out = digits;
    }
    return n('${neg ? '-' : ''}$out');
  }

  /// A number with fixed decimals, one by default.
  String fixed(num v, [int digits = 1]) => n(v.toStringAsFixed(digits));

  /// "৫০.৪%" / "50.4%": a share of a whole, one decimal.
  String pct(num part, num whole) =>
      whole <= 0 ? '${n(0)}%' : '${fixed(part * 100 / whole)}%';

  /// "১৭ ফেব্রুয়ারি ২০২৬" / "17 February 2026", on the Bangladesh calendar;
  /// null when there is nothing to show.
  String? date(String? iso) {
    final x = _dhaka(iso);
    if (x == null) return null;
    return en
        ? '${x.d} ${monthsEn[x.m - 1]} ${x.y}'
        : '${n(x.d)} ${monthsBnList[x.m - 1]} ${n(x.y)}';
  }

  /// "ফেব্রুয়ারি ২০২৬" / "February 2026".
  String? monthYear(String? iso) {
    final x = _dhaka(iso);
    if (x == null) return null;
    return '${month(x.m)} ${n(x.y)}';
  }

  /// The month's name, 1 = January.
  String month(int m) =>
      m < 1 || m > 12 ? '' : (en ? monthsEn : monthsBnList)[m - 1];

  /// The weekday's name: 0 or 7 = Sunday, 1 = Monday (Dart's DateTime.weekday
  /// and the website's 0-based count both work).
  String weekday(int d) => (en ? _weekdaysEnSun : _weekdaysBnSun)[d % 7];

  /// An ordinal: Bangla writes the bare number ("১৩"), English "13th".
  String ord(int v) => en ? _ordinalEn(v) : n(v);

  /// A count with its noun: count(5, 'টি আসন', 'seat', 'seats') is "৫টি আসন"
  /// or "5 seats". The Bangla classifier is given in full ('টি আসন', ' জন').
  String count(int v, String bn, String one, String many) =>
      en ? '$v ${plural(v, one, many)}' : '${n(v)}$bn';

  /// A path of the website in this language: "/mp/x" or "/en/mp/x".
  String href(String path) {
    if (!en || !path.startsWith('/') || path.startsWith('//')) return path;
    if (path == '/') return '/en';
    if (path.startsWith('/en/') || path == '/en') return path;
    return '/en$path';
  }

  /// "রাত ১২:৫৯" / "12:59 am" on the Bangladesh clock; null for a value with
  /// no clock time.
  String? time(String? iso) {
    if (iso == null || !hasClock(iso)) return null;
    final x = _dhaka(iso);
    if (x == null) return null;
    final h12 = x.hour % 12 == 0 ? 12 : x.hour % 12;
    final mm = x.minute.toString().padLeft(2, '0');
    if (en) return '$h12:$mm ${x.hour < 12 ? 'am' : 'pm'}';
    return '${_partOfDay(x.hour)} ${n(h12)}:${n(mm)}';
  }

  /// "১৫ অক্টোবর ২০২৬, সকাল ১০:২৬" / "15 October 2026, 10:26 am", or only
  /// the date when the value has no clock time.
  String? dateTime(String? iso) {
    final d = date(iso);
    if (d == null) return null;
    final tm = time(iso);
    return tm == null ? d : '$d, $tm';
  }

  /// "এইমাত্র", "৫ মিনিট আগে", "৩ ঘণ্টা আগে", "গতকাল", "৩ দিন আগে" within a
  /// week ("just now", "5 minutes ago", …); null for anything older, for a
  /// date still ahead, and for a value with no clock time, where the date
  /// says it better.
  String? ago(String? iso, {DateTime? now}) {
    if (iso == null || !hasClock(iso)) return null;
    final then = _instant(iso);
    if (then == null) return null;
    final mins =
        ((now ?? DateTime.now()).toUtc().difference(then).inSeconds / 60)
            .round();
    // A date ahead of us is a date, not "just now".
    if (mins < -10) return null;
    if (mins < 1) return call('এইমাত্র', 'just now');
    if (mins < 60) {
      return en
          ? '$mins ${plural(mins, 'minute', 'minutes')} ago'
          : '${n(mins)} মিনিট আগে';
    }
    final hours = mins ~/ 60;
    if (hours < 24) {
      return en
          ? '$hours ${plural(hours, 'hour', 'hours')} ago'
          : '${n(hours)} ঘণ্টা আগে';
    }
    final days = hours ~/ 24;
    if (days == 1) return call('গতকাল', 'yesterday');
    if (days < 7) return en ? '$days days ago' : '${n(days)} দিন আগে';
    return null;
  }

  /// When a story was published, in pieces that should not break inside:
  /// ["১৭ অক্টোবর ২০২৬,", "রাত ১২:৫৯", "· ১৬ মিনিট আগে"]. Empty when the
  /// value is not a date.
  List<String> whenParts(String? iso, {DateTime? now}) {
    final d = date(iso);
    if (d == null) return const [];
    final tm = time(iso);
    final a = ago(iso, now: now);
    return [if (tm == null) d else '$d,', ?tm, if (a != null) '· $a'];
  }

  /// "১৭ অক্টোবর ২০২৬, রাত ১২:৫৯ · ১৬ মিনিট আগে" /
  /// "17 October 2026, 12:59 am · 16 minutes ago".
  String when(String? iso, {DateTime? now}) =>
      whenParts(iso, now: now).join(' ');
}

/// Sits above the app: rebuilds every widget when the language changes, and
/// lets a widget that wants it depend on the language explicitly
/// ([T.watch]). Screens holding fetched data listen to [appLang] and refetch.
class LangRoot extends StatefulWidget {
  final Widget child;
  const LangRoot({super.key, required this.child});

  @override
  State<LangRoot> createState() => _LangRootState();
}

class _LangRootState extends State<LangRoot> {
  @override
  void initState() {
    super.initState();
    appLang.addListener(_changed);
  }

  @override
  void dispose() {
    appLang.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    // Most of the app reads the global `t` rather than an inherited widget, so
    // every element is marked for a rebuild: the open tab, the pages pushed
    // over it and any sheet or dialog. State (scroll positions, the tab, a
    // typed search) is kept.
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) =>
      LangScope(notifier: appLang, child: widget.child);
}

class LangScope extends InheritedNotifier<LangController> {
  const LangScope({
    super.key,
    required LangController super.notifier,
    required super.child,
  });
}

/// For a screen that holds fetched data: [onLangChanged] runs after the reader
/// switches language, to fetch it again in the new one.
mixin RefetchOnLang<W extends StatefulWidget> on State<W> {
  void onLangChanged();

  void _langChanged() {
    if (mounted) onLangChanged();
  }

  @override
  void initState() {
    super.initState();
    appLang.addListener(_langChanged);
  }

  @override
  void dispose() {
    appLang.removeListener(_langChanged);
    super.dispose();
  }
}
