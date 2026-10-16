import 'package:flutter/material.dart';

import '../data/places.dart';
import '../i18n.dart';
import '../loading.dart';
import '../party_logo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'district_map.dart';
import 'place_widgets.dart';

/// One district (the website's /jela/{slug}): the district in a paragraph,
/// its map, each seat with its member, and the seats by party.
class DistrictScreen extends StatefulWidget {
  final String slug;
  const DistrictScreen({super.key, required this.slug});

  @override
  State<DistrictScreen> createState() => _DistrictScreenState();
}

class _DistrictScreenState extends State<DistrictScreen>
    with RefetchOnLang<DistrictScreen> {
  late Future<DistrictDetail> _future = fetchDistrict(widget.slug);

  @override
  void onLangChanged() => setState(() => _future = fetchDistrict(widget.slug));

  Future<void> _refresh() async {
    final f = fetchDistrict(widget.slug);
    setState(() => _future = f);
    await settle(f);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DistrictDetail>(
      future: _future,
      builder: (context, snap) => Scaffold(
        appBar: AppBar(
          title: Text(
            snap.data == null
                ? t('জেলা', 'District')
                : t(
                    '${snap.data!.nameBn} জেলা',
                    '${snap.data!.nameBn} district',
                  ),
          ),
        ),
        body: Loaded<DistrictDetail>(
          future: _future,
          onRetry: () => setState(() => _future = fetchDistrict(widget.slug)),
          builder: (context, d) => RefreshIndicator(
            color: AppColors.brand,
            onRefresh: _refresh,
            child: _body(context, d),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, DistrictDetail d) {
    final text = Theme.of(context).textTheme;
    final name = d.nameBn;
    final n = d.seats.length;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pagePad,
        12,
        AppSizes.pagePad,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        PlaceHero(
          eyebrow: t('জেলা', 'District'),
          title: t('$name জেলা', '$name district'),
          lede: t(
            '${d.nameEn}, ${t.n(n)}টি সংসদীয় আসন। প্রতিটি আসনের বর্তমান সদস্য, সংসদের তথ্যভান্ডার অনুযায়ী।',
            "$name, ${t.count(n, '', 'parliamentary seat', 'parliamentary seats')}. The current member for each seat, according to Parliament's database.",
          ),
          stats: [
            (value: t.n(n), label: t('আসন', 'Seats'), note: null),
            (
              value: t.n(d.parties.length),
              label: t('দল', 'Parties'),
              note: null,
            ),
          ],
        ),
        if (d.introBn.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(d.introBn, style: text.bodyLarge?.copyWith(height: 1.7)),
        ],

        SectionHeading(t('জেলার মানচিত্র', 'Map of the district')),
        DistrictMap(
          districtSlug: d.slug,
          colours: {
            for (final s in d.seats) s.slug: partyColour(s.member?.party),
          },
          seatNames: {for (final s in d.seats) s.slug: s.name},
          onSeat: (slug) => openSeat(context, slug),
        ),

        const SizedBox(height: 10),
        for (final s in d.seats) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () => openSeat(context, s.slug),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Row(
                children: [
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        text: s.name,
                        children: [
                          TextSpan(
                            text: t(', আসন ${t.n(s.no)}', ', seat ${s.no}'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                  // The member listed for a vacant seat is the one who
                  // resigned; the seat's own page says so in full.
                  if (s.vacant) ...[
                    const SizedBox(width: 8),
                    Pill(t('শূন্য', 'Vacant'), colour: AppColors.warn),
                  ],
                ],
              ),
            ),
          ),
          if (s.member != null)
            PlaceMemberTile(member: s.member!)
          else
            PlaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                t(
                  'এই আসনের সদস্যের তথ্য সংসদের তথ্যভান্ডারে নেই।',
                  "Parliament's database has no member for this seat.",
                ),
                style: text.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            ),
        ],

        if (d.parties.isNotEmpty) ...[
          SectionHeading(t('দলভিত্তিক আসন', 'Seats by party')),
          PlaceCard(
            child: Column(
              children: [
                for (final p in d.parties)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        PartyLogo(abbr: p.abbr, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            p.nameBn,
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          t.n(p.seats),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          t(
            'তথ্যসূত্র: বাংলাদেশ জাতীয় সংসদ',
            'Source: Parliament of Bangladesh',
          ),
          style: text.labelSmall,
        ),
      ],
    );
  }
}
