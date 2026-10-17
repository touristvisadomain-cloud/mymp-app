/// The shapes /api/app/v1 answers with. Each one parses defensively: a field
/// the site adds later must never crash a phone that has not been updated.
///
/// The field names say Bn because Bangla came first; with `lang=en` the site
/// sends the same keys carrying English (null where it has no English), so in
/// English `nameBn` holds the English name. A news headline in English is
/// Google Translate's English once the site has it (`titleTranslated`), and
/// the outlet's own Bangla until then.
library;

import 'i18n.dart';

String? _s(dynamic v) => v is String && v.isNotEmpty ? v : null;
int? _i(dynamic v) => v is num ? v.toInt() : null;
bool _b(dynamic v) => v == true;
List<String> _strings(dynamic v) =>
    v is List ? v.whereType<String>().toList() : const [];

class MemberBrief {
  final String id;
  final String slug;
  final String nameBn;
  final String? nameEn;
  final String? photoUrl;
  final String? gender;
  final String? party;
  final String? partyBn;
  final int? seatNo;
  final String? seatBn;
  final String? seatEn;
  final String? districtBn;
  final String? districtEn;

  /// The upazilas the seat covers, for search.
  final String? areaBn;
  final String? officeBn;
  final bool reserved;

  const MemberBrief({
    required this.id,
    required this.slug,
    required this.nameBn,
    this.nameEn,
    this.photoUrl,
    this.gender,
    this.party,
    this.partyBn,
    this.seatNo,
    this.seatBn,
    this.seatEn,
    this.districtBn,
    this.districtEn,
    this.areaBn,
    this.officeBn,
    this.reserved = false,
  });

  factory MemberBrief.fromJson(Map<String, dynamic> j) => MemberBrief(
    id: j['id'] as String? ?? '',
    slug: j['slug'] as String? ?? '',
    nameBn: j['nameBn'] as String? ?? '',
    nameEn: _s(j['nameEn']),
    photoUrl: _s(j['photoUrl']),
    gender: _s(j['gender']),
    party: _s(j['party']),
    partyBn: _s(j['partyBn']),
    seatNo: _i(j['seatNo']),
    seatBn: _s(j['seatBn']),
    seatEn: _s(j['seatEn']),
    districtBn: _s(j['districtBn']),
    districtEn: _s(j['districtEn']),
    areaBn: _s(j['areaBn']),
    officeBn: _s(j['officeBn']),
    reserved: _b(j['reserved']),
  );

  /// "ঢাকা-১৭" for a territorial member, "সংরক্ষিত আসন" for a reserved one.
  String get seatLabel => seatBn ?? t('সংরক্ষিত আসন', 'Reserved seat');
}

class PartyBrief {
  final String abbr;
  final String slug;
  final String nameBn;
  final String shortBn;
  final String colorHex;
  final int seats;

  const PartyBrief({
    required this.abbr,
    required this.slug,
    required this.nameBn,
    required this.shortBn,
    required this.colorHex,
    required this.seats,
  });

  factory PartyBrief.fromJson(Map<String, dynamic> j) => PartyBrief(
    abbr: j['abbr'] as String? ?? '',
    slug: j['slug'] as String? ?? '',
    nameBn: j['nameBn'] as String? ?? j['abbr'] as String? ?? '',
    shortBn:
        j['shortBn'] as String? ??
        j['nameBn'] as String? ??
        j['abbr'] as String? ??
        '',
    colorHex: j['color'] as String? ?? '#9A5FC7',
    seats: _i(j['seats']) ?? 0,
  );
}

class Bootstrap {
  final String version;
  final int parliamentNo;
  final List<MemberBrief> members;
  final List<PartyBrief> parties;
  final List<String> districts;

  /// The Prime Minister, Speaker, Deputy, Opposition Leader and Chief Whip.
  final List<Leader> leaders;

  const Bootstrap({
    required this.version,
    required this.parliamentNo,
    required this.members,
    required this.parties,
    required this.districts,
    this.leaders = const [],
  });

  factory Bootstrap.fromJson(Map<String, dynamic> j) => Bootstrap(
    version: j['version'] as String? ?? '',
    parliamentNo: _i(j['parliamentNo']) ?? 13,
    members: (j['members'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(MemberBrief.fromJson)
        .toList(),
    parties: (j['parties'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PartyBrief.fromJson)
        .toList(),
    districts: _strings(j['districts']),
    leaders: (j['leaders'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Leader.fromJson)
        .where((l) => l.memberId.isNotEmpty)
        .toList(),
  );
}

class Leader {
  final String roleBn;
  final String memberId;
  const Leader({required this.roleBn, required this.memberId});

  factory Leader.fromJson(Map<String, dynamic> j) => Leader(
    roleBn: j['roleBn'] as String? ?? '',
    memberId: j['memberId'] as String? ?? '',
  );
}

/// One candidate in a seat's result.
class Candidate {
  final String name;
  final String? party;
  final String? partyBn;
  final int votes;
  const Candidate({
    required this.name,
    this.party,
    this.partyBn,
    required this.votes,
  });

  factory Candidate.fromJson(Map<String, dynamic> j) => Candidate(
    name: j['name'] as String? ?? '',
    party: _s(j['party']),
    partyBn: _s(j['partyBn']),
    votes: _i(j['votes']) ?? 0,
  );
}

/// A seat's 2026 result, candidates by votes, with where it was read.
class SeatResult {
  final List<Candidate> candidates;
  final String? sourceUrl;
  final String? sourceNote;
  const SeatResult({required this.candidates, this.sourceUrl, this.sourceNote});

  static SeatResult? fromJson(dynamic j) {
    if (j is! Map<String, dynamic>) return null;
    final list = (j['candidates'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Candidate.fromJson)
        .toList();
    if (list.isEmpty) return null;
    return SeatResult(
      candidates: list,
      sourceUrl: _s(j['sourceUrl']),
      sourceNote: _s(j['sourceNote']),
    );
  }
}

class CommitteeRef {
  final String slug;
  final String nameBn;
  final String? role;
  const CommitteeRef({required this.slug, required this.nameBn, this.role});

  factory CommitteeRef.fromJson(Map<String, dynamic> j) => CommitteeRef(
    slug: j['slug'] as String? ?? '',
    nameBn: j['nameBn'] as String? ?? '',
    role: _s(j['role']),
  );
}

class PriorTerm {
  final int parliamentNo;
  final String? seatBn;
  final String? partyAbbr;
  const PriorTerm({required this.parliamentNo, this.seatBn, this.partyAbbr});

  factory PriorTerm.fromJson(Map<String, dynamic> j) => PriorTerm(
    parliamentNo: _i(j['parliamentNo']) ?? _i(j['no']) ?? 0,
    seatBn: _s(j['seatBn']) ?? _s(j['seatNameBn']),
    partyAbbr: _s(j['partyAbbr']) ?? _s(j['party']),
  );
}

class SocialLink {
  final String label;
  final String url;

  /// A Facebook page the site has not confirmed yet; shown with a note.
  final bool unverified;
  const SocialLink({
    required this.label,
    required this.url,
    this.unverified = false,
  });

  factory SocialLink.fromJson(Map<String, dynamic> j) => SocialLink(
    label: j['label'] as String? ?? j['key'] as String? ?? '',
    url: j['url'] as String? ?? '',
    unverified: _b(j['unverified']),
  );
}

class MemberDetail {
  final MemberBrief brief;
  final String? professionBn;
  final String? educationBn;
  final String? birthPlaceBn;
  final String? dateOfBirth;
  final String? fatherBn;
  final String? motherBn;
  final bool isFreedomFighter;
  final String? email;
  final String? bioBn;
  final String? summaryBn;
  final List<String> bioSources;
  final String? partyNameBn;
  final String? partyRoleBn;
  final String? ministryBn;
  final int? termsCount;
  final String? resignedOn;
  final List<String> offices;
  final List<SocialLink> socials;

  /// Shown instead of a Facebook link while the member's page is in dispute.
  final String? facebookNotice;
  final List<CommitteeRef> committees;
  final List<PriorTerm> priorTerms;
  final SeatResult? result;

  const MemberDetail({
    required this.brief,
    this.professionBn,
    this.educationBn,
    this.birthPlaceBn,
    this.dateOfBirth,
    this.fatherBn,
    this.motherBn,
    this.isFreedomFighter = false,
    this.email,
    this.bioBn,
    this.summaryBn,
    this.bioSources = const [],
    this.partyNameBn,
    this.partyRoleBn,
    this.ministryBn,
    this.termsCount,
    this.resignedOn,
    this.offices = const [],
    this.socials = const [],
    this.facebookNotice,
    this.committees = const [],
    this.priorTerms = const [],
    this.result,
  });

  factory MemberDetail.fromJson(Map<String, dynamic> j) => MemberDetail(
    brief: MemberBrief.fromJson(j),
    professionBn: _s(j['professionBn']),
    educationBn: _s(j['educationBn']),
    birthPlaceBn: _s(j['birthPlaceBn']),
    dateOfBirth: _s(j['dateOfBirth']),
    fatherBn: _s(j['fatherBn']),
    motherBn: _s(j['motherBn']),
    isFreedomFighter: _b(j['isFreedomFighter']),
    email: _s(j['email']),
    bioBn: _s(j['bioBn']),
    summaryBn: _s(j['summaryBn']),
    bioSources: _strings(j['bioSources']),
    partyNameBn: _s(j['partyNameBn']),
    partyRoleBn: _s(j['partyRoleBn']),
    ministryBn: _s(j['ministryBn']),
    termsCount: _i(j['termsCount']),
    resignedOn: _s(j['resignedOn']),
    offices: _strings(j['offices']),
    facebookNotice: _s(j['facebookNotice']),
    socials: (j['socials'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SocialLink.fromJson)
        .toList(),
    committees: (j['committees'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(CommitteeRef.fromJson)
        .toList(),
    priorTerms: (j['priorTerms'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PriorTerm.fromJson)
        .toList(),
    result: SeatResult.fromJson(j['result']),
  );
}

class CabinetPost {
  final String title;
  final String? ministryBn;
  final String holderBn;
  final MemberBrief? member;
  final String? photoUrl;

  /// Set for an adviser from outside parliament who has a profile of their own.
  final String? adviserSlug;

  const CabinetPost({
    required this.title,
    this.ministryBn,
    required this.holderBn,
    this.member,
    this.photoUrl,
    this.adviserSlug,
  });

  factory CabinetPost.fromJson(Map<String, dynamic> j) => CabinetPost(
    title: j['title'] as String? ?? '',
    ministryBn: _s(j['ministryBn']),
    holderBn: j['holderBn'] as String? ?? '',
    member: j['member'] is Map<String, dynamic>
        ? MemberBrief.fromJson(j['member'] as Map<String, dynamic>)
        : null,
    photoUrl: _s(j['photoUrl']),
    adviserSlug: _s(j['adviserSlug']),
  );

  /// The name without the "জনাব" the cabinet list puts before it.
  String get plainHolder =>
      holderBn.replaceFirst(RegExp(r'^জনাব\s+'), '').trim();
}

class AdviserPost {
  final String title;
  final String? ministryBn;
  final String? fromDate;
  const AdviserPost({required this.title, this.ministryBn, this.fromDate});

  factory AdviserPost.fromJson(Map<String, dynamic> j) => AdviserPost(
    title: j['title'] as String? ?? '',
    ministryBn: _s(j['ministryBn']),
    fromDate: _s(j['fromDate']),
  );
}

/// A cabinet member from outside parliament: an adviser to the Prime Minister,
/// or a technocrat minister.
class AdviserDetail {
  final String slug;
  final String nameBn;
  final String roleBn;
  final String? rankBn;
  final String bioBn;
  final String? professionBn;
  final String? educationBn;
  final String? birthPlaceBn;
  final String? partyRoleBn;
  final String? photoUrl;
  final List<String> sources;
  final List<AdviserPost> posts;

  const AdviserDetail({
    required this.slug,
    required this.nameBn,
    required this.roleBn,
    this.rankBn,
    required this.bioBn,
    this.professionBn,
    this.educationBn,
    this.birthPlaceBn,
    this.partyRoleBn,
    this.photoUrl,
    this.sources = const [],
    this.posts = const [],
  });

  factory AdviserDetail.fromJson(Map<String, dynamic> j) => AdviserDetail(
    slug: j['slug'] as String? ?? '',
    nameBn: j['nameBn'] as String? ?? '',
    roleBn:
        j['roleBn'] as String? ??
        t('প্রধানমন্ত্রীর উপদেষ্টা', 'Adviser to the Prime Minister'),
    rankBn: _s(j['rankBn']),
    bioBn: j['bioBn'] as String? ?? '',
    professionBn: _s(j['professionBn']),
    educationBn: _s(j['educationBn']),
    birthPlaceBn: _s(j['birthPlaceBn']),
    partyRoleBn: _s(j['partyRoleBn']),
    photoUrl: _s(j['photoUrl']),
    sources: _strings(j['sources']),
    posts: (j['posts'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AdviserPost.fromJson)
        .toList(),
  );
}

class StoryLink {
  /// The headline to show: the outlet's own, or on English its machine
  /// translation when the site has one.
  final String title;
  final String source;
  final String url;

  /// On English: the outlet's own headline, as published (usually Bangla).
  /// Null on Bangla, and from a site older than the translations.
  final String? titleOriginal;

  /// On English: [title] is Google Translate's translation of
  /// [titleOriginal]. False on Bangla and from an older site.
  final bool titleTranslated;

  const StoryLink({
    required this.title,
    required this.source,
    required this.url,
    this.titleOriginal,
    this.titleTranslated = false,
  });

  factory StoryLink.fromJson(Map<String, dynamic> j) => StoryLink(
    title: j['title'] as String? ?? '',
    source: j['source'] as String? ?? '',
    url: j['url'] as String? ?? '',
    titleOriginal: _s(j['titleOriginal']),
    titleTranslated: _b(j['titleTranslated']),
  );
}

class StoryMember {
  final String slug;
  final String name;
  final String? party;
  const StoryMember({required this.slug, required this.name, this.party});

  factory StoryMember.fromJson(Map<String, dynamic> j) => StoryMember(
    slug: j['slug'] as String? ?? '',
    name: j['name'] as String? ?? '',
    party: _s(j['party']),
  );
}

class Story {
  final String id;
  final String date;

  /// The moment it was published, with the clock time ("2026-10-16T18:59:00Z"),
  /// when the site sends it; [date] is only the day.
  final String? publishedAt;
  final String dateLabel;
  final StoryLink lead;
  final List<StoryLink> also;
  final List<StoryMember> members;
  final String kind;
  final String? thumbnail;
  final int? durationSeconds;

  const Story({
    required this.id,
    required this.date,
    this.publishedAt,
    required this.dateLabel,
    required this.lead,
    this.also = const [],
    this.members = const [],
    this.kind = 'news',
    this.thumbnail,
    this.durationSeconds,
  });

  bool get isVideo => kind == 'video';

  /// Its headline is a machine translation (English only).
  bool get translated => lead.titleTranslated;

  factory Story.fromJson(Map<String, dynamic> j) {
    final people = <StoryMember>[];
    final list = j['members'];
    if (list is List) {
      people.addAll(
        list.whereType<Map<String, dynamic>>().map(StoryMember.fromJson),
      );
    } else if (j['member'] is Map<String, dynamic>) {
      people.add(StoryMember.fromJson(j['member'] as Map<String, dynamic>));
    }
    return Story(
      id: j['id'] as String? ?? '',
      date: j['date'] as String? ?? '',
      publishedAt: _s(j['publishedAt']),
      dateLabel: j['dateLabel'] as String? ?? '',
      lead: StoryLink.fromJson(
        (j['lead'] as Map<String, dynamic>?) ?? const {},
      ),
      also: (j['also'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(StoryLink.fromJson)
          .toList(),
      members: people,
      kind: j['kind'] as String? ?? 'news',
      thumbnail: _s(j['thumbnail']),
      durationSeconds: _i(j['durationSeconds']),
    );
  }
}
