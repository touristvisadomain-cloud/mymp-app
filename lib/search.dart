/// Member search that answers in Bangla or English, however the name is spelt.
///
/// Readers type "tarek", "Tarique", "তারেক" or "tareq rahman" and expect the
/// same person; the secretariat itself writes one man "Hossain" and the next
/// "Hussain". So every name is also reduced to its consonant sounds in one
/// shared Latin alphabet ("তারেক" and "Tarique" both become t-r-k), and a word
/// matches when its letters or its sounds agree. Seats and districts match in
/// either script and with either digits ("dhaka 17", "ঢাকা-১৭"), and a seat's
/// upazilas find its member.
///
/// The second half is the website's place finder (src/lib/findSeat.ts in the
/// mymp repo), ported line for line: which seat an upazila, a union or a city
/// ward is in, read from the Election Commission's boundary text clause by
/// clause, so a union listed as an exception is not taken as part of the seat
/// that excludes it; and, from the site's place list (/place-names.json), every
/// union the text does not name and the city thanas.
library;

import 'models.dart';

const _bnDigits = '০১২৩৪৫৬৭৮৯';

/// Bengali digits to ASCII, lower case, punctuation to spaces.
String _plain(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final d = _bnDigits.indexOf(ch);
    if (d >= 0) {
      b.write(d);
    } else if (RegExp(
      r'[.,\-_/()\[\]:;!?"'
      "'"
      r'`’‘“”]',
    ).hasMatch(ch)) {
      b.write(' ');
    } else {
      b.write(ch);
    }
  }
  return b.toString();
}

/// Spelling a Bengali reader will not think about: the two ই, the two উ, ণ and
/// ন, the three স, ৎ and ত, the nukta, the joiners.
String _foldBn(String s) => s
    .replaceAll('\u200c', '')
    .replaceAll('\u200d', '')
    // ড় ঢ় য় arrive both precomposed and as letter plus nukta.
    .replaceAll('\u09a1\u09bc', 'র')
    .replaceAll('\u09dc', 'র')
    .replaceAll('\u09a2\u09bc', 'র')
    .replaceAll('\u09dd', 'র')
    .replaceAll('\u09af\u09bc', '\u09df')
    .replaceAll('\u09bc', '')
    .replaceAll('ী', 'ি')
    .replaceAll('ূ', 'ু')
    .replaceAll('ণ', 'ন')
    .replaceAll('ষ', 'স')
    .replaceAll('শ', 'স')
    .replaceAll('ৎ', 'ত');

const _bnSound = {
  'ক': 'k', 'খ': 'k', 'গ': 'g', 'ঘ': 'g', 'ঙ': 'n', //
  'চ': 'c', 'ছ': 'c', 'জ': 'j', 'ঝ': 'j', 'ঞ': 'n', //
  'ট': 't', 'ঠ': 't', 'ড': 'd', 'ঢ': 'd', 'ণ': 'n', //
  'ত': 't', 'থ': 't', 'দ': 'd', 'ধ': 'd', 'ন': 'n', //
  'প': 'p', 'ফ': 'f', 'ব': 'b', 'ভ': 'b', 'ম': 'm', //
  'য': 'j', 'র': 'r', 'ল': 'l', 'শ': 's', 'ষ': 's', //
  'স': 's', 'হ': 'h', 'ৎ': 't', 'ং': 'n', //
};

/// A Bengali word's consonant sounds: "রহমান" is r-h-m-n. The য of a যফলা
/// ("ব্যারিস্টার") and য় (left unmapped) are vowels, as in English spelling,
/// and a বফলা ("স্বরাষ্ট্র") is not heard.
String _skeletonBn(String word) {
  final b = StringBuffer();
  final chars = word.runes.map(String.fromCharCode).toList();
  for (var i = 0; i < chars.length; i++) {
    final ch = chars[i];
    if ((ch == 'য' || ch == 'ব') && i > 0 && chars[i - 1] == '্') continue;
    final s = _bnSound[ch];
    if (s != null) b.write(s);
  }
  return _collapse(b.toString());
}

/// An English word's consonant sounds, spelt the way the Bengali ones are:
/// "Tarique" and "Tareq" are t-r-k, "Chowdhury" is c-d-r, "Zamir" is j-m-r.
String _skeletonEn(String word) {
  var w = word
      .replaceAll('ph', 'f')
      .replaceAll('ck', 'k')
      .replaceAll('qu', 'k')
      .replaceAll('q', 'k')
      .replaceAll('x', 'ks')
      .replaceAll('z', 'j')
      .replaceAll('v', 'b');
  // "ch" is one sound; any other c is a k.
  w = w.replaceAll('ch', '#').replaceAll('c', 'k').replaceAll('#', 'c');
  final b = StringBuffer();
  const vowels = 'aeiouwy';
  String prev = '';
  for (final r in w.runes) {
    final ch = String.fromCharCode(r);
    if (!RegExp(r'[a-z]').hasMatch(ch)) continue;
    // An h after a consonant only colours it (kh, dh, sh, bh), as in Bengali
    // spelling, where খ, ধ, শ and ভ carry no separate h.
    if (ch == 'h' && prev.isNotEmpty && !vowels.contains(prev)) {
      prev = ch;
      continue;
    }
    if (!vowels.contains(ch)) b.write(ch);
    prev = ch;
  }
  var out = b.toString();
  // A final h is silent: "Miah" is "Mia".
  if (out.endsWith('h') && word.endsWith('h')) {
    out = out.substring(0, out.length - 1);
  }
  return _collapse(out);
}

String _collapse(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    if (b.isEmpty || !b.toString().endsWith(ch)) b.write(ch);
  }
  return b.toString();
}

final _bengali = RegExp(r'[\u0980-\u09FF]');
final _number = RegExp(r'^\d+$');

class _Word {
  final String text;
  final String sound;
  const _Word(this.text, this.sound);
}

List<_Word> _words(String? s) {
  if (s == null || s.trim().isEmpty) return const [];
  final out = <_Word>[];
  for (final raw in _plain(s).split(RegExp(r'\s+'))) {
    if (raw.isEmpty) continue;
    final bn = _bengali.hasMatch(raw);
    // A hasanta is spelling, not sound, once the যফলা has been read.
    final text = bn ? _foldBn(raw).replaceAll('্', '') : raw;
    final sound = _number.hasMatch(raw)
        ? raw
        : bn
        ? _skeletonBn(_foldBn(raw))
        : _skeletonEn(raw);
    out.add(_Word(text, sound));
  }
  return out;
}

/// Titles people type or leave out: a query "md tarek" means "tarek".
const _titles = {
  'md',
  'mohammad',
  'mohammed',
  'muhammad',
  'mohd',
  'mst',
  'most',
  'mosammat', //
  'dr', 'barrister', 'adv', 'advocate', 'alhaj', 'alhajj', 'engr', 'prof', //
  'মো', 'মোঃ', 'মোহাম্মদ', 'মুহাম্মদ', 'মোছাঃ', 'মোসাম্মত', 'ডা', 'ডাঃ', 'ড', //
  'ব্যারিস্টার',
  'ব্যারিষ্টার',
  'অ্যাডভোকেট',
  'এডভোকেট',
  'আলহাজ্ব',
  'আলহাজ',
  'অধ্যাপক',
};

final _titleTexts = {for (final t in _titles) ..._words(t).map((w) => w.text)};

int _editDistance(String a, String b, int limit) {
  if ((a.length - b.length).abs() > limit) return limit + 1;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    var best = cur[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      if (cur[j] < best) best = cur[j];
    }
    if (best > limit) return limit + 1;
    prev = cur;
  }
  return prev[b.length];
}

/// How close two spellings in the same script are, 0 to 1.
double _likeness(String a, String b) {
  final longest = a.length > b.length ? a.length : b.length;
  if (longest == 0) return 0;
  final d = _editDistance(a, b, longest);
  return 1 - d / longest;
}

/// How well one typed word fits one word of a field: letters first, sounds
/// next, a slip of one sound last. Among sound-alikes the nearer spelling wins.
double _fit(_Word q, _Word w) {
  if (_number.hasMatch(q.text)) return q.text == w.text ? 4 : 0;
  if (w.text == q.text) return 4;
  if (w.text.startsWith(q.text)) return q.text.length >= 2 ? 3 : 1.5;
  if (q.sound.isEmpty || w.sound.isEmpty) return 0;
  final sameScript = _bengali.hasMatch(q.text) == _bengali.hasMatch(w.text);
  final near = sameScript ? _likeness(q.text, w.text) * 0.4 : 0.2;
  if (w.sound == q.sound) return (q.sound.length >= 2 ? 2.4 : 1) + near;
  if (q.sound.length >= 3 && w.sound.startsWith(q.sound)) return 1.7 + near;
  // One slipped sound in a longer word, but never the first: "safiqur" may
  // find "Shafiqul", "srstr" must not find "brstr".
  if (q.sound.length >= 4 && q.sound[0] == w.sound[0]) {
    final limit = q.sound.length >= 7 ? 2 : 1;
    if (_editDistance(q.sound, w.sound, limit) <= limit) return 1.1 + near;
  }
  return 0;
}

class _Field {
  final List<_Word> words;
  final double weight;
  const _Field(this.words, this.weight);
}

class _Indexed {
  final MemberBrief member;
  final List<_Field> fields;
  const _Indexed(this.member, this.fields);
}

/// A member's names in the other script: on an English list, the Bangla name,
/// seat and district the site sends beside the English ones (`nameAlt`,
/// `seatAlt`, `districtAlt`), so "তারেক" still finds Tarique Rahman.
class MemberAlt {
  final String? name;
  final String? seat;
  final String? district;
  const MemberAlt({this.name, this.seat, this.district});
}

/// The member list, indexed once, searched on every keystroke.
class MemberSearch {
  final List<_Indexed> _index;

  /// [alt] is keyed by member id.
  MemberSearch(
    List<MemberBrief> members, {
    Map<String, String> partyNames = const {},
    Map<String, MemberAlt> alt = const {},
  }) : _index = [
         for (final m in members)
           _Indexed(m, [
             _Field(
               _words('${m.nameBn} ${m.nameEn ?? ''} ${alt[m.id]?.name ?? ''}'),
               1.5,
             ),
             _Field(
               _words(
                 '${m.seatBn ?? ''} ${m.seatEn ?? ''} ${m.districtBn ?? ''} ${m.districtEn ?? ''} '
                 '${alt[m.id]?.seat ?? ''} ${alt[m.id]?.district ?? ''}',
               ),
               1.2,
             ),
             _Field(
               _words(
                 '${m.partyBn ?? ''} ${m.party ?? ''} ${partyNames[m.party] ?? ''} ${m.officeBn ?? ''}',
               ),
               0.8,
             ),
             _Field(
               _words(
                 m.areaBn,
               ).where((w) => !_number.hasMatch(w.text)).toList(),
               0.5,
             ),
           ]),
       ];

  /// Everyone who matches every typed word, best first; ties keep [members]'
  /// order. An empty query returns nothing: the caller shows the full list.
  List<MemberBrief> search(String query) {
    var words = _words(query);
    final meaningful = words
        .where((w) => !_titleTexts.contains(w.text))
        .toList();
    if (meaningful.isNotEmpty) words = meaningful;
    if (words.isEmpty) return const [];

    final scored = <(MemberBrief, double, int)>[];
    for (final (i, entry) in _index.indexed) {
      var total = 0.0;
      var all = true;
      for (final q in words) {
        var best = 0.0;
        for (final f in entry.fields) {
          for (final w in f.words) {
            final s = _fit(q, w) * f.weight;
            if (s > best) best = s;
          }
        }
        if (best == 0) {
          all = false;
          break;
        }
        total += best;
      }
      if (all) scored.add((entry.member, total, i));
    }
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      return byScore != 0 ? byScore : a.$3.compareTo(b.$3);
    });
    // Keep strong matches when there are some: a sound-alike should not bury
    // the member whose name was typed exactly.
    if (scored.isNotEmpty) {
      final top = scored.first.$2;
      return [
        for (final s in scored)
          if (s.$2 >= top * 0.5) s.$1,
      ];
    }
    return const [];
  }
}

/// The member search's matching for any list: each item's words in weighted
/// fields, in either script and either digits, by spelling or by sound.
/// Every typed word must fit some word of the item; the best come first.
/// The election map finds its seats and districts with it.
class TextSearch<T> {
  final List<(T, List<_Field>)> _index;

  TextSearch(Iterable<T> items, List<(String, double)> Function(T) fields)
    : _index = [
        for (final item in items)
          (item, [for (final (s, w) in fields(item)) _Field(_words(s), w)]),
      ];

  /// Matches for [query], best first; ties keep the items' order. Fewer than
  /// two letters find nothing.
  List<T> search(String query) {
    if (query.trim().length < 2) return const [];
    var words = _words(query);
    final meaningful = words
        .where((w) => !_titleTexts.contains(w.text))
        .toList();
    if (meaningful.isNotEmpty) words = meaningful;
    if (words.isEmpty) return const [];

    final scored = <(T, double, int)>[];
    for (final (i, (item, fields)) in _index.indexed) {
      var total = 0.0;
      var all = true;
      for (final q in words) {
        var best = 0.0;
        for (final f in fields) {
          for (final w in f.words) {
            final s = _fit(q, w) * f.weight;
            if (s > best) best = s;
          }
        }
        if (best == 0) {
          all = false;
          break;
        }
        total += best;
      }
      if (all) scored.add((item, total, i));
    }
    if (scored.isEmpty) return const [];
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      return byScore != 0 ? byScore : a.$3.compareTo(b.$3);
    });
    // As with members: a sound-alike does not bury what was typed exactly.
    final top = scored.first.$2;
    return [
      for (final s in scored)
        if (s.$2 >= top * 0.5) s.$1,
    ];
  }
}

// ---------------------------------------------------------------- places

/// A territorial seat as the place finder reads it: the Bangla names and
/// boundary text (Bangla in both languages), and the sitting member.
class FinderSeat {
  final int no;

  /// "ঢাকা-২", in Bangla whatever the reader's language.
  final String seat;
  final String? seatEn;
  final String slug;

  /// The district in Bangla.
  final String district;
  final String? districtEn;

  /// The Election Commission's description, in Bangla.
  final String? boundary;

  /// The sitting member; null while the seat is vacant.
  final MemberBrief? member;

  /// The seat's name in the reader's language, for showing.
  final String seatLabel;

  const FinderSeat({
    required this.no,
    required this.seat,
    this.seatEn,
    required this.slug,
    required this.district,
    this.districtEn,
    this.boundary,
    this.member,
    String? seatLabel,
  }) : seatLabel = seatLabel ?? seat;
}

enum MatchKind { seat, district, upazila, union, ward, thana, place }

class SeatMatch {
  final FinderSeat seat;
  final MatchKind kind;

  /// The clause of the boundary text that matched, as written.
  final String? clause;

  /// True when the seat holds only part of the place (some unions, or all
  /// but some).
  final bool partial;
  final int score;

  /// For a union or thana found through the place list rather than the
  /// boundary text: where it is ("বাবরা হাচলা ইউনিয়ন, কালিয়া উপজেলা"), since
  /// many unions share a name. [placeEn] on English screens.
  final String? place;
  final String? placeEn;

  /// A listed union's upazila, to say how to tell apart unions that share a
  /// name.
  final String? upazila;
  final String? upazilaEn;

  const SeatMatch(
    this.seat,
    this.kind,
    this.clause,
    this.partial,
    this.score, {
    this.place,
    this.placeEn,
    this.upazila,
    this.upazilaEn,
  });
}

/// A union of the place list: [bn], [en], its upazila as the boundary text
/// spells it, its district, the upazila in English, and for a union since
/// taken into a city corporation the slugs of the seats that share the city.
typedef PlaceUnion = ({
  String bn,
  String en,
  String upazila,
  String district,
  String? upazilaEn,
  List<String>? inCity,
});

/// A city thana of the place list, placed on the seat map by OpenStreetMap's
/// points for it; [partial]: it may reach into a neighbouring seat.
typedef PlaceThana = ({String bn, String en, List<String> slugs, bool partial});

/// The places the boundary text does not name (the site's
/// public/place-names.json, built by scripts/build-place-names.ts). The
/// Election Commission names a union only where a seat holds part of an
/// upazila; every other union is found through its upazila. Many unions share
/// a name, so "চরপাতা দৌলতখান" (a union, then its upazila or district) narrows it.
class PlaceNames {
  final List<PlaceUnion> unions;
  final List<PlaceThana> thanas;
  const PlaceNames({this.unions = const [], this.thanas = const []});

  /// Read defensively: a row the app does not understand is skipped.
  factory PlaceNames.fromJson(Map<String, dynamic> j) {
    String? s(dynamic v) => v is String ? v : null;
    final unions = <PlaceUnion>[];
    if (j['unions'] is List) {
      for (final r in j['unions'] as List) {
        if (r is! List || r.length < 4) continue;
        final bn = s(r[0]), en = s(r[1]), up = s(r[2]), d = s(r[3]);
        if (bn == null || en == null || up == null || d == null) continue;
        unions.add((
          bn: bn,
          en: en,
          upazila: up,
          district: d,
          upazilaEn: r.length > 4 ? s(r[4]) : null,
          inCity: r.length > 5 && r[5] is List
              ? [
                  for (final x in r[5] as List)
                    if (x is String) x,
                ]
              : null,
        ));
      }
    }
    final thanas = <PlaceThana>[];
    if (j['thanas'] is List) {
      for (final r in j['thanas'] as List) {
        if (r is! List || r.length < 4) continue;
        final bn = s(r[0]), en = s(r[1]);
        if (bn == null || en == null || r[2] is! List) continue;
        thanas.add((
          bn: bn,
          en: en,
          slugs: [
            for (final x in r[2] as List)
              if (x is String) x,
          ],
          partial: r[3] == true,
        ));
      }
    }
    return PlaceNames(unions: unions, thanas: thanas);
  }
}

const _bnDigitsPlace = '০১২৩৪৫৬৭৮৯';

/// What `String.normalize('NFC')` does to Bengali text, which Dart has no
/// call for: য় ড় ঢ় are written as letter plus nukta, and the two-part
/// vowel signs ো ৌ are composed.
String _nfcBn(String s) => s
    .replaceAll('য়', 'য়')
    .replaceAll('ড়', 'ড়')
    .replaceAll('ঢ়', 'ঢ়')
    .replaceAll('ো', 'ো')
    .replaceAll('ৌ', 'ৌ');

/// The site's foldBangla (src/lib/matching/nameMatch.ts).
String _foldBangla(String s) => _nfcBn(s)
    .replaceAll(RegExp('[​-‍﻿]'), '')
    .replaceAll('্', '')
    .replaceAll('়', '')
    .replaceAll('ী', 'ি')
    .replaceAll('ূ', 'ু')
    .replaceAll('ণ', 'ন')
    .replaceAll(RegExp('[ষশ]'), 'স')
    .replaceAll('ৎ', 'ত')
    .replaceAll('ঁ', '')
    .toLowerCase();

final _notWord = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);

/// Folded words: one spelling for the many, Latin digits as Bangla,
/// punctuation as space.
String placeFold(String s) =>
    // লক্ষ্মীপুর is written লক্ষীপুর in the boundary text. ঙ and ং are one
    // sound: the text writes রাংগুনিয়া and টাংগাইল, other lists রাঙ্গুনিয়া.
    _foldBangla(_nfcBn(s).replaceAll('ক্ষ্ম', 'ক্ষ'))
        .replaceAll('ঙ', 'ং')
        .replaceAllMapped(
          RegExp(r'\d'),
          (m) => _bnDigitsPlace[int.parse(m[0]!)],
        )
        .replaceAll(_notWord, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

List<String> _placeWords(String s) =>
    placeFold(s).split(' ').where((w) => w.isNotEmpty).toList();

String _toLatinDigits(String s) => s.replaceAllMapped(
  RegExp('[০-৯]'),
  (m) => '${_bnDigitsPlace.indexOf(m[0]!)}',
);

/// Words that say what kind of place a name is, which a person may or may not
/// type.
final _kindWords = {
  for (final w in const [
    'উপজেলা', 'উপজেলার', 'ইউনিয়ন', 'ইউনিয়নের', 'জেলা', 'জেলার', 'থানা', //
    'থানার', 'পৌরসভা', 'পৌরসভার', 'upazila', 'union', 'district', 'thana',
  ])
    placeFold(w),
};

/// "ওয়ার্ড" both ways it is encoded (য় as one letter, and as য plus nukta).
final _wardWords = {
  for (final w in const ['ওয়ার্ড', 'ওয়ার্ড', 'ward']) placeFold(w),
};

/// The ward numbers a city clause names: "ওয়ার্ড- ০৪,১৩,১৪, ও ১৬", "ওয়ার্ড ৭
/// থেকে ১২ পর্যন্ত", "১ হতে ১৮ নং ওয়ার্ড". A range runs from the number
/// before থেকে or হতে to the one after.
List<int> wardNumbers(String clause) {
  final out = <int>{};
  final rest = _toLatinDigits(_nfcBn(clause)).replaceAllMapped(
    RegExp(r'(\d+)\s*(?:থেকে|হতে)\s*(\d+)'),
    (m) {
      final a = int.parse(m[1]!);
      final b = int.parse(m[2]!);
      for (var n = a; n <= b && n < a + 200; n++) {
        out.add(n);
      }
      return ' ';
    },
  );
  for (final m in RegExp(r'\d+').allMatches(rest)) {
    out.add(int.parse(m[0]!));
  }
  return out.toList()..sort();
}

/// Does the folded word list [hay] contain [needle] as whole words? The last
/// word may be half typed.
bool _hasRun(List<String> hay, List<String> needle, bool prefixLast) {
  if (needle.isEmpty) return false;
  for (var i = 0; i + needle.length <= hay.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      final h = hay[i + j];
      final n = needle[j];
      final last = j == needle.length - 1;
      // A place name takes a case ending in the text: "সাভার উপজেলার",
      // "কেরানিগঞ্জের".
      if (!(h == n ||
          (last &&
              h.startsWith(n) &&
              (prefixLast || h.length - n.length <= 2)))) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

class _Clause {
  final String text;

  /// The part naming places the seat holds.
  final List<String> holds;

  /// Unions the clause names as exceptions: not in this seat.
  final List<String> except;
  final MatchKind kind;
  final bool partial;
  const _Clause(this.text, this.holds, this.except, this.kind, this.partial);
}

/// JavaScript's `s.split(/[ঃ:]/, 2)`: the first two pieces, the rest dropped.
List<String> _split2(String s) => s.split(RegExp('[ঃ:]')).take(2).toList();

final _clauseMark = RegExp('\\([কখগঘঙচছজঝঞটঠ]\\)');
final _clauseEdge = RegExp(r'^[,;।\s]+|[,;।\s]+$');

final _except = RegExp('ব্যা?তীত');
final _andThen = RegExp(r'^(.+?)\s+এবং\s+(.+)$');

List<_Clause> _clause(String text) {
  final isWard = _placeWords(text).any(_wardWords.contains);
  if (_except.hasMatch(text)) {
    // "নিম্নলিখিত ইউনিয়ন সমূহ ব্যতীত কেরানিগঞ্জ উপজেলাঃ(১) জিনজিরা, …"
    final p = _split2(text);
    final upazila = p[0].replaceFirst(RegExp('.*ব্যা?তীত'), '');
    return [
      _Clause(
        text,
        [upazila],
        [p.length > 1 ? p[1] : ''],
        MatchKind.upazila,
        true,
      ),
    ];
  }
  if (text.contains('নিম্নলিখিত')) {
    // "সাভার উপজেলার নিম্নলিখিত ইউনিয়ন সমূহঃ (১) আমিনবাজার, …": only these
    // unions.
    final p = _split2(text);
    final list = p.length > 1 ? p[1] : '';
    // "পলাশ এবং নরসিংদী সদর উপজেলার নিম্নলিখিত …": a whole upazila, then the
    // one the list belongs to.
    final m = _andThen.firstMatch(p[0]);
    if (m != null && !m[1]!.contains('নিম্নলিখিত')) {
      return [
        _Clause(m[1]!, [m[1]!], const [], MatchKind.upazila, false),
        _Clause(text, [m[2]!, list], const [], MatchKind.union, true),
      ];
    }
    return [
      _Clause(text, [p[0], list], const [], MatchKind.union, true),
    ];
  }
  // "সাভার উপজেলার কাউন্দিয়া ইউনিয়ন": named unions of an upazila, without
  // the word নিম্নলিখিত.
  final genitive = text.indexOf('উপজেলার');
  if (genitive > 0 &&
      placeFold(text.substring(genitive)).contains(placeFold('ইউনিয়ন'))) {
    return [
      _Clause(
        text,
        [text.substring(0, genitive), text.substring(genitive)],
        const [],
        MatchKind.union,
        true,
      ),
    ];
  }
  return [
    _Clause(
      text,
      [text],
      const [],
      isWard ? MatchKind.ward : MatchKind.upazila,
      false,
    ),
  ];
}

/// "(ক) …, (খ) …" into its clauses; a boundary with no markers is one clause.
/// "সুবর্ণচরএবং": the text sometimes runs a name into the এবং after it.
List<_Clause> _clausesOf(String boundary) => boundary
    .replaceAllMapped(RegExp(r'(\S)এবং'), (m) => '${m[1]} এবং')
    .split(_clauseMark)
    .map((p) => p.trim().replaceAll(_clauseEdge, ''))
    .where((p) => p.isNotEmpty)
    .expand(_clause)
    .toList();

const _rank = {
  MatchKind.seat: 100,
  MatchKind.district: 80,
  MatchKind.union: 70,
  MatchKind.ward: 65,
  MatchKind.upazila: 60,
  MatchKind.thana: 55,
  MatchKind.place: 40,
};

/// A union found through the place list ranks below an upazila and a city
/// thana of the same name: শিবপুর the upazila, and মিরপুর the Dhaka thana,
/// before the many unions called so.
const _listedUnion = 52;

int _byScore(SeatMatch a, SeatMatch b) {
  final s = b.score.compareTo(a.score);
  return s != 0 ? s : a.seat.no.compareTo(b.seat.no);
}

/// Seats that hold the place the person typed (in Bangla; see [toBangla]),
/// best first. A seat that holds the place whole ranks above one that holds
/// a part of it. With [names], a union or thana the boundary text does not
/// name too.
List<SeatMatch> findSeats(
  String query,
  List<FinderSeat> seats, {
  int limit = 12,
  PlaceNames? names,
}) {
  // Whole words first; a half-typed last word only when nothing matches whole.
  final exact = _searchSeats(query, seats, limit, false);
  final listed = names != null
      ? _byPlaceName(query, seats, names)
      : const <SeatMatch>[];
  final seen = {for (final m in exact) m.seat.no};
  final both = [
    ...exact,
    for (final m in listed)
      if (seen.add(m.seat.no)) m,
  ];
  if (both.isNotEmpty) return (both..sort(_byScore)).take(limit).toList();
  return _searchSeats(query, seats, limit, true);
}

/// Folded words with the words that only name a kind of place dropped.
List<String> _nameWords(String s) =>
    _placeWords(s).where((w) => !_kindWords.contains(w)).toList();

/// Whether a listed name (a union in a clause's list) is this union, past
/// small spelling differences.
bool _sameName(String a, String b) {
  final x = placeFold(a).replaceAll(' ', '');
  final y = placeFold(b).replaceAll(' ', '');
  if (x == y) return true;
  return x.length >= 4 && y.length >= 4 && _plainEditDistance(x, y) <= 1;
}

final _kindInList = RegExp(_nfcBn('উপজেলার?|ইউনিয়ন|সমূহ'));
final _listSplit = RegExp(r'[,;।ঃ:-]|\sও\s|\sএবং\s');
final _listEdge = RegExp(r'^(?:ও|এবং)\s+|\s+(?:ও|এবং)$');

/// The names in a clause's list: "(১) জিনজিরা, (২)আগানগর … ও(৫) শুভাট্যা".
List<String> _listNames(String list) => _nfcBn(list)
    .replaceAll(RegExp(r'\([০-৯\d]+\)'), ',')
    .replaceAll(_kindInList, ',')
    .split(_listSplit)
    .map((x) => x.trim().replaceAll(_listEdge, '').trim())
    .where((x) => x.length > 1)
    .toList();

/// [_hasRun], past one letter's difference in a longer word: the text writes
/// রানিসংকাইল and রানিশংকাইল for one upazila.
bool _nearRun(List<String> hay, List<String> needle) {
  if (_hasRun(hay, needle, false)) return true;
  bool near(String h, String n) =>
      h == n || (n.length >= 4 && _plainEditDistance(h, n) <= 1);
  for (var i = 0; i + needle.length <= hay.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (!near(hay[i + j], needle[j])) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

/// Seats holding a union of [upazila] (as the boundary text spells it), read
/// the way the text means it.
List<FinderSeat> seatsForUnion(
  String name,
  String upazila,
  String district,
  List<FinderSeat> seats,
) {
  final up = _nameWords(upazila);
  final out = <FinderSeat>[];
  bool inDistrict(FinderSeat s) =>
      district.isEmpty || _sameName(s.district, district);
  for (final seat in seats) {
    final boundary = seat.boundary;
    if (boundary == null || !inDistrict(seat)) continue;
    for (final c in _clausesOf(boundary)) {
      if (c.kind == MatchKind.ward) continue;
      if (c.kind == MatchKind.union) {
        // Only the listed unions of the upazila.
        if (_nearRun(_nameWords(c.holds[0]), up) &&
            _listNames(
              c.holds.length > 1 ? c.holds[1] : '',
            ).any((n) => _sameName(n, name))) {
          out.add(seat);
          break;
        }
        continue;
      }
      if (c.partial) {
        // The upazila except the listed unions.
        if (_nearRun(_nameWords(c.holds[0]), up) &&
            !_listNames(
              c.except.isNotEmpty ? c.except[0] : '',
            ).any((n) => _sameName(n, name))) {
          out.add(seat);
          break;
        }
        continue;
      }
      if (_nearRun(_nameWords(c.text), up)) {
        out.add(seat);
        break;
      }
    }
  }
  if (out.isNotEmpty) return out;
  // The hill districts are described whole ("রাংগামাটি পার্বত্য জেলা"),
  // without their upazilas: a clause that is the district and nothing else.
  final dw = _nameWords(district).join(' ');
  final hill = placeFold('পার্বত্য');
  return [
    for (final s in seats)
      if (inDistrict(s) &&
          s.boundary != null &&
          dw.isNotEmpty &&
          _clausesOf(s.boundary!).any(
            (c) => _nameWords(c.text).where((x) => x != hill).join(' ') == dw,
          ))
        s,
  ];
}

String _latin(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '');

/// The place list's names folded once, not on every keystroke.
final _prepared =
    Expando<
      ({
        List<List<String>> unions,
        List<String> unionsEn,
        List<List<String>> thanas,
        List<String> thanasEn,
      })
    >();

final _latinKind = RegExp(
  r'\b(union|thana|upazila|upazilla|police station|ps)\b',
);

/// Unions and thanas from the place list whose name is the query.
List<SeatMatch> _byPlaceName(
  String query,
  List<FinderSeat> seats,
  PlaceNames names,
) {
  final q = _nameWords(query);
  if (q.isEmpty || q.join().length < 2) return const [];
  final pre = _prepared[names] ??= (
    unions: [for (final u in names.unions) _nameWords(u.bn)],
    unionsEn: [for (final u in names.unions) _latin(u.en)],
    thanas: [for (final th in names.thanas) _nameWords(th.bn)],
    thanasEn: [for (final th in names.thanas) _latin(th.en)],
  );
  final english = RegExp('[a-z]', caseSensitive: false).hasMatch(query);
  final typedWords = query
      .toLowerCase()
      .replaceAll(_latinKind, ' ')
      .split(RegExp('[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final typed = typedWords.join();
  bool sameLatin(String a, String key) =>
      key.isNotEmpty &&
      (key == a || (a.length >= 6 && _plainEditDistance(a, key) <= 1));
  // "kalatia" is কলাতিয়া, not also করটিয়া a letter away: a name a letter
  // off counts only when none is exact.
  final exactLatin =
      english && (pre.unionsEn.contains(typed) || pre.thanasEn.contains(typed));
  bool sameName(String a, String key) =>
      exactLatin ? key.isNotEmpty && key == a : sameLatin(a, key);

  // The name, then perhaps words naming where it is: "চরপাতা দৌলতখান",
  // "charpata bhola".
  bool isName(List<String> w, String key, [List<String> Function()? where]) {
    if (english) {
      if (sameName(typed, key)) return true;
      if (where == null) return false;
      // The union's own words, then its upazila's or district's.
      for (var n = 1; n < typedWords.length; n++) {
        if (!sameName(typedWords.take(n).join(), key)) continue;
        final rest = typedWords.skip(n).join();
        if (where().any(
          (x) =>
              sameLatin(rest, _latin(x)) ||
              (rest.length >= 4 && _latin(x).startsWith(rest)),
        )) {
          return true;
        }
      }
      return false;
    }
    if (q.length < w.length) return false;
    for (var i = 0; i < w.length; i++) {
      if (w[i] != q[i]) return false;
    }
    if (q.length == w.length) return true;
    if (where == null) return false;
    final rest = q.sublist(w.length);
    return where().any(
      (x) =>
          _nearRun(_nameWords(x), rest) || _hasRun(_nameWords(x), rest, true),
    );
  }

  String districtEn(String bn) {
    final f = placeFold(bn);
    for (final s in seats) {
      if (placeFold(s.district) == f) return s.districtEn ?? '';
    }
    return '';
  }

  final out = <SeatMatch>[];
  final bySlug = {for (final s in seats) s.slug: s};
  for (final (i, u) in names.unions.indexed) {
    if (!isName(
      pre.unions[i],
      pre.unionsEn[i],
      () => english
          ? [u.upazilaEn ?? '', districtEn(u.district)]
          : [u.upazila, u.district],
    )) {
      continue;
    }
    final place = '${u.bn} ইউনিয়ন, ${u.upazila} উপজেলা';
    final placeEn = '${u.en} union, ${u.upazilaEn ?? u.upazila}';
    final inCity = u.inCity;
    if (inCity != null) {
      // Now city wards the text does not tie to the union: each seat that
      // shares the city may hold it.
      for (final slug in inCity) {
        final seat = bySlug[slug];
        if (seat == null) continue;
        out.add(
          SeatMatch(
            seat,
            MatchKind.union,
            null,
            true,
            _listedUnion - 10,
            place: place,
            placeEn: placeEn,
            upazila: u.upazila,
            upazilaEn: u.upazilaEn,
          ),
        );
      }
      continue;
    }
    for (final seat in seatsForUnion(u.bn, u.upazila, u.district, seats)) {
      out.add(
        SeatMatch(
          seat,
          MatchKind.union,
          null,
          false,
          _listedUnion,
          place: place,
          placeEn: placeEn,
          upazila: u.upazila,
          upazilaEn: u.upazilaEn,
        ),
      );
    }
  }
  for (final (i, th) in names.thanas.indexed) {
    if (!isName(pre.thanas[i], pre.thanasEn[i])) continue;
    for (final slug in th.slugs) {
      final seat = bySlug[slug];
      if (seat == null) continue;
      // Every city thana is marked partial, so being partial costs it no rank.
      out.add(
        SeatMatch(
          seat,
          MatchKind.thana,
          null,
          th.partial,
          _rank[MatchKind.thana]!,
          place: '${th.bn} থানা',
          placeEn: '${th.en} thana',
        ),
      );
    }
  }
  // One line a seat: the same union name in two upazilas of one seat is one
  // answer.
  final seen = <int>{};
  return [
    for (final m in out)
      if (seen.add(m.seat.no)) m,
  ];
}

final _bnNumber = RegExp(r'^[০-৯]+$');
final _bnDigit = RegExp('[০-৯]');

List<SeatMatch> _searchSeats(
  String query,
  List<FinderSeat> seats,
  int limit,
  bool prefix,
) {
  final q = _placeWords(query).where((w) => !_kindWords.contains(w)).toList();
  if (q.isEmpty || q.join().length < 2) return const [];
  final out = <SeatMatch>[];

  // "ঢাকা দক্ষিণ ওয়ার্ড ১৫": the number among a city clause's ward numbers,
  // the other words in the clause.
  final wardAt = q.indexWhere(_wardWords.contains);
  if (wardAt >= 0) {
    final number = q.skip(wardAt + 1).where(_bnNumber.hasMatch).firstOrNull;
    if (number != null) {
      final city = [
        for (final (i, w) in q.indexed)
          if (i != wardAt && w != number) w,
      ];
      final n = int.parse(_toLatinDigits(number));
      for (final seat in seats) {
        final boundary = seat.boundary;
        if (boundary == null) continue;
        for (final c in _clausesOf(boundary)) {
          if (c.kind != MatchKind.ward) continue;
          final cw = _placeWords(c.text);
          if (!wardNumbers(c.text).contains(n) ||
              !city.every((w) => cw.any((h) => h.startsWith(w)))) {
            continue;
          }
          out.add(
            SeatMatch(
              seat,
              MatchKind.ward,
              c.text,
              false,
              _rank[MatchKind.ward]!,
            ),
          );
          break;
        }
      }
      out.sort((a, b) => a.seat.no.compareTo(b.seat.no));
      return out.take(limit).toList();
    }
  }

  for (final seat in seats) {
    final seatWords = [
      ..._placeWords(seat.seat),
      if (seat.seatEn != null) ..._placeWords(seat.seatEn!),
    ];
    if (_hasRun(seatWords, q, prefix) && q.any(_bnDigit.hasMatch)) {
      out.add(
        SeatMatch(seat, MatchKind.seat, null, false, _rank[MatchKind.seat]!),
      );
      continue;
    }
    final districtWords = [
      ..._placeWords(seat.district),
      if (seat.districtEn != null) ..._placeWords(seat.districtEn!),
    ];
    if (_hasRun(districtWords, q, prefix) && q.length <= 2) {
      out.add(
        SeatMatch(
          seat,
          MatchKind.district,
          null,
          false,
          _rank[MatchKind.district]!,
        ),
      );
      continue;
    }
    final boundary = seat.boundary;
    if (boundary == null) continue;
    for (final c in _clausesOf(boundary)) {
      // Listed as not in this seat.
      if (c.except.any((e) => _hasRun(_placeWords(e), q, false))) continue;
      final hit = c.holds.indexWhere((h) => _hasRun(_placeWords(h), q, prefix));
      if (hit < 0) continue;
      // In a "these unions only" clause, a hit in the list is a union; in the
      // head it is the upazila they belong to.
      final kind = c.kind == MatchKind.union
          ? (hit == 1 ? MatchKind.union : MatchKind.upazila)
          : c.kind;
      final partial = c.partial && kind != MatchKind.union;
      out.add(
        SeatMatch(
          seat,
          kind,
          c.text,
          partial,
          _rank[kind]! - (partial ? 15 : 0),
        ),
      );
      break;
    }
  }
  out.sort((a, b) {
    final s = b.score.compareTo(a.score);
    return s != 0 ? s : a.seat.no.compareTo(b.seat.no);
  });
  return out.take(limit).toList();
}

/// City and direction words a person may type in English, for a ward search.
const _enWords = {
  'dhaka': 'ঢাকা',
  'south': 'দক্ষিণ',
  'north': 'উত্তর',
  'dakshin': 'দক্ষিণ',
  'uttar': 'উত্তর',
  'chittagong': 'চট্টগ্রাম',
  'chattogram': 'চট্টগ্রাম',
  'ctg': 'চট্টগ্রাম',
  'khulna': 'খুলনা',
  'rajshahi': 'রাজশাহী',
  'sylhet': 'সিলেট',
  'barishal': 'বরিশাল',
  'barisal': 'বরিশাল',
  'rangpur': 'রংপুর',
  'mymensingh': 'ময়মনসিংহ',
  'gazipur': 'গাজীপুর',
  'narayanganj': 'নারায়ণগঞ্জ',
  'cumilla': 'কুমিল্লা',
  'comilla': 'কুমিল্লা',
  'city': 'সিটি',
  'ward': 'ওয়ার্ড',
  'no': '',
};
const _enDrop = {
  'upazila',
  'upazilla',
  'thana',
  'union',
  'district',
  'zila',
  'zilla',
  'corporation',
  'of',
  'the',
};

int _plainEditDistance(String a, String b) {
  final d = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    var prev = d[0];
    d[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final tmp = d[j];
      final sub = prev + (a[i - 1] == b[j - 1] ? 0 : 1);
      var best = d[j] + 1;
      if (d[j - 1] + 1 < best) best = d[j - 1] + 1;
      if (sub < best) best = sub;
      d[j] = best;
      prev = tmp;
    }
  }
  return d[b.length];
}

/// A query typed in English, put in the Bangla the boundary text uses:
/// "Savar" → সাভার, "doulatkhan upazila" → দৌলতখান, "ward 15 dhaka south" →
/// ওয়ার্ড 15 ঢাকা দক্ষিণ. [upazilas] is [English, Bangla] pairs (the
/// bootstrap's `upazilaEn`). A query with no Latin letters comes back as it is.
String toBangla(String query, List<(String, String)> upazilas) {
  if (!RegExp('[a-z]', caseSensitive: false).hasMatch(query)) return query;
  final words = query
      .toLowerCase()
      .split(RegExp('[^a-z0-9]+'))
      .where((w) => w.isNotEmpty && !_enDrop.contains(w))
      .toList();
  if (words.any((w) => w == 'ward' || w == 'wd')) {
    return words
        .map(
          (w) => w == 'wd'
              ? 'ওয়ার্ড'
              : RegExp(r'^\d+$').hasMatch(w)
              ? w
              : _enWords[w] ?? w,
        )
        .join(' ');
  }
  final typed = words.join();
  if (typed.length < 3) return query;
  String? best;
  num bestD = 0;
  for (final (en, bn) in upazilas) {
    final key = en.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '');
    if (key == typed) return bn;
    // Half typed, or a letter or two off: "doulatkhan" / "daulatkhan",
    // "charfason".
    final num d = key.startsWith(typed) && typed.length >= 4
        ? 0.5
        : _plainEditDistance(typed, key);
    final tol = key.length >= 8 ? 2 : 1;
    if (d <= tol && (best == null || d < bestD)) {
      best = bn;
      bestD = d;
    }
  }
  return best ?? query;
}

/// The seats of the place a reader typed, in either script: an upazila, a
/// union, a thana or a city ward. Seats and districts by name are left to
/// [MemberSearch], as the website leaves them to its own index.
List<SeatMatch> findPlaces(
  String query,
  List<FinderSeat> seats,
  List<(String, String)> upazilaEn, {
  int limit = 8,
  PlaceNames? names,
}) {
  final q = query.trim();
  if (q.length < 2) return const [];
  // An English name that is exactly a union's or thana's stays as typed,
  // rather than becoming an upazila a letter away ("Rampur", not Raipura).
  String key(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'\b(union|thana|upazila|upazilla)\b'), '')
      .replaceAll(RegExp('[^a-z0-9]+'), '');
  final typedKey = key(q);
  final upazilaExactly =
      typedKey.isNotEmpty && upazilaEn.any((p) => key(p.$1) == typedKey);
  final listedExactly =
      names != null &&
      typedKey.isNotEmpty &&
      !upazilaExactly &&
      (names.unions.any((u) => key(u.en) == typedKey) ||
          names.thanas.any((th) => key(th.en) == typedKey));
  final asBangla = listedExactly ? q : toBangla(q, upazilaEn);
  final byName = findSeats(asBangla, seats, limit: limit, names: names);
  // A union or thana typed in English is looked up by its English name too:
  // toBangla knows only the upazilas, and may turn it into a near one.
  final asTyped = names != null && asBangla != q && !upazilaExactly
      ? findSeats(
          q,
          seats,
          limit: limit,
          names: names,
        ).where((m) => m.kind == MatchKind.union || m.kind == MatchKind.thana)
      : const <SeatMatch>[];
  final nos = {for (final m in byName) m.seat.no};
  final found = [
    ...byName,
    for (final m in asTyped)
      if (nos.add(m.seat.no)) m,
  ]..sort(_byScore);
  return found
      .where((m) => m.kind != MatchKind.seat && m.kind != MatchKind.district)
      .take(limit)
      .toList();
}
