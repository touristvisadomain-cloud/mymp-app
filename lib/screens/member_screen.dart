import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../bio.dart';
import '../data/member.dart';
import '../i18n.dart';
import '../loading.dart';
import '../maps/seat_map.dart';
import '../models.dart';
import '../party_logo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'committee_screen.dart';
import 'seat_result_card.dart';
import 'member_feed.dart';

/// Where the member's page leads beyond itself. The shell sets these to open
/// the app's own screens; while one is not set, the link it would draw is
/// left out (the page never points at nothing).
class MemberLinks {
  MemberLinks._();

  /// A party's page, by its slug ("bnp").
  static void Function(BuildContext context, String partySlug)? party;

  /// A seat's page, by its slug ("dhaka-17").
  static void Function(BuildContext context, String seatSlug)? seat;

  /// A district's page, by its slug ("dhaka").
  static void Function(BuildContext context, String districtSlug)? district;

  /// A committee's page, by its slug. Opens the app's CommitteeScreen unless
  /// set otherwise.
  static void Function(BuildContext context, String committeeSlug)? committee;
}

/// One member: who they are, what they hold, and what the press has written
/// about them, as the website's member page (`/mp/<slug>`) shows it. Opens with
/// the name and photograph already on screen when they came with the list, so
/// the fetch never shows a blank page.
class MemberScreen extends StatefulWidget {
  final MemberBrief member;
  const MemberScreen({super.key, required this.member});

  /// A member known only by the slug (a resigned member, a link): the name
  /// and photograph appear when the page arrives.
  MemberScreen.slug(String slug, {super.key})
    : member = MemberBrief(id: '', slug: slug, nameBn: '');

  @override
  State<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends State<MemberScreen>
    with RefetchOnLang<MemberScreen> {
  late Future<MemberProfile> _detail;

  /// The page once it has arrived, for the hero of a member not in the list.
  MemberProfile? _loaded;

  // The name appears in the bar only once the hero has scrolled out of sight.
  // Reading the scroll position is the one way that is certain: a height-based
  // guess inside the flexible space drew the name across the hero and the tabs
  // at the same time.
  static const _heroHeight = 316.0;
  final _scroll = ScrollController();
  bool _barTitle = false;

  String get _slug => widget.member.slug;

  @override
  void initState() {
    super.initState();
    _detail = _fetch();
    Api.instance.bootstrap.addListener(_onList);
    _scroll.addListener(() {
      final show =
          _scroll.hasClients &&
          _scroll.offset > _heroHeight - kToolbarHeight - 40;
      if (show != _barTitle) setState(() => _barTitle = show);
    });
  }

  Future<MemberProfile> _fetch({bool force = false}) {
    final f = fetchMemberProfile(_slug, force: force);
    f.then((p) {
      if (mounted && !identical(p, _loaded)) setState(() => _loaded = p);
    }, onError: (Object _) {});
    return f;
  }

  @override
  void dispose() {
    Api.instance.bootstrap.removeListener(_onList);
    _scroll.dispose();
    super.dispose();
  }

  /// The page again in the new language.
  @override
  void onLangChanged() => setState(() {
    _loaded = null;
    _detail = _fetch();
  });

  /// The name, seat and office in the hero come with the list; when the list
  /// is read again (in the other language) they are taken from the new one.
  void _onList() {
    if (mounted) setState(() {});
  }

  /// The member as the list has them, else as their page has them (a member
  /// who has resigned is not in the list), else as handed in.
  MemberBrief get _member =>
      Api.instance.cached?.members.where((m) => m.slug == _slug).firstOrNull ??
      _loaded?.brief ??
      widget.member;

  Future<void> _refreshDetail() async {
    final f = _fetch(force: true);
    setState(() => _detail = f);
    await settle(f);
  }

  @override
  Widget build(BuildContext context) {
    final m = _member;
    return Scaffold(
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          controller: _scroll,
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: _heroHeight,
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              actions: [
                IconButton(
                  tooltip: t('শেয়ার', 'Share'),
                  icon: const Icon(Icons.share_outlined),
                  onPressed: m.nameBn.isEmpty
                      ? null
                      : () => SharePlus.instance.share(
                          ShareParams(
                            text:
                                '${m.nameBn}, ${m.seatLabel}\n${Api.page('/mp/${m.slug}')}',
                            subject: m.nameBn,
                          ),
                        ),
                ),
              ],
              title: AnimatedOpacity(
                opacity: _barTitle ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Text(
                  m.nameBn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              // The photo and name fade out as the bar collapses, and are gone
              // before they reach the tabs: sliding under them, the photo covered
              // "পরিচিতি" and "সংবাদ ও ভিডিও" halfway through a scroll.
              flexibleSpace: LayoutBuilder(
                builder: (context, box) {
                  final top = MediaQuery.paddingOf(context).top;
                  final collapsed = kToolbarHeight + kTextTabBarHeight + top;
                  final open = _heroHeight + top;
                  final shown =
                      ((box.maxHeight - collapsed) / (open - collapsed)).clamp(
                        0.0,
                        1.0,
                      );
                  return FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: Opacity(
                      opacity: ((shown - 0.45) / 0.55).clamp(0.0, 1.0),
                      child: _hero(context, m),
                    ),
                  );
                },
              ),
              // The tabs sit on the green bar at both sizes, so they are drawn
              // in white: the brand green on brand green could not be read.
              bottom: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.72),
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
                tabs: [
                  Tab(text: t('পরিচিতি', 'Profile')),
                  Tab(text: t('সংবাদ ও ভিডিও', 'News and videos')),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _profileTab(),
              // The website's news section for this member: months with counts,
              // filters, a date span, and 30 at a time (lib/screens/member_feed.dart).
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: MemberFeed(slug: _slug),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The name in the other script: English under the Bangla, Bangla under
  /// the English.
  String? _otherName(MemberBrief m) {
    if (t.en) return _loaded?.nameAlt;
    return titleCaseName(m.nameEn ?? _loaded?.brief.nameEn);
  }

  Widget _hero(BuildContext context, MemberBrief m) {
    final other = _otherName(m);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.brand, AppColors.brandDark],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, box) => FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: box.maxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 28),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.85),
                        width: 3,
                      ),
                    ),
                    child: MemberAvatar(member: m, size: 104),
                  ),
                  const SizedBox(height: 12),
                  if (m.officeBn != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusPill,
                        ),
                      ),
                      child: Text(
                        m.officeBn!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      m.nameBn,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (other != null && other != m.nameBn)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 2, 24, 0),
                      child: Text(
                        other,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 13.5,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  if (m.nameBn.isNotEmpty)
                    Text(
                      m.seatLabel,
                      style: TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  // Clear of the tab bar drawn across the foot of the same bar.
                  const SizedBox(height: kTextTabBarHeight + 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileTab() {
    return Loaded<MemberProfile>(
      future: _detail,
      onRetry: () => setState(() => _detail = _fetch()),
      builder: (context, d) => RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _refreshDetail,
        child: _ProfileBody(profile: d, list: Api.instance.cached),
      ),
    );
  }
}

/// "TARIQUE RAHMAN" → "Tarique Rahman"; a name already in mixed case is kept.
String? titleCaseName(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  if (s != s.toUpperCase() || !RegExp('[A-Z]{2}').hasMatch(s)) return s;
  return s.toLowerCase().replaceAllMapped(
    RegExp(r"(^|[\s.\-('])([a-z])"),
    (m) => '${m[1]}${m[2]!.toUpperCase()}',
  );
}

const _ordinalsBn = [
  '',
  'প্রথম',
  'দ্বিতীয়',
  'তৃতীয়',
  'চতুর্থ',
  'পঞ্চম',
  'ষষ্ঠ',
  'সপ্তম',
  'অষ্টম',
  'নবম',
  'দশম',
  'একাদশ',
  'দ্বাদশ',
  'ত্রয়োদশ',
  'চতুর্দশ',
  'পঞ্চদশ',
];

const _ordinalWordsEn = [
  '',
  'First',
  'Second',
  'Third',
  'Fourth',
  'Fifth',
  'Sixth',
  'Seventh',
  'Eighth',
  'Ninth',
  'Tenth',
  'Eleventh',
  'Twelfth',
  'Thirteenth',
  'Fourteenth',
  'Fifteenth',
];

/// The year of each parliament's election, as the website's history has it.
const _electionYear = {
  1: 1973,
  2: 1979,
  3: 1986,
  4: 1988,
  5: 1991,
  6: 1996,
  7: 1996,
  8: 2001,
  9: 2008,
  10: 2014,
  11: 2018,
  12: 2024,
  13: 2026,
};

/// "ত্রয়োদশ সংসদ" / "13th Parliament".
String _parliamentOrdinal(int no) => t.en
    ? '${t.ord(no)} Parliament'
    : '${no < _ordinalsBn.length ? _ordinalsBn[no] : '${t.n(no)}তম'} সংসদ';

/// "ত্রয়োদশ সংসদ, ২০২৬" / "13th Parliament, 2026".
String parliamentLabel(int no) {
  final y = _electionYear[no];
  return y == null
      ? _parliamentOrdinal(no)
      : '${_parliamentOrdinal(no)}, ${t.n(y)}';
}

/// "Once", "Twice", "3 times".
String _timesEn(int n) => n == 1
    ? 'Once'
    : n == 2
    ? 'Twice'
    : '$n times';

/// Age in whole years on today's date in Bangladesh.
int? _ageFrom(String? iso) {
  final born = iso == null ? null : DateTime.tryParse(iso);
  if (born == null) return null;
  final now = DateTime.now().toUtc().add(const Duration(hours: 6));
  var age = now.year - born.year;
  if (now.month < born.month ||
      (now.month == born.month && now.day < born.day)) {
    age--;
  }
  return age >= 0 && age < 130 ? age : null;
}

/// The member's page below the hero, in the website's order: the header's
/// badges and links, the profile, the constituency, the terms, the result,
/// the notices, the seat, the committees, then what the website keeps in its
/// side column (contact, the same party, the district's other seats).
class _ProfileBody extends StatelessWidget {
  final MemberProfile profile;
  final Bootstrap? list;
  const _ProfileBody({required this.profile, required this.list});

  MemberProfile get d => profile;
  bool get en => t.en;

  /// The Bangla page on the website, for text only in Bangla so far.
  String get _bnPage => '${Api.base}/mp/${d.brief.slug}';

  /// "his", "her" or "their", for the English sentences.
  String get _his => d.brief.gender == 'Female'
      ? 'her'
      : d.brief.gender == 'Male'
      ? 'his'
      : 'their';

  String get _name => d.brief.nameBn;

  @override
  Widget build(BuildContext context) {
    final seat = d.seat;
    final general = seat != null && !seat.reserved;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pagePad,
        16,
        AppSizes.pagePad,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _header(context),
        const SizedBox(height: 24),
        ..._profile(context),
        if (general && seat.districtSlug != null) ...[
          const SizedBox(height: 28),
          _Heading(t('নির্বাচনী এলাকা', 'Constituency')),
          SeatMap(
            districtSlug: seat.districtSlug!,
            seatSlug: seat.slug,
            color: AppColors.party(d.brief.party),
            title: seat.nameBn,
            districtName: seat.districtBn,
            note: seat.boundaryBn,
          ),
        ],
        const SizedBox(height: 28),
        ..._terms(context),
        if (general) ...[const SizedBox(height: 28), ..._result(context)],
        const SizedBox(height: 28),
        ..._notices(context),
        if (general) ...[const SizedBox(height: 28), ..._seat(context, seat)],
        const SizedBox(height: 28),
        ..._committees(context),
        const SizedBox(height: 28),
        _contact(context),
        ..._partyMates(context),
        ..._sameDistrict(context),
        const SizedBox(height: 16),
        _sourceNote(context),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => openLink(context, Api.page('/mp/${d.brief.slug}')),
            icon: const Icon(
              Icons.public_rounded,
              size: 18,
              color: AppColors.brand,
            ),
            label: Text(
              t('ওয়েবসাইটে দেখুন', 'View on the website'),
              style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontWeight: FontWeight.w600,
                color: AppColors.brand,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /* ---------------- the header ---------------- */

  Widget _header(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final b = d.brief;
    final seat = d.seat;
    final checked = t.date(d.postsCheckedAt);
    final times = d.termsCount ?? d.priorTerms.length + 1;
    final districtSlug = seat?.districtSlug;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: AppColors.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: AppColors.party(b.party)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The party on a line of its own, opening its page.
                if (b.party != null)
                  _Tappable(
                    onTap: MemberLinks.party == null
                        ? null
                        : () => MemberLinks.party!(
                            context,
                            b.party!.toLowerCase(),
                          ),
                    child: Row(
                      children: [
                        PartyLogo(abbr: b.party, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d.partyNameBn ?? b.partyBn ?? b.party!,
                            style: text.titleSmall?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (MemberLinks.party != null)
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AppColors.muted,
                          ),
                      ],
                    ),
                  ),
                // Then where: the seat, and its district beside it.
                if (seat?.nameBn != null || seat?.districtBn != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: 6),
                      if (seat?.nameBn != null)
                        _Tappable(
                          onTap: MemberLinks.seat == null
                              ? null
                              : () => MemberLinks.seat!(context, seat!.slug),
                          child: Text(
                            seat!.nameBn!,
                            style: text.labelLarge?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                      if (seat?.nameBn != null && seat?.districtBn != null)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '·',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      if (seat?.districtBn != null)
                        Flexible(
                          child: _Tappable(
                            onTap:
                                MemberLinks.district == null ||
                                    districtSlug == null
                                ? null
                                : () => MemberLinks.district!(
                                    context,
                                    districtSlug,
                                  ),
                            child: Text(
                              t(
                                '${seat!.districtBn} জেলা',
                                '${seat.districtBn} district',
                              ),
                              style: text.bodyMedium,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                // The posts first, in dark; then the plainer facts.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in d.rolesBn)
                      _Badge(
                        r,
                        background: AppColors.ink,
                        foreground: Colors.white,
                      ),
                    for (final r in d.postBadgesBn)
                      _Badge(
                        r,
                        background: AppColors.ink,
                        foreground: Colors.white,
                      ),
                    if (d.resignedOn != null)
                      _Badge(
                        t(
                          'পদত্যাগ করেছেন, ${t.date(d.resignedOn)}',
                          'Resigned, ${t.date(d.resignedOn)}',
                        ),
                        background: AppColors.warnSoft,
                        foreground: AppColors.warn,
                      )
                    else
                      _Badge(
                        t(
                          'বর্তমান সদস্য, ত্রয়োদশ সংসদ',
                          'Current member, 13th Parliament',
                        ),
                        background: AppColors.brandSoft,
                        foreground: AppColors.brand,
                      ),
                    if (times > 1)
                      _Badge(
                        t(
                          'মোট ${t.n(times)} বার নির্বাচিত',
                          'Elected ${_timesEn(times).toLowerCase()}',
                        ),
                        outlined: true,
                      ),
                    if (seat?.reserved ?? b.reserved)
                      _Badge(
                        t('সংরক্ষিত নারী আসন', 'Reserved seat for women'),
                        outlined: true,
                      ),
                  ],
                ),
                if (checked != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        size: 14,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${t('সরকারি পদ সর্বশেষ যাচাই', 'Government posts last checked')}: $checked',
                          style: text.labelSmall?.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
                if (d.resignedOn != null) ...[
                  const SizedBox(height: 12),
                  _resigned(context),
                ],
                // The member's own accounts: round buttons with a short name
                // under each, in one row, rather than long wrapped pills.
                if (d.socials.isNotEmpty || d.facebookNotice != null) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    t('অফিসিয়াল অ্যাকাউন্ট', 'Official accounts'),
                    style: text.labelSmall?.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Up to five share one row evenly; more wrap.
                  d.socials.length <= 5
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final s in d.socials)
                              Expanded(child: _SocialButton(social: s)),
                            for (var k = d.socials.length; k < 5; k++)
                              const Spacer(),
                          ],
                        )
                      : Wrap(
                          spacing: 6,
                          runSpacing: 10,
                          children: [
                            for (final s in d.socials)
                              SizedBox(
                                width: 62,
                                child: _SocialButton(social: s),
                              ),
                          ],
                        ),
                  if (d.facebookNotice != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SocialIcon('facebook', size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            d.facebookNotice!,
                            style: text.labelSmall?.copyWith(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resigned(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final seat = d.seat?.nameBn;
    final body = text.bodyMedium?.copyWith(color: AppColors.ink, height: 1.6);
    final spans = en
        ? [
            TextSpan(
              text:
                  'Resigned as a Member of Parliament on ${t.date(d.resignedOn)}.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (seat != null)
              TextSpan(
                text:
                    ' ${_his[0].toUpperCase()}${_his.substring(1)} seat, $seat, is now vacant.',
              ),
            const TextSpan(
              text:
                  ' Source: the list of members of the Parliament of Bangladesh.',
              style: TextStyle(color: AppColors.inkSoft),
            ),
          ]
        : [
            TextSpan(
              text:
                  '${t.date(d.resignedOn)} তারিখে সংসদ সদস্য পদ থেকে পদত্যাগ করেছেন।',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (seat != null) TextSpan(text: ' তাঁর আসন $seat এখন শূন্য।'),
            const TextSpan(
              text: ' সূত্র: বাংলাদেশ জাতীয় সংসদের সদস্য তালিকা।',
              style: TextStyle(color: AppColors.inkSoft),
            ),
          ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: const BoxDecoration(
        color: AppColors.warnSoft,
        borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
        border: Border(left: BorderSide(color: AppColors.warn, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3, right: 10),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.warn,
            ),
          ),
          Expanded(
            child: Text.rich(TextSpan(children: spans), style: body),
          ),
        ],
      ),
    );
  }

  /* ---------------- the profile ---------------- */

  List<Widget> _profile(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final para = text.bodyLarge?.copyWith(
      color: AppColors.inkSoft,
      height: 1.7,
    );
    final age = _ageFrom(d.dateOfBirth);
    final born = t.date(d.dateOfBirth);
    final wiki = d.bioFromWiki;
    final lEducation = t('শিক্ষা', 'Education');
    final starred = <String>{
      if (wiki.contains('birthPlaceBn')) t('জন্মস্থান', 'Birthplace'),
      if (wiki.contains('educationBn')) lEducation,
      if (wiki.contains('professionBn')) t('পেশা', 'Profession'),
    };
    final times = d.termsCount;
    final facts = <({String label, String value})>[
      if (born != null)
        (
          label: t('জন্ম', 'Born'),
          value: en
              ? '$born${age != null ? ' (aged $age)' : ''}'
              : '$born${age != null ? ', ${t.n(age)} বছর' : ''}',
        ),
      if (d.birthPlaceBn != null)
        (label: t('জন্মস্থান', 'Birthplace'), value: d.birthPlaceBn!),
      if (d.brief.gender != null)
        (
          label: t('লিঙ্গ', 'Gender'),
          value: d.brief.gender == 'Female'
              ? t('নারী', 'Female')
              : t('পুরুষ', 'Male'),
        ),
      if (d.educationBn != null) (label: lEducation, value: d.educationBn!),
      if (d.professionBn != null)
        (label: t('পেশা', 'Profession'), value: d.professionBn!),
      if (d.fatherBn != null) (label: t('পিতা', 'Father'), value: d.fatherBn!),
      if (d.motherBn != null) (label: t('মাতা', 'Mother'), value: d.motherBn!),
      if (d.isFreedomFighter)
        (label: t('মুক্তিযোদ্ধা', 'Freedom fighter'), value: t('হ্যাঁ', 'Yes')),
      if (t.date(d.termStart) case final start?)
        (
          label: d.resignedOn != null
              ? t('মেয়াদ', 'Term')
              : t('বর্তমান মেয়াদ', 'Current term'),
          value: en
              ? (d.termEnd != null
                    ? '$start to ${t.date(d.termEnd)}'
                    : 'From $start, ongoing')
              : '$start থেকে ${t.date(d.termEnd) ?? 'চলমান'}',
        ),
      if (d.resignedOn != null)
        (
          label: t('পদত্যাগ', 'Resigned'),
          value:
              t.date(d.resignedOn) ??
              t('তারিখ পাওয়া যায়নি', 'Date not found'),
        ),
      if (times != null && times > 0)
        (
          label: t('সংসদ সদস্য নির্বাচিত', 'Elected an MP'),
          value: en ? _timesEn(times) : 'মোট ${t.n(times)} বার',
        ),
    ];
    final wikiSources = facts.any((f) => starred.contains(f.label))
        ? d.bioSource
        : const <String>[];

    final won = d.result != null && d.result!.won;
    final introParts = en
        ? [
            "Parliament's list of members",
            if (won) 'the published election result',
            if (wikiSources.isNotEmpty)
              'the Wikipedia facts marked with an asterisk in the list below',
          ]
        : [
            'সংসদের সদস্য তালিকা',
            if (won) 'প্রকাশিত নির্বাচনী ফল',
            if (wikiSources.isNotEmpty)
              'নিচের তালিকায় তারকাচিহ্নিত উইকিপিডিয়ার তথ্য',
          ];
    final introSources = introParts.length > 1
        ? '${introParts.sublist(0, introParts.length - 1).join(', ')}${t(' এবং ', ' and ')}${introParts.last}'
        : introParts.first;

    final bioParagraphs = (d.bioBn ?? '')
        .split(RegExp(r'\n{2,}'))
        .where((p) => p.trim().isNotEmpty)
        .toList();

    return [
      _Heading(t('পরিচিতি', 'Profile')),
      if (d.leadBn != null) Text(d.leadBn!, style: para),
      if (d.introBn.isNotEmpty) ...[
        for (final p in d.introBn) ...[
          const SizedBox(height: 10),
          Text(p, style: para),
        ],
        const SizedBox(height: 10),
        Text(
          en
              ? 'This introduction is put together from the information on this page: $introSources. It contains no assessment of our own.'
              : 'এই পরিচিতি এই পাতার তথ্য থেকে সাজানো: $introSources। নিজস্ব কোনো মূল্যায়ন এতে নেই।',
          style: text.labelSmall?.copyWith(fontSize: 12.5, height: 1.6),
        ),
      ],
      if (d.showSummary && d.summaryBn != null) ...[
        const SizedBox(height: 12),
        Text(d.summaryBn!, style: para),
        if (d.summaryTranslated && bioParagraphs.isEmpty) ...[
          const SizedBox(height: 6),
          TranslatedNote(originalUrl: _bnPage),
        ],
      ],
      if (bioParagraphs.isNotEmpty) ...[
        const SizedBox(height: 14),
        BioCard(
          text: d.bioBn!,
          showTitle: false,
          translated: d.bioTranslated,
          originalUrl: _bnPage,
          sources: [for (final s in d.bioSources) s.url],
          sourceNames: {
            for (final s in d.bioSources)
              if (s.label != null) s.url: s.label!,
          },
          askForCorrections: true,
        ),
      ],
      if (en && d.bioOnlyInBangla) ...[
        const SizedBox(height: 14),
        _InfoCard(
          children: [
            TextSpan(text: '$_name’s biography is available in Bangla. '),
            _link(context, 'Read the biography in Bangla', _bnPage),
          ],
        ),
      ],
      const SizedBox(height: 14),
      if (facts.isNotEmpty)
        FactsCard(
          title: t('তথ্য', 'Details'),
          facts: facts,
          starred: starred,
          lines: {lEducation},
          footer: wikiSources.isEmpty ? null : _wikiNote(context, wikiSources),
        )
      else
        _EmptyCard(
          title: t(
            'পরিচিতির তথ্য সংসদের তথ্যভান্ডারে নেই।',
            "Parliament's database has no profile details for this member.",
          ),
        ),
    ];
  }

  /// "উইকিপিডিয়া নিবন্ধ (বাংলা)" / "Bangla Wikipedia article".
  String _wikiArticle(String url, bool many) {
    final bangla = url.contains('//bn.');
    return en
        ? '${many ? (bangla ? 'Bangla ' : 'English ') : ''}Wikipedia article'
        : 'উইকিপিডিয়া নিবন্ধ${many ? (bangla ? ' (বাংলা)' : ' (ইংরেজি)') : ''}';
  }

  List<InlineSpan> _articles(BuildContext context, List<String> urls) => [
    for (final (i, u) in urls.indexed) ...[
      if (i > 0) TextSpan(text: t(' ও ', ' and ')),
      _link(context, _wikiArticle(u, urls.length > 1), u),
    ],
  ];

  Widget _wikiNote(BuildContext context, List<String> urls) {
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(fontSize: 12.5, height: 1.6);
    const star = TextSpan(
      text: '*',
      style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w700),
    );
    return Text.rich(
      TextSpan(
        children: en
            ? [
                const TextSpan(text: 'Facts marked '),
                star,
                const TextSpan(text: ' are taken from the member’s '),
                ..._articles(context, urls),
                const TextSpan(
                  text:
                      ' and have not been checked against the records of Parliament or the Election Commission. If you see a mistake, let us know.',
                ),
              ]
            : [
                star,
                const TextSpan(text: ' চিহ্নিত তথ্য সদস্যের '),
                ..._articles(context, urls),
                const TextSpan(
                  text:
                      ' থেকে নেওয়া; সংসদ বা নির্বাচন কমিশনের নথির সঙ্গে মিলিয়ে দেখা হয়নি। ভুল দেখলে জানান।',
                ),
              ],
      ),
      style: style,
    );
  }

  /* ---------------- terms in Parliament ---------------- */

  List<Widget> _terms(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final b = d.brief;
    final prior = d.priorTerms;
    final n = d.termsCount;
    final no = list?.parliamentNo ?? 13;

    Widget row({
      required String label,
      required bool current,
      required String seat,
      String? seatSub,
      required String? party,
      String? sub,
    }) => Container(
      color: current ? AppColors.brandSoft.withValues(alpha: 0.4) : null,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 13,
                height: 1.4,
                fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                color: current ? AppColors.brand : AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(seat, style: text.labelLarge?.copyWith(fontSize: 14.5)),
                if (seatSub != null)
                  Text(
                    seatSub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(fontSize: 12.5),
                  ),
                if (sub != null)
                  Text(sub, style: text.labelSmall?.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PartyLogo(abbr: party, size: 16),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 72),
            child: Text(
              party ?? t('দল নেই', 'No party'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );

    final String note;
    if (en) {
      final he = _his == 'her' ? 'she' : 'he';
      final String first;
      if (n != null) {
        final rest = n > 1
            ? (prior.length >= n - 1
                  ? '. '
                  : prior.isEmpty
                  ? '; details of the ${n - 1 == 1 ? 'earlier term were' : '${n - 1} earlier terms were'} not found in Parliament\'s database. '
                  : '; details of ${prior.length} of the ${n - 1} earlier terms are given here. ')
            : '. ';
        first =
            'According to the Parliament Secretariat, $he has been elected an MP ${n == 1 ? 'once' : '${_timesEn(n).toLowerCase()} in all'}$rest';
      } else if (prior.isNotEmpty) {
        final k = prior.length + 1;
        first =
            'According to Parliament\'s database, this is $_his ${(k < _ordinalWordsEn.length ? _ordinalWordsEn[k] : '${k}th').toLowerCase()} term. ';
      } else {
        first = "Parliament's database has no earlier term for this member. ";
      }
      note =
          '${first}Parliament’s database holds the records of the 4th, 5th and 7th to 12th Parliaments; it has no lists for the 1st to 3rd and the 6th, so an earlier term in those, if any, does not appear here.';
    } else {
      final String first;
      if (n != null) {
        final rest = n > 1
            ? (prior.length >= n - 1
                  ? '। '
                  : prior.isEmpty
                  ? '; আগের ${t.n(n - 1)}টি মেয়াদের বিস্তারিত সংসদের তথ্যভান্ডারে পাওয়া যায়নি। '
                  : '; আগের ${t.n(n - 1)}টি মেয়াদের মধ্যে ${t.n(prior.length)}টির বিস্তারিত এখানে আছে। ')
            : '। ';
        first =
            'সংসদ সচিবালয়ের তথ্য অনুযায়ী তিনি মোট ${t.n(n)} বার সংসদ সদস্য নির্বাচিত হয়েছেন$rest';
      } else if (prior.isNotEmpty) {
        final k = prior.length + 1;
        first =
            'সংসদের তথ্যভান্ডার অনুযায়ী এটি ${k < _ordinalsBn.length ? _ordinalsBn[k] : '${t.n(k)}তম'} মেয়াদ। ';
      } else {
        first =
            'সংসদের তথ্যভান্ডারে এই সদস্যের আগের কোনো মেয়াদ পাওয়া যায়নি। ';
      }
      note =
          '$firstসেখানে ৪র্থ, ৫ম ও ৭ম থেকে ১২শ সংসদের রেকর্ড আছে; ১ম থেকে ৩য় ও ৬ষ্ঠ সংসদের তালিকা নেই, তাই তার আগের মেয়াদ থাকলে এখানে দেখা যাবে না।';
    }

    return [
      _Heading(t('সংসদে মেয়াদ', 'Terms in Parliament')),
      _Card(
        children: [
          row(
            label: parliamentLabel(no),
            current: true,
            seat: d.seat?.nameBn ?? t('আসন উল্লেখ নেই', 'Seat not stated'),
            sub: d.resignedOn != null
                ? t(
                    'পদত্যাগ করেছেন ${t.date(d.resignedOn)}',
                    'Resigned ${t.date(d.resignedOn)}',
                  )
                : t('বর্তমান মেয়াদ', 'Current term'),
            party: b.party,
          ),
          for (final pt in prior)
            row(
              label: pt.labelBn ?? parliamentLabel(pt.parliamentNo),
              current: false,
              seat: en
                  ? pt.seatNameBn ?? 'Seat not stated'
                  : pt.seatNameBn ?? pt.seatNameEn ?? 'আসন উল্লেখ নেই',
              seatSub: !en && pt.seatNameBn != null ? pt.seatNameEn : null,
              party: pt.partyAbbr,
            ),
        ],
      ),
      const SizedBox(height: 10),
      Text(note, style: text.labelSmall?.copyWith(fontSize: 12.5, height: 1.6)),
    ];
  }

  /* ---------------- the result ---------------- */

  List<Widget> _result(BuildContext context) {
    final r = d.result;
    final year = _electionYear[list?.parliamentNo ?? 13];
    final other = r != null && !r.won;
    final title = en
        ? other
              ? 'Result for this seat in the ${year != null ? '$year ' : ''}general election'
              : 'Votes won in the ${year != null ? '$year ' : ''}election'
        : other
        ? '${year != null ? '${t.n(year)} সালের সাধারণ নির্বাচনে' : 'সাধারণ নির্বাচনে'} এই আসনের ফল'
        : '${year != null ? '${t.n(year)} নির্বাচনে' : 'নির্বাচনে'} প্রাপ্ত ভোট';
    final seat = d.seat;
    return [
      _Heading(
        title,
        link: MemberLinks.seat == null || seat == null
            ? null
            : t('আসনের সব ফল', 'All results for the seat'),
        onLink: () => MemberLinks.seat!(context, seat!.slug),
      ),
      if (r != null) ...[
        if (other) ...[
          Text(
            t(
              'এই আসনের সাধারণ নির্বাচনের বিজয়ী ও বর্তমান সংসদ সদস্যের নাম আলাদা। নিচের কার্ডের শেষে উৎসের বিবরণ দেখুন।',
              "The winner of this seat's general election and the current MP have different names. See the details of the source at the end of the card below.",
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 12),
        ],
        SeatResultCard(
          result: r,
          parliamentLabel: parliamentLabel(list?.parliamentNo ?? 13),
        ),
      ] else
        _EmptyCard(
          title: t(
            'এই আসনের ভোটের সংখ্যা এখনো যোগ হয়নি।',
            'The vote counts for this seat have not been added yet.',
          ),
          body: t(
            'সংসদের তথ্যভান্ডারে ভোটের সংখ্যা নেই। নির্বাচন কমিশনের গেজেট থেকে যাচাই করে যোগ করা হলে এখানে দেখা যাবে।',
            "Parliament's database has no vote counts. They will appear here once they have been checked against the Election Commission's gazette and added.",
          ),
        ),
    ];
  }

  /* ---------------- notices ---------------- */

  List<Widget> _notices(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final notices = d.notices;
    return [
      _Heading(
        t('সংসদ সচিবালয়ের প্রজ্ঞাপন', 'Parliament Secretariat notifications'),
        count: notices.length,
      ),
      if (notices.isNotEmpty)
        _Card(
          children: [
            for (final n in notices)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (n.titleBn != null)
                            Text(
                              n.titleBn!,
                              style: text.bodyLarge?.copyWith(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              t.date(n.date) ?? t('তারিখ নেই', 'No date'),
                              ?n.categoryBn,
                            ].join(', '),
                            style: text.labelSmall?.copyWith(fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    if (n.pdfUrl != null) ...[
                      const SizedBox(width: 10),
                      DocButton(label: 'PDF', url: n.pdfUrl!),
                    ],
                  ],
                ),
              ),
          ],
        )
      else
        _EmptyCard(
          title: t(
            'এই সদস্য সম্পর্কে সংসদ সচিবালয়ের কোনো প্রজ্ঞাপন নেই।',
            'There are no Parliament Secretariat notifications about this member.',
          ),
          body: t(
            'সংসদ সচিবালয় কোনো সদস্যের নামে প্রজ্ঞাপন বা সরকারি আদেশ প্রকাশ করলে তা প্রতিদিন এখানে যুক্ত হয়।',
            "When the Parliament Secretariat publishes a notification or government order in a member's name, it is added here in the daily update.",
          ),
        ),
    ];
  }

  /* ---------------- the seat ---------------- */

  List<Widget> _seat(BuildContext context, ProfileSeat seat) {
    final text = Theme.of(context).textTheme;
    final area = seat.boundaryBn;
    return [
      _Heading(
        '${t('আসন', 'Seat')}: ${seat.nameBn ?? ''}',
        link: MemberLinks.seat == null ? null : t('আসনের পাতা', 'Seat page'),
        onLink: () => MemberLinks.seat!(context, seat.slug),
      ),
      if (area != null)
        _Card(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              t('এলাকা', 'Area'),
              style: text.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(area, style: text.bodyLarge?.copyWith(height: 1.65)),
            if (seat.boundaryTranslated) ...[
              const SizedBox(height: 6),
              TranslatedNote(originalUrl: _bnPage),
            ],
          ],
        )
      // English with no English of the Election Commission's words yet; every
      // general seat has them in Bangla.
      else if (en)
        _InfoCard(
          children: [
            const TextSpan(
              text:
                  'The Election Commission’s description of this seat’s area is available in Bangla. ',
            ),
            _link(context, 'Read it in Bangla', _bnPage),
          ],
        )
      else
        _EmptyCard(title: 'এই আসনের এলাকার বিবরণ পাওয়া যায়নি।'),
    ];
  }

  /* ---------------- committees ---------------- */

  List<Widget> _committees(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final list = d.committees;
    void open(CommitteeRef c) {
      final hook = MemberLinks.committee;
      if (hook != null) {
        hook(context, c.slug);
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CommitteeScreen(slug: c.slug, name: c.nameBn),
        ),
      );
    }

    return [
      _Heading(
        t('সংসদীয় কমিটি', 'Parliamentary committees'),
        count: list.length,
      ),
      if (list.isNotEmpty)
        for (final c in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                side: const BorderSide(color: AppColors.rule),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                onTap: c.slug.isEmpty ? null : () => open(c),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.nameBn,
                          style: text.labelLarge?.copyWith(fontSize: 15),
                        ),
                      ),
                      // A chair is marked; a member is what everyone is.
                      if (c.role != null &&
                          c.role != 'সদস্য' &&
                          c.role != 'Member') ...[
                        const SizedBox(width: 8),
                        _Badge(
                          c.role!,
                          background: AppColors.brandSoft,
                          foreground: AppColors.brand,
                        ),
                      ],
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
      else
        _EmptyCard(
          title: t(
            'হালনাগাদ কোনো কমিটিতে এই সদস্যের নাম নেই।',
            'This member is not on any committee whose membership list has been updated.',
          ),
          body: en
              ? "Of Parliament's ${d.committeesTotal} committees, the membership lists of ${d.committeesCurrent} have been updated for the 13th Parliament. The rest will be added here when they are updated."
              : 'সংসদের ${t.n(d.committeesTotal)}টি কমিটির মধ্যে ${t.n(d.committeesCurrent)}টির সদস্য তালিকা ত্রয়োদশ সংসদের জন্য হালনাগাদ হয়েছে। বাকিগুলো হালনাগাদ হলে এখানে যুক্ত হবে।',
        ),
    ];
  }

  /* ---------------- the side column ---------------- */

  Widget _contact(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final small = text.bodyMedium?.copyWith(fontSize: 13.5, height: 1.6);
    final email = d.email;
    final reserved = d.seat?.reserved ?? d.brief.reserved;
    return _Card(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(
              Icons.mail_outline_rounded,
              size: 18,
              color: AppColors.brand,
            ),
            const SizedBox(width: 8),
            Text(t('যোগাযোগ', 'Contact'), style: text.titleMedium),
          ],
        ),
        const SizedBox(height: 10),
        if (email != null) ...[
          Text(
            en
                ? 'The official address published by Parliament. Messages go straight to the member; My MP does not reply on $_his behalf.'
                : 'সংসদ কর্তৃক প্রকাশিত দাপ্তরিক ঠিকানা। বার্তা সরাসরি সদস্যের কাছে যাবে; আমার এমপি তাঁর পক্ষে উত্তর দেয় না।',
            style: small,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => openLink(context, 'mailto:$email'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ] else
          Text(
            t(
                  'সংসদের তথ্যভান্ডারে এই সদস্যের কোনো দাপ্তরিক ইমেইল প্রকাশ করা নেই।',
                  "Parliament's database publishes no official email address for this member.",
                ) +
                (reserved
                    ? t(
                        ' সংরক্ষিত আসনের সদস্যদের ক্ষেত্রে এটি সাধারণ।',
                        ' This is common for members in reserved seats.',
                      )
                    : ''),
            style: small,
          ),
        if (d.socials.isNotEmpty || d.facebookNotice != null) ...[
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.rule),
          const SizedBox(height: 12),
          Text(
            t('অফিসিয়াল সোশ্যাল মিডিয়া', 'Official social media'),
            style: text.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          for (final s in d.socials)
            InkWell(
              onTap: () => openLink(context, s.url),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SocialIcon(s.key, size: 17),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          text: s.label,
                          children: [
                            if (s.unverified)
                              TextSpan(
                                text:
                                    ' (${t('যাচাই করা হয়নি', 'Not verified')})',
                                style: text.labelSmall,
                              ),
                          ],
                        ),
                        style: text.labelLarge?.copyWith(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 13,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          if (d.facebookNotice != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const SocialIcon('facebook', size: 17),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      d.facebookNotice!,
                      style: text.bodyMedium?.copyWith(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: d.socialSource.isNotEmpty
                  ? [
                      TextSpan(
                        text: '${t('সূত্র: সদস্যের', 'Source: the member’s')} ',
                      ),
                      ..._articles(context, d.socialSource),
                      TextSpan(
                        text: t(
                          '। ভুল দেখলে জানান।',
                          '. If you see a mistake, let us know.',
                        ),
                      ),
                    ]
                  : [
                      TextSpan(
                        text: t(
                          'আমার এমপির সম্পাদক যাচাই করে যুক্ত করেছেন।',
                          'Checked and added by the editor of My MP.',
                        ),
                      ),
                    ],
            ),
            style: text.labelSmall?.copyWith(height: 1.6),
          ),
        ],
      ],
    );
  }

  List<Widget> _partyMates(BuildContext context) {
    final b = d.brief;
    final party = b.party;
    final members = list?.members ?? const <MemberBrief>[];
    if (party == null) return const [];
    final mates = members
        .where((x) => x.party == party && x.slug != b.slug)
        .toList();
    if (mates.isEmpty) return const [];
    final all = mates.length + 1;
    return [
      const SizedBox(height: 14),
      _ListCard(
        leading: PartyLogo(abbr: party, size: 22),
        title: t('একই দলের', 'Same party'),
        link: MemberLinks.party == null
            ? null
            : en
            ? 'All $all'
            : 'সব ${t.n(all)}',
        onLink: () => MemberLinks.party!(context, party.toLowerCase()),
        rows: [
          for (final x in mates.take(5))
            _ListRow(
              left: x.nameBn,
              right: x.seatLabel,
              onTap: () => _openMember(context, x),
            ),
        ],
      ),
    ];
  }

  List<Widget> _sameDistrict(BuildContext context) {
    final b = d.brief;
    final district = d.seat?.districtBn ?? b.districtBn;
    final members = list?.members ?? const <MemberBrief>[];
    if (district == null || d.seat?.reserved == true) return const [];
    final others = members
        .where(
          (x) => x.slug != b.slug && !x.reserved && x.districtBn == district,
        )
        .toList();
    if (others.isEmpty) return const [];
    final slug = d.seat?.districtSlug;
    return [
      const SizedBox(height: 14),
      _ListCard(
        title: en
            ? 'Other seats in $district district'
            : '$district জেলার অন্য আসন',
        link: MemberLinks.district == null || slug == null
            ? null
            : t('জেলা', 'District'),
        onLink: () => MemberLinks.district!(context, slug!),
        rows: [
          for (final x in others.take(6))
            _ListRow(
              left: x.seatLabel,
              right: x.nameBn,
              party: x.party,
              strongLeft: false,
              onTap: () => _openMember(context, x),
            ),
        ],
      ),
    ];
  }

  void _openMember(BuildContext context, MemberBrief x) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => MemberScreen(member: x)));
  }

  Widget _sourceNote(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.brandSoft,
      borderRadius: BorderRadius.circular(AppSizes.radiusCard),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2, right: 10),
          child: Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.brand,
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: en
                  ? [
                      const TextSpan(
                        text:
                            'Source: the Parliament of Bangladesh. Updated daily from Parliament’s database. If you see a mistake, ',
                      ),
                      _link(context, 'let us know', Api.page('/jogajog')),
                      const TextSpan(text: '.'),
                    ]
                  : [
                      const TextSpan(
                        text:
                            'তথ্যসূত্র বাংলাদেশ জাতীয় সংসদ। সংসদের তথ্যভান্ডার থেকে প্রতিদিন হালনাগাদ। ভুল দেখলে ',
                      ),
                      _link(context, 'আমাদের জানান', Api.page('/jogajog')),
                      const TextSpan(text: '।'),
                    ],
            ),
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 13,
              height: 1.6,
              color: AppColors.brandDark,
            ),
          ),
        ),
      ],
    ),
  );
}

/// A link inside running text.
InlineSpan _link(BuildContext context, String label, String url) => WidgetSpan(
  alignment: PlaceholderAlignment.baseline,
  baseline: TextBaseline.alphabetic,
  child: GestureDetector(
    onTap: () => openLink(context, url),
    child: Text(
      label,
      style: DefaultTextStyle.of(context).style
          .merge(
            const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontWeight: FontWeight.w600,
              color: AppColors.brand,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.brand,
            ),
          )
          .copyWith(fontSize: 13),
    ),
  ),
);

/// A section's heading, with its count and a link to the whole when there is
/// one: the website's h2.
class _Heading extends StatelessWidget {
  final String title;
  final int? count;
  final String? link;
  final VoidCallback? onLink;
  const _Heading(this.title, {this.count, this.link, this.onLink});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: title,
                children: [
                  if (count != null && count! > 0)
                    TextSpan(
                      text: '  (${t.n(count)})',
                      style: text.titleSmall?.copyWith(color: AppColors.muted),
                    ),
                ],
              ),
              style: text.titleLarge?.copyWith(fontSize: 19.5),
            ),
          ),
          if (link != null && onLink != null)
            TextButton(
              onPressed: onLink,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                '$link →',
                style: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brand,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A white card holding rows split by hairlines.
class _Card extends StatelessWidget {
  final List<Widget> children;

  /// Padding means one block of content; without it the children are rows
  /// with hairlines between them.
  final EdgeInsets? padding;
  const _Card({required this.children, this.padding});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusCard),
      border: Border.all(color: AppColors.rule),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: padding != null
          ? children
          : [
              for (final (i, c) in children.indexed) ...[
                if (i > 0) const Divider(height: 1),
                c,
              ],
            ],
    ),
  );
}

/// The website's empty state: what is missing, and why.
class _EmptyCard extends StatelessWidget {
  final String title;
  final String? body;
  const _EmptyCard({required this.title, this.body});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: AppColors.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.labelLarge?.copyWith(fontSize: 14.5)),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!, style: text.bodyMedium?.copyWith(height: 1.6)),
          ],
        ],
      ),
    );
  }
}

/// A card with the info mark and a sentence, links inside it.
class _InfoCard extends StatelessWidget {
  final List<InlineSpan> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) => _Card(
    padding: const EdgeInsets.all(16),
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3, right: 10),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.brand,
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(children: children),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontSize: 15, height: 1.6),
            ),
          ),
        ],
      ),
    ],
  );
}

/// A badge in the header: an office, a post, the status.
class _Badge extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  final bool outlined;
  const _Badge(
    this.text, {
    this.background = Colors.transparent,
    this.foreground = AppColors.inkSoft,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
    decoration: BoxDecoration(
      color: outlined ? null : background,
      borderRadius: BorderRadius.circular(text.length > 26 ? 12 : 999),
      border: outlined ? Border.all(color: AppColors.rule) : null,
    ),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: 'NotoSansBengali',
        fontSize: 12.5,
        height: 1.4,
        fontWeight: outlined ? FontWeight.w600 : FontWeight.w700,
        color: foreground,
      ),
    ),
  );
}

/// Text that opens something when there is something to open.
class _Tappable extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _Tappable({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => onTap == null
      ? child
      : InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: child,
          ),
        );
}

/// One of the member's accounts in the header: the service's mark in a round
/// button and its short name under it; a page not yet confirmed says so.
class _SocialButton extends StatelessWidget {
  final ProfileSocial social;
  const _SocialButton({required this.social});

  static String _name(String key) => switch (key) {
    'facebook' => t('ফেসবুক', 'Facebook'),
    'x' => 'X',
    'youtube' => t('ইউটিউব', 'YouTube'),
    'instagram' => t('ইনস্টাগ্রাম', 'Instagram'),
    'website' => t('ওয়েবসাইট', 'Website'),
    _ => key,
  };

  @override
  Widget build(BuildContext context) {
    final s = social;
    return Semantics(
      button: true,
      label: s.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openLink(context, s.url),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.rule),
                  ),
                  alignment: Alignment.center,
                  child: SocialIcon(s.key, size: 20),
                ),
                const SizedBox(height: 5),
                Text(
                  _name(s.key),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                    height: 1.3,
                  ),
                ),
                if (s.unverified)
                  Text(
                    t('যাচাই হয়নি', 'Unverified'),
                    style: const TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 10,
                      color: AppColors.muted,
                      height: 1.2,
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

/// A short list in a card, as the website's side column draws it.
class _ListCard extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? link;
  final VoidCallback? onLink;
  final List<Widget> rows;
  const _ListCard({
    this.leading,
    required this.title,
    this.link,
    this.onLink,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Card(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
      children: [
        Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Expanded(child: Text(title, style: text.titleMedium)),
            if (link != null)
              TextButton(
                onPressed: onLink,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '$link →',
                  style: const TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brand,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (final (i, r) in rows.indexed) ...[
          if (i > 0) const Divider(height: 1),
          r,
        ],
      ],
    );
  }
}

class _ListRow extends StatelessWidget {
  final String left;
  final String right;
  final String? party;
  final bool strongLeft;
  final VoidCallback onTap;
  const _ListRow({
    required this.left,
    required this.right,
    this.party,
    this.strongLeft = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 9, 6, 9),
        child: Row(
          children: [
            Expanded(
              flex: strongLeft ? 3 : 2,
              child: Text(
                left,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 14.5,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: strongLeft ? 2 : 3,
              child: Text(
                right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 14,
                  color: AppColors.muted,
                ),
              ),
            ),
            if (party != null) ...[
              const SizedBox(width: 8),
              PartyLogo(abbr: party, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

/// The mark of a member's account: Facebook, X, YouTube, Instagram, or a
/// globe for a website. Drawn here, so no icon font or package is added.
class SocialIcon extends StatelessWidget {
  /// facebook, x, youtube, instagram or website.
  final String kind;
  final double size;
  const SocialIcon(this.kind, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case 'facebook':
        return Icon(Icons.facebook, size: size, color: const Color(0xFF1877F2));
      case 'website':
      case 'globe':
        return Icon(Icons.public_rounded, size: size, color: AppColors.muted);
      default:
        return CustomPaint(
          size: Size.square(size),
          painter: _BrandPainter(kind),
        );
    }
  }
}

class _BrandPainter extends CustomPainter {
  final String kind;
  const _BrandPainter(this.kind);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final p = Paint()..isAntiAlias = true;
    switch (kind) {
      case 'youtube':
        // A red rounded screen with a white play mark.
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(0, w * 0.16, w, w * 0.68),
          Radius.circular(w * 0.2),
        );
        canvas.drawRRect(r, p..color = const Color(0xFFFF0000));
        final play = Path()
          ..moveTo(w * 0.4, w * 0.33)
          ..lineTo(w * 0.68, w * 0.5)
          ..lineTo(w * 0.4, w * 0.67)
          ..close();
        canvas.drawPath(play, p..color = Colors.white);
      case 'instagram':
        // A rounded square, a lens and the small dot, in Instagram's pink.
        p
          ..color = const Color(0xFFD62976)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.1;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.08, w * 0.08, w * 0.84, w * 0.84),
            Radius.circular(w * 0.26),
          ),
          p,
        );
        canvas.drawCircle(Offset(w / 2, w / 2), w * 0.2, p);
        canvas.drawCircle(
          Offset(w * 0.73, w * 0.27),
          w * 0.055,
          p..style = PaintingStyle.fill,
        );
      case 'x':
        // X's mark: a broad stroke one way, a thin one the other.
        p
          ..color = AppColors.ink
          ..strokeCap = StrokeCap.square
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(w * 0.14, w * 0.12),
          Offset(w * 0.86, w * 0.88),
          p..strokeWidth = w * 0.2,
        );
        canvas.drawLine(
          Offset(w * 0.84, w * 0.12),
          Offset(w * 0.16, w * 0.88),
          p..strokeWidth = w * 0.09,
        );
      default:
        canvas.drawCircle(
          Offset(w / 2, w / 2),
          w * 0.4,
          p
            ..color = AppColors.muted
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.1,
        );
    }
  }

  @override
  bool shouldRepaint(_BrandPainter old) => old.kind != kind;
}
