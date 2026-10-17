/// The 2026 election and the House it produced (/api/app/v1/election), as the
/// website's নির্বাচন (/nirbachon) and পরিসংখ্যান (/parisonkhan) pages show
/// them, and the outlines the election map draws (/geo/overview.json and
/// `/geo/<district>.json`, the same files the website's map reads).
///
/// Every shape parses defensively, like lib/models.dart: a field the site adds
/// later, or one that comes back null, must never crash a phone. The text
/// fields are `…Bn` on the wire and hold English on an English answer (null
/// where there is no English); here they are named for what they are.
library;

import 'dart:ui' show Color, Offset;

import '../api.dart';
import '../i18n.dart';
import '../models.dart';

String? _s(dynamic v) => v is String && v.trim().isNotEmpty ? v : null;
int? _i(dynamic v) => v is num ? v.toInt() : null;
double? _d(dynamic v) => v is num ? v.toDouble() : null;
List<Map<String, dynamic>> _maps(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];
Map<String, dynamic> _map(dynamic v) =>
    v is Map<String, dynamic> ? v : const {};
MemberBrief? _brief(dynamic v) {
  if (v is! Map<String, dynamic>) return null;
  final m = MemberBrief.fromJson(v);
  return m.slug.isEmpty ? null : m;
}

/* ---------------- colours ---------------- */

/// The website's party colours (src/lib/data.ts partyColor): BNP, Jamaat,
/// independents and NCP have their own, every other party shares one.
/// (AppColors.party keys Jamaat as "Jamaat", which the API never sends.)
Color partyColour(String? abbr) => switch (abbr) {
  'BNP' => const Color(0xFF1F7A4F),
  'BJEI' => const Color(0xFF8CBF2A),
  'Ind' => const Color(0xFF5B6FB5),
  'NCP' => const Color(0xFFE0641F),
  _ => const Color(0xFF9A5FC7),
};

/// The grey the website gives men in its men/women bars.
const menColour = Color(0xFFB9B4A6);

/* ---------------- /election ---------------- */

class ElectionDates {
  final String? election, gazette, oath, end;
  const ElectionDates({this.election, this.gazette, this.oath, this.end});
  factory ElectionDates.fromJson(dynamic v) {
    final j = _map(v);
    return ElectionDates(
      election: _s(j['election']),
      gazette: _s(j['gazette']),
      oath: _s(j['oath']),
      end: _s(j['end']),
    );
  }
}

/// A party in the House: its short name, all its seats and those won at the
/// election (the rest are reserved seats for women).
class HouseParty {
  final String abbr;
  final String label;
  final int seats;
  final int seatsTerritorial;
  const HouseParty({
    required this.abbr,
    required this.label,
    required this.seats,
    required this.seatsTerritorial,
  });
  int get seatsReserved => (seats - seatsTerritorial).clamp(0, seats);

  factory HouseParty.fromJson(Map<String, dynamic> j) {
    final abbr = _s(j['abbr']) ?? '';
    return HouseParty(
      abbr: abbr,
      label: _s(j['labelBn']) ?? abbr,
      seats: _i(j['seats']) ?? 0,
      seatsTerritorial: _i(j['seatsTerritorial']) ?? 0,
    );
  }
}

class House {
  final int total, generalSeats, territorial, reserved, majority;
  final List<HouseParty> parties;
  const House({
    this.total = 0,
    this.generalSeats = 300,
    this.territorial = 0,
    this.reserved = 0,
    this.majority = 0,
    this.parties = const [],
  });
  factory House.fromJson(dynamic v) {
    final j = _map(v);
    return House(
      total: _i(j['total']) ?? 0,
      generalSeats: _i(j['generalSeats']) ?? 300,
      territorial: _i(j['territorial']) ?? 0,
      reserved: _i(j['reserved']) ?? 0,
      majority: _i(j['majority']) ?? 0,
      parties: _maps(
        j['parties'],
      ).map(HouseParty.fromJson).where((p) => p.abbr.isNotEmpty).toList(),
    );
  }
}

class Voters {
  final int registered, male, female, pollingCentres, registeredParties;
  final double? womenShare;
  final String? source, sourceUrl, readOn;
  const Voters({
    this.registered = 0,
    this.male = 0,
    this.female = 0,
    this.pollingCentres = 0,
    this.registeredParties = 0,
    this.womenShare,
    this.source,
    this.sourceUrl,
    this.readOn,
  });
  factory Voters.fromJson(dynamic v) {
    final j = _map(v);
    return Voters(
      registered: _i(j['registered']) ?? 0,
      male: _i(j['male']) ?? 0,
      female: _i(j['female']) ?? 0,
      pollingCentres: _i(j['pollingCentres']) ?? 0,
      registeredParties: _i(j['registeredParties']) ?? 0,
      womenShare: _d(j['womenShare']),
      source: _s(j['sourceBn']),
      sourceUrl: _s(j['sourceUrl']),
      readOn: _s(j['readOn']),
    );
  }

  /// Women among the voters, per cent, one decimal: the API's figure, or
  /// worked out the website's way when it is missing.
  double get womenPct =>
      womenShare ?? (registered > 0 ? female * 100 / registered : 0);
}

/// A label and a count: an age band, a profession, a term band.
class Band {
  /// Null for a profession with no English yet, on an English answer.
  final String? label;
  final int count;
  const Band(this.label, this.count);
  static List<Band> list(dynamic v) => [
    for (final j in _maps(v)) Band(_s(j['label']), _i(j['count']) ?? 0),
  ];
}

class AgedMember {
  final int age;
  final MemberBrief member;
  const AgedMember(this.age, this.member);
  static AgedMember? fromJson(dynamic v) {
    final j = _map(v);
    final m = _brief(j['member']);
    final age = _i(j['age']);
    return m == null || age == null ? null : AgedMember(age, m);
  }
}

class TermsMember {
  final MemberBrief member;
  final int terms;
  const TermsMember(this.member, this.terms);
}

class MembersStats {
  final int women, womenTerritorial, womenReserved, freedomFighters;
  final int? medianAge;
  final AgedMember? youngest, oldest;
  final List<Band> ageBands, professions, experience;
  final int withProfession, firstTime, returning;
  final List<TermsMember> mostTerms;
  const MembersStats({
    this.women = 0,
    this.womenTerritorial = 0,
    this.womenReserved = 0,
    this.freedomFighters = 0,
    this.medianAge,
    this.youngest,
    this.oldest,
    this.ageBands = const [],
    this.professions = const [],
    this.experience = const [],
    this.withProfession = 0,
    this.firstTime = 0,
    this.returning = 0,
    this.mostTerms = const [],
  });
  factory MembersStats.fromJson(dynamic v) {
    final j = _map(v);
    return MembersStats(
      women: _i(j['women']) ?? 0,
      womenTerritorial: _i(j['womenTerritorial']) ?? 0,
      womenReserved: _i(j['womenReserved']) ?? 0,
      freedomFighters: _i(j['freedomFighters']) ?? 0,
      medianAge: _i(j['medianAge']),
      youngest: AgedMember.fromJson(j['youngest']),
      oldest: AgedMember.fromJson(j['oldest']),
      ageBands: Band.list(j['ageBands']),
      professions: Band.list(j['professions']),
      experience: Band.list(j['experience']),
      withProfession: _i(j['withProfession']) ?? 0,
      firstTime: _i(j['firstTime']) ?? 0,
      returning: _i(j['returning']) ?? 0,
      mostTerms: [
        for (final r in _maps(j['mostTerms']))
          if (_brief(r['member']) case final m?)
            TermsMember(m, _i(r['terms']) ?? 0),
      ],
    );
  }
}

class RunnerUp {
  final String name;
  final String? party;
  final String? partyLabel;
  final int votes;
  const RunnerUp(this.name, this.party, this.partyLabel, this.votes);
  static RunnerUp? fromJson(dynamic v) {
    final j = _map(v);
    final name = _s(j['name']);
    final votes = _i(j['votes']);
    if (name == null || votes == null) return null;
    return RunnerUp(name, _s(j['party']), _s(j['partyBn']), votes);
  }
}

/// One of the 300 general seats, where its pin goes, who sits for it and how
/// the vote went.
class ElectionSeat {
  final int no;
  final String slug;
  final String name;
  final String districtSlug;
  final String districtName;
  final double? lon, lat;
  final MemberBrief? member;
  final String? party;
  final int? votes;
  final int? margin;
  final RunnerUp? runnerUp;

  /// On an English answer, the Bangla names beside the English ones, so a
  /// search typed in Bangla still finds the seat.
  final String? nameAlt, seatAlt, districtAlt;

  const ElectionSeat({
    required this.no,
    required this.slug,
    required this.name,
    required this.districtSlug,
    required this.districtName,
    this.lon,
    this.lat,
    this.member,
    this.party,
    this.votes,
    this.margin,
    this.runnerUp,
    this.nameAlt,
    this.seatAlt,
    this.districtAlt,
  });

  /// The party's everyday short name ("বিএনপি" / "BNP").
  String? get partyShort => member?.partyBn ?? party;

  factory ElectionSeat.fromJson(Map<String, dynamic> j) {
    final m = _map(j['member']);
    return ElectionSeat(
      no: _i(j['no']) ?? 0,
      slug: _s(j['slug']) ?? '',
      name: _s(j['seatBn']) ?? _s(j['slug']) ?? '',
      districtSlug: _s(j['districtSlug']) ?? '',
      districtName: _s(j['districtBn']) ?? _s(j['districtSlug']) ?? '',
      lon: _d(j['lon']),
      lat: _d(j['lat']),
      member: _brief(j['member']),
      party: _s(j['party']),
      votes: _i(j['votes']),
      margin: _i(j['margin']),
      runnerUp: RunnerUp.fromJson(j['runnerUp']),
      nameAlt: _s(m['nameAlt']),
      seatAlt: _s(m['seatAlt']),
      districtAlt: _s(m['districtAlt']),
    );
  }

  /// Whether a search matches this seat: its name, slug, member or district,
  /// in either script. English names match whatever their capitals.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return false;
    bool has(String? x) => x != null && x.toLowerCase().contains(q);
    return has(name) ||
        slug.contains(q) ||
        has(member?.nameBn) ||
        has(districtName) ||
        has(nameAlt) ||
        has(seatAlt) ||
        has(districtAlt);
  }
}

/// Seats by party in one parliament, general seats only.
class EarlierParliament {
  final int no;
  final String label;
  final int recorded;
  final List<({String abbr, String label, int seats})> parties;
  const EarlierParliament({
    required this.no,
    required this.label,
    required this.recorded,
    required this.parties,
  });
  factory EarlierParliament.fromJson(Map<String, dynamic> j) =>
      EarlierParliament(
        no: _i(j['parliamentNo']) ?? 0,
        label: _s(j['labelBn']) ?? '',
        recorded: _i(j['recorded']) ?? 0,
        parties: [
          for (final p in _maps(j['parties']))
            if (_s(p['abbr']) case final abbr?)
              (
                abbr: abbr,
                label: _s(p['labelBn']) ?? abbr,
                seats: _i(p['seats']) ?? 0,
              ),
        ],
      );

  int seatsOf(String abbr) =>
      parties.where((p) => p.abbr == abbr).fold(0, (n, p) => n + p.seats);
  int get total => parties.fold(0, (n, p) => n + p.seats);
}

class ElectionData {
  final String version;
  final int parliamentNo;
  final ElectionDates dates;
  final House house;
  final Voters voters;
  final int seatsCounted;
  final String? resultsSource;
  final MembersStats members;
  final int committeesTotal, committeesCurrent;
  final List<ElectionSeat> seats;
  final List<EarlierParliament> earlier;

  const ElectionData({
    this.version = '',
    this.parliamentNo = 13,
    this.dates = const ElectionDates(),
    this.house = const House(),
    this.voters = const Voters(),
    this.seatsCounted = 0,
    this.resultsSource,
    this.members = const MembersStats(),
    this.committeesTotal = 0,
    this.committeesCurrent = 0,
    this.seats = const [],
    this.earlier = const [],
  });

  factory ElectionData.fromJson(Map<String, dynamic> j) {
    final results = _map(j['results']);
    final committees = _map(j['committees']);
    return ElectionData(
      version: _s(j['version']) ?? '',
      parliamentNo: _i(j['parliamentNo']) ?? 13,
      dates: ElectionDates.fromJson(j['dates']),
      house: House.fromJson(j['house']),
      voters: Voters.fromJson(j['voters']),
      seatsCounted: _i(results['seatsCounted']) ?? 0,
      resultsSource: _s(results['sourceBn']),
      members: MembersStats.fromJson(j['members']),
      committeesTotal: _i(committees['total']) ?? 0,
      committeesCurrent: _i(committees['current']) ?? 0,
      seats: _maps(
        j['seats'],
      ).map(ElectionSeat.fromJson).where((s) => s.slug.isNotEmpty).toList(),
      earlier: _maps(j['earlier'])
          .map(EarlierParliament.fromJson)
          .where((p) => p.parties.isNotEmpty)
          .toList(),
    );
  }

  /// Seats whose result is published (the website's `publishedSeats`).
  int get publishedSeats => seats.where((s) => s.votes != null).length;

  /// Each district's name in the answer's language, by slug.
  Map<String, String> get districtNames => {
    for (final s in seats)
      if (s.districtSlug.isNotEmpty) s.districtSlug: s.districtName,
  };
}

final _election = <Lang, ElectionData>{};

/// The election and the House, kept for the session once read; [force] for
/// pull-to-refresh.
Future<ElectionData> fetchElection({bool force = false}) async {
  final lang = appLang.value;
  final held = _election[lang];
  if (held != null && !force) return held;
  final json = await Api.instance.getJson('/api/app/v1/election');
  final data = ElectionData.fromJson(json);
  _election[lang] = data;
  return data;
}

/* ---------------- the map's outlines ---------------- */

/// A district's outline (outer rings, as lon/lat), its label's place and its
/// Bangla name.
class GeoDistrict {
  final String slug;
  final String name;
  final Offset center;
  final List<List<Offset>> rings;
  const GeoDistrict(this.slug, this.name, this.center, this.rings);
}

class GeoOverview {
  final List<GeoDistrict> districts;

  /// Each seat's point, by seat slug, as (lon, lat).
  final Map<String, Offset> seats;
  const GeoOverview(this.districts, this.seats);

  factory GeoOverview.fromJson(Map<String, dynamic> j) {
    final districts = <GeoDistrict>[];
    for (final d in _maps(j['districts'])) {
      final slug = _s(d['slug']);
      if (slug == null) continue;
      districts.add(
        GeoDistrict(
          slug,
          _s(d['name']) ?? slug,
          _point(d['center']) ?? Offset.zero,
          _rings(d['polys']),
        ),
      );
    }
    final seats = <String, Offset>{};
    _map(j['seats']).forEach((k, v) {
      final p = _point(v);
      if (p != null) seats[k] = p;
    });
    return GeoOverview(districts, seats);
  }
}

Offset? _point(dynamic v) {
  if (v is List && v.length >= 2 && v[0] is num && v[1] is num) {
    return Offset((v[0] as num).toDouble(), (v[1] as num).toDouble());
  }
  return null;
}

List<List<Offset>> _rings(dynamic v) {
  if (v is! List) return const [];
  final out = <List<Offset>>[];
  for (final ring in v) {
    if (ring is! List) continue;
    final pts = <Offset>[for (final p in ring) ?_point(p)];
    if (pts.length >= 3) out.add(pts);
  }
  return out;
}

GeoOverview? _overview;
Future<GeoOverview>? _overviewLoading;

/// The country's districts and the seats' points, fetched once a session.
/// The same in both languages; a failure is forgotten, so a retry fetches.
/// (The value is kept, not the future: a test's zone dies with the test.)
Future<GeoOverview> fetchOverview() {
  final held = _overview;
  if (held != null) return Future.value(held);
  return _overviewLoading ??= () async {
    try {
      final j = await Api.instance.getJson(
        '/geo/overview.json',
        timeout: const Duration(seconds: 30),
      );
      return _overview = GeoOverview.fromJson(j);
    } finally {
      _overviewLoading = null;
    }
  }();
}

/// A place a seat covers, wholly or in part: an upazila, a city or a ward.
class SeatArea {
  final String name;
  final String kind;
  final bool whole;

  /// The outer ring of each of its polygons, as (lon, lat).
  final List<List<Offset>> rings;
  const SeatArea(this.name, this.kind, this.whole, this.rings);
}

final _areas = <String, List<Map<String, dynamic>>>{};

/// The places of [seatSlug], from its district's file (`/geo/<district>.json`,
/// kept once read). Empty when the file cannot be had.
Future<List<SeatArea>> fetchSeatAreas(
  String districtSlug,
  String seatSlug,
) async {
  var features = _areas[districtSlug];
  if (features == null) {
    try {
      final j = await Api.instance.getJson(
        '/geo/$districtSlug.json',
        timeout: const Duration(seconds: 30),
      );
      features = _areas[districtSlug] = _maps(j['features']);
    } catch (_) {
      return const [];
    }
  }
  final out = <SeatArea>[];
  for (final f in features) {
    final p = _map(f['properties']);
    final part = _map(p['seats'])[seatSlug];
    if (part is! String) continue;
    final g = _map(f['geometry']);
    final coords = g['coordinates'];
    // A Polygon is a list of rings; a MultiPolygon a list of those. Only each
    // polygon's outer ring is drawn, as on the website.
    final polys = g['type'] == 'MultiPolygon'
        ? (coords is List ? coords : const [])
        : [coords];
    final rings = <List<Offset>>[];
    for (final poly in polys) {
      if (poly is List && poly.isNotEmpty) rings.addAll(_rings([poly.first]));
    }
    if (rings.isEmpty) continue;
    out.add(
      SeatArea(
        _s(p['name']) ?? '',
        _s(p['kind']) ?? '',
        part == 'whole',
        rings,
      ),
    );
  }
  return out;
}
