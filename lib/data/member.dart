/// One member's page as the website draws it: what /api/app/v1/mp/{slug}
/// answers (docs/app-api.md), parsed defensively like lib/models.dart, and
/// the district maps the member's constituency is drawn from.
///
/// The `…Bn` fields carry English on an English answer (null where there is
/// no English); a screen leaves a null out, never shows the Bangla instead.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../i18n.dart';
import '../models.dart';

String? _s(dynamic v) => v is String && v.trim().isNotEmpty ? v : null;
int? _i(dynamic v) => v is num ? v.toInt() : null;
bool _b(dynamic v) => v == true;
List<String> _strings(dynamic v) => v is List
    ? v.whereType<String>().where((s) => s.trim().isNotEmpty).toList()
    : const [];
List<Map<String, dynamic>> _maps(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

/// The member's seat as the page names it.
class ProfileSeat {
  final int? no;
  final String slug;
  final String? nameBn;
  final bool reserved;
  final String? districtSlug;
  final String? districtBn;

  /// The Election Commission's description of the area; null on English when
  /// it has no English yet (the page then says it is available in Bangla).
  final String? boundaryBn;
  final bool boundaryTranslated;

  /// Set when the seat's member resigned.
  final String? vacantSince;

  const ProfileSeat({
    this.no,
    required this.slug,
    this.nameBn,
    this.reserved = false,
    this.districtSlug,
    this.districtBn,
    this.boundaryBn,
    this.boundaryTranslated = false,
    this.vacantSince,
  });

  static ProfileSeat? fromJson(dynamic j) {
    if (j is! Map<String, dynamic>) return null;
    final slug = _s(j['slug']);
    if (slug == null) return null;
    return ProfileSeat(
      no: _i(j['no']),
      slug: slug,
      nameBn: _s(j['nameBn']),
      reserved: _b(j['reserved']),
      districtSlug: _s(j['districtSlug']),
      districtBn: _s(j['districtBn']),
      boundaryBn: _s(j['boundaryBn']),
      boundaryTranslated: _b(j['boundaryTranslated']),
      vacantSince: _s(j['vacantSince']),
    );
  }
}

/// One of the member's own accounts.
class ProfileSocial {
  /// facebook, x, youtube, instagram or website.
  final String key;
  final String url;
  final String label;

  /// A Facebook page still being checked: shown with "যাচাই করা হয়নি".
  final bool unverified;
  const ProfileSocial({
    required this.key,
    required this.url,
    required this.label,
    this.unverified = false,
  });

  factory ProfileSocial.fromJson(Map<String, dynamic> j) => ProfileSocial(
    key: _s(j['key']) ?? _s(j['icon']) ?? 'website',
    url: _s(j['url']) ?? '',
    label: _s(j['label']) ?? _s(j['key']) ?? '',
    unverified: _b(j['unverified']),
  );
}

/// An earlier parliament the member sat in.
class ProfileTerm {
  final int parliamentNo;

  /// "নবম সংসদ, ২০০৮" / "9th Parliament, 2008".
  final String? labelBn;
  final String? seatNameBn;

  /// The source's English seat name, in both languages.
  final String? seatNameEn;
  final String? partyAbbr;
  final String? partyNameBn;

  const ProfileTerm({
    required this.parliamentNo,
    this.labelBn,
    this.seatNameBn,
    this.seatNameEn,
    this.partyAbbr,
    this.partyNameBn,
  });

  factory ProfileTerm.fromJson(Map<String, dynamic> j) => ProfileTerm(
    parliamentNo: _i(j['parliamentNo']) ?? 0,
    labelBn: _s(j['labelBn']),
    seatNameBn: _s(j['seatNameBn']),
    seatNameEn: _s(j['seatNameEn']),
    partyAbbr: _s(j['partyAbbr']),
    partyNameBn: _s(j['partyNameBn']),
  );
}

/// One candidate in the seat's result. [name] is null on English when only a
/// Bangla name is known; [partyBn] is null for a party with no certain name.
class ProfileCandidate {
  final String? name;
  final String? party;
  final String? partyBn;
  final int votes;
  const ProfileCandidate({
    this.name,
    this.party,
    this.partyBn,
    required this.votes,
  });

  factory ProfileCandidate.fromJson(Map<String, dynamic> j) => ProfileCandidate(
    name: _s(j['name']),
    party: _s(j['party']),
    partyBn: _s(j['partyBn']),
    votes: _i(j['votes']) ?? 0,
  );
}

/// The seat's general-election result, most votes first.
class ProfileResult {
  final List<ProfileCandidate> candidates;
  final String? sourceUrl;

  /// Who published the numbers: "দ্য বিজনেস স্ট্যান্ডার্ড".
  final String? sourceBn;

  /// The note the page shows under the result.
  final String? noteBn;

  /// False when this member is not the result's winner (after a by-election).
  final bool won;

  const ProfileResult({
    required this.candidates,
    this.sourceUrl,
    this.sourceBn,
    this.noteBn,
    this.won = true,
  });

  static ProfileResult? fromJson(dynamic j) {
    if (j is! Map<String, dynamic>) return null;
    final list = _maps(j['candidates']).map(ProfileCandidate.fromJson).toList()
      ..sort((a, b) => b.votes.compareTo(a.votes));
    if (list.isEmpty) return null;
    return ProfileResult(
      candidates: list,
      sourceUrl: _s(j['sourceUrl']),
      sourceBn: _s(j['sourceBn']),
      noteBn: _s(j['noteBn']),
      won: j['won'] != false,
    );
  }
}

/// A Parliament Secretariat notice in the member's name.
class ProfileNotice {
  final String id;

  /// English: the source's English title, null when it has none.
  final String? titleBn;
  final String? date;
  final String? categoryBn;
  final String? pdfUrl;
  const ProfileNotice({
    required this.id,
    this.titleBn,
    this.date,
    this.categoryBn,
    this.pdfUrl,
  });

  factory ProfileNotice.fromJson(Map<String, dynamic> j) => ProfileNotice(
    id: '${j['id'] ?? ''}',
    titleBn: _s(j['titleBn']),
    date: _s(j['date']),
    categoryBn: _s(j['categoryBn']),
    pdfUrl: _s(j['pdfUrl']),
  );
}

/// A source the biography was written from, named as the page names it.
class ProfileSource {
  final String url;
  final String? label;
  const ProfileSource(this.url, this.label);
}

/// Everything the member's page shows, in the answer's language.
class MemberProfile {
  final MemberBrief brief;

  /// English answers only: the Bangla name, shown under the English one.
  final String? nameAlt;
  final String? seatSlug;
  final String? districtSlug;

  final String? professionBn;
  final String? educationBn;
  final String? birthPlaceBn;
  final String? dateOfBirth;
  final String? fatherBn;
  final String? motherBn;
  final bool isFreedomFighter;
  final String? email;

  final String? bioBn;
  final bool bioTranslated;
  final bool bioOnlyInBangla;
  final String? summaryBn;
  final bool summaryTranslated;
  final bool showSummary;
  final String? leadBn;
  final List<String> introBn;

  /// The Wikipedia article(s) the starred facts came from.
  final List<String> bioSource;
  final List<ProfileSource> bioSources;

  /// Which of educationBn, birthPlaceBn, professionBn came from Wikipedia.
  final Set<String> bioFromWiki;

  final String? termStart;
  final String? termEnd;
  final int? termsCount;
  final String? resignedOn;
  final String? partyRoleBn;
  final String? partyNameBn;
  final ProfileSeat? seat;

  /// Every House office, whips included, as the page's badges show them.
  final List<String> rolesBn;

  /// The government posts as badges ("প্রতিমন্ত্রী, পানি সম্পদ মন্ত্রণালয়").
  final List<String> postBadgesBn;
  final String? postsCheckedAt;

  final List<ProfileSocial> socials;
  final String? facebookNotice;

  /// The Wikipedia article(s) the links were read from; empty when an editor
  /// added them.
  final List<String> socialSource;

  final List<CommitteeRef> committees;
  final int committeesTotal;
  final int committeesCurrent;
  final List<ProfileTerm> priorTerms;
  final ProfileResult? result;
  final List<ProfileNotice> notices;

  const MemberProfile({
    required this.brief,
    this.nameAlt,
    this.seatSlug,
    this.districtSlug,
    this.professionBn,
    this.educationBn,
    this.birthPlaceBn,
    this.dateOfBirth,
    this.fatherBn,
    this.motherBn,
    this.isFreedomFighter = false,
    this.email,
    this.bioBn,
    this.bioTranslated = false,
    this.bioOnlyInBangla = false,
    this.summaryBn,
    this.summaryTranslated = false,
    this.showSummary = false,
    this.leadBn,
    this.introBn = const [],
    this.bioSource = const [],
    this.bioSources = const [],
    this.bioFromWiki = const {},
    this.termStart,
    this.termEnd,
    this.termsCount,
    this.resignedOn,
    this.partyRoleBn,
    this.partyNameBn,
    this.seat,
    this.rolesBn = const [],
    this.postBadgesBn = const [],
    this.postsCheckedAt,
    this.socials = const [],
    this.facebookNotice,
    this.socialSource = const [],
    this.committees = const [],
    this.committeesTotal = 0,
    this.committeesCurrent = 0,
    this.priorTerms = const [],
    this.result,
    this.notices = const [],
  });

  factory MemberProfile.fromJson(Map<String, dynamic> j) {
    final term = j['term'] is Map ? j['term'] as Map : const {};
    final counts = j['committeeCounts'] is Map
        ? j['committeeCounts'] as Map
        : const {};
    final links = _maps(j['bioSourceLinks']);
    List<String> urls(dynamic v) =>
        (_s(v) ?? '').split(RegExp(r'\s+')).where((u) => u.isNotEmpty).toList();
    return MemberProfile(
      brief: MemberBrief.fromJson(j),
      nameAlt: _s(j['nameAlt']),
      seatSlug: _s(j['seatSlug']),
      districtSlug: _s(j['districtSlug']),
      professionBn: _s(j['professionBn']),
      educationBn: _s(j['educationBn']),
      birthPlaceBn: _s(j['birthPlaceBn']),
      dateOfBirth: _s(j['dateOfBirth']),
      fatherBn: _s(j['fatherBn']),
      motherBn: _s(j['motherBn']),
      isFreedomFighter: _b(j['isFreedomFighter']),
      email: _s(j['email']),
      bioBn: _s(j['bioBn']),
      bioTranslated: _b(j['bioTranslated']),
      bioOnlyInBangla: _b(j['bioOnlyInBangla']),
      summaryBn: _s(j['summaryBn']),
      summaryTranslated: _b(j['summaryTranslated']),
      showSummary: _b(j['showSummary']),
      leadBn: _s(j['leadBn']),
      introBn: _strings(j['introBn']),
      bioSource: urls(j['bioSource']),
      bioSources: links.isNotEmpty
          ? [
              for (final l in links)
                if (_s(l['url']) != null)
                  ProfileSource(l['url'] as String, _s(l['label'])),
            ]
          : [for (final u in _strings(j['bioSources'])) ProfileSource(u, null)],
      bioFromWiki: (_s(j['bioFromWiki']) ?? '')
          .split(',')
          .map((x) => x.trim())
          .where((x) => x.isNotEmpty)
          .toSet(),
      termStart: _s(term['start']),
      termEnd: _s(term['end']),
      termsCount: _i(j['termsCount']),
      resignedOn: _s(j['resignedOn']),
      partyRoleBn: _s(j['partyRoleBn']),
      partyNameBn: _s(j['partyNameBn']),
      seat: ProfileSeat.fromJson(j['seat']),
      rolesBn: _strings(j['rolesBn']),
      postBadgesBn: _strings(j['postBadgesBn']),
      postsCheckedAt: _s(j['postsCheckedAt']),
      socials: _maps(
        j['socials'],
      ).map(ProfileSocial.fromJson).where((s) => s.url.isNotEmpty).toList(),
      facebookNotice: _s(j['facebookNotice']),
      socialSource: urls(j['socialSource']),
      committees: _maps(j['committees']).map(CommitteeRef.fromJson).toList(),
      committeesTotal: _i(counts['total']) ?? 0,
      committeesCurrent: _i(counts['current']) ?? 0,
      priorTerms: _maps(j['priorTerms']).map(ProfileTerm.fromJson).toList(),
      result: ProfileResult.fromJson(j['result']),
      notices: _maps(j['notices']).map(ProfileNotice.fromJson).toList(),
    );
  }
}

final _profiles = <String, MemberProfile>{};

/// One member's page, kept for the session once read; [force] reads it again
/// (pull to refresh). Resigned members answer too.
Future<MemberProfile> fetchMemberProfile(
  String slug, {
  bool force = false,
}) async {
  final key = '${appLang.value.name}/$slug';
  final held = _profiles[key];
  if (held != null && !force) return held;
  final json = await Api.instance.getJson('/api/app/v1/mp/$slug');
  final p = MemberProfile.fromJson(json);
  _profiles[key] = p;
  return p;
}

/* ---------------- the district maps ---------------- */

/// How much of a place a seat holds.
enum SeatPart { whole, part }

/// One upazila, city corporation or city ward of a district's map.
class GeoPlace {
  /// The Bangla name: "দোহার", "ওয়ার্ড ৪৭", "ঢাকা দক্ষিণ সিটি কর্পোরেশন".
  final String name;

  /// upazila, city or ward.
  final String kind;

  /// A ward's city corporation, in Bangla.
  final String? city;
  final Map<String, SeatPart> seats;

  /// Polygons, each a list of rings (the outline, then any holes), each ring
  /// a list of (longitude, latitude).
  final List<List<List<(double, double)>>> polygons;

  const GeoPlace({
    required this.name,
    required this.kind,
    this.city,
    required this.seats,
    required this.polygons,
  });

  static GeoPlace? fromJson(Map<String, dynamic> f) {
    final p = f['properties'];
    final g = f['geometry'];
    if (p is! Map || g is! Map) return null;
    List<(double, double)> ring(dynamic r) => [
      if (r is List)
        for (final pt in r)
          if (pt is List && pt.length >= 2 && pt[0] is num && pt[1] is num)
            ((pt[0] as num).toDouble(), (pt[1] as num).toDouble()),
    ];
    List<List<(double, double)>> polygon(dynamic rings) => [
      if (rings is List)
        for (final r in rings) ring(r),
    ].where((r) => r.length >= 3).toList();
    final coords = g['coordinates'];
    final polygons = switch (g['type']) {
      'Polygon' => [polygon(coords)],
      'MultiPolygon' => [
        if (coords is List)
          for (final c in coords) polygon(c),
      ],
      _ => <List<List<(double, double)>>>[],
    }.where((p) => p.isNotEmpty).toList();
    if (polygons.isEmpty) return null;
    final seats = <String, SeatPart>{};
    if (p['seats'] is Map) {
      (p['seats'] as Map).forEach((k, v) {
        if (k is String) {
          seats[k] = v == 'whole' ? SeatPart.whole : SeatPart.part;
        }
      });
    }
    return GeoPlace(
      name: _s(p['name']) ?? '',
      kind: _s(p['kind']) ?? 'upazila',
      city: _s(p['city']),
      seats: seats,
      polygons: polygons,
    );
  }
}

final _geo = <String, List<GeoPlace>>{};

/// A district's upazilas, cities and wards with the seats each lies in, from
/// the website's own map file (`/geo/<district>.json`). Kept for the session
/// once read; a failure is not kept, so the next look tries again.
Future<List<GeoPlace>> fetchDistrictGeo(String districtSlug) async {
  final held = _geo[districtSlug];
  if (held != null) return held;
  final j = await Api.instance.getJson(
    '/geo/$districtSlug.json',
    timeout: const Duration(seconds: 30),
  );
  final places = _maps(
    j['features'],
  ).map(GeoPlace.fromJson).whereType<GeoPlace>().toList();
  if (places.isNotEmpty) _geo[districtSlug] = places;
  return places;
}

Map<String, String>? _upazilaEn;

/// Upazila names in English by their Bangla names, from the English bootstrap
/// the app keeps on the phone (its `upazilaEn` table). Empty when there is no
/// stored English copy yet: the map then leaves those places unnamed, as the
/// website does where it has no English.
Future<Map<String, String>> upazilaNamesEn() async {
  final held = _upazilaEn;
  if (held != null && held.isNotEmpty) return held;
  final table = <String, String>{};
  try {
    final prefs = await SharedPreferences.getInstance();
    // The key lib/api.dart keeps the English bootstrap under.
    final saved = prefs.getString('bootstrap_v4_en');
    if (saved != null) {
      final j = jsonDecode(saved);
      final rows = j is Map ? j['upazilaEn'] : null;
      if (rows is List) {
        // The first English name for a Bangla name wins, as on the website.
        for (final r in rows.reversed) {
          if (r is List && r.length >= 2 && r[0] is String && r[1] is String) {
            table[bnKey(r[1] as String)] = r[0] as String;
          }
        }
      }
    }
  } catch (_) {}
  _upazilaEn = table;
  return table;
}

/// A Bangla name as a lookup key: no joiners, no spaces around it.
String bnKey(String s) => s.replaceAll(RegExp('[‌‍]'), '').trim();
