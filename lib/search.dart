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
/// that excludes it.
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

enum MatchKind { seat, district, upazila, union, ward, place }

class SeatMatch {
  final FinderSeat seat;
  final MatchKind kind;

  /// The clause of the boundary text that matched, as written.
  final String? clause;

  /// True when the seat holds only part of the place (some unions, or all
  /// but some).
  final bool partial;
  final int score;
  const SeatMatch(this.seat, this.kind, this.clause, this.partial, this.score);
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
    // লক্ষ্মীপুর is written লক্ষীপুর in the boundary text.
    _foldBangla(_nfcBn(s).replaceAll('ক্ষ্ম', 'ক্ষ'))
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

_Clause _clause(String text) {
  final isWard = _placeWords(text).any(_wardWords.contains);
  if (text.contains('ব্যতীত')) {
    // "নিম্নলিখিত ইউনিয়ন সমূহ ব্যতীত কেরানিগঞ্জ উপজেলাঃ(১) জিনজিরা, …"
    final p = _split2(text);
    final upazila = p[0].replaceFirst(RegExp('.*ব্যতীত'), '');
    return _Clause(
      text,
      [upazila],
      [p.length > 1 ? p[1] : ''],
      MatchKind.upazila,
      true,
    );
  }
  if (text.contains('নিম্নলিখিত')) {
    // "সাভার উপজেলার নিম্নলিখিত ইউনিয়ন সমূহঃ (১) আমিনবাজার, …": only these
    // unions.
    final p = _split2(text);
    return _Clause(
      text,
      [p[0], p.length > 1 ? p[1] : ''],
      const [],
      MatchKind.union,
      true,
    );
  }
  // "সাভার উপজেলার কাউন্দিয়া ইউনিয়ন": named unions of an upazila, without
  // the word নিম্নলিখিত.
  final genitive = text.indexOf('উপজেলার');
  if (genitive > 0 &&
      placeFold(text.substring(genitive)).contains(placeFold('ইউনিয়ন'))) {
    return _Clause(
      text,
      [text.substring(0, genitive), text.substring(genitive)],
      const [],
      MatchKind.union,
      true,
    );
  }
  return _Clause(
    text,
    [text],
    const [],
    isWard ? MatchKind.ward : MatchKind.upazila,
    false,
  );
}

/// "(ক) …, (খ) …" into its clauses; a boundary with no markers is one clause.
List<_Clause> _clausesOf(String boundary) => boundary
    .split(_clauseMark)
    .map((p) => p.trim().replaceAll(_clauseEdge, ''))
    .where((p) => p.isNotEmpty)
    .map(_clause)
    .toList();

const _rank = {
  MatchKind.seat: 100,
  MatchKind.district: 80,
  MatchKind.union: 70,
  MatchKind.ward: 65,
  MatchKind.upazila: 60,
  MatchKind.place: 40,
};

/// Seats that hold the place the person typed (in Bangla; see [toBangla]),
/// best first. A seat that holds the place whole ranks above one that holds
/// a part of it.
List<SeatMatch> findSeats(
  String query,
  List<FinderSeat> seats, {
  int limit = 12,
}) {
  // Whole words first; a half-typed last word only when nothing matches whole.
  final exact = _searchSeats(query, seats, limit, false);
  return exact.isNotEmpty ? exact : _searchSeats(query, seats, limit, true);
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
/// union or a city ward. Seats and districts by name are left to
/// [MemberSearch], as the website leaves them to its own index.
List<SeatMatch> findPlaces(
  String query,
  List<FinderSeat> seats,
  List<(String, String)> upazilaEn, {
  int limit = 6,
}) {
  final q = query.trim();
  if (q.length < 2) return const [];
  return findSeats(toBangla(q, upazilaEn), seats, limit: limit)
      .where((m) => m.kind != MatchKind.seat && m.kind != MatchKind.district)
      .toList();
}
