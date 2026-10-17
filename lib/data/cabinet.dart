/// The cabinet and the people on it from outside Parliament, as the website's
/// মন্ত্রিসভা / Cabinet page (`/ministers`) and its adviser pages
/// (`/ministers/<slug>`) show them: `/api/app/v1/cabinet` and
/// `/api/app/v1/adviser/<slug>` (docs/app-api.md).
///
/// Everything parses defensively, like lib/models.dart: a field the site adds
/// later never crashes a phone that has not been updated, and a field with no
/// English (null on `?lang=en`) stays null, never Bangla.
///
/// The second half turns the list into what the page draws: one card per
/// person and rank, the ranks in the page's order, the ministry filter, the
/// party make-up. It is plain code, so the tests can check it without a
/// screen. It is the same grouping as the site's src/app/[lang]/(site)/
/// ministers/page.tsx and src/components/MinistersBrowser.tsx.
library;

import 'dart:ui' show Color;

import '../api.dart';
import '../bn.dart';
import '../i18n.dart';
import '../models.dart';
import '../theme.dart';

String? _s(dynamic v) => v is String && v.trim().isNotEmpty ? v : null;
bool _b(dynamic v) => v == true;
List<Map<String, dynamic>> _maps(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

/// The list writes "জনাব" before most names; the site's names never carry it.
String plainName(String name) =>
    name.replaceFirst(RegExp(r'^জনাব\s+'), '').trim();

/// One row of the Cabinet Division's list: one post and one ministry. A person
/// with three ministries has three rows.
class CabinetRow {
  /// The rank: "প্রধানমন্ত্রী" … "উপদেষ্টা" / "Prime Minister" … "Adviser";
  /// null on English for a title the site has no English for.
  final String? title;
  final String? ministryBn;
  final String? fromDate;
  final MemberBrief? member;

  /// The member's Bangla name and seat on an English answer, for search.
  final String? nameAlt;
  final String? seatAlt;

  /// As the list writes it (Bangla with "জনাব"); null on English when the
  /// site knows no English name.
  final String? holderBn;
  final String? photoUrl;
  final String? adviserSlug;

  /// "মন্ত্রীর পদমর্যাদা" / "With the rank of a minister".
  final String? rankNoteBn;
  final String? sourceUrl;

  const CabinetRow({
    this.title,
    this.ministryBn,
    this.fromDate,
    this.member,
    this.nameAlt,
    this.seatAlt,
    this.holderBn,
    this.photoUrl,
    this.adviserSlug,
    this.rankNoteBn,
    this.sourceUrl,
  });

  factory CabinetRow.fromJson(Map<String, dynamic> j) {
    final m = j['member'];
    return CabinetRow(
      title: _s(j['title']),
      ministryBn: _s(j['ministryBn']),
      fromDate: _s(j['fromDate']),
      member: m is Map<String, dynamic> ? MemberBrief.fromJson(m) : null,
      nameAlt: m is Map<String, dynamic> ? _s(m['nameAlt']) : null,
      seatAlt: m is Map<String, dynamic> ? _s(m['seatAlt']) : null,
      holderBn: _s(j['holderBn']),
      photoUrl: _s(j['photoUrl']),
      adviserSlug: _s(j['adviserSlug']),
      rankNoteBn: _s(j['rankNoteBn']),
      sourceUrl: _s(j['sourceUrl']),
    );
  }
}

/// On the list, not yet confirmed by an editor as an MP or not.
class PendingHolder {
  final String? titleBn;

  /// Always null on English: the list gives these names in Bangla only.
  final String? nameBn;
  final List<String?> ministries;
  const PendingHolder({this.titleBn, this.nameBn, this.ministries = const []});

  factory PendingHolder.fromJson(Map<String, dynamic> j) => PendingHolder(
    titleBn: _s(j['titleBn']),
    nameBn: _s(j['nameBn']),
    ministries: j['ministries'] is List
        ? (j['ministries'] as List).map(_s).toList()
        : const [],
  );
}

/// One line of the পরিবর্তন / Changes log.
class CabinetChange {
  final String date;
  final String? nameBn;
  final String? memberSlug;

  /// "start" (took office), "end" (left) or "change" (both on one day).
  final String kind;

  /// "পানি সম্পদ মন্ত্রণালয়: দায়িত্ব পেলেন" / "…: took office".
  final String? textBn;
  const CabinetChange({
    required this.date,
    this.nameBn,
    this.memberSlug,
    this.kind = 'start',
    this.textBn,
  });

  factory CabinetChange.fromJson(Map<String, dynamic> j) => CabinetChange(
    date: _s(j['date']) ?? '',
    nameBn: _s(j['nameBn']),
    memberSlug: _s(j['memberSlug']),
    kind: _s(j['kind']) ?? 'start',
    textBn: _s(j['textBn']),
  );
}

class CabinetData {
  /// When the list was last checked against the Cabinet Division's.
  final String? checkedAt;
  final String? sourceUrl;
  final List<CabinetRow> posts;
  final List<PendingHolder> pending;
  final List<CabinetChange> changes;

  const CabinetData({
    this.checkedAt,
    this.sourceUrl,
    this.posts = const [],
    this.pending = const [],
    this.changes = const [],
  });

  factory CabinetData.fromJson(Map<String, dynamic> j) => CabinetData(
    checkedAt: _s(j['checkedAt']),
    sourceUrl: _s(j['sourceUrl']),
    posts: _maps(j['posts']).map(CabinetRow.fromJson).toList(),
    pending: _maps(j['pending']).map(PendingHolder.fromJson).toList(),
    changes: _maps(
      j['changes'],
    ).map(CabinetChange.fromJson).where((c) => c.date.isNotEmpty).toList(),
  );
}

Future<CabinetData> fetchCabinet() async =>
    CabinetData.fromJson(await Api.instance.getJson('/api/app/v1/cabinet'));

/// A current post of someone from outside Parliament.
class AdviserPostRow {
  final String? title;
  final String? ministryBn;
  final String? fromDate;
  const AdviserPostRow({this.title, this.ministryBn, this.fromDate});

  factory AdviserPostRow.fromJson(Map<String, dynamic> j) => AdviserPostRow(
    title: _s(j['title']),
    ministryBn: _s(j['ministryBn']),
    fromDate: _s(j['fromDate']),
  );
}

class SourceLink {
  final String url;
  final String label;
  const SourceLink({required this.url, required this.label});
}

/// Someone on the cabinet list from outside Parliament: an adviser to the
/// Prime Minister, or a technocrat minister.
class AdviserProfile {
  final String slug;

  /// The name as the cabinet list writes it; always null on English.
  final String? postNameBn;

  /// Null on English when no English name is known.
  final String? nameBn;
  final String roleBn;
  final String? rankBn;
  final String? bioBn;
  final bool bioTranslated;
  final String? professionBn;
  final String? educationBn;
  final String? birthPlaceBn;
  final String? partyRoleBn;
  final List<SourceLink> sources;
  final String? checkedOn;
  final String? photoUrl;
  final List<AdviserPostRow> posts;

  const AdviserProfile({
    required this.slug,
    this.postNameBn,
    this.nameBn,
    required this.roleBn,
    this.rankBn,
    this.bioBn,
    this.bioTranslated = false,
    this.professionBn,
    this.educationBn,
    this.birthPlaceBn,
    this.partyRoleBn,
    this.sources = const [],
    this.checkedOn,
    this.photoUrl,
    this.posts = const [],
  });

  factory AdviserProfile.fromJson(Map<String, dynamic> j) {
    // The named links when the site sends them, else the bare addresses
    // named the way the site names them.
    final named = _maps(j['sourceLinks'])
        .where((l) => _s(l['url']) != null)
        .map(
          (l) => SourceLink(
            url: l['url'] as String,
            label: _s(l['label']) ?? sourceName(l['url'] as String),
          ),
        )
        .toList();
    final bare = j['sources'] is List
        ? (j['sources'] as List)
              .map(_s)
              .whereType<String>()
              .map((u) => SourceLink(url: u, label: sourceName(u)))
              .toList()
        : <SourceLink>[];
    return AdviserProfile(
      slug: _s(j['slug']) ?? '',
      postNameBn: _s(j['postNameBn']),
      nameBn: _s(j['nameBn']),
      roleBn:
          _s(j['roleBn']) ??
          t('প্রধানমন্ত্রীর উপদেষ্টা', 'Adviser to the Prime Minister'),
      rankBn: _s(j['rankBn']),
      bioBn: _s(j['bioBn']),
      bioTranslated: _b(j['bioTranslated']),
      professionBn: _s(j['professionBn']),
      educationBn: _s(j['educationBn']),
      birthPlaceBn: _s(j['birthPlaceBn']),
      partyRoleBn: _s(j['partyRoleBn']),
      sources: named.isNotEmpty ? named : bare,
      checkedOn: _s(j['checkedOn']),
      photoUrl: _s(j['photoUrl']),
      posts: _maps(j['posts']).map(AdviserPostRow.fromJson).toList(),
    );
  }
}

Future<AdviserProfile> fetchAdviser(String slug) async =>
    AdviserProfile.fromJson(
      await Api.instance.getJson('/api/app/v1/adviser/$slug'),
    );

/// "উইকিপিডিয়া (বাংলা)" for a cited address, the way the website names it
/// (src/lib/sourceLabel.ts), for a source that came without a label.
String sourceName(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
  final wiki = RegExp(r'^(\w+)\.wikipedia\.org$').firstMatch(host);
  if (wiki != null) {
    final l = wiki.group(1);
    final which = l == 'bn'
        ? t('বাংলা', 'Bangla')
        : l == 'en'
        ? t('ইংরেজি', 'English')
        : l;
    return '${t('উইকিপিডিয়া', 'Wikipedia')} ($which)';
  }
  if (host.endsWith('parliament.gov.bd')) {
    return t('জাতীয় সংসদ', 'Parliament of Bangladesh');
  }
  if (host.endsWith('cabinet.gov.bd')) {
    return t('মন্ত্রিপরিষদ বিভাগ', 'Cabinet Division');
  }
  return host.isEmpty ? url : host;
}

// ---------------------------------------------------------------------------
// The page, built from the list.
// ---------------------------------------------------------------------------

/// A rank as the page shows it. The API sends the title in the reader's
/// language, so a rank is known by either spelling (and the spellings the
/// Cabinet Division has used before).
class CabinetRank {
  final String bn;
  final List<String> en;

  /// The tile's and the section's name in English, plural as the tiles count.
  final String enPlural;

  /// The line under the rank's tile.
  final String shortBn;
  final String shortEn;

  /// The line under the rank's heading.
  final String noteBn;
  final String noteEn;

  const CabinetRank({
    required this.bn,
    required this.en,
    required this.enPlural,
    required this.shortBn,
    required this.shortEn,
    required this.noteBn,
    required this.noteEn,
  });

  bool names(String? title) =>
      title != null && (title == bn || en.contains(title));
}

/// The page's order: the Prime Minister, ministers, state ministers, deputy
/// ministers, advisers. Not the list's order, which puts each source page's
/// people in turn.
const cabinetRanks = [
  CabinetRank(
    bn: 'প্রধানমন্ত্রী',
    en: ['Prime Minister'],
    enPlural: 'Prime Minister',
    shortBn: 'সরকারপ্রধান',
    shortEn: 'Head of government',
    noteBn: 'সরকারপ্রধান, মন্ত্রিসভার সভাপতি।',
    noteEn: 'Head of government, who chairs the Cabinet.',
  ),
  CabinetRank(
    bn: 'মন্ত্রী',
    en: ['Minister'],
    enPlural: 'Ministers',
    shortBn: 'মন্ত্রণালয়ের পূর্ণ দায়িত্বে',
    shortEn: 'In full charge of a ministry',
    noteBn: 'মন্ত্রণালয়ের পূর্ণ দায়িত্বে।',
    noteEn: 'In full charge of a ministry.',
  ),
  CabinetRank(
    bn: 'প্রতিমন্ত্রী',
    en: ['State Minister', 'Minister of State'],
    enPlural: 'State Ministers',
    shortBn: 'পদমর্যাদায় মন্ত্রীর পরে',
    shortEn: 'Next in rank below a minister',
    noteBn:
        'মন্ত্রীর সঙ্গে বা একাই কোনো মন্ত্রণালয়ের দায়িত্বে, পদমর্যাদায় মন্ত্রীর পরে।',
    noteEn:
        'In charge of a ministry with a minister or alone; next in rank below a minister.',
  ),
  CabinetRank(
    bn: 'উপমন্ত্রী',
    en: ['Deputy Minister'],
    enPlural: 'Deputy Ministers',
    shortBn: 'প্রতিমন্ত্রীর পরের ধাপ',
    shortEn: 'The step below a state minister',
    noteBn: 'প্রতিমন্ত্রীর পরের ধাপ।',
    noteEn: 'The step below a state minister.',
  ),
  CabinetRank(
    bn: 'উপদেষ্টা',
    en: ['Adviser', 'Advisor'],
    enPlural: 'Advisers',
    shortBn: 'প্রধানমন্ত্রীর পরামর্শক',
    shortEn: 'Advises the Prime Minister',
    noteBn:
        'নির্দিষ্ট বিষয়ে প্রধানমন্ত্রীকে পরামর্শ দেন; বেশিরভাগ উপদেষ্টা সংসদ সদস্য নন।',
    noteEn:
        'Advises the Prime Minister on particular matters; most advisers are not Members of Parliament.',
  ),
];

/// The rank a title names, in either language; null for a title the page
/// does not know, which then follows the known ranks.
CabinetRank? rankOf(String? title) {
  for (final r in cabinetRanks) {
    if (r.names(title)) return r;
  }
  return null;
}

/// "বাংলাদেশ জাতীয়তাবাদী দল (বি.এন.পি)" / "Bangladesh Nationalist Party
/// (BNP)": the name the cabinet page gives a party, from the member list the
/// app already holds; null until it is there in the reader's language.
String? fullPartyName(String? abbr) {
  if (abbr == null) return null;
  for (final p in Api.instance.cached?.parties ?? const <PartyBrief>[]) {
    if (p.abbr != abbr || p.nameBn.isEmpty) continue;
    final bangla = RegExp('[ঀ-৿]').hasMatch(p.nameBn);
    return bangla == !t.en ? p.nameBn : null;
  }
  return null;
}

/// The party's colour, as the website draws it. (The site's code for Jamaat
/// is BJEI; the app's palette keys it as "Jamaat".)
Color partyColour(String? abbr) =>
    AppColors.party(abbr == 'BJEI' ? 'Jamaat' : abbr);

/// A ministry name for grouping and filtering: the list's typing slips (a
/// sign typed twice, "বিজ্ঞানও প্রযুক্তি", a stray joiner) must not make a
/// second ministry. The cards still show the list's own text. (The site's
/// ministryKey in src/lib/posts/names.ts.)
String ministryKey(String name) => _foldBangla(name)
    .replaceAllMapped(RegExp(r'([ংঃা-ৌ])\1+'), (m) => m[1]!)
    .replaceAllMapped(RegExp(r'(\S)ও\s'), (m) => '${m[1]} ও ')
    .replaceAll(RegExp(r'[,.]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The site's foldBangla (src/lib/matching/nameMatch.ts): spellings a reader
/// would not call different. (Dart has no NFC; the list's text comes
/// composed.)
String _foldBangla(String s) => s
    .replaceAll(RegExp('[​-‍﻿]'), '')
    .replaceAll('্', '') // hasanta: "প্রযু্ক্তি" and "প্রযুক্তি"
    .replaceAll('়', '') // nukta
    .replaceAll('ী', 'ি')
    .replaceAll('ূ', 'ু')
    .replaceAll('ণ', 'ন')
    .replaceAll(RegExp('[ষশ]'), 'স')
    .replaceAll('ৎ', 'ত')
    .replaceAll('ঁ', '')
    .toLowerCase();

class MinisterPortfolio {
  /// Null on English while the ministry has no English name.
  final String? name;
  final String key;
  final String? since;
  const MinisterPortfolio({this.name, required this.key, this.since});
}

/// One card: a person in one rank, with every ministry they hold in it.
class MinisterPerson {
  final String key;
  final String? title;

  /// Null on English when the site has no English name for them.
  final String? name;
  final MemberBrief? member;
  final String? nameAlt;
  final String? seatAlt;
  final String? adviserSlug;
  final String? photoUrl;
  final String? rankNote;
  final bool pending;
  final String? sourceUrl;
  final List<MinisterPortfolio> ministries;

  MinisterPerson({
    required this.key,
    this.title,
    this.name,
    this.member,
    this.nameAlt,
    this.seatAlt,
    this.adviserSlug,
    this.photoUrl,
    this.rankNote,
    this.pending = false,
    this.sourceUrl,
    List<MinisterPortfolio>? ministries,
  }) : ministries = ministries ?? [];

  bool get isMp => member != null;
  String? get party => member?.party;

  /// The party's full name, as the page writes it, when the member list is
  /// at hand; its short name otherwise.
  String? get partyName =>
      fullPartyName(party) ?? member?.partyBn ?? member?.party;
  String? get seat => member?.seatBn;
  Color? get colour => member?.party == null ? null : partyColour(party);

  /// The name, or what stands in for it on English when there is none.
  String get shownName =>
      name ?? t('নাম জানা নেই', 'Name given only in Bangla');

  String get initial => initialOf(name ?? '');

  /// A name, a ministry or a seat, as typed: any part of any matches. On
  /// English the Bangla name and seat match too.
  bool matches(String q) {
    if (q.isEmpty) return true;
    bool has(String? s) => s != null && s.toLowerCase().contains(q);
    return has(name) ||
        has(nameAlt) ||
        has(seat) ||
        has(seatAlt) ||
        ministries.any((m) => has(m.name));
  }
}

class MinisterGroup {
  /// The title as the API sends it, the group's key.
  final String title;
  final CabinetRank? rank;
  final List<MinisterPerson> people;
  const MinisterGroup({required this.title, this.rank, required this.people});

  /// "মন্ত্রী" / "Ministers".
  String get label => rank == null
      ? (title.isEmpty ? t('অন্যান্য', 'Other') : title)
      : t(rank!.bn, rank!.enPlural);

  bool get isPrimeMinister => identical(rank, cabinetRanks.first);
}

class MinistryOption {
  final String key;
  final String label;
  final int count;
  const MinistryOption(this.key, this.label, this.count);
}

/// The page: the ranks in order (an empty one too, which the page says is
/// empty), and the ministries the filter offers.
class Cabinet {
  final List<MinisterGroup> groups;
  final List<MinistryOption> ministries;
  const Cabinet(this.groups, this.ministries);

  List<MinisterPerson> get everyone => [for (final g in groups) ...g.people];

  int count(CabinetRank r) =>
      groups.where((g) => g.rank == r).fold(0, (n, g) => n + g.people.length);

  factory Cabinet.of(CabinetData data, {String? pendingSource}) {
    final people = <String, MinisterPerson>{};
    for (final r in data.posts) {
      final m = r.member;
      final who = m?.id.isNotEmpty == true
          ? m!.id
          : r.adviserSlug ?? r.holderBn ?? r.photoUrl ?? '';
      final key = '${r.title}|$who';
      final p = people.putIfAbsent(
        key,
        () => MinisterPerson(
          key: key,
          title: r.title,
          name:
              m?.nameBn ?? (r.holderBn == null ? null : plainName(r.holderBn!)),
          member: m,
          nameAlt: r.nameAlt,
          seatAlt: r.seatAlt,
          adviserSlug: m == null ? r.adviserSlug : null,
          photoUrl: m?.photoUrl ?? r.photoUrl,
          rankNote: r.rankNoteBn,
          sourceUrl: r.sourceUrl,
        ),
      );
      p.ministries.add(
        MinisterPortfolio(
          name: r.ministryBn,
          key: r.ministryBn == null
              ? '#${p.ministries.length}'
              : ministryKey(r.ministryBn!),
          since: t.date(r.fromDate),
        ),
      );
    }
    for (final x in data.pending) {
      final key = '${x.titleBn}|pending|${x.nameBn ?? people.length}';
      people[key] = MinisterPerson(
        key: key,
        title: x.titleBn,
        name: x.nameBn == null ? null : plainName(x.nameBn!),
        pending: true,
        sourceUrl: pendingSource ?? data.sourceUrl,
        ministries: [
          for (final (i, n) in x.ministries.indexed)
            MinisterPortfolio(name: n, key: n == null ? '#$i' : ministryKey(n)),
        ],
      );
    }

    final all = people.values.toList();
    // The known ranks in the page's order, each one even when empty; then any
    // other title the list has, in the order it first appears.
    final groups = <MinisterGroup>[
      for (final r in cabinetRanks)
        MinisterGroup(
          title: t(r.bn, r.en.first),
          rank: r,
          people: all.where((p) => r.names(p.title)).toList(),
        ),
    ];
    final others = <String>[];
    for (final p in all) {
      final title = p.title ?? '';
      if (rankOf(p.title) == null && !others.contains(title)) {
        others.add(title);
      }
    }
    for (final title in others) {
      groups.add(
        MinisterGroup(
          title: title,
          people: all
              .where((p) => rankOf(p.title) == null && (p.title ?? '') == title)
              .toList(),
        ),
      );
    }

    // A ministry with no name in this language cannot be offered.
    final options = <String, ({String label, int count})>{};
    for (final p in all) {
      final seen = <String>{};
      for (final m in p.ministries) {
        if (m.name == null || !seen.add(m.key)) continue;
        final e = options[m.key];
        options[m.key] = (
          label: e?.label ?? m.name!,
          count: (e?.count ?? 0) + 1,
        );
      }
    }
    final ministries = [
      for (final e in options.entries)
        MinistryOption(e.key, e.value.label, e.value.count),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return Cabinet(groups, ministries);
  }
}

/// One share of the composition bar: a party, or everyone who is not an MP.
class CabinetShare {
  /// The party's code, or null for those who are not MPs.
  final String? party;
  final String label;
  final Color colour;
  final int count;
  const CabinetShare(this.party, this.label, this.colour, this.count);
  bool get outside => party == null;
}

/// The whole cabinet by party, the largest first, those who are not MPs
/// last and apart.
List<CabinetShare> compositionOf(List<MinisterPerson> people) {
  final parts = <String?, ({String label, Color colour, int n})>{};
  for (final p in people) {
    final k = p.isMp && p.party != null ? p.party : null;
    final e = parts[k];
    parts[k] = (
      label: k == null
          ? t('সংসদ সদস্য নন', 'Not an MP')
          : (e?.label ?? p.partyName ?? k),
      colour: k == null ? AppColors.muted : partyColour(k),
      n: (e?.n ?? 0) + 1,
    );
  }
  final list = [
    for (final e in parts.entries)
      CabinetShare(e.key, e.value.label, e.value.colour, e.value.n),
  ];
  list.sort((a, b) {
    if (a.outside != b.outside) return a.outside ? 1 : -1;
    return b.count.compareTo(a.count);
  });
  return list;
}
