import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../data/places.dart';
import '../i18n.dart';
import '../loading.dart';
import '../models.dart';
import '../party_logo.dart';
import '../theme.dart';
import 'party_screen.dart';
import 'place_widgets.dart';

/// The fifty seats reserved for women (the website's /sangrakkhito-ason):
/// how they are filled, how many each party has, who holds them, and the
/// questions readers ask about them.
class ReservedScreen extends StatefulWidget {
  const ReservedScreen({super.key});

  @override
  State<ReservedScreen> createState() => _ReservedScreenState();
}

class _ReservedScreenState extends State<ReservedScreen>
    with RefetchOnLang<ReservedScreen> {
  late Future<ReservedData> _future = fetchReserved();

  @override
  void onLangChanged() => setState(() => _future = fetchReserved());

  Future<void> _refresh() async {
    final f = fetchReserved();
    setState(() => _future = f);
    await settle(f);
  }

  void _share(int total) => SharePlus.instance.share(
    ShareParams(
      text:
          '${t('ত্রয়োদশ জাতীয় সংসদের ${t.n(total)}টি সংরক্ষিত নারী আসনের সংসদ সদস্যরা', 'The Members of Parliament for the $total reserved seats for women in the 13th Parliament')}\n${Api.page('/sangrakkhito-ason')}',
      subject: t(
        'সংরক্ষিত নারী আসন | আমার এমপি',
        'Reserved seats for women | My MP',
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReservedData>(
      future: _future,
      builder: (context, snap) => Scaffold(
        appBar: AppBar(
          title: Text(t('সংরক্ষিত নারী আসন', 'Reserved seats for women')),
          actions: [
            if (snap.data != null)
              IconButton(
                tooltip: t('শেয়ার', 'Share'),
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _share(snap.data!.total),
              ),
          ],
        ),
        body: Loaded<ReservedData>(
          future: _future,
          onRetry: () => setState(() => _future = fetchReserved()),
          builder: (context, d) => RefreshIndicator(
            color: AppColors.brand,
            onRefresh: _refresh,
            child: _body(context, d),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ReservedData d) {
    final text = Theme.of(context).textTheme;
    final total = d.total;
    final parties = Api.instance.cached?.parties ?? const <PartyBrief>[];
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pagePad,
        12,
        AppSizes.pagePad,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        PlaceHero(
          eyebrow: t('ত্রয়োদশ জাতীয় সংসদ', '13th Parliament'),
          title: t('সংরক্ষিত নারী আসন', 'Reserved seats for women'),
          lede: t(
            'সংবিধান অনুযায়ী সংসদে নারীদের জন্য ${t.n(total)}টি আসন সংরক্ষিত। এই আসনে সাধারণ ভোটাররা ভোট দেন না; সাধারণ আসনে জেতা দলগুলোর আনুপাতিক হারে আসনগুলো ভাগ হয়, আর নির্বাচিত ৩০০ সংসদ সদস্য ভোট দিয়ে সদস্য বেছে নেন।',
            'Under the Constitution, $total seats in Parliament are reserved for women. Ordinary voters do not vote for these seats: they are shared among the parties in proportion to the general seats each won, and the 300 elected Members of Parliament vote to choose the members.',
          ),
          stats: [
            (
              value: t.n(total),
              label: t('সংরক্ষিত আসন', 'Reserved seats'),
              note: null,
            ),
            (
              value: t.n(d.women),
              label: t('মোট নারী সদস্য', 'Women members in all'),
              note: t(
                'সাধারণ আসনে ${t.n(d.womenTerritorial)} জন',
                '${d.womenTerritorial} in general seats',
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        PlaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('কোন দল কতটি পেয়েছে', 'How many each party has'),
                style: text.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                t(
                  'সাধারণ আসনে দলগুলোর ভাগ অনুযায়ী। দলের পাতায় তার সব সদস্যের তালিকা আছে।',
                  "In proportion to the parties' shares of the general seats. Each party's page lists all its members.",
                ),
                style: text.labelSmall?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 10),
              for (final p in d.parties)
                _PartyRow(
                  party: p,
                  total: total,
                  brief: parties.where((x) => x.abbr == p.abbr).firstOrNull,
                ),
            ],
          ),
        ),

        SectionHeading(
          t(
            'সংরক্ষিত আসনের সংসদ সদস্য',
            'Members of Parliament for the reserved seats',
          ),
          count: t('${t.n(d.filled)} জন', '${d.filled}'),
        ),
        for (final m in d.members) ...[
          PlaceMemberTile(member: m),
          const SizedBox(height: 10),
        ],

        SectionHeading(t('প্রশ্ন ও উত্তর', 'Questions and answers')),
        for (final q in d.questions) ...[
          PlaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.q, style: text.titleMedium),
                const SizedBox(height: 6),
                Text(q.a, style: text.bodyMedium?.copyWith(height: 1.6)),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (d.sourceBn != null) ...[
          const SizedBox(height: 4),
          Text(
            '${t('সূত্র: ', 'Sources: ')}${d.sourceBn}',
            style: text.labelSmall?.copyWith(height: 1.5),
          ),
          InkWell(
            onTap: () => openLink(context, 'https://www.parliament.gov.bd'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'parliament.gov.bd ↗',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PartyRow extends StatelessWidget {
  final ReservedParty party;
  final int total;
  final PartyBrief? brief;
  const _PartyRow({required this.party, required this.total, this.brief});

  @override
  Widget build(BuildContext context) {
    final b = brief;
    return InkWell(
      onTap: b == null
          ? null
          : () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => PartyScreen(party: b))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Row(
              children: [
                PartyLogo(abbr: party.abbr, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    party.nameBn,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  t('${t.n(party.held)}টি', '${party.held}'),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  height: 6,
                  width: double.infinity,
                  color: AppColors.sunk,
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: total <= 0
                        ? 0
                        : (party.held / total).clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: ColoredBox(color: partyColour(party.abbr)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
