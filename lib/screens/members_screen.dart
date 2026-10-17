import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../bn.dart';
import '../brand_header.dart';
import '../data/places.dart';
import '../i18n.dart';
import '../loading.dart';
import '../models.dart';
import '../party_logo.dart';
import '../search.dart';
import '../disclaimer.dart';
import '../theme.dart';
import '../widgets.dart';
import 'house_overview.dart';
import 'leaders_strip.dart';
import 'member_screen.dart';
import 'seat_screen.dart';

/// The list every reader opens first: all 348 members, searchable by name, by
/// seat and by district, filterable by party, district and kind of seat
/// (elected or reserved, as the website's list has it). A query naming a
/// place, an upazila, a union or a city ward, in Bangla or English, puts that
/// place's member first, under "আপনার এলাকার এমপি". Above the list, as on
/// the website's home page: four facts and the House's composition.
class MembersScreen extends StatefulWidget {
  /// What the cabinet fact does: the shell switches to the cabinet tab.
  final VoidCallback? onShowCabinet;
  const MembersScreen({super.key, this.onShowCabinet});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen>
    with RefetchOnLang<MembersScreen> {
  final _search = TextEditingController();
  late Future<Bootstrap> _future;
  String _query = '';
  String? _party;
  String? _district;

  /// null for every member, 'territorial' or 'reserved'.
  String? _kind;

  /// The seats' areas, for the place search; arrives after the list.
  Places? _places;

  final _scroll = ScrollController();
  bool _headerGone = false;

  @override
  void initState() {
    super.initState();
    _future = Api.instance.loadBootstrap();
    // The list opens from the copy on the phone; when the fresh one arrives in
    // the background it replaces what is on screen in place: same scroll
    // position, same search, keyboard still open.
    Api.instance.bootstrap.addListener(_onFresh);
    _loadPlaces();
    _scroll.addListener(() {
      final gone = _scroll.hasClients && _scroll.offset > 170;
      if (gone != _headerGone) setState(() => _headerGone = gone);
    });
  }

  void _onFresh() {
    final fresh = Api.instance.bootstrap.value;
    if (mounted && fresh != null) {
      setState(() {
        _future = Future.value(fresh);
      });
      if (_places?.version != fresh.version) _loadPlaces();
    }
  }

  /// The place search's data, read from the stored list; the search by name
  /// works without it.
  void _loadPlaces() {
    final lang = appLang.value;
    Places.load().then((p) {
      if (mounted && p.lang == lang && lang == appLang.value) {
        setState(() => _places = p);
      }
    }, onError: (Object _) {});
  }

  /// The list again in the new language. A district picked in the old one
  /// names nothing in the new list, so the district filter is let go.
  @override
  void onLangChanged() {
    setState(() {
      _district = null;
      _places = null;
      _future = Api.instance.loadBootstrap();
    });
    _loadPlaces();
  }

  @override
  void dispose() {
    Api.instance.bootstrap.removeListener(_onFresh);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final fresh = Api.instance.loadBootstrap(force: true);
    setState(() {
      _future = fresh;
    });
    await settle(fresh);
  }

  void _clearAll() => setState(() {
    _search.clear();
    _query = '';
    _party = null;
    _district = null;
    _kind = null;
  });

  MemberSearch? _searchIndex;
  Bootstrap? _indexed;
  Places? _indexedPlaces;

  /// Built once per member list, not per keystroke. On English the Bangla
  /// names beside the English ones are searched too, once they have arrived.
  MemberSearch _searchFor(Bootstrap data) {
    if (_searchIndex == null ||
        !identical(_indexed, data) ||
        !identical(_indexedPlaces, _places)) {
      _searchIndex = MemberSearch(
        data.members,
        partyNames: {for (final p in data.parties) p.abbr: p.nameBn},
        alt: _places?.alt ?? const {},
      );
      _indexed = data;
      _indexedPlaces = _places;
    }
    return _searchIndex!;
  }

  bool _keep(MemberBrief m) =>
      (_party == null || m.party == _party) &&
      (_district == null || m.districtBn == _district) &&
      (_kind == null || (_kind == 'reserved') == m.reserved);

  /// The seats of the place the query names, under the same filters as the
  /// list: a vacant seat only while no party is chosen.
  List<SeatMatch> _placeHits() {
    final places = _places;
    if (places == null || _query.trim().isEmpty || _kind == 'reserved') {
      return const [];
    }
    final hits = <SeatMatch>[];
    for (final h in findPlaces(_query, places.finderSeats, places.upazilaEn)) {
      final m = h.seat.member;
      if (m != null ? _keep(m) : _party == null && _district == null) {
        hits.add(h);
      }
    }
    return hits;
  }

  /// Party, district and kind of seat narrow the list; a typed query then
  /// ranks it, best match first, in Bangla or English (see search.dart). With
  /// no query the list keeps seat order.
  List<MemberBrief> _filter(Bootstrap data) {
    bool keep(MemberBrief m) => _keep(m);
    if (_query.trim().isEmpty) {
      return data.members.where(keep).toList()
        ..sort((a, b) => (a.seatNo ?? 9999).compareTo(b.seatNo ?? 9999));
    }
    return _searchFor(data).search(_query).where(keep).toList();
  }

  Future<void> _pickDistrict(List<String> districts) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DistrictSheet(districts: districts, selected: _district),
    );
    if (picked == null) return;
    setState(() => _district = picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final statusBar = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _list()),
          if (_headerGone)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: statusBar,
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.dark.copyWith(
                  statusBarColor: Colors.transparent,
                ),
                child: ColoredBox(
                  color: AppColors.paper.withValues(alpha: 0.96),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _list() {
    return Builder(
      builder: (context) => Loaded<Bootstrap>(
        future: _future,
        onRetry: _refresh,
        wrap: (child) => SafeArea(child: child),
        builder: (context, data) {
          final hits = _placeHits();
          // A member found by their place is shown once, at the top.
          final placed = {
            for (final h in hits)
              if (h.seat.member != null) h.seat.member!.id,
          };
          final shown = _filter(
            data,
          ).where((m) => !placed.contains(m.id)).toList();
          final filtered =
              _party != null ||
              _district != null ||
              _kind != null ||
              _query.isNotEmpty;

          return RefreshIndicator(
            color: AppColors.brand,
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(child: _header(data)),
                // The House at a glance, its leaders and the election figures
                // first; a reader searching or filtering wants the list, so
                // they step aside.
                if (!filtered) ...[
                  SliverToBoxAdapter(
                    child: HouseOverview(
                      data: data,
                      onShowCabinet: widget.onShowCabinet,
                    ),
                  ),
                  SliverToBoxAdapter(child: LeadersStrip(data: data)),
                  const SliverToBoxAdapter(child: ElectionCard()),
                ],
                SliverToBoxAdapter(
                  child: _filters(data, shown.length + placed.length, filtered),
                ),
                if (hits.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _GroupLabel(
                      t('আপনার এলাকার এমপি', 'The MP for your area'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.pagePad,
                    ),
                    sliver: SliverList.separated(
                      itemCount: hits.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _PlaceTile(match: hits[i]),
                    ),
                  ),
                  if (shown.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _GroupLabel(t('আরও ফল', 'More results')),
                    ),
                ],
                if (shown.isEmpty && hits.isNotEmpty)
                  const SliverToBoxAdapter(child: _Footnote())
                else if (shown.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.search_off_rounded,
                      title: t('কাউকে পাওয়া যায়নি', 'No one found'),
                      body: t(
                        'নাম, আসন বা জেলা দিয়ে আবার খুঁজে দেখুন।',
                        'Try searching again by name, seat or district.',
                      ),
                      actionLabel: t('সব দেখুন', 'Show all'),
                      onAction: _clearAll,
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.pagePad,
                      2,
                      AppSizes.pagePad,
                      0,
                    ),
                    sliver: SliverList.separated(
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => MemberTile(
                        member: shown[i],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MemberScreen(member: shown[i]),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: _Footnote()),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(Bootstrap data) {
    return BrandHeader(
      title: t('সংসদ সদস্য', 'Members of Parliament'),
      subtitle: t(
        '${parliamentBn(data.parliamentNo)} জাতীয় সংসদ',
        '${t.ord(data.parliamentNo)} Parliament',
      ),
      bottom: Column(
        children: [
          Row(
            children: [
              HeaderStat(
                value: t.n(data.members.length),
                label: t('সদস্য', 'Members'),
              ),
              const SizedBox(width: 8),
              HeaderStat(
                value: t.n(data.parties.length),
                label: t('দল', 'Parties'),
              ),
              const SizedBox(width: 8),
              HeaderStat(
                value: t.n(data.districts.length),
                label: t('জেলা', 'Districts'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          HeaderSearchField(
            controller: _search,
            hint: t(
              'নাম, আসন, জেলা বা উপজেলা (বাংলা/English)',
              'Name, seat, district or upazila',
            ),
            onChanged: (v) => setState(() => _query = v),
            onClear: () => setState(() {
              _search.clear();
              _query = '';
            }),
          ),
        ],
      ),
    );
  }

  Widget _filters(Bootstrap data, int shownCount, bool filtered) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChipBar(
            options: [
              (label: t('সব', 'All'), value: null),
              (label: t('আসনভিত্তিক', 'Elected seats'), value: 'territorial'),
              (label: t('সংরক্ষিত', 'Reserved seats'), value: 'reserved'),
            ],
            selected: _kind,
            onSelect: (v) => setState(() => _kind = v),
          ),
          const SizedBox(height: 10),
          ChipBar(
            options: [
              (label: t('সব দল', 'All parties'), value: null),
              ...data.parties.map(
                (p) => (label: '${p.shortBn} ${t.n(p.seats)}', value: p.abbr),
              ),
            ],
            selected: _party,
            leading: (v) => v == null ? null : PartyLogo(abbr: v, size: 18),
            onSelect: (v) => setState(() => _party = v == _party ? null : v),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePad),
            child: Row(
              children: [
                // On a small phone with a large font the button gives way to
                // the count and "Clear all".
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _DistrictButton(
                      label: _district ?? t('সব জেলা', 'All districts'),
                      active: _district != null,
                      onTap: () => _pickDistrict(data.districts),
                      onClear: _district == null
                          ? null
                          : () => setState(() => _district = null),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  t.count(shownCount, ' জন', 'MP', 'MPs'),
                  style: const TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                if (filtered) ...[
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: _clearAll,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(
                      t('সব মুছুন', 'Clear all'),
                      style: const TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistrictButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _DistrictButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.brandSoft : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        child: Container(
          height: 36,
          padding: const EdgeInsets.only(left: 12, right: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            border: Border.all(
              color: active ? AppColors.brandRing : AppColors.rule,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 17,
                color: active ? AppColors.brand : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.brand : AppColors.inkSoft,
                  ),
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.brand,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: AppColors.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 64 districts in a sheet, with a search box: a row of 64 chips was a
/// long sideways scroll to reach Sylhet.
class _DistrictSheet extends StatefulWidget {
  final List<String> districts;
  final String? selected;
  const _DistrictSheet({required this.districts, this.selected});

  @override
  State<_DistrictSheet> createState() => _DistrictSheetState();
}

class _DistrictSheetState extends State<_DistrictSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    // Case does not matter to an English reader typing "dhaka".
    final q = _q.toLowerCase();
    final list = widget.districts
        .where((d) => q.isEmpty || d.toLowerCase().contains(q))
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.rule,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.pagePad,
                  14,
                  AppSizes.pagePad,
                  10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t('জেলা বেছে নিন', 'Choose a district'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (widget.selected != null)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(''),
                        child: Text(
                          t('সব জেলা', 'All districts'),
                          style: const TextStyle(
                            fontFamily: 'NotoSansBengali',
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.pagePad,
                ),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _q = v.trim()),
                  decoration: InputDecoration(
                    hintText: t('জেলার নাম', 'District name'),
                    isDense: true,
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.muted,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final d = list[i];
                    final on = d == widget.selected;
                    return ListTile(
                      dense: true,
                      title: Text(
                        d,
                        style: TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 15,
                          fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                          color: on ? AppColors.brand : AppColors.ink,
                        ),
                      ),
                      trailing: on
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppColors.brand,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(d),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the list comes from, and that this is not the government's app.
class _Footnote extends StatelessWidget {
  const _Footnote();

  @override
  Widget build(BuildContext context) {
    // Tapping opens the full list of sources, one link each; the line itself
    // names the three government ones so the statement stands on its own.
    return InkWell(
      onTap: () => showSourcesSheet(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePad,
          18,
          AppSizes.pagePad,
          28,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t(
                  'আমার এমপি একটি স্বাধীন, বেসরকারি তথ্যসেবা; সরকারি অ্যাপ নয়। তথ্যের সূত্র: জাতীয় সংসদ (parliament.gov.bd), '
                      'নির্বাচন কমিশন (ecs.gov.bd), মন্ত্রিপরিষদ বিভাগ (cabinet.gov.bd), দ্য বিজনেস স্ট্যান্ডার্ড ও উইকিপিডিয়া। সব সূত্র দেখতে চাপুন।',
                  'My MP is an independent, non-governmental information service; it is not a government app. Sources: '
                      'Parliament (parliament.gov.bd), the Election Commission (ecs.gov.bd), the Cabinet Division '
                      '(cabinet.gov.bd), The Business Standard and Wikipedia. Tap to see every source.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small heading over a group of results, as the website's search box has
/// them: "আপনার এলাকার এমপি", then "আরও ফল".
class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePad + 2,
        8,
        AppSizes.pagePad,
        8,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'NotoSansBengali',
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: AppColors.brand,
        ),
      ),
    );
  }
}

/// A seat found by the place a reader typed: its member (or that it is
/// vacant), the seat and party, what kind of place matched, and a note when
/// the seat holds only part of it.
class _PlaceTile extends StatelessWidget {
  final SeatMatch match;
  const _PlaceTile({required this.match});

  static String _kindLabel(MatchKind k) => switch (k) {
    MatchKind.seat => t('আসন', 'Seat'),
    MatchKind.district => t('জেলা', 'District'),
    MatchKind.upazila => t('উপজেলা', 'Upazila'),
    MatchKind.union => t('ইউনিয়ন', 'Union'),
    MatchKind.ward => t('সিটি ওয়ার্ড', 'City ward'),
    MatchKind.place => t('এলাকা', 'Area'),
  };

  @override
  Widget build(BuildContext context) {
    final seat = match.seat;
    final m = seat.member;
    final ward = match.kind == MatchKind.ward;
    final partial = match.partial
        ? t(
            '${ward ? 'সিটির' : 'উপজেলার'} একাংশ এই আসনে',
            'Part of the ${ward ? 'city' : 'upazila'} is in this seat',
          )
        : null;
    final title =
        m?.nameBn ??
        t(
          '${seat.seatLabel}: আসনটি এখন শূন্য',
          '${seat.seatLabel}: the seat is now vacant',
        );
    final sub = [
      if (m != null || !t.en) seat.seatLabel,
      ?m?.partyBn,
      ?partial,
    ].join(' · ');
    final colour = AppColors.party(m?.party == 'BJEI' ? 'Jamaat' : m?.party);

    return Container(
      decoration: AppDecor.card(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => m != null
                  ? MemberScreen(member: m)
                  : SeatScreen(slug: seat.slug),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Row(
              children: [
                if (m != null)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colour.withValues(alpha: 0.55),
                        width: 2,
                      ),
                    ),
                    child: MemberAvatar(member: m, size: 46),
                  )
                else
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: AppColors.warnSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_seat_outlined,
                      color: AppColors.warn,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          height: 1.35,
                        ),
                      ),
                      if (sub.isNotEmpty)
                        Text(
                          sub,
                          style: const TextStyle(
                            fontFamily: 'NotoSansBengali',
                            fontSize: 13,
                            color: AppColors.muted,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _kindLabel(match.kind),
                  style: const TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
