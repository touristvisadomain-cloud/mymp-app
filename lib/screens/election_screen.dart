import 'package:flutter/material.dart';

import '../api.dart';
import '../bn.dart';
import '../data/election.dart';
import '../i18n.dart';
import '../loading.dart';
import '../maps/election_map.dart';
import '../party_logo.dart';
import '../theme.dart';
import 'election_parts.dart';

/// ত্রয়োদশ জাতীয় সংসদ নির্বাচন: the website's নির্বাচন page (/nirbachon), in
/// its order: the map of who won where, the results, the voters and the
/// dates, the parties' seats at earlier elections, and every seat by
/// district. The figures about the members are on [StatisticsScreen]'s page.
class ElectionScreen extends StatefulWidget {
  const ElectionScreen({super.key});

  @override
  State<ElectionScreen> createState() => _ElectionScreenState();
}

class _ElectionScreenState extends State<ElectionScreen>
    with RefetchOnLang<ElectionScreen> {
  late Future<ElectionData> _future = fetchElection();

  /// Set while a finger moves the zoomed map, so the page stays still.
  final _hold = ValueNotifier(false);

  final _mapKey = GlobalKey();
  final _resultsKey = GlobalKey();
  final _votersKey = GlobalKey();
  final _earlierKey = GlobalKey();
  final _districtsKey = GlobalKey();

  @override
  void onLangChanged() => setState(() {
    _future = fetchElection();
  });

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final f = fetchElection(force: true);
    setState(() {
      _future = f;
    });
    await settle(f);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('নির্বাচন', 'Election'))),
      body: Loaded<ElectionData>(
        future: _future,
        onRetry: () => setState(() {
          _future = fetchElection();
        }),
        builder: (context, e) => ValueListenableBuilder<bool>(
          valueListenable: _hold,
          // The page is built once; holding it only swaps its physics.
          child: _body(e),
          builder: (context, hold, child) => RefreshIndicator(
            color: AppColors.brand,
            onRefresh: _refresh,
            notificationPredicate: (n) => !hold && n.depth == 0,
            child: SingleChildScrollView(
              physics: hold
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSizes.pagePad,
                12,
                AppSizes.pagePad,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(ElectionData e) {
    final h = e.house;
    final published = e.publishedSeats;
    final year = e.dates.election?.substring(0, 4) ?? '2026';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeading(
          eyebrow: t.n(year),
          title: t(
            '${parliamentBn(e.parliamentNo)} জাতীয় সংসদ নির্বাচন',
            'Election to the ${t.ord(e.parliamentNo)} Parliament',
          ),
          lede: t(
            '${t.n(h.generalSeats)}টি আসনে নির্বাচন। বর্তমানে ${t.n(h.territorial)}টি আসনে সদস্য আছেন, সেই সঙ্গে ${t.n(h.reserved)}টি সংরক্ষিত নারী আসন মিলিয়ে সংসদে ${t.n(h.total)} জন।',
            'An election to ${h.generalSeats} seats. ${h.territorial} ${plural(h.territorial, 'seat has', 'seats have')} a member at present; with the ${h.reserved} reserved seats for women, Parliament has ${h.total} ${plural(h.total, 'member', 'members')}.',
          ),
        ),
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatTile(
                  label: t('আসন', 'Seats'),
                  value: t.n(h.generalSeats),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: t('পূর্ণ', 'Filled'),
                  value: t.n(h.territorial),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: t('দল', 'Parties'),
                  value: t.n(h.parties.length),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionShortcuts(
          sections: [
            (_mapKey, t('মানচিত্র', 'Map')),
            (_resultsKey, t('ফলাফল', 'Results')),
            (_votersKey, t('ভোটার ও তারিখ', 'Voters and dates')),
            (_earlierKey, t('আগের নির্বাচন', 'Earlier elections')),
            (_districtsKey, t('জেলা অনুযায়ী আসন', 'Seats by district')),
          ],
        ),

        // The map.
        const SizedBox(height: 22),
        SectionHead(
          key: _mapKey,
          title: t('কোন জেলায় কে জিতল', 'Who won in each district'),
        ),
        const SizedBox(height: 8),
        Text(
          t(
            'দেশের মানচিত্রে ${t.n(h.generalSeats)}টি আসন, প্রত্যেকটি তার জায়গায় দলের প্রতীকে; প্রতীকে চাপ দিলে আসনের এলাকা আর সংসদ সদস্য। “জেলার রং”-এ প্রতিটি জেলা সেখানে বেশিরভাগ আসন যে দলের, সেই রঙে।',
            'The ${h.generalSeats} seats on a map of the country, each in its place and marked with its party’s symbol; tap a symbol to see the seat’s area and its Member of Parliament. In “District colours”, each district is in the colour of the party that holds most of its seats.',
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
        const SizedBox(height: 12),
        ElectionMap(
          seats: e.seats,
          districtNames: e.districtNames,
          partyName: fullPartyName,
          holdPage: _hold,
          onMember: (m) => openMember(context, m),
          onSeatPage: ElectionLinks.seat == null
              ? null
              : (slug) => ElectionLinks.seat!(context, slug),
          onDistrictPage: ElectionLinks.district == null
              ? null
              : (slug) => ElectionLinks.district!(context, slug),
        ),

        // Results.
        const SizedBox(height: 28),
        SectionHead(
          key: _resultsKey,
          title: t('ফলাফল', 'Results'),
          note: published > 0
              ? t(
                  '${t.n(published)}টি আসনের ফল প্রকাশিত',
                  'Results published for $published ${plural(published, 'seat', 'seats')}',
                )
              : t(
                  'আসনভিত্তিক ফল এখনো যোগ হয়নি',
                  'Seat-by-seat results not yet added',
                ),
        ),
        const SizedBox(height: 12),
        _Results(e: e, published: published),

        // Voters and dates.
        const SizedBox(height: 28),
        SectionHead(
          key: _votersKey,
          title: t('ভোটার ও নির্বাচনের তারিখ', 'Voters and election dates'),
          note: t(
            'নির্বাচন কমিশন ও সংসদের তথ্য',
            'Figures from the Election Commission and Parliament',
          ),
        ),
        const SizedBox(height: 12),
        _VotersCard(v: e.voters),
        const SizedBox(height: 12),
        _DatesCard(d: e.dates),

        // Earlier elections.
        const SizedBox(height: 28),
        SectionHead(
          key: _earlierKey,
          title: t(
            'আগের নির্বাচনগুলোতে দলগুলোর আসন',
            'Seats by party in earlier elections',
          ),
          note: t('সংসদের তথ্যভান্ডার', 'Parliament’s database'),
        ),
        const SizedBox(height: 12),
        _EarlierTable(rows: e.earlier, current: e.parliamentNo),
        const SizedBox(height: 10),
        Text(
          t(
            'সাধারণ (আসনভিত্তিক) আসনে সংসদের তথ্যভান্ডারে নথিভুক্ত সদস্য অনুযায়ী; সংরক্ষিত নারী আসন বাদ। উপনির্বাচন ও অসম্পূর্ণ রেকর্ডের কারণে কোনো কোনো সংসদে সংখ্যা সরকারি ফলের সঙ্গে সামান্য ভিন্ন হতে পারে; “নথিভুক্ত” কলামে সেটি দেখা যায়। ১ম থেকে ৩য় ও ৬ষ্ঠ সংসদের রেকর্ড সেখানে নেই।',
            'By the members recorded in Parliament’s database for the general (constituency) seats; the reserved seats for women are left out. Because of by-elections and incomplete records, the numbers for some parliaments may differ slightly from the official results; the “Recorded” column shows this. The database has no records for the 1st to 3rd and the 6th parliaments.',
          ),
          style: mutedStyle.copyWith(fontSize: 12.5),
        ),

        // Seats by district.
        const SizedBox(height: 28),
        _Districts(key: _districtsKey, seats: e.seats),
        const SizedBox(height: 14),
        Text(
          '${t('তথ্যসূত্র: বাংলাদেশ জাতীয় সংসদ | হালনাগাদ ', 'Source: Parliament of Bangladesh | Updated ')}'
          '${t.date(e.version) ?? ''}',
          style: mutedStyle,
        ),
      ],
    );
  }
}

/// A party's full name in the reader's language, from the member list the
/// app keeps; null when it is not to hand (or is in the other language).
String? fullPartyName(String abbr) {
  final b = Api.instance.cached;
  if (b == null) return null;
  for (final p in b.parties) {
    if (p.abbr != abbr) continue;
    final name = p.nameBn;
    if (t.en && RegExp('[ঀ-৿]').hasMatch(name)) return null;
    return name;
  }
  return null;
}

class _Results extends StatelessWidget {
  final ElectionData e;
  final int published;
  const _Results({required this.e, required this.published});

  @override
  Widget build(BuildContext context) {
    final h = e.house;
    final top = h.parties.take(4).toList();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelTitle(
            t('সংসদের গঠন', 'Make-up of Parliament'),
            note: t(
              'সংরক্ষিত আসনসহ মোট ${t.n(h.total)}টি আসন; নিচে শুধু নির্বাচনে জেতা আসন।',
              '${h.total} seats in all, including the reserved seats; below, only the seats won at the election.',
            ),
          ),
          const SizedBox(height: 14),
          CompositionBar(
            parties: h.parties,
            total: h.total,
            majority: h.majority,
            nameOf: (p) => fullPartyName(p.abbr) ?? p.label,
          ),
          const Divider(height: 20, color: AppColors.rule),
          TileGrid(
            gap: 8,
            tiles: [
              for (final p in top)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: ElectionLinks.party == null
                      ? null
                      : () =>
                            ElectionLinks.party!(context, p.abbr.toLowerCase()),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            PartyLogo(abbr: p.abbr, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                p.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: mutedStyle,
                              ),
                            ),
                          ],
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: t.n(p.seatsTerritorial),
                                style: figureStyle(17),
                              ),
                              TextSpan(
                                text: t(
                                  ' আসনে নির্বাচিত',
                                  ' ${plural(p.seatsTerritorial, 'seat', 'seats')} won',
                                ),
                                style: mutedStyle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          PanelFoot(
            published > 0
                ? t(
                    'প্রতিটি আসনের পাতায় সব প্রার্থী, দল ও প্রাপ্ত ভোট আছে; নিচে জেলা অনুযায়ী তালিকায় বিজয়ীর ভোট দেখুন। সূত্র দ্য বিজনেস স্ট্যান্ডার্ড ও উইকিপিডিয়া, নির্বাচন কমিশনের গেজেটের সঙ্গে এখনো মিলিয়ে দেখা হয়নি। যেসব আসনের ফল পাওয়া যায়নি, সেগুলোর পাতায় তা লেখা আছে।',
                    'Each seat’s page has every candidate, their party and the votes they received; the list by district below shows the winner’s votes. Sources: The Business Standard and Wikipedia; not yet checked against the Election Commission’s gazette. Seats whose results could not be found say so on their pages.',
                  )
                : t(
                    'নির্বাচন কমিশনের গেজেট থেকে প্রতিটি আসনের প্রার্থী, প্রতীক ও প্রাপ্ত ভোট যোগ করা হবে। যাচাই করা সংখ্যা ছাড়া কিছু দেখানো হবে না।',
                    'Each seat’s candidates, symbols and votes will be added from the Election Commission’s gazette. No figure will be shown unless it has been verified.',
                  ),
          ),
        ],
      ),
    );
  }
}

class _VotersCard extends StatelessWidget {
  final Voters v;
  const _VotersCard({required this.v});

  @override
  Widget build(BuildContext context) {
    final figures = [
      (t('মোট ভোটার', 'Total voters'), t.group(v.registered)),
      (t('ভোটকেন্দ্র', 'Polling centres'), t.group(v.pollingCentres)),
      (
        t('নিবন্ধিত রাজনৈতিক দল', 'Registered political parties'),
        t.n(v.registeredParties),
      ),
      (
        t('ভোটারের মধ্যে নারী', 'Women among voters'),
        '${t.fixed(v.womenPct)}%',
      ),
    ];
    Widget figure((String, String) f) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(f.$2, style: figureStyle(24)),
        ),
        Text(f.$1, style: mutedStyle),
      ],
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Crore-sized figures in Bangla grouping are wide: one column on a
          // narrow phone, so two never run together.
          LayoutBuilder(
            builder: (context, box) {
              if (box.maxWidth < 300) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final f in figures)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: figure(f),
                      ),
                  ],
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TileGrid(
                  gap: 14,
                  tiles: [for (final f in figures) figure(f)],
                ),
              );
            },
          ),
          SplitBar(
            shares: false,
            semantics: t(
              'পুরুষ ভোটার ${t.group(v.male)}, নারী ভোটার ${t.group(v.female)}',
              'Male voters ${t.group(v.male)}, female voters ${t.group(v.female)}',
            ),
            a: (label: t('পুরুষ', 'Men'), n: v.male, colour: menColour),
            b: (
              label: t('নারী', 'Women'),
              n: v.female,
              colour: AppColors.brand,
            ),
          ),
          PanelFoot(
            '${t('তথ্যসূত্র: ', 'Source: ')}${v.source ?? t('বাংলাদেশ নির্বাচন কমিশন', 'Bangladesh Election Commission')}'
            '${v.readOn != null ? '${t(' | পড়া হয়েছে ', ' | Read on ')}${t.date(v.readOn)}' : ''}',
          ),
        ],
      ),
    );
  }
}

/// The election's dates as a timeline.
class _DatesCard extends StatelessWidget {
  final ElectionDates d;
  const _DatesCard({required this.d});

  @override
  Widget build(BuildContext context) {
    final rows = [
      (t('নির্বাচন', 'Election'), d.election),
      (t('গেজেট', 'Gazette'), d.gazette),
      (t('শপথ', 'Oath'), d.oath),
      (t('মেয়াদ শেষ', 'Term ends'), d.end),
    ];
    return Panel(
      child: Column(
        children: [
          for (final (i, (label, value)) in rows.indexed)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 22,
                    child: Stack(
                      children: [
                        if (i < rows.length - 1)
                          const Positioned(
                            left: 5,
                            top: 18,
                            bottom: 0,
                            child: SizedBox(
                              width: 2,
                              child: ColoredBox(color: AppColors.brandSoft),
                            ),
                          ),
                        Positioned(
                          left: 0,
                          top: 6,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < rows.length - 1
                                  ? AppColors.brand
                                  : AppColors.surface,
                              border: Border.all(
                                color: AppColors.brand,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i < rows.length - 1 ? 16 : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: mutedStyle.copyWith(fontSize: 12.5),
                          ),
                          Text(
                            t.date(value) ?? t('তারিখ নেই', 'No date'),
                            style: const TextStyle(
                              fontFamily: 'NotoSansBengali',
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
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

/// Seats by party in each parliament on record: the five parties with most
/// seats over them all, the rest together, and the members recorded.
class _EarlierTable extends StatelessWidget {
  final List<EarlierParliament> rows;
  final int current;
  const _EarlierTable({required this.rows, required this.current});

  @override
  Widget build(BuildContext context) {
    final totals = <String, int>{};
    for (final p in rows) {
      for (final ps in p.parties) {
        totals[ps.abbr] = (totals[ps.abbr] ?? 0) + ps.seats;
      }
    }
    final cols =
        (totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .take(5)
            .map((e) => e.key)
            .toList();
    const head = TextStyle(
      fontFamily: 'NotoSansBengali',
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.muted,
      height: 1.3,
    );
    const cell = TextStyle(
      fontFamily: 'NotoSansBengali',
      fontSize: 13.5,
      color: AppColors.ink,
      height: 1.3,
    );
    Widget num(int n, {bool muted = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: Text(
        t.n(n),
        textAlign: TextAlign.end,
        style: cell.copyWith(
          color: muted || n == 0 ? AppColors.muted : AppColors.ink,
        ),
      ),
    );
    return Container(
      decoration: AppDecor.card(),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: AppColors.sunk.withValues(alpha: 0.7),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
                  child: Text(t('সংসদ', 'Parliament'), style: head),
                ),
                for (final c in cols)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Dot(partyColour(c)),
                        const SizedBox(width: 5),
                        Text(c, style: head),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 9,
                  ),
                  child: Text(
                    t('অন্য', 'Other'),
                    textAlign: TextAlign.end,
                    style: head,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 9, 14, 9),
                  child: Text(
                    t('নথিভুক্ত', 'Recorded'),
                    textAlign: TextAlign.end,
                    style: head,
                  ),
                ),
              ],
            ),
            for (final p in rows)
              TableRow(
                decoration: BoxDecoration(
                  color: p.no == current
                      ? AppColors.brandSoft.withValues(alpha: 0.6)
                      : null,
                  border: const Border(
                    top: BorderSide(color: AppColors.ruleSoft),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
                    child: Text(
                      p.label,
                      style: cell.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  for (final c in cols) num(p.seatsOf(c)),
                  num(
                    p.parties
                        .where((x) => !cols.contains(x.abbr))
                        .fold(0, (n, x) => n + x.seats),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: num(p.total, muted: true),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Every general seat, district by district: its member, party and the
/// winner's votes.
class _Districts extends StatelessWidget {
  final List<ElectionSeat> seats;
  const _Districts({super.key, required this.seats});

  @override
  Widget build(BuildContext context) {
    final by = <String, List<ElectionSeat>>{};
    final names = <String, String>{};
    for (final s in seats) {
      if (s.districtSlug.isEmpty) continue;
      by.putIfAbsent(s.districtSlug, () => []).add(s);
      names[s.districtSlug] = s.districtName;
    }
    final order = by.keys.toList()
      ..sort(
        (a, b) => names[a]!.toLowerCase().compareTo(names[b]!.toLowerCase()),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHead(
          title: t('জেলা অনুযায়ী আসন', 'Seats by district'),
          note: t.count(order.length, ' জেলা', 'district', 'districts'),
        ),
        const SizedBox(height: 12),
        for (final slug in order) ...[
          _DistrictPanel(name: names[slug]!, seats: by[slug]!),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DistrictPanel extends StatelessWidget {
  final String name;
  final List<ElectionSeat> seats;
  const _DistrictPanel({required this.name, required this.seats});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                t.count(seats.length, ' আসন', 'seat', 'seats'),
                style: mutedStyle,
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final s in seats) _SeatRow(seat: s),
        ],
      ),
    );
  }
}

class _SeatRow extends StatelessWidget {
  final ElectionSeat seat;
  const _SeatRow({required this.seat});

  @override
  Widget build(BuildContext context) {
    final m = seat.member;
    final open = ElectionLinks.seat != null
        ? () => ElectionLinks.seat!(context, seat.slug)
        : m != null
        ? () => openMember(context, m)
        : null;
    return InkWell(
      onTap: open,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: m == null
                  ? const Center(child: Dot(AppColors.rule))
                  : PartyLogo(abbr: seat.party, size: 18),
            ),
            const SizedBox(width: 8),
            // The seat and its member on one line where they fit; on a narrow
            // phone the member's name gives way first.
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: seat.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    if (m != null) TextSpan(text: '  ${m.nameBn}'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 13.5,
                  color: AppColors.muted,
                  height: 1.35,
                ),
              ),
            ),
            if (seat.votes != null) ...[
              const SizedBox(width: 6),
              Text(
                '${t.group(seat.votes!)}${t(' ভোট', ' votes')}',
                style: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
