import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api.dart';
import '../bn.dart';
import '../data/election.dart';
import '../i18n.dart';
import '../loading.dart';
import '../theme.dart';
import 'election_parts.dart';
import 'election_screen.dart' show fullPartyName;

/// পরিসংখ্যান: the website's statistics page (/parisonkhan): the House by
/// party as a hemicycle, the members' ages, professions, women, experience,
/// and the country's voters, from the same /election answer as
/// [ElectionScreen]'s page.
class StatisticsScreen extends StatefulWidget {
  /// A section to open at, as the website's /parisonkhan#nari links do.
  final StatsSection? section;
  const StatisticsScreen({super.key, this.section});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

/// The sections a link may open the statistics at.
enum StatsSection { women, experience }

class _StatisticsScreenState extends State<StatisticsScreen>
    with RefetchOnLang<StatisticsScreen> {
  late Future<ElectionData> _future = fetchElection();

  final _seatsKey = GlobalKey();
  final _ageKey = GlobalKey();
  final _professionKey = GlobalKey();
  final _womenKey = GlobalKey();
  final _experienceKey = GlobalKey();
  final _votersKey = GlobalKey();

  /// Whether the section asked for has been scrolled to, once.
  bool _jumped = false;

  void _jumpOnce() {
    final section = widget.section;
    if (_jumped || section == null) return;
    _jumped = true;
    final key = switch (section) {
      StatsSection.women => _womenKey,
      StatsSection.experience => _experienceKey,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = key.currentContext;
      if (c == null || !c.mounted) return;
      Scrollable.ensureVisible(
        c,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void onLangChanged() => setState(() {
    _future = fetchElection();
  });

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
      appBar: AppBar(title: Text(t('পরিসংখ্যান', 'Statistics'))),
      body: Loaded<ElectionData>(
        future: _future,
        onRetry: () => setState(() {
          _future = fetchElection();
        }),
        builder: (context, e) => RefreshIndicator(
          color: AppColors.brand,
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSizes.pagePad,
              12,
              AppSizes.pagePad,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            child: _body(context, e),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ElectionData e) {
    _jumpOnce();
    final h = e.house;
    final s = e.members;
    final total = h.total;
    final womenPct = total > 0 ? s.women * 100 / total : 0.0;
    final seated = h.parties.where((p) => p.seats > 0).toList();
    String nameOf(HouseParty p) => fullPartyName(p.abbr) ?? p.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeading(
          eyebrow: t(
            '${parliamentBn(e.parliamentNo)} জাতীয় সংসদ',
            '${t.ord(e.parliamentNo)} Parliament',
          ),
          title: t('পরিসংখ্যান', 'Statistics'),
          lede: t(
            'বর্তমান ${t.n(total)} জন সংসদ সদস্যের তথ্য থেকে হিসাব করা। প্রতিটি সংখ্যা জাতীয় সংসদের নিজস্ব তথ্যভান্ডার থেকে, কোনো অনুমান নয়।',
            'Worked out from the records of the $total current Members of Parliament. Every figure comes from Parliament’s own database; none is an estimate.',
          ),
        ),
        const SizedBox(height: 14),
        SectionShortcuts(
          sections: [
            (_seatsKey, t('দলভিত্তিক আসন', 'Seats by party')),
            (_ageKey, t('বয়স', 'Age')),
            (_professionKey, t('পেশা', 'Profession')),
            (_womenKey, t('নারী প্রতিনিধিত্ব', 'Women')),
            (_experienceKey, t('অভিজ্ঞতা', 'Experience')),
            (_votersKey, t('ভোটার', 'Voters')),
          ],
        ),
        const SizedBox(height: 16),

        // The summary.
        TileGrid(
          tiles: [
            StatTile(
              label: t('মোট সদস্য', 'Total members'),
              value: t.n(total),
              note: t(
                '${t.n(h.territorial)} আসনভিত্তিক, ${t.n(h.reserved)} সংরক্ষিত',
                '${h.territorial} elected from seats, ${h.reserved} reserved',
              ),
            ),
            StatTile(
              label: t('নারী সদস্য', 'Women members'),
              value: t.n(s.women),
              note: t(
                '${t.fixed(womenPct)}%, এর ${t.n(s.womenReserved)} জন সংরক্ষিত আসনে',
                '${t.fixed(womenPct)}%, of whom ${s.womenReserved} in reserved seats',
              ),
            ),
            StatTile(
              label: t('মধ্যক বয়স', 'Median age'),
              value: s.medianAge != null
                  ? t.n(s.medianAge)
                  : t('তথ্য নেই', 'No data'),
              note: s.youngest != null && s.oldest != null
                  ? t(
                      'সর্বকনিষ্ঠ ${t.n(s.youngest!.age)}, সর্বজ্যেষ্ঠ ${t.n(s.oldest!.age)}',
                      'Youngest ${s.youngest!.age}, oldest ${s.oldest!.age}',
                    )
                  : null,
            ),
            StatTile(
              label: t('সংসদীয় কমিটি', 'Parliamentary committees'),
              value: t.n(e.committeesTotal),
              note: t(
                '${t.n(e.committeesCurrent)}টির সদস্য তালিকা হালনাগাদ',
                '${e.committeesCurrent} with an up-to-date membership list',
              ),
            ),
          ],
        ),

        // Seats by party.
        const SizedBox(height: 14),
        Panel(
          key: _seatsKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelTitle(
                t('দলভিত্তিক আসন', 'Seats by party'),
                note: t(
                  '${t.n(total)}টি আসনের সবগুলো, সংরক্ষিত আসনসহ; প্রতিটি বিন্দু একটি আসন',
                  'All $total seats, reserved seats included; each dot is one seat',
                ),
              ),
              const SizedBox(height: 14),
              Hemicycle(
                blocs: [
                  for (final p in seated)
                    (
                      label: nameOf(p),
                      seats: p.seats,
                      colour: partyColour(p.abbr),
                    ),
                ],
                total: total,
                majority: h.majority,
              ),
              const SizedBox(height: 14),
              _PartyTable(parties: seated, nameOf: nameOf),
              PanelFoot(
                t(
                  'সরকার গঠনে দরকার ${t.n(h.majority)}টি আসন। সংরক্ষিত ${t.n(h.reserved)}টি নারী আসন সাধারণ আসনের ফলের অনুপাতে দলগুলোর মধ্যে ভাগ হয়।',
                  'Forming a government takes ${h.majority} seats. The ${h.reserved} seats reserved for women are shared among the parties in proportion to their results in the general seats.',
                ),
              ),
            ],
          ),
        ),

        // Age.
        const SizedBox(height: 14),
        Panel(
          key: _ageKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelTitle(
                t('বয়স', 'Age'),
                note: t(
                  '${t.n(total)} জনেরই জন্মতারিখ পাওয়া গেছে',
                  'Dates of birth found for all $total',
                ),
              ),
              const SizedBox(height: 14),
              BandBars(
                rows: [
                  for (final b in s.ageBands)
                    if (b.label != null) (label: b.label!, count: b.count),
                ],
                total: total,
              ),
              if (s.youngest != null && s.oldest != null)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.rule)),
                  ),
                  child: Column(
                    children: [
                      _AgeRow(
                        label: t('সর্বকনিষ্ঠ', 'Youngest'),
                        who: s.youngest!,
                      ),
                      _AgeRow(
                        label: t('সর্বজ্যেষ্ঠ', 'Oldest'),
                        who: s.oldest!,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Profession.
        const SizedBox(height: 14),
        _Professions(key: _professionKey, s: s, total: total),

        // Women.
        const SizedBox(height: 14),
        _Women(key: _womenKey, s: s, house: h),

        // Experience.
        const SizedBox(height: 28),
        SectionHead(
          key: _experienceKey,
          title: t('সংসদে অভিজ্ঞতা', 'Experience in Parliament'),
          note: t(
            'সংসদের তথ্যভান্ডার, ৪র্থ সংসদ থেকে',
            'Parliament’s database, from the 4th Parliament on',
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SplitBar(
                semantics: t(
                  'এবারই প্রথম ${t.n(s.firstTime)}, আগেও সদস্য ${t.n(s.returning)}',
                  'First time ${s.firstTime}, members before ${s.returning}',
                ),
                a: (
                  label: t('এবারই প্রথম', 'First time'),
                  n: s.firstTime,
                  colour: AppColors.brand,
                ),
                b: (
                  label: t('আগেও সদস্য ছিলেন', 'Members before'),
                  n: s.returning,
                  colour: partyColour('BJEI'),
                ),
              ),
              const SizedBox(height: 16),
              BandBars(
                rows: [
                  for (final b in s.experience)
                    if (b.label != null) (label: b.label!, count: b.count),
                ],
                labelWidth: 112,
                emphasiseLargest: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _MostTerms(rows: s.mostTerms),

        // Voters.
        const SizedBox(height: 28),
        SectionHead(
          key: _votersKey,
          title: t('ভোটার ও ভোটকেন্দ্র', 'Voters and polling centres'),
          note: t(
            'সারা দেশের হিসাব, নির্বাচন কমিশনের প্রকাশিত তথ্য অনুযায়ী। আসনভিত্তিক ভোটার সংখ্যা এখনো যোগ করা হয়নি।',
            'Figures for the whole country, as published by the Election Commission. Voter numbers by seat have not been added yet.',
          ),
        ),
        const SizedBox(height: 12),
        TileGrid(
          tiles: [
            StatTile(
              label: t('মোট ভোটার', 'Total voters'),
              value: t.group(e.voters.registered),
              valueSize: 20,
            ),
            StatTile(
              label: t('পুরুষ ভোটার', 'Male voters'),
              value: t.group(e.voters.male),
              valueSize: 20,
            ),
            StatTile(
              label: t('নারী ভোটার', 'Female voters'),
              value: t.group(e.voters.female),
              valueSize: 20,
            ),
            StatTile(
              label: t('ভোটকেন্দ্র', 'Polling centres'),
              value: t.group(e.voters.pollingCentres),
              valueSize: 20,
              note: t(
                'নিবন্ধিত রাজনৈতিক দল ${t.n(e.voters.registeredParties)}টি',
                '${e.voters.registeredParties} registered political parties',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Panel(
          child: SplitBar(
            semantics: t(
              'পুরুষ ভোটার ${t.group(e.voters.male)}, নারী ভোটার ${t.group(e.voters.female)}',
              'Male voters ${t.group(e.voters.male)}, female voters ${t.group(e.voters.female)}',
            ),
            a: (label: t('পুরুষ', 'Men'), n: e.voters.male, colour: menColour),
            b: (
              label: t('নারী', 'Women'),
              n: e.voters.female,
              colour: AppColors.brand,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${t('তথ্যসূত্র: ', 'Source: ')}${e.voters.source ?? t('বাংলাদেশ নির্বাচন কমিশন', 'Bangladesh Election Commission')}'
          '${e.voters.readOn != null ? '${t(' | পড়া হয়েছে ', ' | read on ')}${t.date(e.voters.readOn)}' : ''}',
          style: mutedStyle,
        ),

        // What is not here.
        const SizedBox(height: 24),
        NoteBox(
          title: t('যেসব হিসাব এখানে নেই', 'Figures not shown here'),
          body: t(
            'আসনভিত্তিক ভোটের সংখ্যা, ভোটার উপস্থিতি, সংসদে উপস্থিতি বা উত্থাপিত প্রশ্নের হিসাব কোনো উন্মুক্ত সূত্রে পাওয়া যায়নি। নির্ভরযোগ্য সূত্র ছাড়া এসব সংখ্যা আমরা দেখাই না।',
            'Votes by seat, voter turnout, attendance in Parliament and questions asked: none of these was found in any open source. We do not show such figures without a reliable source.',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          t(
            'তথ্যসূত্র: বাংলাদেশ জাতীয় সংসদ | হালনাগাদ ${t.date(e.version) ?? ''} | মুক্তিযোদ্ধা সদস্য ${t.n(s.freedomFighters)} জন',
            'Source: Parliament of Bangladesh | updated ${t.date(e.version) ?? ''} | freedom fighter members: ${s.freedomFighters}',
          ),
          style: mutedStyle,
        ),
      ],
    );
  }
}

/// The House as it sits: every seat a dot on a half circle, rows from the
/// floor outward, the largest party from the left, each in its colour; the
/// majority mark runs from the centre to the seat that makes it. The
/// website's Hemicycle, painted.
class Hemicycle extends StatelessWidget {
  final List<({String label, int seats, Color colour})> blocs;
  final int total;
  final int majority;
  const Hemicycle({
    super.key,
    required this.blocs,
    required this.total,
    required this.majority,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: blocs.map((b) => '${b.label} ${t.n(b.seats)}').join(', '),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: AspectRatio(
          aspectRatio: _HemicyclePainter.w / _HemicyclePainter.h,
          child: CustomPaint(
            painter: _HemicyclePainter(
              colours: [
                for (final b in blocs)
                  for (var i = 0; i < b.seats; i++) b.colour,
              ],
              total: total,
              majority: majority,
              big: t.n(total),
              small:
                  '${t('আসন · সংখ্যাগরিষ্ঠতা ', 'seats · majority ')}${t.n(majority)}',
            ),
          ),
        ),
      ),
    );
  }
}

class _HemicyclePainter extends CustomPainter {
  static const w = 420.0;
  static const h = 226.0;
  static const _cx = w / 2;
  static const _cy = 212.0;
  static const _rIn = 86.0;
  static const _rOut = 200.0;
  static const _rows = 11;

  final List<Color> colours;
  final int total;
  final int majority;
  final String big;
  final String small;
  _HemicyclePainter({
    required this.colours,
    required this.total,
    required this.majority,
    required this.big,
    required this.small,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    canvas.save();
    canvas.scale(size.width / w);

    // Seats per row, in proportion to each row's length, adding up to the
    // total; the seats the rounding lost go to the outer rows.
    final radii = [
      for (var i = 0; i < _rows; i++) _rIn + (_rOut - _rIn) * i / (_rows - 1),
    ];
    final sum = radii.fold<double>(0, (a, b) => a + b);
    final counts = [for (final r in radii) (total * r / sum).floor()];
    var left = total - counts.fold<int>(0, (a, b) => a + b);
    for (var i = _rows - 1; left > 0; i = (i - 1 + _rows) % _rows, left--) {
      counts[i]++;
    }
    // Every seat's place, ordered left to right by angle so each party is
    // one wedge.
    final places = <({double a, Offset at})>[];
    for (var row = 0; row < _rows; row++) {
      final n = counts[row];
      for (var j = 0; j < n; j++) {
        final a = math.pi - math.pi * j / math.max(n - 1, 1);
        places.add((
          a: a,
          at: Offset(
            _cx + radii[row] * math.cos(a),
            _cy - radii[row] * math.sin(a),
          ),
        ));
      }
    }
    places.sort((p, q) => q.a.compareTo(p.a));
    final dot = (_rOut - _rIn) / 10 * 0.4;
    final paint = Paint();
    for (var i = 0; i < places.length; i++) {
      paint.color = i < colours.length ? colours[i] : AppColors.rule;
      canvas.drawCircle(places[i].at, dot, paint);
    }

    // The majority mark.
    final mark = majority >= 1 && majority <= places.length
        ? places[majority - 1].a
        : math.pi / 2;
    final end = Offset(
      _cx + (_rOut + 8) * math.cos(mark),
      _cy - (_rOut + 8) * math.sin(mark),
    );
    final line = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 1.2;
    const start = Offset(_cx, _cy);
    final len = (end - start).distance;
    final dir = (end - start) / len;
    for (var d = 0.0; d < len; d += 6) {
      canvas.drawLine(
        start + dir * d,
        start + dir * math.min(d + 3, len),
        line,
      );
    }

    // The count in the middle.
    void text(String s, double y, TextStyle style) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_cx - tp.width / 2, y - tp.height));
    }

    text(
      big,
      _cy - 26,
      const TextStyle(
        fontFamily: 'NotoSansBengali',
        fontSize: 40,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        height: 1.1,
      ),
    );
    text(
      small,
      _cy - 6,
      const TextStyle(
        fontFamily: 'NotoSansBengali',
        fontSize: 12.5,
        color: AppColors.muted,
        height: 1.2,
      ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HemicyclePainter old) =>
      old.total != total ||
      old.majority != majority ||
      old.big != big ||
      old.small != small ||
      old.colours.length != colours.length ||
      !_sameColours(old.colours, colours);

  static bool _sameColours(List<Color> a, List<Color> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Each party's seats: elected, reserved, all.
class _PartyTable extends StatelessWidget {
  final List<HouseParty> parties;
  final String Function(HouseParty) nameOf;
  const _PartyTable({required this.parties, required this.nameOf});

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(
      fontFamily: 'NotoSansBengali',
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.muted,
      height: 1.3,
    );
    const cell = TextStyle(
      fontFamily: 'NotoSansBengali',
      fontSize: 13.5,
      color: AppColors.ink,
      height: 1.35,
    );
    Widget n(int v, {TextStyle style = cell}) => Padding(
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: Text(t.n(v), textAlign: TextAlign.end, style: style),
    );
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(),
        1: IntrinsicColumnWidth(),
        2: IntrinsicColumnWidth(),
        3: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.rule)),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Text(t('দল', 'Party'), style: head),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Text(
                t('আসনভিত্তিক', 'Elected'),
                textAlign: TextAlign.end,
                style: head,
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Text(
                t('সংরক্ষিত', 'Reserved'),
                textAlign: TextAlign.end,
                style: head,
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Text(
                t('মোট', 'Total'),
                textAlign: TextAlign.end,
                style: head,
              ),
            ),
          ],
        ),
        for (final (i, p) in parties.indexed)
          TableRow(
            decoration: BoxDecoration(
              border: i == 0
                  ? null
                  : const Border(top: BorderSide(color: AppColors.ruleSoft)),
            ),
            children: [
              InkWell(
                onTap: ElectionLinks.party == null
                    ? null
                    : () => ElectionLinks.party!(context, p.abbr.toLowerCase()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Dot(partyColour(p.abbr)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          nameOf(p),
                          style: cell.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              n(p.seatsTerritorial),
              n(p.seatsReserved, style: cell.copyWith(color: AppColors.muted)),
              n(p.seats, style: cell.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
      ],
    );
  }
}

class _AgeRow extends StatelessWidget {
  final String label;
  final AgedMember who;
  const _AgeRow({required this.label, required this.who});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: mutedStyle.copyWith(fontSize: 13.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => openMember(context, who.member),
                      child: Text(
                        who.member.nameBn,
                        style: const TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                  TextSpan(
                    text: ' ${t.n(who.age)}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Professions extends StatelessWidget {
  final MembersStats s;
  final int total;
  const _Professions({super.key, required this.s, required this.total});

  @override
  Widget build(BuildContext context) {
    final top = s.professions.take(8).toList();
    final named = [
      for (final p in top)
        if (p.label != null) (label: p.label!, count: p.count),
    ];
    final unnamed = top.length - named.length;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelTitle(
            t('পেশা', 'Profession'),
            note: t(
              '${t.n(total)} জনের মধ্যে ${t.n(s.withProfession)} জনের পেশা লিপিবদ্ধ',
              'Profession recorded for ${s.withProfession} of $total',
            ),
          ),
          const SizedBox(height: 14),
          if (named.isNotEmpty)
            BandBars(rows: named, total: s.withProfession, labelWidth: 96),
          if (t.en && unnamed > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: unnamed == top.length
                          ? 'The commonest professions are recorded in Bangla and have not been translated yet: '
                          : '$unnamed more of the commonest professions have not been translated yet: ',
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: () =>
                            openLink(context, '${Api.base}/parisonkhan#pesha'),
                        child: const Text(
                          'see them on the Bangla page',
                          style: TextStyle(
                            fontFamily: 'NotoSansBengali',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                style: mutedStyle,
              ),
            ),
          PanelFoot(
            t(
              '${t.n(total - s.withProfession)} জনের পেশা সংসদের তথ্যভান্ডারে নেই, তাই এই হিসাবে তাঁরা ধরা হয়নি। একই পেশার ভিন্ন বানান এক করে গোনা হয়েছে।',
              'Parliament’s database has no profession for ${total - s.withProfession}, so they are not counted here. Different spellings of the same profession are counted as one.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Women extends StatelessWidget {
  final MembersStats s;
  final House house;
  const _Women({super.key, required this.s, required this.house});

  @override
  Widget build(BuildContext context) {
    final total = house.total;
    final men = math.max(0, total - s.women);
    final generalPct = house.territorial > 0
        ? s.womenTerritorial * 100 / house.territorial
        : 0.0;
    const inBar = TextStyle(
      fontFamily: 'NotoSansBengali',
      fontSize: 13,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
    Widget tile(int n, String a, String b) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.n(n), style: figureStyle(26, color: AppColors.brand)),
          const SizedBox(height: 4),
          Text(
            '$a\n$b',
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 13,
              color: AppColors.inkSoft,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelTitle(
            t('নারী প্রতিনিধিত্ব', 'Women in Parliament'),
            note: t(
              '${t.n(s.women)} জন নারী, ${t.n(total)} জনের মধ্যে',
              '${s.women} women out of $total',
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: t(
              'পুরুষ ${t.n(men)}, নারী ${t.n(s.women)}',
              'Men $men, women ${s.women}',
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 30,
                child: Row(
                  children: [
                    if (men > 0)
                      Expanded(
                        flex: men,
                        child: Container(
                          color: menColour,
                          alignment: AlignmentDirectional.centerStart,
                          padding: const EdgeInsetsDirectional.only(start: 10),
                          child: Text(
                            '${t('পুরুষ', 'Men')} ${t.n(men)}',
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: inBar.copyWith(color: AppColors.ink),
                          ),
                        ),
                      ),
                    if (men > 0 && s.women > 0) const SizedBox(width: 2),
                    if (s.women > 0)
                      Expanded(
                        flex: s.women,
                        child: Container(
                          color: AppColors.brand,
                          alignment: AlignmentDirectional.centerStart,
                          padding: const EdgeInsetsDirectional.only(start: 6),
                          child: Text(
                            t.n(s.women),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: inBar.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: t(
                    'সংরক্ষিত আসন বাদ দিলে সাধারণ আসনে নারীর হার ${t.fixed(generalPct)}%।',
                    'Leaving the reserved seats aside, women hold ${t.fixed(generalPct)}% of the general seats.',
                  ),
                ),
                if (ElectionLinks.reserved != null) ...[
                  const TextSpan(text: ' '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => ElectionLinks.reserved!(context),
                      child: Text(
                        t(
                          'সংরক্ষিত আসনের সদস্যরা',
                          'Members in the reserved seats',
                        ),
                        style: const TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            style: mutedStyle,
          ),
          const SizedBox(height: 14),
          TileGrid(
            tiles: [
              tile(
                s.womenTerritorial,
                t('সাধারণ আসনে নির্বাচিত', 'Elected in general seats'),
                t(
                  '${t.n(house.territorial)} জনের মধ্যে',
                  'out of ${house.territorial}',
                ),
              ),
              tile(
                s.womenReserved,
                t('সংরক্ষিত আসনে', 'In reserved seats'),
                t(
                  '${t.n(house.reserved)} জনের মধ্যে',
                  'out of ${house.reserved}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MostTerms extends StatelessWidget {
  final List<TermsMember> rows;
  const _MostTerms({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('সবচেয়ে বেশি মেয়াদ', 'Most terms'),
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          if (rows.isEmpty)
            Text(
              t(
                'সংসদের তথ্যভান্ডারে কারও আগের মেয়াদ পাওয়া যায়নি।',
                'Parliament’s database shows no earlier term for anyone.',
              ),
              style: mutedStyle.copyWith(fontSize: 14),
            ),
          for (final (i, r) in rows.indexed)
            InkWell(
              onTap: () => openMember(context, r.member),
              child: Container(
                decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : const Border(
                          top: BorderSide(color: AppColors.ruleSoft),
                        ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.member.nameBn,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'NotoSansBengali',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                              height: 1.4,
                            ),
                          ),
                          Text(
                            [
                              r.member.seatLabel,
                              if (r.member.party != null) r.member.party!,
                            ].join(', '),
                            style: mutedStyle.copyWith(fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      t.count(r.terms, ' মেয়াদ', 'term', 'terms'),
                      style: const TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            t(
              '১ম থেকে ৩য় ও ৬ষ্ঠ সংসদের রেকর্ড সেখানে নেই, তাই তার আগের মেয়াদ গোনা যায়নি।',
              'The records of the 1st to 3rd and the 6th Parliaments are not in it, so terms in those could not be counted.',
            ),
            style: mutedStyle.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
