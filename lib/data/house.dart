/// The House: its sessions and sittings (/api/app/v1/sessions), its
/// committees (/committees, /committee/{slug}) and one party (/party/{slug}),
/// as the website's /odhibeshon, /committee and /dol/{slug} pages show them.
///
/// Every shape parses defensively, like lib/models.dart: a field the site adds
/// later, or one that comes back null, must never crash a phone. The text
/// fields are `…Bn` on the wire and hold English on an English answer (null
/// where there is no English); here they are named for what they are.
library;

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
MemberBrief? _brief(dynamic v) {
  if (v is! Map<String, dynamic>) return null;
  final m = MemberBrief.fromJson(v);
  return m.slug.isEmpty ? null : m;
}

/* ---------------- sessions ---------------- */

class ParliamentDates {
  final int no;
  final String? electionDate;
  final String? gazetteDate;
  final String? oathDate;
  final String? endDate;
  const ParliamentDates({
    this.no = 13,
    this.electionDate,
    this.gazetteDate,
    this.oathDate,
    this.endDate,
  });

  factory ParliamentDates.fromJson(dynamic j) {
    if (j is! Map<String, dynamic>) return const ParliamentDates();
    return ParliamentDates(
      no: _i(j['no']) ?? 13,
      electionDate: _s(j['electionDate']),
      gazetteDate: _s(j['gazetteDate']),
      oathDate: _s(j['oathDate']),
      endDate: _s(j['endDate']),
    );
  }
}

/// One sitting's order of the day.
class Sitting {
  final String id;

  /// "দিনের কার্যসূচী: ১০-০৯-২০২৬" / "Order of the day: 10 September 2026".
  final String? title;
  final String? date;
  final String? weekday;
  final String? pdfUrl;
  const Sitting({
    required this.id,
    this.title,
    this.date,
    this.weekday,
    this.pdfUrl,
  });

  factory Sitting.fromJson(Map<String, dynamic> j) => Sitting(
    id: '${j['id'] ?? ''}',
    title: _s(j['titleBn']),
    date: _s(j['date']),
    weekday: _s(j['weekdayBn']),
    pdfUrl: _s(j['pdfUrl']),
  );
}

class Circular {
  final int? no;

  /// "পরিপত্র-১" / "Circular 1".
  final String? title;
  final String? date;
  final String? pdfUrl;
  const Circular({this.no, this.title, this.date, this.pdfUrl});

  factory Circular.fromJson(Map<String, dynamic> j) => Circular(
    no: _i(j['no']),
    title: _s(j['titleBn']),
    date: _s(j['date']),
    pdfUrl: _s(j['pdfUrl']),
  );
}

class HouseSession {
  final String id;

  /// "তৃতীয় অধিবেশন" / "3rd session".
  final String title;
  final String? startDate;
  final String? endDate;

  /// Newest first: the n-th sitting is `sittings[length - n]`.
  final List<Sitting> sittings;
  final List<Circular> circulars;
  const HouseSession({
    required this.id,
    required this.title,
    this.startDate,
    this.endDate,
    this.sittings = const [],
    this.circulars = const [],
  });

  factory HouseSession.fromJson(Map<String, dynamic> j) => HouseSession(
    id: '${j['id'] ?? ''}',
    title: _s(j['titleBn']) ?? '',
    startDate: _s(j['startDate']),
    endDate: _s(j['endDate']),
    sittings: _maps(j['sittings']).map(Sitting.fromJson).toList(),
    circulars: _maps(j['circulars']).map(Circular.fromJson).toList(),
  );

  /// The session's first circular, which carries the hour the House meets.
  Circular? get firstCircular {
    final list = [...circulars]
      ..sort((a, b) => (a.date ?? '').compareTo(b.date ?? ''));
    return list.firstOrNull;
  }
}

/// A notice of the Parliament Secretariat, or of a committee.
class HouseNotice {
  final String id;

  /// Null on English when the source has no English title.
  final String? title;
  final String? date;
  final String? category;
  final String? pdfUrl;
  const HouseNotice({
    required this.id,
    this.title,
    this.date,
    this.category,
    this.pdfUrl,
  });

  factory HouseNotice.fromJson(Map<String, dynamic> j) => HouseNotice(
    id: '${j['id'] ?? ''}',
    title: _s(j['titleBn']),
    date: _s(j['date']),
    category: _s(j['categoryBn']),
    pdfUrl: _s(j['pdfUrl']),
  );
}

/// A presiding officer, leader or whip.
class HouseOfficer {
  /// SPEAKER, DEPUTY_SPEAKER, LEADER_OF_HOUSE, OPPOSITION_LEADER, CHIEF_WHIP, WHIP.
  final String role;
  final String roleName;
  final String name;

  /// Null when the source does not link the officer to a member.
  final MemberBrief? member;

  /// "১২ মার্চ ২০২৬ -" / "from 12 March 2026".
  final String? tenure;
  const HouseOfficer({
    required this.role,
    required this.roleName,
    required this.name,
    this.member,
    this.tenure,
  });

  factory HouseOfficer.fromJson(Map<String, dynamic> j) {
    final member = _brief(j['member']);
    return HouseOfficer(
      role: _s(j['role']) ?? '',
      roleName: _s(j['roleBn']) ?? _s(j['role']) ?? '',
      name: _s(j['nameBn']) ?? member?.nameBn ?? '',
      member: member,
      tenure: _s(j['tenureBn']),
    );
  }
}

class SessionsData {
  final String? version;
  final ParliamentDates parliament;
  final int sessionCount;
  final int sittingCount;
  final String? lastSittingDate;

  /// Newest first; the first is the current one.
  final List<HouseSession> sessions;
  final List<HouseNotice> generalNotices;
  final List<HouseOfficer> officers;

  const SessionsData({
    this.version,
    this.parliament = const ParliamentDates(),
    this.sessionCount = 0,
    this.sittingCount = 0,
    this.lastSittingDate,
    this.sessions = const [],
    this.generalNotices = const [],
    this.officers = const [],
  });

  factory SessionsData.fromJson(Map<String, dynamic> j) {
    final sessions = _maps(j['sessions']).map(HouseSession.fromJson).toList();
    final counts = j['counts'] is Map<String, dynamic>
        ? j['counts'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return SessionsData(
      version: _s(j['version']),
      parliament: ParliamentDates.fromJson(j['parliament']),
      sessionCount: _i(counts['sessions']) ?? sessions.length,
      sittingCount:
          _i(counts['sittings']) ??
          sessions.fold<int>(0, (n, s) => n + s.sittings.length),
      lastSittingDate: _s(j['lastSittingDate']),
      sessions: sessions,
      generalNotices: _maps(
        j['generalNotices'],
      ).map(HouseNotice.fromJson).toList(),
      officers: _maps(
        j['officers'],
      ).map(HouseOfficer.fromJson).where((o) => o.name.isNotEmpty).toList(),
    );
  }
}

/// Midnight in Dhaka (UTC+6, no daylight saving) on a "YYYY-MM-DD" day.
DateTime? dhakaMidnight(String? iso) {
  if (iso == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  if (m == null) return null;
  return DateTime.utc(
    int.parse(m[1]!),
    int.parse(m[2]!),
    int.parse(m[3]!),
  ).subtract(const Duration(hours: 6));
}

/// The weekday of a day, as the calendar in Dhaka has it: 7 = Sunday.
int? weekdayOfDay(String? iso) {
  final at = dhakaMidnight(iso);
  return at?.add(const Duration(hours: 6)).weekday;
}

/// Whole days from a day to [now], on Dhaka's calendar: 0 on the day itself.
int? daysSinceDay(String? iso, DateTime now) {
  final at = dhakaMidnight(iso);
  if (at == null) return null;
  final today = now.toUtc().add(const Duration(hours: 6));
  final todayMidnight = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).subtract(const Duration(hours: 6));
  return todayMidnight.difference(at).inHours ~/ 24;
}

/// Where the latest session stands by the clock, as the website's
/// SessionCountdown tells it.
sealed class SessionClock {
  const SessionClock();
}

/// Before the first day: what is left until midnight in Dhaka on that day.
class ClockBefore extends SessionClock {
  final int days, hours, minutes, seconds;
  const ClockBefore(this.days, this.hours, this.minutes, this.seconds);
}

/// While it sits: the [day]-th day of the session, counting the first as 1.
class ClockSitting extends SessionClock {
  final int day;
  const ClockSitting(this.day);
}

/// Over: [days] since the last sitting.
class ClockAfter extends SessionClock {
  final int days;
  const ClockAfter(this.days);
}

/// A session the source has not closed counts as over this long after its
/// last sitting (the website's QUIET_DAYS).
const sessionQuietDays = 10;

/// The source gives the start date, not the hour the House meets, so the
/// count runs to the start of that day in Dhaka. Null without a start date.
SessionClock? sessionClockAt(
  DateTime now,
  String? start,
  String? end,
  String? lastSitting,
) {
  final t0 = dhakaMidnight(start);
  if (t0 == null) return null;
  final at = now.toUtc();
  const day = Duration(days: 1);
  if (at.isBefore(t0)) {
    var left = t0.difference(at).inSeconds;
    final d = left ~/ 86400;
    left -= d * 86400;
    final h = left ~/ 3600;
    left -= h * 3600;
    final m = left ~/ 60;
    return ClockBefore(d, h, m, left - m * 60);
  }
  final endAt = dhakaMidnight(end);
  final lastAt = dhakaMidnight(lastSitting);
  final closed = endAt != null
      ? !at.isBefore(endAt.add(day))
      : lastAt != null
      ? !at.isBefore(lastAt.add(day * sessionQuietDays))
      : false;
  if (closed) {
    final from = lastAt ?? endAt ?? t0;
    return ClockAfter(at.difference(from).inSeconds ~/ 86400);
  }
  return ClockSitting(at.difference(t0).inSeconds ~/ 86400 + 1);
}

/* ---------------- committees ---------------- */

class CommitteeSummary {
  final String slug;
  final String name;

  /// The source's English, in both languages (untidied).
  final String? nameEn;
  final String? type;
  final String? typeName;

  /// False while the list still holds the previous parliament's members.
  final bool rosterCurrent;
  final int memberCount;
  final String? startDate;
  final MemberBrief? chair;

  /// What the committee does, in a sentence or two.
  final String? summary;

  const CommitteeSummary({
    required this.slug,
    required this.name,
    this.nameEn,
    this.type,
    this.typeName,
    this.rosterCurrent = false,
    this.memberCount = 0,
    this.startDate,
    this.chair,
    this.summary,
  });

  factory CommitteeSummary.fromJson(Map<String, dynamic> j) => CommitteeSummary(
    slug: _s(j['slug']) ?? '',
    name: _s(j['nameBn']) ?? _s(j['nameEn']) ?? '',
    nameEn: _s(j['nameEn']),
    type: _s(j['type']),
    typeName: _s(j['typeBn']),
    rosterCurrent: _b(j['rosterCurrent']),
    memberCount: _i(j['memberCount']) ?? 0,
    startDate: _s(j['startDate']),
    chair: _brief(j['chair']),
    summary: _s(j['summaryBn']),
  );
}

class CommitteesData {
  final String? version;
  final int total;
  final int current;
  final int membersOnCommittees;

  /// Up-to-date committees first, then the rest.
  final List<CommitteeSummary> committees;

  const CommitteesData({
    this.version,
    this.total = 0,
    this.current = 0,
    this.membersOnCommittees = 0,
    this.committees = const [],
  });

  factory CommitteesData.fromJson(Map<String, dynamic> j) {
    final list = _maps(
      j['committees'],
    ).map(CommitteeSummary.fromJson).where((c) => c.slug.isNotEmpty).toList();
    return CommitteesData(
      version: _s(j['version']),
      total: _i(j['total']) ?? list.length,
      current: _i(j['current']) ?? list.where((c) => c.rosterCurrent).length,
      membersOnCommittees: _i(j['membersOnCommittees']) ?? 0,
      committees: list,
    );
  }
}

/// What a committee does, from Parliament's Rules of Procedure.
class CommitteeDutyInfo {
  final String summary;
  final List<String> duties;
  final String? note;

  /// Where in the rules: "বিধি ২৩৩-২৩৪".
  final String? rule;
  final String? rulesUrl;
  final ({String slug, String name})? parent;

  const CommitteeDutyInfo({
    required this.summary,
    this.duties = const [],
    this.note,
    this.rule,
    this.rulesUrl,
    this.parent,
  });

  static CommitteeDutyInfo? fromJson(dynamic j) {
    if (j is! Map<String, dynamic>) return null;
    final summary = _s(j['summaryBn']);
    final duties = _strings(j['dutiesBn']);
    if (summary == null && duties.isEmpty) return null;
    final p = j['parent'];
    final parentSlug = p is Map<String, dynamic> ? _s(p['slug']) : null;
    final parentName = p is Map<String, dynamic> ? _s(p['nameBn']) : null;
    return CommitteeDutyInfo(
      summary: summary ?? '',
      duties: duties,
      note: _s(j['noteBn']),
      rule: _s(j['ruleBn']),
      rulesUrl: _s(j['rulesUrl']),
      parent: parentSlug != null && parentName != null
          ? (slug: parentSlug, name: parentName)
          : null,
    );
  }
}

class CommitteeSeat {
  /// "Chairman", "Member" or another source role.
  final String role;
  final String roleName;
  final MemberBrief member;
  const CommitteeSeat({
    required this.role,
    required this.roleName,
    required this.member,
  });

  bool get isChair => role == 'Chairman';
}

class CommitteeDetail {
  final String slug;
  final String name;
  final String? nameEn;
  final String? type;
  final String? typeName;
  final bool rosterCurrent;
  final int memberCount;
  final String? startDate;
  final String? previousStartDate;
  final CommitteeDutyInfo? duty;

  /// The chair first. Empty while the roster is the previous parliament's.
  final List<CommitteeSeat> members;
  final List<HouseNotice> notices;
  final String? version;

  const CommitteeDetail({
    required this.slug,
    required this.name,
    this.nameEn,
    this.type,
    this.typeName,
    this.rosterCurrent = false,
    this.memberCount = 0,
    this.startDate,
    this.previousStartDate,
    this.duty,
    this.members = const [],
    this.notices = const [],
    this.version,
  });

  factory CommitteeDetail.fromJson(Map<String, dynamic> j) {
    final seats = <CommitteeSeat>[];
    for (final m in _maps(j['members'])) {
      final brief = _brief(m['member']);
      if (brief == null) continue;
      final role = _s(m['role']) ?? 'Member';
      seats.add(
        CommitteeSeat(
          role: role,
          roleName: _s(m['roleBn']) ?? role,
          member: brief,
        ),
      );
    }
    return CommitteeDetail(
      slug: _s(j['slug']) ?? '',
      name: _s(j['nameBn']) ?? _s(j['nameEn']) ?? '',
      nameEn: _s(j['nameEn']),
      type: _s(j['type']),
      typeName: _s(j['typeBn']),
      rosterCurrent: _b(j['rosterCurrent']),
      memberCount: _i(j['memberCount']) ?? seats.length,
      startDate: _s(j['startDate']),
      previousStartDate: _s(j['previousStartDate']),
      duty: CommitteeDutyInfo.fromJson(j['duty']),
      members: _b(j['rosterCurrent']) ? seats : const [],
      notices: _maps(j['notices']).map(HouseNotice.fromJson).toList(),
      version: _s(j['version']),
    );
  }

  CommitteeSeat? get chair => members.where((m) => m.isChair).firstOrNull;
  List<CommitteeSeat> get rest => members.where((m) => !m.isChair).toList();
}

/* ---------------- parties ---------------- */

class PartySource {
  final String url;
  final String label;
  const PartySource({required this.url, required this.label});
}

class PartyProfile {
  final String? summary;
  final List<String> origin;

  /// YYYY-MM-DD, or YYYY when only the year is known.
  final String? foundedOn;
  final String? founder;

  /// "person" or "org".
  final String? founderKind;
  final String? symbol;
  final String? leaderTitle;
  final String? leaderName;
  final MemberBrief? leader;
  final String? secretaryTitle;
  final String? secretaryName;
  final MemberBrief? secretary;
  final String? headquarters;
  final String? website;
  final List<PartySource> sources;
  final String? checked;
  final bool edited;

  const PartyProfile({
    this.summary,
    this.origin = const [],
    this.foundedOn,
    this.founder,
    this.founderKind,
    this.symbol,
    this.leaderTitle,
    this.leaderName,
    this.leader,
    this.secretaryTitle,
    this.secretaryName,
    this.secretary,
    this.headquarters,
    this.website,
    this.sources = const [],
    this.checked,
    this.edited = false,
  });

  static PartyProfile? fromJson(dynamic j) {
    if (j is! Map<String, dynamic>) return null;
    return PartyProfile(
      summary: _s(j['summaryBn']),
      origin: _strings(j['originBn']),
      foundedOn: _s(j['foundedOn']),
      founder: _s(j['founderBn']),
      founderKind: _s(j['founderKind']),
      symbol: _s(j['symbolBn']),
      leaderTitle: _s(j['leaderTitleBn']),
      leaderName: _s(j['leaderNameBn']),
      leader: _brief(j['leader']),
      secretaryTitle: _s(j['secretaryTitleBn']),
      secretaryName: _s(j['secretaryNameBn']),
      secretary: _brief(j['secretary']),
      headquarters: _s(j['headquartersBn']),
      website: _s(j['website']),
      sources: [
        for (final s in _maps(j['sources']))
          if (_s(s['url']) case final url?)
            PartySource(url: url, label: _s(s['label']) ?? url),
      ],
      checked: _s(j['checked']),
      edited: _b(j['edited']),
    );
  }
}

/// The party's logo (or flag) and its credit.
class PartyLogoInfo {
  /// "logo" or "flag".
  final String kind;

  /// The file's page on Wikimedia: the credit link.
  final String? page;
  final String? licence;
  final String? licenceUrl;
  final String? author;
  const PartyLogoInfo({
    this.kind = 'logo',
    this.page,
    this.licence,
    this.licenceUrl,
    this.author,
  });

  static PartyLogoInfo? fromJson(dynamic j) {
    if (j is! Map<String, dynamic>) return null;
    return PartyLogoInfo(
      kind: _s(j['kind']) ?? 'logo',
      page: _s(j['page']),
      licence: _s(j['licenceBn']),
      licenceUrl: _s(j['licenceUrl']),
      author: _s(j['author']),
    );
  }
}

class PartyDetail {
  final String abbr;
  final String slug;
  final String? name;
  final String? nameEn;
  final String shortName;
  final int seats;
  final int seatsTerritorial;
  final int seatsReserved;
  final PartyProfile? profile;
  final PartyLogoInfo? logo;

  /// Elected members in seat order, then those for reserved seats.
  final List<MemberBrief> members;
  final String? version;

  const PartyDetail({
    required this.abbr,
    required this.slug,
    this.name,
    this.nameEn,
    required this.shortName,
    this.seats = 0,
    this.seatsTerritorial = 0,
    this.seatsReserved = 0,
    this.profile,
    this.logo,
    this.members = const [],
    this.version,
  });

  factory PartyDetail.fromJson(Map<String, dynamic> j) {
    final abbr = _s(j['abbr']) ?? '';
    final members = _maps(
      j['members'],
    ).map(MemberBrief.fromJson).where((m) => m.slug.isNotEmpty).toList();
    final reserved = members.where((m) => m.reserved).length;
    return PartyDetail(
      abbr: abbr,
      slug: _s(j['slug']) ?? abbr.toLowerCase(),
      name: _s(j['nameBn']),
      nameEn: _s(j['nameEn']),
      shortName: _s(j['shortBn']) ?? abbr,
      seats: _i(j['seats']) ?? members.length,
      seatsTerritorial: _i(j['seatsTerritorial']) ?? members.length - reserved,
      seatsReserved: _i(j['seatsReserved']) ?? reserved,
      profile: PartyProfile.fromJson(j['profile']),
      logo: PartyLogoInfo.fromJson(j['logo']),
      members: members,
      version: _s(j['version']),
    );
  }

  List<MemberBrief> get territorial =>
      members.where((m) => !m.reserved).toList();
  List<MemberBrief> get reservedMembers =>
      members.where((m) => m.reserved).toList();
}

/* ---------------- fetching ---------------- */

/// What was read this session, per language, so going back and forth between
/// a committee and the list costs nothing; a pull fetches again.
final _held = <String, Object>{};

Future<X> _get<X>(
  String path,
  X Function(Map<String, dynamic>) parse, {
  bool force = false,
}) async {
  final key = '${appLang.value.name}$path';
  final held = _held[key];
  if (held is X && !force) return held;
  final value = parse(await Api.instance.getJson(path));
  _held[key] = value as Object;
  return value;
}

Future<SessionsData> fetchSessions({bool force = false}) =>
    _get('/api/app/v1/sessions', SessionsData.fromJson, force: force);

Future<CommitteesData> fetchCommittees({bool force = false}) =>
    _get('/api/app/v1/committees', CommitteesData.fromJson, force: force);

Future<CommitteeDetail> fetchCommittee(String slug, {bool force = false}) =>
    _get(
      '/api/app/v1/committee/${Uri.encodeComponent(slug)}',
      CommitteeDetail.fromJson,
      force: force,
    );

Future<PartyDetail> fetchParty(String slug, {bool force = false}) => _get(
  '/api/app/v1/party/${Uri.encodeComponent(slug)}',
  PartyDetail.fromJson,
  force: force,
);
