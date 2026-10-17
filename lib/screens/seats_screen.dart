import 'package:flutter/material.dart';

import '../api.dart';
import '../data/places.dart';
import '../i18n.dart';
import '../loading.dart';
import '../models.dart';
import '../party_logo.dart';
import '../theme.dart';
import 'place_widgets.dart';
import 'reserved_screen.dart';

/// Every constituency, district by district (the website's /ason): each
/// seat's member, or "শূন্য" where no one sits for it now.
class SeatsScreen extends StatefulWidget {
  const SeatsScreen({super.key});

  @override
  State<SeatsScreen> createState() => _SeatsScreenState();
}

typedef _Data = ({List<SeatRow> seats, Bootstrap boot});

class _SeatsScreenState extends State<SeatsScreen>
    with RefetchOnLang<SeatsScreen> {
  late Future<_Data> _future = _load();

  Future<_Data> _load() async {
    final r = await Future.wait([fetchSeats(), Api.instance.loadBootstrap()]);
    return (seats: r[0] as List<SeatRow>, boot: r[1] as Bootstrap);
  }

  @override
  void onLangChanged() => setState(() => _future = _load());

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    await settle(f);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('সব আসন', 'All seats'))),
      body: Loaded<_Data>(
        future: _future,
        onRetry: () => setState(() => _future = _load()),
        builder: (context, d) => RefreshIndicator(
          color: AppColors.brand,
          onRefresh: _refresh,
          child: _body(context, d),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, _Data d) {
    final byId = {for (final m in d.boot.members) m.id: m};
    final general = d.seats.where((s) => !s.reserved).toList();
    final reservedCount = d.seats.length - general.length;
    final vacant = general.where((s) => s.vacant).length;

    // The districts in seat order, each with its seats.
    final groups = <String, List<SeatRow>>{};
    for (final s in general) {
      groups.putIfAbsent(s.districtSlug ?? '', () => []).add(s);
    }
    final rows = <Object>[];
    for (final g in groups.values) {
      rows.add(g.first);
      rows.addAll(g.map((s) => (seat: s)));
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePad,
            12,
            AppSizes.pagePad,
            4,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PlaceHero(
                  eyebrow: t('ত্রয়োদশ জাতীয় সংসদ', '13th Parliament'),
                  title: t('সব সংসদীয় আসন', 'All constituencies'),
                  lede: t(
                    '${t.n(general.length)}টি আসনে সরাসরি ভোটে সদস্য নির্বাচিত হন, আর ${t.n(reservedCount)}টি সংরক্ষিত নারী আসন ভাগ হয় দলগুলোর আনুপাতিক হারে। নিচের তালিকা জেলা অনুযায়ী সাজানো; আসনের পাতায় সেখানকার ভোটের ফল ও আগের সদস্যরা আছেন।',
                    'Members for ${general.length} seats are elected by direct vote, and the $reservedCount reserved seats for women are shared among the parties in proportion. The list below is arranged by district; each seat\'s page has its election results and its earlier members.',
                  ),
                  stats: [
                    (
                      value: t.n(general.length),
                      label: t('আসন', 'Seats'),
                      note: null,
                    ),
                    (
                      value: t.n(groups.length),
                      label: t('জেলা', 'Districts'),
                      note: null,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ReservedNote(count: reservedCount, vacant: vacant),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSizes.pagePad,
            0,
            AppSizes.pagePad,
            28 + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              if (row is SeatRow) {
                return _DistrictHeading(
                  seat: row,
                  count: groups[row.districtSlug ?? '']!.length,
                );
              }
              final s = (row as ({SeatRow seat})).seat;
              final m = s.vacant ? null : byId[s.memberId];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SeatListRow(
                  name: s.name,
                  member: m,
                  vacant: m == null,
                  onTap: () => openSeat(context, s.slug),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReservedNote extends StatelessWidget {
  final int count;
  final int vacant;
  const _ReservedNote({required this.count, required this.vacant});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    const link = TextStyle(fontWeight: FontWeight.w700, color: AppColors.brand);
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ReservedScreen())),
      child: Text.rich(
        t.en
            ? TextSpan(
                children: [
                  TextSpan(
                    text:
                        'The $count reserved seats for women are listed separately, on the ',
                  ),
                  const TextSpan(text: 'Reserved seats for women', style: link),
                  const TextSpan(text: ' page.'),
                  if (vacant > 0)
                    TextSpan(
                      text:
                          ' $vacant ${vacant == 1 ? 'seat is' : 'seats are'} vacant at the moment.',
                    ),
                ],
              )
            : TextSpan(
                children: [
                  TextSpan(text: 'সংরক্ষিত নারী আসনের ${t.n(count)}টি আলাদা '),
                  const TextSpan(text: 'সংরক্ষিত নারী আসন', style: link),
                  const TextSpan(text: ' পাতায়।'),
                  if (vacant > 0)
                    TextSpan(text: ' এই মুহূর্তে ${t.n(vacant)}টি আসন শূন্য।'),
                ],
              ),
        style: style,
      ),
    );
  }
}

class _DistrictHeading extends StatelessWidget {
  final SeatRow seat;
  final int count;
  const _DistrictHeading({required this.seat, required this.count});

  @override
  Widget build(BuildContext context) {
    final slug = seat.districtSlug;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: InkWell(
        onTap: slug == null ? null : () => openDistrict(context, slug),
        child: Text.rich(
          TextSpan(
            text: seat.districtBn ?? '',
            children: [
              TextSpan(
                text: '  ${t.count(count, 'টি আসন', 'seat', 'seats')}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// One seat in a list: its name, its member (or "শূন্য") and the party.
class SeatListRow extends StatelessWidget {
  final String name;
  final MemberBrief? member;
  final bool vacant;
  final VoidCallback onTap;
  const SeatListRow({
    super.key,
    required this.name,
    required this.member,
    required this.vacant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final m = member;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusCard),
            border: Border.all(color: AppColors.rule),
          ),
          child: Row(
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  vacant || m == null ? t('শূন্য', 'Vacant') : m.nameBn,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: vacant || m == null
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: vacant || m == null
                        ? AppColors.warn
                        : AppColors.muted,
                  ),
                ),
              ),
              if (!vacant && m?.party != null) ...[
                const SizedBox(width: 8),
                PartyLogo(abbr: m!.party, size: 18),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.rule,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
