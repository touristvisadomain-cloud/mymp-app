import 'package:flutter/material.dart';

import '../data/cabinet.dart'
    show CabinetData, CabinetRank, cabinetRanks, fetchCabinet;
import '../data/election.dart';
import '../i18n.dart';
import '../models.dart';
import '../theme.dart';
import 'cabinet_screen.dart';
import 'election_parts.dart';
import 'member_screen.dart';
import 'statistics_screen.dart';

/// The top of the members tab, as the website's home page has it: four facts
/// at a glance (women, first-time members, the cabinet, the youngest member),
/// each opening the screen that has the rest, and the House's composition:
/// the governing party against the majority, one bar of every party's
/// elected and reserved seats, the four largest parties and the rest, and the
/// Speaker. (src/app/[lang]/(site)/page.tsx and
/// src/components/HouseComposition.tsx in the website.)
///
/// The composition and the women are counted from the member list the app
/// keeps offline; the first-time members and the youngest come from
/// /election (the statistics screen's answer), the cabinet from /cabinet. A
/// fact whose answer does not arrive is left out, never shown wrong.
class HouseOverview extends StatefulWidget {
  final Bootstrap data;

  /// What the cabinet tile does: the shell switches to the cabinet tab.
  /// Without it the cabinet opens as a page of its own.
  final VoidCallback? onShowCabinet;

  const HouseOverview({super.key, required this.data, this.onShowCabinet});

  @override
  State<HouseOverview> createState() => _HouseOverviewState();
}

class _HouseOverviewState extends State<HouseOverview>
    with RefetchOnLang<HouseOverview> {
  late Future<ElectionData> _election = fetchElection();
  late Future<CabinetData> _cabinet = fetchCabinet();

  @override
  void onLangChanged() => setState(() {
    _election = fetchElection();
    _cabinet = fetchCabinet();
  });

  @override
  Widget build(BuildContext context) {
    final makeup = HouseMakeup.of(widget.data);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePad,
        16,
        AppSizes.pagePad,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<ElectionData>(
            future: _election,
            builder: (context, election) => FutureBuilder<CabinetData>(
              future: _cabinet,
              builder: (context, cabinet) => HouseFacts(
                makeup: makeup,
                election: election.data,
                electionPending: !election.hasData && !election.hasError,
                cabinet: cabinet.data == null
                    ? null
                    : CabinetSummary.of(cabinet.data!),
                cabinetPending: !cabinet.hasData && !cabinet.hasError,
                onShowCabinet: widget.onShowCabinet,
              ),
            ),
          ),
          if (makeup.parties.isNotEmpty) ...[
            const SizedBox(height: 14),
            HouseCompositionCard(makeup: makeup),
          ],
        ],
      ),
    );
  }
}

/* ---------------- the figures ---------------- */

/// One party's members: those elected from a seat and those in a reserved
/// seat for women.
class HouseShare {
  final String abbr;

  /// "বিএনপি" / "BNP".
  final String short;

  /// The full name, for screen readers.
  final String name;
  final int territorial;
  final int reserved;
  const HouseShare({
    required this.abbr,
    required this.short,
    required this.name,
    required this.territorial,
    required this.reserved,
  });
  int get seats => territorial + reserved;
}

/// The House as the website's home page counts it (statistics() in the site's
/// src/lib/data.ts): the sitting members, by party, most first.
class HouseMakeup {
  /// 300 general seats and 50 reserved for women.
  static const generalSeats = 300;
  static const reservedSeats = 50;
  static const houseSeats = generalSeats + reservedSeats;

  /// A majority of the whole House, not of whoever sits today: a vacancy does
  /// not lower the bar (176).
  static const majority = houseSeats ~/ 2 + 1;

  /// Every party with a member, most members first.
  final List<HouseShare> parties;

  /// Sitting members, those for general seats and those for reserved seats.
  final int total, territorial, reserved;
  final int women, womenTerritorial, womenReserved;

  /// The governing party: the Prime Minister's.
  final HouseShare? lead;
  final MemberBrief? speaker;

  /// The sitting members by id.
  final Map<String, MemberBrief> byId;

  const HouseMakeup({
    required this.parties,
    required this.total,
    required this.territorial,
    required this.reserved,
    required this.women,
    required this.womenTerritorial,
    required this.womenReserved,
    this.lead,
    this.speaker,
    this.byId = const {},
  });

  /// The four largest parties get a row each; the rest fold into one.
  List<HouseShare> get top => parties.take(4).toList();
  List<HouseShare> get rest => parties.skip(4).toList();
  int get restSeats => rest.fold(0, (n, p) => n + p.seats);

  /// The governing party's share of the sitting members, in whole per cent.
  int get leadShare =>
      lead == null || total == 0 ? 0 : (lead!.seats * 100 / total).round();

  /// Seats the governing party has over the majority (negative when short).
  int get leadOver => lead == null ? 0 : lead!.seats - majority;

  factory HouseMakeup.of(Bootstrap b) {
    final elected = <String, int>{};
    final reservedBy = <String, int>{};
    var territorial = 0, reserved = 0;
    var women = 0, womenTerritorial = 0, womenReserved = 0;
    for (final m in b.members) {
      final female = m.gender == 'Female';
      if (female) women++;
      if (m.reserved) {
        reserved++;
        if (female) womenReserved++;
      } else {
        territorial++;
        if (female) womenTerritorial++;
      }
      final p = m.party;
      if (p == null) continue;
      final into = m.reserved ? reservedBy : elected;
      into[p] = (into[p] ?? 0) + 1;
    }

    // In the order the list names the parties, then any it does not.
    final order = [
      for (final p in b.parties) p.abbr,
      for (final a in {...elected.keys, ...reservedBy.keys})
        if (!b.parties.any((p) => p.abbr == a)) a,
    ];
    final named = {for (final p in b.parties) p.abbr: p};
    final parties = [
      for (final abbr in order)
        if ((elected[abbr] ?? 0) + (reservedBy[abbr] ?? 0) > 0)
          HouseShare(
            abbr: abbr,
            short: _orElse(named[abbr]?.shortBn, abbr),
            name: _orElse(named[abbr]?.nameBn, abbr),
            territorial: elected[abbr] ?? 0,
            reserved: reservedBy[abbr] ?? 0,
          ),
    ];
    // Stable, so parties with as many members keep the list's order.
    _stableSort(parties, compare: (a, b) => b.seats.compareTo(a.seats));

    final byId = {for (final m in b.members) m.id: m};
    MemberBrief? holder(Set<String> roles) {
      for (final l in b.leaders) {
        if (roles.contains(l.roleBn) && byId[l.memberId] != null) {
          return byId[l.memberId];
        }
      }
      for (final m in b.members) {
        if (roles.contains(m.officeBn)) return m;
      }
      return null;
    }

    final pm = holder(const {'প্রধানমন্ত্রী', 'Prime Minister'});
    final lead =
        parties.where((p) => p.abbr == pm?.party).firstOrNull ??
        parties.firstOrNull;

    return HouseMakeup(
      parties: parties,
      total: b.members.length,
      territorial: territorial,
      reserved: reserved,
      women: women,
      womenTerritorial: womenTerritorial,
      womenReserved: womenReserved,
      lead: lead,
      speaker: holder(const {'স্পিকার', 'Speaker'}),
      byId: byId,
    );
  }
}

String _orElse(String? s, String fallback) =>
    s == null || s.isEmpty ? fallback : s;

/// A stable insertion sort: the lists here have a dozen entries.
void _stableSort<E>(List<E> list, {required int Function(E, E) compare}) {
  for (var i = 1; i < list.length; i++) {
    final x = list[i];
    var j = i - 1;
    while (j >= 0 && compare(list[j], x) > 0) {
      list[j + 1] = list[j];
      j--;
    }
    list[j + 1] = x;
  }
}

/// The cabinet as the website's home page counts it: each person once,
/// however many portfolios they hold, under their first-listed post.
class CabinetSummary {
  final int size;

  /// The ranks with anyone in them, in the page's order.
  final List<({CabinetRank rank, int count})> ranks;
  const CabinetSummary(this.size, this.ranks);

  factory CabinetSummary.of(CabinetData d) {
    final first = <String, String?>{};
    for (final (i, r) in d.posts.indexed) {
      final id = r.member?.id ?? '';
      final who = id.isNotEmpty
          ? id
          : r.adviserSlug ?? r.holderBn ?? r.photoUrl ?? '#$i';
      first.putIfAbsent(who, () => r.title);
    }
    return CabinetSummary(first.length, [
      for (final r in cabinetRanks)
        if (first.values.where(r.names).length case final n when n > 0)
          (rank: r, count: n),
    ]);
  }

  /// "প্রধানমন্ত্রী, ২৬ মন্ত্রী, ১৮ প্রতিমন্ত্রী…" / "Prime Minister, 26
  /// ministers…": the one Prime Minister goes unnumbered.
  String get note => [
    for (final (:rank, :count) in ranks)
      if (count == 1 && identical(rank, cabinetRanks.first))
        t(rank.bn, rank.en.first)
      else if (t.en)
        '$count ${count == 1 ? rank.en.first.toLowerCase() : rank.enPlural.toLowerCase()}'
      else
        '${t.n(count)} ${rank.bn}',
  ].join(', ');
}

/* ---------------- the four facts ---------------- */

/// Four facts at a glance, two to a row, each opening the screen that has the
/// rest. A fact still loading shows its label; one that could not be had is
/// left out.
class HouseFacts extends StatelessWidget {
  final HouseMakeup makeup;
  final ElectionData? election;
  final bool electionPending;
  final CabinetSummary? cabinet;
  final bool cabinetPending;
  final VoidCallback? onShowCabinet;

  const HouseFacts({
    super.key,
    required this.makeup,
    this.election,
    this.electionPending = false,
    this.cabinet,
    this.cabinetPending = false,
    this.onShowCabinet,
  });

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final e = election;
    final total = e != null && e.house.total > 0 ? e.house.total : makeup.total;
    final youngest = e?.members.youngest;
    // The member as the list has them, so their page opens with the same
    // brief as everywhere else.
    final youngestMember = youngest == null
        ? null
        : makeup.byId[youngest.member.id] ?? youngest.member;
    final firstTime = e?.members.firstTime ?? 0;

    final tiles = <Widget>[
      FactTile(
        icon: Icons.groups_2_outlined,
        label: t('নারী সদস্য', 'Women MPs'),
        value: t.n(makeup.women),
        note: t(
          '${t.n(makeup.womenTerritorial)} জন সরাসরি নির্বাচিত, ${t.n(makeup.womenReserved)} জন সংরক্ষিত আসনে',
          '${makeup.womenTerritorial} directly elected, ${makeup.womenReserved} in reserved seats',
        ),
        onTap: () =>
            _push(context, const StatisticsScreen(section: StatsSection.women)),
      ),
      if (e != null && firstTime > 0)
        FactTile(
          icon: Icons.person_add_alt_outlined,
          label: t('প্রথমবার সংসদে', 'First-time MPs'),
          value: t.n(firstTime),
          note: t(
            'নতুন মুখ, সংসদের ${t.n((firstTime * 100 / total).round())}%',
            'New faces: ${(firstTime * 100 / total).round()}% of the House',
          ),
          onTap: () => _push(
            context,
            const StatisticsScreen(section: StatsSection.experience),
          ),
        )
      else if (electionPending)
        FactTile.pending(
          icon: Icons.person_add_alt_outlined,
          label: t('প্রথমবার সংসদে', 'First-time MPs'),
        ),
      if (cabinet != null && cabinet!.size > 0)
        FactTile(
          icon: Icons.account_balance_outlined,
          label: t('মন্ত্রিসভায়', 'In the Cabinet'),
          value: t.n(cabinet!.size),
          note: cabinet!.note,
          onTap: onShowCabinet ?? () => _push(context, const CabinetScreen()),
        )
      else if (cabinetPending)
        FactTile.pending(
          icon: Icons.account_balance_outlined,
          label: t('মন্ত্রিসভায়', 'In the Cabinet'),
        ),
      if (youngest != null && youngestMember != null)
        FactTile(
          icon: Icons.workspace_premium_outlined,
          label: t('সর্বকনিষ্ঠ এমপি', 'Youngest MP'),
          value: t('${t.n(youngest.age)} বছর', '${youngest.age} years'),
          note: youngestMember.nameBn,
          onTap: () => _push(context, MemberScreen(member: youngestMember)),
        )
      else if (electionPending)
        FactTile.pending(
          icon: Icons.workspace_premium_outlined,
          label: t('সর্বকনিষ্ঠ এমপি', 'Youngest MP'),
        ),
    ];
    return TileGrid(tiles: tiles);
  }
}

/// One fact: an icon and a label, the figure, a short line under it.
class FactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String? note;
  final VoidCallback? onTap;

  const FactTile({
    super.key,
    required this.icon,
    required this.label,
    required String this.value,
    this.note,
    this.onTap,
  });

  /// The label alone while the figure is on its way.
  const FactTile.pending({super.key, required this.icon, required this.label})
    : value = null,
      note = null,
      onTap = null;

  static const _font = 'NotoSansBengali';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      child: Container(
        decoration: AppDecor.card(radius: 14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1.5),
                        child: Icon(icon, size: 15, color: AppColors.brand),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontFamily: _font,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      value ?? '…',
                      style: figureStyle(
                        24,
                        color: value == null ? AppColors.rule : AppColors.ink,
                      ),
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      note!,
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 11.5,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- the composition ---------------- */

const _font = 'NotoSansBengali';

/// Text on a party's colour: ink on Jamaat's light green, white on the rest.
Color _onParty(String abbr) => abbr == 'BJEI' ? AppColors.ink : Colors.white;

/// সংসদের গঠন: the website's home-page card.
class HouseCompositionCard extends StatelessWidget {
  final HouseMakeup makeup;
  const HouseCompositionCard({super.key, required this.makeup});

  @override
  Widget build(BuildContext context) {
    final m = makeup;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  t('সংসদের গঠন', 'Composition of Parliament'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(
                  '${t('পরিসংখ্যান', 'Statistics')} →',
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Text(
            t(
              '${t.n(HouseMakeup.houseSeats)} আসনের ${t.n(m.total)}টি পূর্ণ: ${t.n(m.territorial)} আসনভিত্তিক, ${t.n(m.reserved)} সংরক্ষিত নারী আসন',
              '${m.total} of ${HouseMakeup.houseSeats} seats filled: ${m.territorial} elected from constituencies, ${m.reserved} reserved seats for women',
            ),
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 13,
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
          if (m.lead != null) ...[
            const SizedBox(height: 14),
            _LeadBox(makeup: m),
          ],
          const SizedBox(height: 16),
          _HouseBar(makeup: m),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _Legend(
                colour: partyColour('BNP'),
                label: t('আসনভিত্তিক', 'Elected seats'),
              ),
              _Legend(
                colour: partyColour('BNP').withValues(alpha: 0.5),
                label: t('সংরক্ষিত নারী আসন', 'Reserved seats for women'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in m.top)
            _PartyRow(
              colour: partyColour(p.abbr),
              title: p.short,
              semantics: p.name,
              sub: p.reserved > 0
                  ? t(
                      '${t.n(p.territorial)} + ${t.n(p.reserved)} সংরক্ষিত',
                      '${p.territorial} + ${p.reserved} reserved',
                    )
                  : t(
                      '${t.n(p.territorial)} আসনভিত্তিক',
                      '${p.territorial} elected',
                    ),
              seats: p.seats,
              total: m.total,
            ),
          if (m.rest.isNotEmpty) _OtherParties(makeup: m),
          if (m.speaker != null) ...[
            const Divider(height: 1),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _SpeakerChip(member: m.speaker!),
            ),
          ],
        ],
      ),
    );
  }
}

/// "সরকারি দল বিএনপি: ২৪৫টি আসন", its share in a party-coloured disc, and
/// how far past the majority it is.
class _LeadBox extends StatelessWidget {
  final HouseMakeup makeup;
  const _LeadBox({required this.makeup});

  @override
  Widget build(BuildContext context) {
    final lead = makeup.lead!;
    final over = makeup.leadOver;
    const majority = HouseMakeup.majority;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: partyColour(lead.abbr),
              shape: BoxShape.circle,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  '${t.n(makeup.leadShare)}%',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _onParty(lead.abbr),
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(
                    'সরকারি দল ${lead.short}: ${t.n(lead.seats)}টি আসন',
                    'Governing party ${lead.short}: ${lead.seats} seats',
                  ),
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandDark,
                    height: 1.4,
                  ),
                ),
                Text(
                  over > 0
                      ? t(
                          'সংখ্যাগরিষ্ঠতার (${t.n(majority)}) চেয়ে ${t.n(over)}টি বেশি',
                          '$over more than a majority ($majority)',
                        )
                      : t(
                          'সংখ্যাগরিষ্ঠতা ${t.n(majority)}',
                          'Majority $majority',
                        ),
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 12.5,
                    color: AppColors.inkSoft,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The House as one bar: each of the four largest parties' elected seats,
/// then its reserved seats paler, then everyone else; the majority marked
/// with a dashed line at majority / sitting members, as the website draws it.
class _HouseBar extends StatelessWidget {
  final HouseMakeup makeup;
  const _HouseBar({required this.makeup});

  @override
  Widget build(BuildContext context) {
    final m = makeup;
    final segments = [
      for (final p in m.top) ...[
        (abbr: p.abbr, seats: p.territorial, pale: false),
        (abbr: p.abbr, seats: p.reserved, pale: true),
      ],
      if (m.restSeats > 0) (abbr: 'other', seats: m.restSeats, pale: false),
    ].where((s) => s.seats > 0).toList();
    final total = segments.fold(0, (n, s) => n + s.seats);
    final mark = m.total > 0
        ? (HouseMakeup.majority / m.total).clamp(0.0, 1.0)
        : 0.5;

    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final x = w * mark;
        const labelW = 130.0;
        return SizedBox(
          height: 52,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: (x - labelW / 2).clamp(0.0, (w - labelW).clamp(0, w)),
                width: labelW,
                top: 0,
                child: Text(
                  '${t('সংখ্যাগরিষ্ঠতা', 'Majority')} ${t.n(HouseMakeup.majority)}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.2,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 30,
                child: Semantics(
                  label: m.parties
                      .map((p) => '${p.short} ${t.n(p.seats)}')
                      .join(', '),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      children: [
                        for (final (i, s) in segments.indexed) ...[
                          if (i > 0) const SizedBox(width: 2),
                          Expanded(
                            flex: s.seats,
                            child: Container(
                              color: partyColour(
                                s.abbr == 'other' ? null : s.abbr,
                              ).withValues(alpha: s.pale ? 0.5 : 1),
                              alignment: AlignmentDirectional.centerStart,
                              padding: const EdgeInsetsDirectional.only(
                                start: 8,
                              ),
                              child:
                                  !s.pale && total > 0 && s.seats / total > 0.12
                                  ? Text(
                                      t.n(s.seats),
                                      maxLines: 1,
                                      overflow: TextOverflow.clip,
                                      softWrap: false,
                                      style: TextStyle(
                                        fontFamily: _font,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _onParty(s.abbr),
                                        height: 1.2,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: x.clamp(0.0, w - 1.5),
                top: 16,
                bottom: -4,
                child: const DashedLine(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  final Color colour;
  final String label;
  const _Legend({required this.colour, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: _font,
            fontSize: 12,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// A party's row: its colour, its short name over its elected and reserved
/// seats, a small bar of its share of the House, the count.
class _PartyRow extends StatelessWidget {
  final Color colour;
  final String title;

  /// In place of [sub]: the other parties' "▾ দেখুন".
  final Widget? subWidget;
  final String? semantics;
  final String? sub;
  final int seats;
  final int total;
  const _PartyRow({
    required this.colour,
    required this.title,
    this.subWidget,
    this.semantics,
    this.sub,
    required this.seats,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.ruleSoft)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, box) {
          final barW = (box.maxWidth * 0.28).clamp(48.0, 110.0);
          return Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colour,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      label: semantics,
                      excludeSemantics: semantics != null,
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: _font,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink,
                          height: 1.35,
                        ),
                      ),
                    ),
                    ?subWidget,
                    if (sub != null)
                      Text(
                        sub!,
                        style: const TextStyle(
                          fontFamily: _font,
                          fontSize: 12,
                          color: AppColors.muted,
                          height: 1.35,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: barW,
                height: 7,
                alignment: AlignmentDirectional.centerStart,
                decoration: BoxDecoration(
                  color: AppColors.sunk,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  widthFactor: total > 0 ? (seats / total).clamp(0.0, 1.0) : 0,
                  heightFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colour,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 36,
                child: Text(
                  t.n(seats),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// "অন্য ৭ দল ▾ দেখুন": the smaller parties in one row, which opens to name
/// them.
class _OtherParties extends StatefulWidget {
  final HouseMakeup makeup;
  const _OtherParties({required this.makeup});

  @override
  State<_OtherParties> createState() => _OtherPartiesState();
}

class _OtherPartiesState extends State<_OtherParties> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.makeup;
    final rest = m.rest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            child: _PartyRow(
              colour: partyColour(null),
              title: t(
                'অন্য ${t.n(rest.length)} দল',
                '${rest.length} other ${plural(rest.length, 'party', 'parties')}',
              ),
              // The website's "▾ দেখুন" / "▴ লুকান", the triangle drawn as an
              // icon: the Bengali font has no glyph for it.
              subWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _open
                        ? Icons.arrow_drop_up_rounded
                        : Icons.arrow_drop_down_rounded,
                    size: 18,
                    color: AppColors.brand,
                  ),
                  Text(
                    _open ? t('লুকান', 'Hide') : t('দেখুন', 'Show'),
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brand,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
              seats: m.restSeats,
              total: m.total,
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 22, bottom: 8),
            child: Text(
              rest.map((p) => '${p.short} ${t.n(p.seats)}').join(' · '),
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 12.5,
                color: AppColors.muted,
                height: 1.55,
              ),
            ),
          ),
      ],
    );
  }
}

/// The Speaker, a chip that opens their page.
class _SpeakerChip extends StatelessWidget {
  final MemberBrief member;
  const _SpeakerChip({required this.member});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      // Rounded rather than a pill: a long name may take a second line.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.rule),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => MemberScreen(member: member))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gavel_rounded, size: 16, color: AppColors.brand),
              const SizedBox(width: 6),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${t('স্পিকার', 'Speaker')}: ',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      TextSpan(text: member.nameBn),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
