/// Seats, districts and the reserved seats: what /api/app/v1/seats, /seat,
/// /district and /reserved answer (see docs/app-api.md), parsed defensively
/// like lib/models.dart; and the parts of the bootstrap the shared model does
/// not carry (the district list, the resigned members, the upazilas' English
/// names and, on English answers, the Bangla names beside the English ones)
/// for the place search and the seat lists.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../i18n.dart';
import '../models.dart';
import '../search.dart';

String? _s(dynamic v) => v is String && v.isNotEmpty ? v : null;
int? _i(dynamic v) => v is num ? v.toInt() : null;
double? _d(dynamic v) => v is num ? v.toDouble() : null;
bool _b(dynamic v) => v == true;
List<Map<String, dynamic>> _maps(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];
MemberBrief? _brief(dynamic v) =>
    v is Map<String, dynamic> ? MemberBrief.fromJson(v) : null;

/// One seat, as /seats lists it and /seat/{slug} heads its answer with.
class SeatRow {
  final int no;
  final String slug;

  /// In the answer's language.
  final String? nameBn;

  /// The source's English, both languages.
  final String? nameEn;
  final bool reserved;
  final String? districtSlug;
  final String? districtBn;

  /// The member listed for the seat; one who resigned stays until it is
  /// filled (see [vacant]).
  final String? memberId;
  final bool vacant;
  final String? vacantSince;

  /// The Election Commission's description of the area; null on English when
  /// untranslated.
  final String? boundaryBn;
  final bool boundaryTranslated;

  /// English answers only: the Bangla seat and district names, for search.
  final String? nameAlt;
  final String? districtAlt;

  const SeatRow({
    required this.no,
    required this.slug,
    this.nameBn,
    this.nameEn,
    this.reserved = false,
    this.districtSlug,
    this.districtBn,
    this.memberId,
    this.vacant = false,
    this.vacantSince,
    this.boundaryBn,
    this.boundaryTranslated = false,
    this.nameAlt,
    this.districtAlt,
  });

  factory SeatRow.fromJson(Map<String, dynamic> j) => SeatRow(
    no: _i(j['no']) ?? 0,
    slug: j['slug'] as String? ?? '',
    nameBn: _s(j['nameBn']),
    nameEn: _s(j['nameEn']),
    reserved: _b(j['reserved']),
    districtSlug: _s(j['districtSlug']),
    districtBn: _s(j['districtBn']),
    memberId: _s(j['memberId']),
    vacant: _b(j['vacant']),
    vacantSince: _s(j['vacantSince']),
    boundaryBn: _s(j['boundaryBn']),
    boundaryTranslated: _b(j['boundaryTranslated']),
    nameAlt: _s(j['nameAlt']),
    districtAlt: _s(j['districtAlt']),
  );

  /// The seat's name on screen: the answer's language, else the source's.
  String get name => nameBn ?? nameEn ?? slug;
}

Future<List<SeatRow>> fetchSeats() async {
  final json = await Api.instance.getJson('/api/app/v1/seats');
  return _maps(json['seats']).map(SeatRow.fromJson).toList();
}

/// Someone who held a seat in an earlier parliament.
class SeatHolder {
  final int parliamentNo;
  final String labelBn;

  /// English: null when no English name is known.
  final String? nameBn;
  final String? nameEn;
  final String? partyAbbr;
  final String? partyBn;

  /// Set when the holder sits in this parliament.
  final MemberBrief? member;

  const SeatHolder({
    required this.parliamentNo,
    required this.labelBn,
    this.nameBn,
    this.nameEn,
    this.partyAbbr,
    this.partyBn,
    this.member,
  });

  factory SeatHolder.fromJson(Map<String, dynamic> j) => SeatHolder(
    parliamentNo: _i(j['parliamentNo']) ?? 0,
    labelBn: j['labelBn'] as String? ?? '',
    nameBn: _s(j['nameBn']),
    nameEn: _s(j['nameEn']),
    partyAbbr: _s(j['partyAbbr']),
    partyBn: _s(j['partyBn']),
    member: _brief(j['member']),
  );
}

/// One parliament's result for a seat.
class ElectionResult {
  final int parliamentNo;
  final String labelBn;

  /// Null when not published: the page then shows the candidates' total.
  final int? totalVotes;
  final double? turnout;
  final List<Candidate> candidates;
  final String? sourceUrl;
  final String? sourceBn;
  final String? noteBn;

  const ElectionResult({
    required this.parliamentNo,
    required this.labelBn,
    this.totalVotes,
    this.turnout,
    this.candidates = const [],
    this.sourceUrl,
    this.sourceBn,
    this.noteBn,
  });

  factory ElectionResult.fromJson(Map<String, dynamic> j) => ElectionResult(
    parliamentNo: _i(j['parliamentNo']) ?? 0,
    labelBn: j['labelBn'] as String? ?? '',
    totalVotes: _i(j['totalVotes']),
    turnout: _d(j['turnout']),
    candidates: _maps(j['candidates']).map(Candidate.fromJson).toList()
      ..sort((a, b) => b.votes.compareTo(a.votes)),
    sourceUrl: _s(j['sourceUrl']),
    sourceBn: _s(j['sourceBn']),
    noteBn: _s(j['noteBn']),
  );
}

/// Another seat of the same district.
class SeatLink {
  final int no;
  final String slug;
  final String? nameBn;
  final MemberBrief? member;

  /// /district only: no sitting member ([member] is then the one who resigned).
  final bool vacant;

  const SeatLink({
    required this.no,
    required this.slug,
    this.nameBn,
    this.member,
    this.vacant = false,
  });

  factory SeatLink.fromJson(Map<String, dynamic> j) => SeatLink(
    no: _i(j['no']) ?? 0,
    slug: j['slug'] as String? ?? '',
    nameBn: _s(j['nameBn']),
    member: _brief(j['member']),
    vacant: _b(j['vacant']),
  );

  String get name => nameBn ?? slug;
}

class SeatDetail {
  final SeatRow seat;

  /// The sitting member; null while vacant.
  final MemberBrief? member;

  /// While vacant: the member elected for the seat who resigned.
  final MemberBrief? resignedMember;
  final String? resignedOn;
  final List<SeatHolder> holders;

  /// Some holders are from before the 2008 redrawing of boundaries.
  final bool oldBoundary;
  final List<ElectionResult> results;
  final List<SeatLink> neighbours;

  const SeatDetail({
    required this.seat,
    this.member,
    this.resignedMember,
    this.resignedOn,
    this.holders = const [],
    this.oldBoundary = false,
    this.results = const [],
    this.neighbours = const [],
  });

  factory SeatDetail.fromJson(Map<String, dynamic> j) {
    final resigned = j['resignedMember'];
    return SeatDetail(
      seat: SeatRow.fromJson(
        (j['seat'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      member: _brief(j['member']),
      resignedMember: _brief(resigned),
      resignedOn: resigned is Map ? _s(resigned['resignedOn']) : null,
      holders: _maps(j['holders']).map(SeatHolder.fromJson).toList(),
      oldBoundary: _b(j['oldBoundary']),
      results: _maps(j['results']).map(ElectionResult.fromJson).toList(),
      neighbours: _maps(j['neighbours']).map(SeatLink.fromJson).toList(),
    );
  }
}

Future<SeatDetail> fetchSeat(String slug) async =>
    SeatDetail.fromJson(await Api.instance.getJson('/api/app/v1/seat/$slug'));

class DistrictParty {
  final String abbr;
  final String nameBn;
  final int seats;
  const DistrictParty({
    required this.abbr,
    required this.nameBn,
    required this.seats,
  });

  factory DistrictParty.fromJson(Map<String, dynamic> j) => DistrictParty(
    abbr: j['abbr'] as String? ?? '',
    nameBn: j['nameBn'] as String? ?? j['abbr'] as String? ?? '',
    seats: _i(j['seats']) ?? 0,
  );
}

class DistrictDetail {
  final String slug;
  final String nameBn;
  final String nameEn;
  final String introBn;
  final List<SeatLink> seats;
  final List<DistrictParty> parties;

  const DistrictDetail({
    required this.slug,
    required this.nameBn,
    required this.nameEn,
    required this.introBn,
    this.seats = const [],
    this.parties = const [],
  });

  factory DistrictDetail.fromJson(Map<String, dynamic> j) => DistrictDetail(
    slug: j['slug'] as String? ?? '',
    nameBn: j['nameBn'] as String? ?? j['nameEn'] as String? ?? '',
    nameEn: j['nameEn'] as String? ?? '',
    introBn: j['introBn'] as String? ?? '',
    seats: _maps(j['seats']).map(SeatLink.fromJson).toList(),
    parties: _maps(j['parties']).map(DistrictParty.fromJson).toList(),
  );
}

Future<DistrictDetail> fetchDistrict(String slug) async =>
    DistrictDetail.fromJson(
      await Api.instance.getJson('/api/app/v1/district/$slug'),
    );

class ReservedParty {
  final String abbr;
  final String slug;
  final String nameBn;
  final int held;
  const ReservedParty({
    required this.abbr,
    required this.slug,
    required this.nameBn,
    required this.held,
  });

  factory ReservedParty.fromJson(Map<String, dynamic> j) => ReservedParty(
    abbr: j['abbr'] as String? ?? '',
    slug: j['slug'] as String? ?? '',
    nameBn: j['nameBn'] as String? ?? j['abbr'] as String? ?? '',
    held: _i(j['held']) ?? 0,
  );
}

class ReservedData {
  final int total;
  final int filled;
  final int women;
  final int womenTerritorial;
  final List<ReservedParty> parties;
  final List<MemberBrief> members;
  final List<({String q, String a})> questions;
  final String? sourceBn;

  const ReservedData({
    required this.total,
    required this.filled,
    required this.women,
    required this.womenTerritorial,
    this.parties = const [],
    this.members = const [],
    this.questions = const [],
    this.sourceBn,
  });

  factory ReservedData.fromJson(Map<String, dynamic> j) {
    final members = _maps(j['members']).map(MemberBrief.fromJson).toList();
    return ReservedData(
      total: _i(j['total']) ?? 50,
      filled: _i(j['filled']) ?? members.length,
      women: _i(j['women']) ?? 0,
      womenTerritorial: _i(j['womenTerritorial']) ?? 0,
      parties: _maps(j['parties']).map(ReservedParty.fromJson).toList(),
      members: members,
      questions: [
        for (final q in _maps(j['questions']))
          if (_s(q['questionBn']) != null)
            (q: q['questionBn'] as String, a: q['answerBn'] as String? ?? ''),
      ],
      sourceBn: _s(j['sourceBn']),
    );
  }
}

Future<ReservedData> fetchReserved() async =>
    ReservedData.fromJson(await Api.instance.getJson('/api/app/v1/reserved'));

/// A district of the bootstrap's `districtList`, in seat order.
class DistrictEntry {
  final String slug;
  final String nameBn;
  final String nameEn;
  final int seats;
  const DistrictEntry({
    required this.slug,
    required this.nameBn,
    required this.nameEn,
    required this.seats,
  });

  factory DistrictEntry.fromJson(Map<String, dynamic> j) => DistrictEntry(
    slug: j['slug'] as String? ?? '',
    nameBn: j['nameBn'] as String? ?? '',
    nameEn: j['nameEn'] as String? ?? '',
    seats: _i(j['seats']) ?? 0,
  );
}

/// What the bootstrap carries beyond lib/models.dart's [Bootstrap]: read from
/// the copy the app keeps on the phone, so it costs no second download.
class Places {
  final String version;
  final Lang lang;
  final List<DistrictEntry> districts;

  /// Resigned members, with the day they resigned.
  final List<({MemberBrief member, String? resignedOn})> former;

  /// [English, Bangla] upazila names, for an English place search.
  final List<(String, String)> upazilaEn;

  /// English answers only: each member's Bangla name, seat and district, by
  /// member id, so a Bangla query still finds them.
  final Map<String, MemberAlt> alt;

  /// The territorial seats as the place finder reads them: Bangla seat,
  /// district and boundary, and the sitting member.
  final List<FinderSeat> finderSeats;

  const Places({
    required this.version,
    required this.lang,
    this.districts = const [],
    this.former = const [],
    this.upazilaEn = const [],
    this.alt = const {},
    this.finderSeats = const [],
  });

  factory Places.fromJson(Map<String, dynamic> j, Lang lang) {
    final alt = <String, MemberAlt>{};
    final seats = <int, FinderSeat>{};

    void add(Map<String, dynamic> raw, {required bool sitting}) {
      final m = MemberBrief.fromJson(raw);
      final a = MemberAlt(
        name: _s(raw['nameAlt']),
        seat: _s(raw['seatAlt']),
        district: _s(raw['districtAlt']),
      );
      if (a.name != null || a.seat != null || a.district != null) {
        alt[m.id] = a;
      }
      final no = m.seatNo;
      final slug = _s(raw['seatSlug']);
      if (m.reserved || no == null || slug == null) return;
      // A sitting member is the seat's; a resigned one only names a seat no
      // one holds now.
      if (!sitting && seats.containsKey(no)) return;
      final bnSeat = lang == Lang.en ? a.seat : m.seatBn;
      final bnDistrict = lang == Lang.en ? a.district : m.districtBn;
      seats[no] = FinderSeat(
        no: no,
        seat: bnSeat ?? m.seatBn ?? m.seatEn ?? '',
        seatEn: m.seatEn,
        slug: slug,
        district: bnDistrict ?? m.districtBn ?? '',
        districtEn: m.districtEn,
        boundary: m.areaBn,
        member: sitting ? m : null,
        seatLabel: m.seatBn ?? m.seatEn ?? '',
      );
    }

    for (final raw in _maps(j['members'])) {
      add(raw, sitting: true);
    }
    final former = <({MemberBrief member, String? resignedOn})>[];
    for (final raw in _maps(j['former'])) {
      add(raw, sitting: false);
      former.add((
        member: MemberBrief.fromJson(raw),
        resignedOn: _s(raw['resignedOn']),
      ));
    }

    return Places(
      version: j['version'] as String? ?? '',
      lang: lang,
      districts: _maps(j['districtList']).map(DistrictEntry.fromJson).toList(),
      former: former,
      upazilaEn: [
        if (j['upazilaEn'] is List)
          for (final p in j['upazilaEn'] as List)
            if (p is List && p.length >= 2 && p[0] is String && p[1] is String)
              (p[0] as String, p[1] as String),
      ],
      alt: alt,
      finderSeats: seats.values.toList()..sort((a, b) => a.no.compareTo(b.no)),
    );
  }

  static final _held = <Lang, Places>{};
  static final _loading = <Lang, Future<Places>>{};

  /// The places for the current language, once the member list is in hand.
  /// Read from the phone's stored copy of the bootstrap when its version is
  /// the list's; fetched only when it is not.
  static Future<Places> load() {
    final lang = appLang.value;
    final pending = _loading[lang];
    if (pending != null) return pending;
    final f = _load(lang);
    _loading[lang] = f;
    f.whenComplete(() => _loading.remove(lang)).ignore();
    return f;
  }

  static Future<Places> _load(Lang lang) async {
    final boot = await Api.instance.loadBootstrap();
    final held = _held[lang];
    if (held != null && held.version == boot.version) return held;
    Map<String, dynamic>? json;
    try {
      final prefs = await SharedPreferences.getInstance();
      // The key lib/api.dart keeps each language's bootstrap under.
      final saved = prefs.getString(
        lang == Lang.en ? 'bootstrap_v4_en' : 'bootstrap_v4',
      );
      if (saved != null) {
        final decoded = jsonDecode(saved);
        if (decoded is Map<String, dynamic> &&
            decoded['version'] == boot.version) {
          json = decoded;
        }
      }
    } catch (_) {}
    json ??= await Api.instance.getJson('/api/app/v1/bootstrap');
    // The answer's own language: a switch while it was fetched must not file
    // one language's names under the other.
    final places = Places.fromJson(
      json,
      json['lang'] == 'en' ? Lang.en : Lang.bn,
    );
    _held[places.lang] = places;
    return places;
  }

  /// For tests: forget what was read.
  static void reset() {
    _held.clear();
    _loading.clear();
  }
}

/// Every union and the city thanas, for the place search
/// (the site's /place-names.json, the same in both languages). The phone's
/// copy is in hand at once when there is one, so a union is found on a train
/// with no signal; a fresh list is fetched once a run and replaces it quietly.
class PlaceNamesStore {
  PlaceNamesStore._();

  static const _key = 'place_names_v1';

  /// The list in hand; null until the phone's copy or the first fetch
  /// arrives. Screens listen, and search again when it changes.
  static final names = ValueNotifier<PlaceNames?>(null);
  static bool _started = false;
  static DateTime? _failedAt;

  /// Starts reading, once a run: the phone's copy, then the network. A fetch
  /// that failed is tried again a minute later at the earliest.
  static void ensure() {
    final failed = _failedAt;
    if (_started &&
        (failed == null ||
            DateTime.now().difference(failed) < const Duration(minutes: 1))) {
      return;
    }
    _started = true;
    _failedAt = null;
    _load().ignore();
  }

  static Future<void> _load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null) {
        final decoded = jsonDecode(saved);
        if (decoded is Map<String, dynamic>) {
          names.value = PlaceNames.fromJson(decoded);
        }
      }
    } catch (_) {}
    try {
      final json = await Api.instance.getJson('/place-names.json');
      final fresh = PlaceNames.fromJson(json);
      if (fresh.unions.isEmpty) return;
      names.value = fresh;
      prefs ??= await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(json));
    } catch (_) {
      // No signal: the search by upazila and name works without it.
      _failedAt = DateTime.now();
    }
  }

  /// For tests: forget what was read.
  static void reset() {
    names.value = null;
    _started = false;
    _failedAt = null;
  }
}
