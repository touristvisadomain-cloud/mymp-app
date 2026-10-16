/// The number and date helpers the screens were written with. They now follow
/// the reader's language (lib/i18n.dart): in Bangla they write exactly what
/// they always wrote, ৩৪৮ and ১৩ সেপ্টেম্বর ২০২৬; in English, 348 and
/// 13 September 2026. New code calls `t` directly.
library;

import 'i18n.dart';

/// Digits in the reader's script: "৩৪৮" in Bangla, "348" in English.
String bn(Object n) => t.n(n);

/// "১২,৭৭,১১,৮৯৯": thousands, then lakh and crore groups, as Bangla readers
/// count; "127,711,899" in English.
String bnGroup(int n) => t.group(n);

/// "৫০.৪%" for a share of a whole, one decimal.
String pctBn(num part, num whole) => t.pct(part, whole);

const monthsBn = monthsBnList;

const weekdaysBn = [
  'সোমবার',
  'মঙ্গলবার',
  'বুধবার',
  'বৃহস্পতিবার',
  'শুক্রবার',
  'শনিবার',
  'রবিবার',
];

/// "১৩ সেপ্টেম্বর ২০২৬" from an ISO date, or null when there is nothing to show.
String? dateBn(String? iso) => t.date(iso);

/// "২ ঘণ্টা আগে" for something today, a date for anything older.
String whenBn(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final then = DateTime.tryParse(iso);
  if (then == null) return '';
  final minutes = DateTime.now().difference(then.toLocal()).inMinutes;
  if (minutes < 1) return t('এইমাত্র', 'just now');
  if (minutes < 60) {
    return t(
      '${bn(minutes)} মিনিট আগে',
      '$minutes ${plural(minutes, 'minute', 'minutes')} ago',
    );
  }
  if (minutes < 24 * 60) {
    final h = minutes ~/ 60;
    return t('${bn(h)} ঘণ্টা আগে', '$h ${plural(h, 'hour', 'hours')} ago');
  }
  return dateBn(iso) ?? '';
}

/// "১২:০৫" from a number of seconds, for a video's length.
String? durationBn(int? seconds) {
  if (seconds == null || seconds <= 0) return null;
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '${bn(m)}:${bn(s)}';
}

/// The date as a card has room for it: today and yesterday by name, then the
/// day and month, and the year only once it is not this one.
String shortDateBn(String? iso, {String? label}) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) {
    // Fall back to the website's own label, minus the weekday it starts with.
    final l = label ?? '';
    return l.contains(',') ? l.split(',').last.trim() : l;
  }
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (days == 0) return t('আজ', 'Today');
  if (days == 1) return t('গতকাল', 'Yesterday');
  final base = '${bn(d.day)} ${t.month(d.month)}';
  return d.year == now.year ? base : '$base ${bn(d.year)}';
}

/// The letter drawn in place of a missing photograph.
String initialOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  // Names often start with an honorific the reader does not think of as part
  // of the name; the first real word is the one to take a letter from.
  const skip = {
    'মোঃ',
    'মো.',
    'মোহাম্মদ',
    'মুহাম্মদ',
    'ডাঃ',
    'ডা.',
    'ব্যারিস্টার',
    'অ্যাডভোকেট',
    'এড.',
  };
  // The same titles as an English name writes them: "Md. Abul Hasnat" is
  // filed under A. Compared without case or a closing full stop.
  const skipEn = {
    'md',
    'mohammad',
    'mohammed',
    'muhammad',
    'mohd',
    'dr',
    'barrister',
    'advocate',
    'adv',
    'engr',
    'prof',
  };
  bool honorific(String word) =>
      skip.contains(word) ||
      skipEn.contains(word.toLowerCase().replaceAll(RegExp(r'\.$'), ''));
  for (final word in trimmed.split(RegExp(r'\s+'))) {
    if (!honorific(word) && word.isNotEmpty) return word.characters0;
  }
  return trimmed.characters0;
}

extension on String {
  /// The first user-perceived character: a Bengali letter plus its vowel signs.
  String get characters0 {
    if (isEmpty) return '?';
    var end = 1;
    while (end < length && RegExp(r'[া-্ৗ‌‍]').hasMatch(this[end])) {
      end++;
    }
    // A Latin letter is drawn as a capital, as an English reader files a name.
    return substring(0, end).toUpperCase();
  }
}

/// A parliament by its Bangla ordinal, as the secretariat writes it: ত্রয়োদশ, not ১৩তম.
/// In English, "13th".
String parliamentBn(int n) {
  if (t.en) return t.ord(n);
  const words = {
    1: 'প্রথম',
    2: 'দ্বিতীয়',
    3: 'তৃতীয়',
    4: 'চতুর্থ',
    5: 'পঞ্চম',
    6: 'ষষ্ঠ',
    7: 'সপ্তম',
    8: 'অষ্টম',
    9: 'নবম',
    10: 'দশম',
    11: 'একাদশ',
    12: 'দ্বাদশ',
    13: 'ত্রয়োদশ',
    14: 'চতুর্দশ',
    15: 'পঞ্চদশ',
  };
  return words[n] ?? '${bn(n)}তম';
}
