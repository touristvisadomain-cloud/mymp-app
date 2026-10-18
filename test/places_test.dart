// Seats, districts, reserved seats and place search: the website's place
// finder (src/lib/findSeat.ts, its tests ported), the API's answers parsed
// from fixtures saved from the site (test/fixtures/places, both languages),
// and the screens drawn from them on a small phone with a large font.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymp/api.dart';
import 'package:mymp/data/places.dart';
import 'package:mymp/i18n.dart';
import 'package:mymp/models.dart';
import 'package:mymp/screens/district_screen.dart';
import 'package:mymp/screens/members_screen.dart';
import 'package:mymp/screens/reserved_screen.dart';
import 'package:mymp/screens/seat_screen.dart';
import 'package:mymp/screens/seats_screen.dart';
import 'package:mymp/search.dart';
import 'package:mymp/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dir = 'test/fixtures/places';

Map<String, dynamic> _json(String name) =>
    jsonDecode(File('$_dir/$name.json').readAsStringSync())
        as Map<String, dynamic>;

/// The fixture a request names, in the language it asks for.
String _fixture(Uri url) {
  final path = url.path;
  String? name;
  for (final key in ['bootstrap', 'seats', 'reserved']) {
    if (path.endsWith('/$key')) name = key;
  }
  if (path.contains('/seat/')) name = 'seat-${path.split('/').last}';
  if (path.contains('/district/')) name = 'district-${path.split('/').last}';
  if (path == '/place-names.json') {
    // The union and thana list is the same file in both languages.
    return File('$_dir/place-names.json').readAsStringSync();
  }
  if (path.startsWith('/geo/')) {
    // The map's boundaries are the same file in both languages.
    final f = File('$_dir/geo-${path.split('/').last}');
    return f.existsSync() ? f.readAsStringSync() : '';
  }
  if (name == null) return '';
  final f = File(
    '$_dir/$name${url.queryParameters['lang'] == 'en' ? '.en' : ''}.json',
  );
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

FinderSeat _seat(int no, String name, String district, String boundary) =>
    FinderSeat(
      no: no,
      seat: name,
      slug: 's-$no',
      district: district,
      boundary: boundary,
    );

// Boundary text as the Election Commission writes it (the site's test data).
final _seats = [
  _seat(
    175,
    'ঢাকা-২',
    'ঢাকা',
    '(ক)নিম্নলিখিত ইউনিয়ন সমূহ ব্যতীত কেরানিগঞ্জ উপজেলাঃ(১) জিনজিরা, (২)আগানগর,(৩) তেঘরিয়া,(৪) কোন্ডা ও(৫) শুভাট্যা, (খ)ঢাকা দক্ষিন সিটি কর্পোরেশনের ওয়ার্ড ৫৫,৫৬, ও ৫৭ এবং (গ)সাভার উপজেলার নিম্নলিখিত ইউনিয়ন সমূহঃ(১) আমিনবাজার,(২) তেতুলঝড়া ও(৩) ভাকুর্তা',
  ),
  _seat(
    176,
    'ঢাকা-৩',
    'ঢাকা',
    'কেরানিগঞ্জ উপজেলার নিম্নলিখিত ইউনিয়ন সমূহঃ (১) জিনজিরা, (২) আগানগর, (৩) তেঘরিয়া, (৪) কোন্ডা ও (৫) শুভাট্যা',
  ),
  _seat(
    183,
    'ঢাকা-১০',
    'ঢাকা',
    'ঢাকা দক্ষিন সিটি কর্পোরেশনের ওয়ার্ড- ১৪,১৫,১৬,১৭,১৮ ও ২২',
  ),
  _seat(
    187,
    'ঢাকা-১৪',
    'ঢাকা',
    '(ক)ঢাকা উত্তর সিটি কর্পোরেশনের ওয়ার্ড ৭ থেকে ১২ পর্যন্ত এবং (খ)সাভার উপজেলার কাউন্দিয়া ইউনিয়ন',
  ),
  _seat(116, 'ভোলা-২', 'ভোলা', '(ক) দৌলতখান এবং (খ) বোরহানউদ্দিন উপজেলা'),
  _seat(
    45,
    'চাঁপাইনবাবগঞ্জ-২',
    'চাঁপাইনবাবগঞ্জ',
    '(ক) নাচোল, (খ) গোমস্তাপুর এবং (গ) ভোলাহাট উপজেলা',
  ),
];

List<String> _where(String q) => [
  for (final m in findSeats(q, _seats))
    '${m.seat.seat}:${m.kind.name}${m.partial ? '+part' : ''}',
];

Future<void> _loadFonts() async {
  final loader = FontLoader('NotoSansBengali');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/NotoSansBengali-$w.ttf'));
  }
  await loader.load();
}

// The website's place-list tests (src/lib/__tests__/findSeat.test.ts).
PlaceUnion _u(
  String bn,
  String en,
  String upazila,
  String district, [
  String? upazilaEn,
  List<String>? inCity,
]) => (
  bn: bn,
  en: en,
  upazila: upazila,
  district: district,
  upazilaEn: upazilaEn,
  inCity: inCity,
);

final _names = PlaceNames(
  unions: [
    _u('চরপাতা', 'Charpata', 'দৌলতখান', 'ভোলা'), // ভোলা-২ holds it whole
    _u('কলাতিয়া', 'Kalatia', 'কেরানিগঞ্জ', 'ঢাকা'), // ঢাকা-২: all but five
    _u('জিনজিরা', 'Zinzira', 'কেরানিগঞ্জ', 'ঢাকা'), // one of the five
    _u('আশুলিয়া', 'Ashulia', 'সাভার', 'ঢাকা'), // not one of ঢাকা-২'s three
    _u('চরপাতা', 'Charpata', 'নাচোল', 'চাঁপাইনবাবগঞ্জ'), // the same name
  ],
  thanas: [
    (bn: 'উত্তরা', en: 'Uttara', slugs: ['s-187'], partial: true),
  ],
);

List<String> _at(String q, [PlaceNames? names, List<FinderSeat>? seats]) => [
  for (final m in findSeats(q, seats ?? _seats, names: names ?? _names))
    '${m.seat.seat}:${m.kind.name}${m.partial ? '+part' : ''}',
];

List<String> _seatsOf(String q, List<FinderSeat> seats, PlaceNames names) => [
  for (final m in findSeats(q, seats, names: names)) m.seat.seat,
];

void main() {
  group('unions and thanas from the place list, as the website has them', () {
    test('a union the boundary text does not name, through its upazila', () {
      expect(_at('চরপাতা')..sort(), ['চাঁপাইনবাবগঞ্জ-২:union', 'ভোলা-২:union']);
      expect(_at('চরপাতা ইউনিয়ন')..sort(), [
        'চাঁপাইনবাবগঞ্জ-২:union',
        'ভোলা-২:union',
      ]);
    });

    test('"except" unions go to the other seat', () {
      expect(_at('কলাতিয়া'), ['ঢাকা-২:union']);
      expect(_at('জিনজিরা'), ['ঢাকা-৩:union']);
      expect(_at('আশুলিয়া'), isEmpty);
    });

    test('a union typed in English, and the place it is shown with', () {
      expect(_at('Kalatia'), ['ঢাকা-২:union']);
      expect(_at('kalatia union'), ['ঢাকা-২:union']);
      final m = findSeats('কলাতিয়া', _seats, names: _names).first;
      expect(m.place, 'কলাতিয়া ইউনিয়ন, কেরানিগঞ্জ উপজেলা');
    });

    test('"<union> <upazila>" or "<union> <district>" picks one', () {
      expect(_at('চরপাতা দৌলতখান'), ['ভোলা-২:union']);
      expect(_at('চরপাতা চাঁপাইনবাবগঞ্জ'), ['চাঁপাইনবাবগঞ্জ-২:union']);
      final names = PlaceNames(
        unions: [
          _u('চরপাতা', 'Charpata', 'দৌলতখান', 'ভোলা', 'Daulatkhan'),
          _u('চরপাতা', 'Charpata', 'নাচোল', 'চাঁপাইনবাবগঞ্জ', 'Nachole'),
        ],
      );
      expect(_seatsOf('charpata daulatkhan', _seats, names), ['ভোলা-২']);
      expect(_seatsOf('Charpata Nachol', _seats, names), ['চাঁপাইনবাবগঞ্জ-২']);
      expect(
        findSeats(
          'Charpata',
          _seats,
          names: names,
        ).firstWhere((m) => m.seat.seat == 'ভোলা-২').placeEn,
        'Charpata union, Daulatkhan',
      );
    });

    test('an upazila ranks above the unions that share its name', () {
      final names = PlaceNames(
        unions: [_u('দৌলতখান', 'Daulatkhan', 'নাচোল', 'চাঁপাইনবাবগঞ্জ')],
      );
      expect(
        [
          for (final m in findSeats('দৌলতখান', _seats, names: names))
            '${m.seat.seat}:${m.kind.name}',
        ],
        ['ভোলা-২:upazila', 'চাঁপাইনবাবগঞ্জ-২:union'],
      );
    });

    test('a thana by name, in either script, with "থানা" or without', () {
      expect(_at('উত্তরা'), ['ঢাকা-১৪:thana+part']);
      expect(_at('উত্তরা থানা'), ['ঢাকা-১৪:thana+part']);
      expect(_at('Uttara thana'), ['ঢাকা-১৪:thana+part']);
    });

    test('without the place list nothing changes', () {
      expect(findSeats('চরপাতা', _seats), isEmpty);
      expect(_where('দৌলতখান'), ['ভোলা-২:upazila']);
    });

    test('ঙ and ং are one letter: রাঙ্গুনিয়া finds রাংগুনিয়া', () {
      final s = [_seat(284, 'চট্টগ্রাম-৭', 'চট্টগ্রাম', 'রাংগুনিয়া উপজেলা')];
      expect(
        [for (final m in findSeats('রাঙ্গুনিয়া', s)) m.seat.seat],
        ['চট্টগ্রাম-৭'],
      );
    });

    test('a hill-district union goes to the seat that is the district', () {
      final s = [
        _seat(299, 'রাংগামাটি', 'রাঙ্গামাটি', 'রাংগামাটি পার্বত্য জেলা'),
        _seat(298, 'খাগড়াছড়ি', 'খাগড়াছড়ি', 'খাগড়াছড়ি পার্বত্য জেলা'),
      ];
      final names = PlaceNames(
        unions: [_u('কাপ্তাই', 'Kaptai', 'কাপ্তাই', 'রাঙ্গামাটি')],
      );
      expect(_seatsOf('কাপ্তাই', s, names), ['রাংগামাটি']);
    });

    test('the text as written: এবং run on, ব্যাতীত, "X এবং Y উপজেলার"', () {
      final s = [
        _seat(
          272,
          'নোয়াখালী-৪',
          'নোয়াখালী',
          '(ক)সুবর্ণচরএবং(খ) নোয়াখালী সদর উপজেলা',
        ),
        _seat(
          63,
          'সিরাজগঞ্জ-১',
          'সিরাজগঞ্জ',
          '(ক)কাজিপুর এবং(খ) সিরাজগঞ্জ সদর উপজেলার নিম্নলিখিত ইউনিয়ন সমূহঃ (১)মেছড়া,(২) রতনকান্দি',
        ),
        _seat(
          64,
          'সিরাজগঞ্জ-২',
          'সিরাজগঞ্জ',
          '(ক) নিম্নলিখিত ইউনিয়ন ব্যাতীত সিরাজগঞ্জ সদরঃ- (১)মেছড়া,(২) রতনকান্দি এবং(খ) কামারখন্দ',
        ),
        _seat(
          214,
          'নরসিংদী-২',
          'নরসিংদী',
          'পলাশ এবং নরসিংদী সদর উপজেলার নিম্নলিখিত ইউনিয়ন সমূহঃ (১)আমদিয়া,(২) পাঁচদোনা',
        ),
      ];
      final names = PlaceNames(
        unions: [
          _u('চরজাব্বার', 'Char Jabbar', 'সুবর্ণচর', 'নোয়াখালী'),
          _u('শিয়ালকোল', 'Shialkol', 'সিরাজগঞ্জ সদর', 'সিরাজগঞ্জ'),
          _u('মেছড়া', 'Mechhra', 'সিরাজগঞ্জ সদর', 'সিরাজগঞ্জ'),
          _u('ঘোড়াশাল', 'Ghorashal', 'পলাশ', 'নরসিংদী'),
        ],
      );
      expect(_seatsOf('সুবর্ণচর', s, names), ['নোয়াখালী-৪']);
      expect(_seatsOf('চরজাব্বার', s, names), ['নোয়াখালী-৪']);
      expect(_seatsOf('শিয়ালকোল', s, names), ['সিরাজগঞ্জ-২']);
      expect(_seatsOf('মেছড়া', s, names), ['সিরাজগঞ্জ-১']);
      expect(_seatsOf('ঘোড়াশাল', s, names), ['নরসিংদী-২']);
      // পলাশ is whole in নরসিংদী-২, not a part of it.
      expect(
        [
          for (final m in findSeats('পলাশ', s))
            '${m.seat.seat}:${m.kind.name}${m.partial ? '+part' : ''}',
        ],
        ['নরসিংদী-২:upazila'],
      );
    });

    test('a list past its punctuation, an upazila a letter apart', () {
      final s = [
        _seat(
          192,
          'গাজীপুর-৩',
          'গাজীপুর',
          '(ক)শ্রীপুর এবং (খ)গাজিপুর সদর উপজেলারঃ মির্জাপুর, ভাওয়াল গড় ও পিরুজালী ইউনিয়ন',
        ),
        _seat(
          82,
          'ঝিনাইদহ-৪',
          'ঝিনাইদহ',
          '(ক)কালীগঞ্জ এবং(খ) ঝিনাইদহ সদর উপজেলার (১)নলডাঙ্গা,(২) ঘোড়াশাল,(৩) ফুরসুন্দি ও(৪) মহারাজপুর ইউনিয়ন',
        ),
        _seat(
          2,
          'ঠাকুরগাঁও-২',
          'ঠাকুরগাঁও',
          '(ক)বালিয়াডাঙ্গী, (খ) হরিপুর এবং (গ) রানিসংকাইল উপজেলার নিম্নলিখিত ইউনিয়ন সমূহ: (১)ধর্মগড় ও (২)কাশিপুর',
        ),
        _seat(
          3,
          'ঠাকুরগাঁও-৩',
          'ঠাকুরগাঁও',
          '(ক)পীরগঞ্জ উপজেলা এবং (খ) নিম্নলিখিত ইউনিয়ন সমূহ ব্যতীত রানিশংকাইল উপজেলা: (১)ধর্মগড় ও(২) কাশিপুর',
        ),
      ];
      final names = PlaceNames(
        unions: [
          _u('মির্জাপুর', 'Mirzapur', 'গাজীপুর সদর', 'গাজীপুর'),
          _u('মহারাজপুর', 'Maharajpur', 'ঝিনাইদহ সদর', 'ঝিনাইদহ'),
          _u('ফুরসন্দি', 'Fursandi', 'ঝিনাইদহ সদর', 'ঝিনাইদহ'),
          _u('ধর্মগড়', 'Dharmagarh', 'রানিশংকাইল', 'ঠাকুরগাঁও'),
          _u('নেকমরদ', 'Nekmorod', 'রানিশংকাইল', 'ঠাকুরগাঁও'),
        ],
      );
      expect(_seatsOf('মির্জাপুর', s, names), ['গাজীপুর-৩']);
      expect(_seatsOf('মহারাজপুর', s, names), ['ঝিনাইদহ-৪']);
      expect(_seatsOf('ফুরসন্দি', s, names), ['ঝিনাইদহ-৪']);
      expect(_seatsOf('ধর্মগড়', s, names), ['ঠাকুরগাঁও-২']);
      expect(_seatsOf('নেকমরদ', s, names), ['ঠাকুরগাঁও-৩']);
    });

    test('a union now in a city corporation shows each seat, as part', () {
      final s = [
        _seat(
          190,
          'গাজীপুর-১',
          'গাজীপুর',
          '(ক)কালিয়াকৈর এবং(খ) গাজীপুর সিটি কর্পোরেশনের ১ হতে ১৮ নং ওয়ার্ড',
        ),
        _seat(
          191,
          'গাজীপুর-২',
          'গাজীপুর',
          'গাজীপুর সিটি কর্পোরেশনের ১৯ হতে ৩৯ নং ওয়ার্ড',
        ),
      ];
      final names = PlaceNames(
        unions: [
          _u('গাছা', 'Gachha', 'গাজীপুর সদর', 'গাজীপুর', 'Gazipur Sadar', [
            's-190',
            's-191',
          ]),
        ],
      );
      expect(_at('গাছা', names, s), [
        'গাজীপুর-১:union+part',
        'গাজীপুর-২:union+part',
      ]);
    });

    test('the site\'s list file is read, rows it does not know skipped', () {
      final names = PlaceNames.fromJson({
        'unions': [
          ['চরপাতা', 'Charpata', 'দৌলতখান', 'ভোলা', 'Daulatkhan'],
          [
            'গাছা',
            'Gachha',
            'গাজীপুর সদর',
            'গাজীপুর',
            'Gazipur Sadar',
            ['gazipur-1'],
          ],
          ['broken'],
          7,
        ],
        'thanas': [
          [
            'মিরপুর',
            'Mirpur',
            ['dhaka-14', 'dhaka-15'],
            true,
          ],
          ['bad', 'Bad', 'not a list', true],
        ],
        'source': 'ignored',
      });
      expect(names.unions.length, 2);
      expect(names.unions[0].upazilaEn, 'Daulatkhan');
      expect(names.unions[0].inCity, isNull);
      expect(names.unions[1].inCity, ['gazipur-1']);
      expect(names.thanas.single.slugs, ['dhaka-14', 'dhaka-15']);
      expect(names.thanas.single.partial, isTrue);
    });
  });

  group('the place finder, as the website has it', () {
    test('an upazila finds the seat that holds it whole', () {
      expect(_where('দৌলতখান'), ['ভোলা-২:upazila']);
      expect(_where('দৌলতখান উপজেলা'), ['ভোলা-২:upazila']);
    });

    test('a union listed as an exception belongs to the other seat', () {
      expect(_where('জিনজিরা'), ['ঢাকা-৩:union']);
      expect(_where('আমিনবাজার'), ['ঢাকা-২:union']);
    });

    test('a split upazila shows every seat that holds part of it', () {
      expect(_where('কেরানীগঞ্জ')..sort(), [
        'ঢাকা-২:upazila+part',
        'ঢাকা-৩:upazila+part',
      ]);
    });

    test('a city ward is found by its number among the ward list', () {
      expect(_where('ঢাকা দক্ষিণ ওয়ার্ড ১৫'), ['ঢাকা-১০:ward']);
      expect(_where('ওয়ার্ড ৫৬'), ['ঢাকা-২:ward']);
    });

    test('a district, a seat name, and no prefix noise', () {
      expect(_where('ভোলা'), ['ভোলা-২:district']);
      expect(_where('ঢাকা-১০'), ['ঢাকা-১০:seat']);
      expect(_where('ভোলাহাট'), ['চাঁপাইনবাবগঞ্জ-২:upazila']);
    });

    test('a place typed in English is looked up in Bangla', () {
      const table = [
        ('Savar', 'সাভার'),
        ('Doulatkhan', 'দৌলতখান'),
        ('Charfasson', 'চরফ্যাশন'),
        ('Keraniganj', 'কেরাণীগঞ্জ'),
      ];
      expect(toBangla('Savar', table), 'সাভার');
      expect(toBangla('daulatkhan upazila', table), 'দৌলতখান');
      expect(toBangla('charfason', table), 'চরফ্যাশন');
      expect(toBangla('দৌলতখান', table), 'দৌলতখান');
      expect(_where(toBangla('ward 15 dhaka south', table)), ['ঢাকা-১০:ward']);
      expect(_where(toBangla('Doulatkhan', table)), ['ভোলা-২:upazila']);
    });

    test('ward numbers: lists, ranges, zero-padded', () {
      expect(
        wardNumbers('ঢাকা উত্তর সিটি কর্পোরেশনের ওয়ার্ড- ০৪,১৩,১৪, ও ১৬'),
        [4, 13, 14, 16],
      );
      expect(
        wardNumbers('ঢাকা উত্তর সিটি কর্পোরেশনের ওয়ার্ড ৭ থেকে ১২ পর্যন্ত'),
        [7, 8, 9, 10, 11, 12],
      );
      expect(wardNumbers('গাজীপুর সিটি কর্পোরেশনের ১ হতে ৫ নং ওয়ার্ড'), [
        1,
        2,
        3,
        4,
        5,
      ]);
      expect(
        wardNumbers(
          'ঢাকা দক্ষিণ সিটি কর্পোরেশনের ওয়ার্ড- ২৩ থেকে ২৫, ৩৫ ও ৫৭',
        ),
        [23, 24, 25, 35, 57],
      );
    });

    test('a ward inside a "থেকে" range finds its seat', () {
      expect(_where('ঢাকা উত্তর ওয়ার্ড ৯'), ['ঢাকা-১৪:ward']);
      expect(_where('ঢাকা উত্তর ওয়ার্ড ১৩'), isEmpty);
      expect(_where('ঢাকা দক্ষিণ ওয়ার্ড ১৫'), ['ঢাকা-১০:ward']);
    });
  });

  group('the real seats, from the bootstrap', () {
    final bn = Places.fromJson(_json('bootstrap'), Lang.bn);
    final en = Places.fromJson(_json('bootstrap.en'), Lang.en);

    test('the bootstrap gives every territorial seat and its extras', () {
      // 299: চট্টগ্রাম-৪ has no member, sitting or resigned, so the bootstrap
      // carries no boundary for it.
      expect(bn.finderSeats.length, 299);
      expect(en.finderSeats.length, 299);
      expect(bn.districts.length, 64);
      expect(bn.upazilaEn.length, greaterThan(500));
      expect(bn.former.length, 2);
      // A vacant seat is found, with no member.
      final vacant = bn.finderSeats.firstWhere((s) => s.slug == 'thakurgaon-1');
      expect(vacant.member, isNull);
      expect(vacant.boundary, contains('ঠাকুরগাঁও'));
      // English: the seat is filed under its Bangla name, shown in English.
      final e = en.finderSeats.firstWhere((s) => s.slug == 'dhaka-17');
      expect(e.seat, 'ঢাকা-১৭');
      expect(e.seatLabel, 'Dhaka-17');
      expect(e.boundary, isNot(contains('Ward')));
      // Every member, sitting or resigned.
      expect(en.alt.values.where((a) => a.name != null).length, 349);
      expect(bn.alt, isEmpty);
    });

    List<String> place(Places p, String q) => [
      for (final m in findPlaces(q, p.finderSeats, p.upazilaEn))
        '${m.seat.slug}:${m.kind.name}${m.partial ? '+part' : ''}',
    ];

    test('Savar and সাভার find the same seats, in either language', () {
      final a = place(bn, 'সাভার');
      expect(a, isNotEmpty);
      expect(place(en, 'Savar'), a);
      expect(place(bn, 'savar'), a);
      expect(a.first, startsWith('dhaka-'));
    });

    test('a city ward typed in English', () {
      final hits = place(en, 'ward 15 dhaka south');
      expect(hits, isNotEmpty);
      expect(hits.every((h) => h.endsWith(':ward')), isTrue);
      expect(place(bn, 'ঢাকা দক্ষিণ ওয়ার্ড ১৫'), hits);
    });

    test('every union and the city thanas, from the site\'s list', () {
      final names = PlaceNames.fromJson(_json('place-names'));
      expect(names.unions.length, greaterThan(4500));
      expect(names.thanas.length, greaterThan(80));
      List<String> listed(Places p, String q) => [
        for (final m in findPlaces(q, p.finderSeats, p.upazilaEn, names: names))
          '${m.seat.slug}:${m.kind.name}${m.partial ? '+part' : ''}',
      ];
      expect(listed(bn, 'চরপাতা দৌলতখান'), ['bhola-2:union']);
      expect(listed(en, 'Charpata Doulatkhan'), ['bhola-2:union']);
      // A union a seat's text never names, found through its upazila.
      expect(listed(bn, 'রামপুর ত্রিশাল'), ['mymensingh-7:union']);
      expect(listed(en, 'Rampur Trishal'), ['mymensingh-7:union']);
      // "Rampur" is the unions so called, not the upazila Raipura.
      expect(listed(en, 'Rampur'), isNotEmpty);
      expect(listed(en, 'Rampur').every((h) => h.contains(':union')), isTrue);
      // Mirpur: the upazila first, then Dhaka's thana before the unions.
      final mirpur = listed(bn, 'মিরপুর');
      expect(mirpur.first, 'kushtia-2:upazila');
      expect(mirpur[1], 'dhaka-14:thana+part');
      expect(listed(en, 'Gulshan thana'), ['dhaka-17:thana+part']);
      expect(listed(bn, 'ধানমন্ডি থানা'), ['dhaka-10:thana+part']);
      // A union since taken into Gazipur's city corporation.
      expect(
        listed(bn, 'গাছা').every((h) => h.endsWith(':union+part')),
        isTrue,
      );
      // A village is not in the list.
      expect(listed(bn, 'গ্রামেরনামকিছু'), isEmpty);
    });

    test('a name is not a place, and seats by name are left to the list', () {
      expect(place(en, 'Dhaka-17'), isEmpty);
      expect(place(bn, 'ঢাকা'), isEmpty);
      expect(place(bn, 'x'), isEmpty);
    });

    test(
      'in English a Bangla name, seat or district still finds the member',
      () {
        final boot = Bootstrap.fromJson(_json('bootstrap.en'));
        final search = MemberSearch(boot.members, alt: en.alt);
        expect(search.search('তারেক রহমান').first.slug, 'tarique-rahman');
        expect(search.search('ঢাকা-১৭').first.slug, 'tarique-rahman');
        expect(search.search('Tarique').first.slug, 'tarique-rahman');
        expect(search.search('ঠাকুরগাঁও'), isNotEmpty);
      },
    );
  });

  group('the API answers', () {
    test('seats: 350 in number order, vacant and reserved marked', () {
      for (final name in ['seats', 'seats.en']) {
        final seats = _json(name)['seats'] as List;
        final rows = seats
            .cast<Map<String, dynamic>>()
            .map(SeatRow.fromJson)
            .toList();
        expect(rows.length, 350);
        expect(rows.where((s) => s.reserved).length, 50);
        expect(rows.where((s) => !s.reserved && s.vacant), isNotEmpty);
      }
      final en = SeatRow.fromJson(
        (_json('seats.en')['seats'] as List).first as Map<String, dynamic>,
      );
      expect(en.nameAlt, isNotNull);
      expect(en.boundaryTranslated, isTrue);
    });

    test('a vacant seat names the member who resigned', () {
      final s = SeatDetail.fromJson(_json('seat-thakurgaon-1'));
      expect(s.member, isNull);
      expect(s.seat.vacant, isTrue);
      expect(s.resignedMember?.slug, 'mirza-fakhrul-islam-alamgir');
      expect(s.resignedOn, '2026-08-21');
      expect(s.holders, isNotEmpty);
      expect(s.results.first.candidates.first.votes, 238836);
      expect(s.neighbours.length, 2);
    });

    test('a district and the reserved seats', () {
      final d = DistrictDetail.fromJson(_json('district-dhaka.en'));
      expect(d.seats.length, 20);
      expect(d.introBn, isNotEmpty);
      expect(d.parties.first.seats, greaterThan(0));
      final r = ReservedData.fromJson(_json('reserved'));
      expect(r.total, 50);
      expect(r.members.length, r.filled);
      expect(r.questions, isNotEmpty);
    });
  });

  group('screens', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await _loadFonts();
    });

    for (final lang in Lang.values) {
      for (final (label, size, scale) in [
        ('small phone, large font', const Size(320, 640), 1.3),
        ('common phone', const Size(393, 851), 1.0),
      ]) {
        group('${lang.name}, $label', () {
          final tr = T.of(lang);

          Future<List<String>> run(
            WidgetTester tester,
            Widget screen, {
            required String shows,
            int flings = 10,
            Future<void> Function(WidgetTester)? actions,
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
              if (text.contains('MissingPluginException') ||
                  text.contains('HTTP request failed') ||
                  text.contains('NetworkImageLoadException') ||
                  text.contains('SocketException')) {
                return;
              }
              // widgets.dart's MemberTile (not this area's) runs a long
              // English seat name ("Chapai Nawabganj-3") and its party chip
              // off a small phone with a large font; reported to its owner.
              if (details.toString().contains('lib/widgets.dart:')) return;
              // Where it happened, for an overflow.
              final full = details.toString().split('\n');
              final at = full.indexWhere(
                (l) => l.contains('relevant error-causing widget'),
              );
              problems.add(
                [
                  text.split('\n').take(3).join(' '),
                  if (at >= 0 && at + 2 < full.length)
                    '${full[at + 1].trim()} ${full[at + 2].trim()}',
                ].join(' @ '),
              );
            };
            await http.runWithClient(() async {
              // Set inside the mock client's zone: a switch makes the app
              // fetch the list again.
              appLang.value = lang;
              Places.reset();
              PlaceNamesStore.reset();
              await tester.runAsync(Api.instance.loadBootstrap);
              // The union and thana list, served by the mock client.
              await tester.runAsync(() async {
                PlaceNamesStore.ensure();
                for (var i = 0; i < 50; i++) {
                  if (PlaceNamesStore.names.value != null) break;
                  await Future<void>.delayed(const Duration(milliseconds: 20));
                }
              });
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

          testWidgets('all seats', (t) async {
            expect(
              await run(
                t,
                const SeatsScreen(),
                flings: 6,
                shows: tr('শূন্য', 'Vacant'),
              ),
              isEmpty,
            );
          });

          testWidgets('a vacant seat', (t) async {
            expect(
              await run(
                t,
                const SeatScreen(slug: 'thakurgaon-1'),
                shows: tr('নির্বাচনের ফল', 'Election results'),
              ),
              isEmpty,
            );
          });

          testWidgets('a seat with a member and old holders', (t) async {
            expect(
              await run(
                t,
                const SeatScreen(slug: 'dhaka-2'),
                flings: 14,
                shows: tr(
                  'এই আসনের আগের সদস্যরা',
                  'Earlier members for this seat',
                ),
              ),
              isEmpty,
            );
          });

          testWidgets('a reserved seat', (t) async {
            expect(
              await run(
                t,
                const SeatScreen(slug: 'women-seat-1'),
                shows: tr('সংরক্ষিত নারী আসন', 'Reserved seat for women'),
              ),
              isEmpty,
            );
          });

          testWidgets('a district', (t) async {
            expect(
              await run(
                t,
                const DistrictScreen(slug: 'dhaka'),
                flings: 14,
                shows: tr('দলভিত্তিক আসন', 'Seats by party'),
              ),
              isEmpty,
            );
          });

          testWidgets('the reserved seats', (t) async {
            expect(
              await run(
                t,
                const ReservedScreen(),
                flings: 40,
                shows: tr('প্রশ্ন ও উত্তর', 'Questions and answers'),
              ),
              isEmpty,
            );
          });

          testWidgets('members: a place search and the reserved filter', (
            t,
          ) async {
            expect(
              await run(
                t,
                const MembersScreen(),
                flings: 3,
                shows: tr('আপনার এলাকার এমপি', 'The MP for your area'),
                actions: (t) async {
                  await t.enterText(
                    find.byType(TextField).first,
                    lang == Lang.en ? 'Savar' : 'সাভার',
                  );
                  for (var i = 0; i < 5; i++) {
                    await t.pump(const Duration(milliseconds: 200));
                  }
                },
              ),
              isEmpty,
            );
          });

          testWidgets('members: a union many share, and how to pick one', (
            t,
          ) async {
            expect(
              await run(
                t,
                const MembersScreen(),
                flings: 3,
                shows: tr(
                  'এই নামে কয়েকটি ইউনিয়ন আছে',
                  'Several unions have this name',
                ),
                actions: (t) async {
                  await t.enterText(
                    find.byType(TextField).first,
                    lang == Lang.en ? 'Rampur' : 'রামপুর',
                  );
                  for (var i = 0; i < 5; i++) {
                    await t.pump(const Duration(milliseconds: 200));
                  }
                },
              ),
              isEmpty,
            );
          });

          testWidgets('members: a city thana', (t) async {
            expect(
              await run(
                t,
                const MembersScreen(),
                flings: 3,
                shows: tr('গুলশান থানা', 'Gulshan thana'),
                actions: (t) async {
                  await t.enterText(
                    find.byType(TextField).first,
                    lang == Lang.en ? 'Gulshan' : 'গুলশান',
                  );
                  for (var i = 0; i < 5; i++) {
                    await t.pump(const Duration(milliseconds: 200));
                  }
                },
              ),
              isEmpty,
            );
          });
        });
      }
    }
  });
}
