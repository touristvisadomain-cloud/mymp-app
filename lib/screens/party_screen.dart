import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../bn.dart';
import '../data/house.dart';
import '../i18n.dart';
import '../models.dart';
import '../party_logo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'house_widgets.dart';
import 'member_screen.dart';

const _font = 'NotoSansBengali';

/// Seats in the House, and the general (constituency) seats among them; a
/// majority is of the whole House, so a vacancy does not lower the bar.
const _houseSeats = 350;
const _generalSeats = 300;
const _majority = _houseSeats ~/ 2 + 1;

/// One party, as the website's /dol/{slug} page has it: its seats at a
/// glance, who founded it and when, who leads it, its story with its sources,
/// and every member, those elected from seats first and then those for
/// reserved seats.
///
/// The members come from the list already on the phone, so the page opens at
/// once and works with no signal; the profile arrives from /party/{slug}
/// behind it.
class PartyScreen extends StatefulWidget {
  final PartyBrief party;
  const PartyScreen({super.key, required this.party});

  /// A party known only by its slug ("bnp") or abbreviation ("BNP"); the
  /// rest is read from the list on the phone.
  PartyScreen.slug(String slug, {super.key})
    : party = PartyBrief(
        abbr: slug,
        slug: slug.toLowerCase(),
        nameBn: slug,
        shortBn: slug,
        colorHex: '',
        seats: 0,
      );

  @override
  State<PartyScreen> createState() => _PartyScreenState();
}

/// What the page shows, from /party/{slug} when it has arrived and from the
/// list on the phone until then.
class _View {
  final String abbr;
  final String slug;
  final String name;
  final String? nameEn;
  final int seats;
  final int seatsTerritorial;
  final int seatsReserved;
  final List<MemberBrief> territorial;
  final List<MemberBrief> reserved;
  final PartyProfile? profile;
  final PartyLogoInfo? logo;
  final bool full;

  const _View({
    required this.abbr,
    required this.slug,
    required this.name,
    this.nameEn,
    required this.seats,
    required this.seatsTerritorial,
    required this.seatsReserved,
    required this.territorial,
    required this.reserved,
    this.profile,
    this.logo,
    this.full = false,
  });

  factory _View.of(PartyDetail d) => _View(
    abbr: d.abbr,
    slug: d.slug,
    name: d.name ?? d.shortName,
    nameEn: d.nameEn,
    seats: d.seats,
    seatsTerritorial: d.seatsTerritorial,
    seatsReserved: d.seatsReserved,
    territorial: d.territorial,
    reserved: d.reservedMembers,
    profile: d.abbr == 'Ind' ? null : d.profile,
    logo: d.logo,
    full: true,
  );

  factory _View.fromList(PartyBrief party, Bootstrap? data) {
    final p =
        data?.parties
            .where(
              (x) =>
                  (party.abbr.isNotEmpty && x.abbr == party.abbr) ||
                  (party.slug.isNotEmpty && x.slug == party.slug),
            )
            .firstOrNull ??
        party;
    int bySeat(MemberBrief a, MemberBrief b) =>
        (a.seatNo ?? 9999).compareTo(b.seatNo ?? 9999);
    final members = (data?.members ?? const <MemberBrief>[])
        .where((m) => m.party == p.abbr)
        .toList();
    final territorial = members.where((m) => !m.reserved).toList()
      ..sort(bySeat);
    final reserved = members.where((m) => m.reserved).toList()..sort(bySeat);
    return _View(
      abbr: p.abbr,
      slug: p.slug.isNotEmpty ? p.slug : p.abbr.toLowerCase(),
      name: p.nameBn,
      seats: members.isEmpty ? p.seats : members.length,
      seatsTerritorial: territorial.length,
      seatsReserved: reserved.length,
      territorial: territorial,
      reserved: reserved,
    );
  }
}

class _PartyScreenState extends State<PartyScreen>
    with RefetchOnLang<PartyScreen> {
  late Future<PartyDetail> _future = fetchParty(_slug);
  bool _allTerritorial = false;
  bool _allReserved = false;

  String get _slug {
    final p = widget.party;
    if (p.slug.isNotEmpty) return p.slug;
    return p.abbr.toLowerCase();
  }

  @override
  void onLangChanged() => setState(() => _future = fetchParty(_slug));

  void _retry() => setState(() => _future = fetchParty(_slug, force: true));

  @override
  Widget build(BuildContext context) {
    // Redrawn when the list changes, which it does after a language switch.
    return ValueListenableBuilder<Bootstrap?>(
      valueListenable: Api.instance.bootstrap,
      builder: (context, _, _) => FutureBuilder<PartyDetail>(
        future: _future,
        builder: (context, snap) {
          final view = snap.hasData
              ? _View.of(snap.data!)
              : _View.fromList(widget.party, Api.instance.cached);
          return _page(
            context,
            view,
            loading: snap.connectionState == ConnectionState.waiting,
            failed: snap.hasError,
          );
        },
      ),
    );
  }

  Future<void> _share(_View v) => SharePlus.instance.share(
    ShareParams(
      text: '${v.name}\n${Api.page('/dol/${v.slug}')}',
      subject: v.name,
    ),
  );

  void _openMember(MemberBrief m) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => MemberScreen(member: m)));

  Widget _page(
    BuildContext context,
    _View v, {
    required bool loading,
    required bool failed,
  }) {
    final colour = AppColors.party(v.abbr);
    final profile = v.profile;
    final items = <Widget>[
      _head(context, v, colour),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: StatBox(
              label: t('মোট আসন', 'Total seats'),
              value: t.n(v.seats),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatBox(
              label: t('নির্বাচিত', 'Elected'),
              value: t.n(v.seatsTerritorial),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatBox(
              label: t('সংরক্ষিত', 'Reserved'),
              value: t.n(v.seatsReserved),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Container(
        height: 6,
        decoration: BoxDecoration(
          color: colour,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(height: 18),
      if (loading && !v.full)
        const Padding(
          padding: EdgeInsets.only(bottom: 18),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.brand,
              ),
            ),
          ),
        ),
      if (failed && !v.full && v.abbr != 'Ind') ...[
        _profileMissing(context),
        const SizedBox(height: 18),
      ],
      if (profile != null) ...[
        _ProfileCard(view: v, profile: profile, colour: colour),
        const SizedBox(height: 14),
        if (profile.leaderName != null) ...[
          _LeaderCard(profile: profile, colour: colour, onOpen: _openMember),
          const SizedBox(height: 14),
        ],
        _AtAGlance(profile: profile, onOpen: _openMember),
        const SizedBox(height: 24),
      ],
      if (v.abbr == 'Ind') ...[
        Text(
          t(
            'স্বতন্ত্র কোনো রাজনৈতিক দল নয়: এই সংসদ সদস্যরা কোনো দলের প্রার্থী হিসেবে নির্বাচিত হননি, তাই এখানে দলের পরিচিতি নেই।',
            'Independents are not a political party: these Members of Parliament were not elected as the candidates of any party, so there is no party profile here.',
          ),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.inkSoft,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 24),
      ],
      if (v.territorial.isEmpty && v.reserved.isEmpty && !loading)
        EmptyState(
          icon: Icons.group_outlined,
          title: t('কোনো সদস্য নেই', 'No members'),
          body: t(
            'এই দলের কোনো নির্বাচিত সদস্য তালিকায় নেই।',
            'No elected member of this party is on the list.',
          ),
        ),
      ..._members(
        t('আসন থেকে নির্বাচিত', 'Elected from constituencies'),
        v.territorial,
        _allTerritorial,
        () => setState(() => _allTerritorial = !_allTerritorial),
      ),
      ..._members(
        t('সংরক্ষিত নারী আসন', 'Reserved seats for women'),
        v.reserved,
        _allReserved,
        () => setState(() => _allReserved = !_allReserved),
      ),
      if (v.logo != null) _LogoCredit(logo: v.logo!),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(v.name),
        actions: [
          IconButton(
            tooltip: t('শেয়ার', 'Share'),
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(v),
          ),
        ],
      ),
      body: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          AppSizes.pagePad,
          8,
          AppSizes.pagePad,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => items[i],
      ),
    );
  }

  Widget _head(BuildContext context, _View v, Color colour) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: colour.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          PartyLogo(abbr: v.abbr, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('ত্রয়োদশ জাতীয় সংসদ', '13th Parliament'),
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                    height: 1.3,
                  ),
                ),
                Text(v.name, style: Theme.of(context).textTheme.titleLarge),
                if (!t.en && v.nameEn != null)
                  Text(v.nameEn!, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  t.count(
                    v.seats,
                    ' জন সংসদ সদস্য',
                    'Member of Parliament',
                    'Members of Parliament',
                  ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileMissing(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: AppDecor.card(),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t(
                'দলের পরিচিতি এখন আনা গেল না।',
                "The party's profile could not be fetched just now.",
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: _retry,
            child: Text(
              t('আবার চেষ্টা করুন', 'Try again'),
              style: const TextStyle(fontFamily: _font),
            ),
          ),
        ],
      ),
    );
  }

  /// A section of members: the first dozen, the rest one tap away.
  List<Widget> _members(
    String title,
    List<MemberBrief> list,
    bool all,
    VoidCallback toggle,
  ) {
    const shown = 12;
    if (list.isEmpty) return const [];
    final visible = all || list.length <= shown ? list : list.sublist(0, shown);
    return [
      SectionTitle(title, count: t.n(list.length)),
      for (final m in visible) ...[
        HouseMemberRow(member: m, onTap: () => _openMember(m)),
        const SizedBox(height: 10),
      ],
      if (list.length > shown)
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: toggle,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.ink),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: Text(
              all
                  ? t('কম দেখুন', 'Show fewer')
                  : t(
                      'আরও ${t.n(list.length - shown)} জন দেখুন',
                      'Show ${list.length - shown} more',
                    ),
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      const SizedBox(height: 24),
    ];
  }
}

/// "১ সেপ্টেম্বর ১৯৭৮" / "1 September 1978", or "১৯৭৮ সাল" / "1978" when only
/// the year is on record.
String _founded(String on) => RegExp(r'^\d{4}$').hasMatch(on)
    ? t('${t.n(on)} সাল', on)
    : t.date(on) ?? on;

/// "ত্রয়োদশ সংসদে", from the seats as they stand now, as the website words
/// it. (The website adds the House offices the party holds; the app's party
/// route does not carry them, so that sentence is left out.)
String _inParliament(_View v) {
  final tr = v.seatsTerritorial;
  final r = v.seatsReserved;
  final n = v.seats;
  if (t.en) {
    final beyond = n >= _majority
        ? ', ${n - _majority >= 30 ? 'well ' : ''}above the $_majority needed for a majority'
        : '';
    final seats = tr > 0
        ? 'The party now holds $tr of the $_generalSeats constituency seats'
              '${r > 0 ? '; with the reserved seats for women, it has $n members in Parliament in all' : ''}$beyond.'
        : 'The party holds no constituency seat; it has '
              '${r == 1 ? '1 member in a reserved seat' : '$r members in reserved seats'} for women.';
    return "$seats All the party's members and their seats are listed below.";
  }
  final beyond = n >= _majority
      ? ', যা সংখ্যাগরিষ্ঠতার জন্য প্রয়োজনীয় ${t.n(_majority)}-এর ${n - _majority >= 30 ? 'অনেক ' : ''}বেশি'
      : '';
  final seats = tr > 0
      ? '${t.n(_generalSeats)}টি নির্বাচনী আসনের মধ্যে ${t.n(tr)}টি এখন দলটির'
            '${r > 0 ? '; সংরক্ষিত নারী আসন যোগ করে সংসদে দলের মোট সদস্য ${t.n(n)} জন' : ''}$beyond।'
      : 'দলটির কোনো নির্বাচনী আসন নেই; সংরক্ষিত নারী আসনে দলের সদস্য ${t.n(r)} জন।';
  return '$seats দলের সব সদস্যের তালিকা ও আসন নিচে।';
}

/// "দলের পরিচিতি": what the party is, its story, where it stands in this
/// House, and where the account comes from.
class _ProfileCard extends StatelessWidget {
  final _View view;
  final PartyProfile profile;
  final Color colour;
  const _ProfileCard({
    required this.view,
    required this.profile,
    required this.colour,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final body = text.bodyLarge?.copyWith(
      color: AppColors.inkSoft,
      height: 1.8,
    );
    return HouseCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(t('দলের পরিচিতি', 'About the party'), bar: colour),
          if (profile.summary != null) ...[
            Text(
              '${profile.summary} ${t('ত্রয়োদশ সংসদে দলটির সদস্য ${t.n(view.seats)} জন।', 'It has ${t.count(view.seats, '', 'member', 'members')} in the 13th Parliament.')}',
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 10),
          ],
          for (final p in profile.origin) ...[
            Text(p, style: body),
            const SizedBox(height: 10),
          ],
          Text(
            t('ত্রয়োদশ সংসদে', 'In the 13th Parliament'),
            style: text.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(_inParliament(view), style: body),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          InlineLinks([
            ('${t('সূত্র:', 'Sources:')} ', null),
            for (var i = 0; i < profile.sources.length; i++) ...[
              if (i > 0) (', ', null),
              (profile.sources[i].label, profile.sources[i].url),
            ],
            if (profile.sources.isNotEmpty)
              (t(' (দলের ইতিহাস); ', ' (party history); '), null),
            (
              t('বাংলাদেশ জাতীয় সংসদ', 'Parliament of Bangladesh'),
              'https://www.parliament.gov.bd/',
            ),
            (
              ' ${t('(বর্তমান সদস্য ও পদ)।', '(current members and offices).')}',
              null,
            ),
            if (profile.checked != null)
              (
                ' ${t('সর্বশেষ যাচাই ${t.date(profile.checked)}।', 'Last checked ${t.date(profile.checked)}.')}',
                null,
              ),
            if (profile.edited)
              (
                ' ${t('কিছু তথ্য আমার এমপির সম্পাদক হালনাগাদ করেছেন।', "Some of this information has been updated by My MP's editors.")}',
                null,
              ),
          ]),
        ],
      ),
    );
  }
}

/// The party's head: photo, office in the party, any office in the
/// government or House, and the seat; a tap opens the profile when they sit
/// in this parliament.
class _LeaderCard extends StatelessWidget {
  final PartyProfile profile;
  final Color colour;
  final ValueChanged<MemberBrief> onOpen;
  const _LeaderCard({
    required this.profile,
    required this.colour,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final m = profile.leader;
    final name = profile.leaderName!;
    final title = profile.leaderTitle;
    final photo = m != null
        ? MemberAvatar(member: m, size: 64)
        : Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            child: Text(
              initialOf(name),
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          );
    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          photo,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(
                    'দলপ্রধান, ${title ?? 'প্রধান'}',
                    'Party leader${title != null ? ', $title' : ''}',
                  ),
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                    height: 1.35,
                  ),
                ),
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.4,
                  ),
                ),
                if (m?.officeBn != null) ...[
                  const SizedBox(height: 4),
                  Pill(m!.officeBn!, colour: AppColors.ink, filled: true),
                ],
                if (m != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    m.reserved || m.seatBn == null
                        ? t(
                            'সংরক্ষিত নারী আসনের সংসদ সদস্য',
                            'Member of Parliament for a reserved seat for women',
                          )
                        : t(
                            '${m.seatBn} আসনের সংসদ সদস্য',
                            'Member of Parliament for ${m.seatBn}',
                          ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (m != null)
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
              size: 22,
            ),
        ],
      ),
    );
    return Container(
      decoration: AppDecor.card(),
      child: m == null
          ? body
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                onTap: () => onOpen(m),
                child: body,
              ),
            ),
    );
  }
}

/// "এক নজরে": founded, founders, symbol, the second office, headquarters and
/// website.
class _AtAGlance extends StatelessWidget {
  final PartyProfile profile;
  final ValueChanged<MemberBrief> onOpen;
  const _AtAGlance({required this.profile, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final founders = p.founder == null
        ? 0
        : p.founder!.split(t.en ? ' and ' : ' ও ').length;
    final rows = <(String, Widget)>[
      if (p.foundedOn != null)
        (t('প্রতিষ্ঠা', 'Founded'), Text(_founded(p.foundedOn!))),
      if (p.founder != null)
        (
          t('প্রতিষ্ঠাতা', founders > 1 ? 'Founders' : 'Founder'),
          Text(p.founder!),
        ),
      if (p.symbol != null)
        (t('নির্বাচনী প্রতীক', 'Electoral symbol'), Text(p.symbol!)),
      if (p.secretaryName != null)
        (
          p.secretaryTitle ?? t('দ্বিতীয় পদ', 'Second-ranking office'),
          p.secretary != null
              ? Semantics(
                  link: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onOpen(p.secretary!),
                    child: Text(
                      p.secretaryName!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                )
              : Text(
                  p.secretaryName!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
        ),
      if (p.headquarters != null)
        (t('প্রধান কার্যালয়', 'Headquarters'), Text(p.headquarters!)),
      if (p.website != null)
        (
          t('ওয়েবসাইট', 'Website'),
          LinkText(
            p.website!
                .replaceFirst(RegExp(r'^https?://(www\.)?'), '')
                .replaceFirst(RegExp(r'/$'), ''),
            url: p.website!,
          ),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return HouseCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('এক নজরে', 'At a glance'),
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.muted,
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            FactLine(
              label: rows[i].$1,
              value: rows[i].$2,
              last: i == rows.length - 1,
            ),
        ],
      ),
    );
  }
}

/// Where the party's logo (or flag) comes from, and its licence; a CC BY
/// logo names its author.
class _LogoCredit extends StatelessWidget {
  final PartyLogoInfo logo;
  const _LogoCredit({required this.logo});

  @override
  Widget build(BuildContext context) {
    final page = logo.page;
    final where = page != null && page.contains('commons.wikimedia.org')
        ? t('উইকিমিডিয়া কমন্স', 'Wikimedia Commons')
        : t('বাংলা উইকিপিডিয়া', 'Bangla Wikipedia');
    return InlineLinks([
      (
        '${logo.kind == 'flag' ? t('দলের পতাকা', 'Party flag') : t('দলের লোগো', 'Party logo')}: ',
        null,
      ),
      (where, page),
      if (logo.author != null) (', ${logo.author}', null),
      if (logo.licence != null) ...[
        (', ', null),
        (logo.licence!, logo.licenceUrl),
      ],
    ]);
  }
}
