import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../bio.dart';
import '../bn.dart';
import '../i18n.dart';
import '../loading.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'seat_result_card.dart';
import 'story_list.dart';

/// One member: who they are, what they hold, and what the press has written
/// about them. Opens with the name and photograph already on screen — they
/// came with the list — so the fetch never shows a blank page.
class MemberScreen extends StatefulWidget {
  final MemberBrief member;
  const MemberScreen({super.key, required this.member});

  @override
  State<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends State<MemberScreen>
    with RefetchOnLang<MemberScreen> {
  late Future<MemberDetail> _detail;
  late Future<List<Story>> _feed;

  // The name appears in the bar only once the hero has scrolled out of sight.
  // Reading the scroll position is the one way that is certain: a height-based
  // guess inside the flexible space drew the name across the hero and the tabs
  // at the same time.
  static const _heroHeight = 300.0;
  final _scroll = ScrollController();
  bool _barTitle = false;

  @override
  void initState() {
    super.initState();
    _detail = Api.instance.member(widget.member.slug);
    _feed = Api.instance.memberFeed(widget.member.slug);
    Api.instance.bootstrap.addListener(_onList);
    _scroll.addListener(() {
      final show =
          _scroll.hasClients &&
          _scroll.offset > _heroHeight - kToolbarHeight - 40;
      if (show != _barTitle) setState(() => _barTitle = show);
    });
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
    _detail = Api.instance.member(widget.member.slug);
    _feed = Api.instance.memberFeed(widget.member.slug);
  });

  /// The name, seat and office in the hero come with the list; when the list
  /// is read again (in the other language) they are taken from the new one.
  void _onList() {
    if (mounted) setState(() {});
  }

  MemberBrief get _member =>
      Api.instance.cached?.members
          .where((m) => m.slug == widget.member.slug)
          .firstOrNull ??
      widget.member;

  Future<void> _open(String url) => openLink(context, url);

  Future<void> _refreshDetail() async {
    final f = Api.instance.member(widget.member.slug, force: true);
    setState(() {
      _detail = f;
    });
    await settle(f);
  }

  Future<void> _refreshFeed() async {
    final f = Api.instance.memberFeed(widget.member.slug);
    setState(() {
      _feed = f;
    });
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
                  onPressed: () => SharePlus.instance.share(
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
              StoryList(
                future: _feed,
                emptyTitle: t(
                  'এখনো কোনো সংবাদ যুক্ত হয়নি',
                  'No news has been added yet',
                ),
                emptyBody: t(
                  'সংবাদমাধ্যমে ${m.nameBn}-এর নাম এলে তা এখানে দেখানো হবে।',
                  'When the press names ${m.nameBn}, it will be shown here.',
                ),
                onRetry: () => setState(() {
                  _feed = Api.instance.memberFeed(m.slug);
                }),
                onRefresh: _refreshFeed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, MemberBrief m) {
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
                  const SizedBox(height: 6),
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
    return Loaded<MemberDetail>(
      future: _detail,
      onRetry: () => setState(() {
        _detail = Api.instance.member(widget.member.slug);
      }),
      builder: (context, d) {
        final born = t.date(d.dateOfBirth);
        final facts = <({String label, String value})>[
          if (d.partyNameBn != null)
            (label: t('দল', 'Party'), value: d.partyNameBn!),
          if (d.partyRoleBn != null)
            (label: t('দলীয় পদ', 'Party post'), value: d.partyRoleBn!),
          if (d.ministryBn != null)
            (label: t('মন্ত্রণালয়', 'Ministry'), value: d.ministryBn!),
          if (d.brief.districtBn != null)
            (label: t('জেলা', 'District'), value: d.brief.districtBn!),
          if (d.professionBn != null)
            (label: t('পেশা', 'Profession'), value: d.professionBn!),
          if (d.educationBn != null)
            (label: t('শিক্ষা', 'Education'), value: d.educationBn!),
          if (d.birthPlaceBn != null)
            (label: t('জন্মস্থান', 'Birthplace'), value: d.birthPlaceBn!),
          if (born != null) (label: t('জন্ম', 'Born'), value: born),
          if (d.fatherBn != null)
            (label: t('পিতা', 'Father'), value: d.fatherBn!),
          if (d.motherBn != null)
            (label: t('মাতা', 'Mother'), value: d.motherBn!),
          if (d.termsCount != null)
            (label: t('নির্বাচিত', 'Elected'), value: _times(d.termsCount!)),
          if (d.isFreedomFighter)
            (
              label: t('মুক্তিযোদ্ধা', 'Freedom fighter'),
              value: t('হ্যাঁ', 'Yes'),
            ),
        ];

        return RefreshIndicator(
          color: AppColors.brand,
          onRefresh: _refreshDetail,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSizes.pagePad,
              16,
              AppSizes.pagePad,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              // The written biography, with its sources; the presiding officers'
              // one-paragraph summary from parliament when there is no biography.
              if (d.bioBn != null)
                BioCard(text: d.bioBn!, sources: d.bioSources)
              else if (d.summaryBn != null)
                BioCard(
                  text: d.summaryBn!,
                  title: t('সংক্ষিপ্ত পরিচিতি', 'Brief profile'),
                ),
              if (facts.isNotEmpty) ...[
                const SizedBox(height: 12),
                FactsCard(title: t('তথ্য', 'Details'), facts: facts),
              ],
              if (d.result != null) ...[
                const SizedBox(height: 12),
                SeatResultCard(seatLabel: d.brief.seatLabel, result: d.result!),
              ],
              if (d.committees.isNotEmpty) ...[
                const SizedBox(height: 12),
                _card(
                  context,
                  t('সংসদীয় কমিটি', 'Parliamentary committees'),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final c in d.committees)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 4, right: 8),
                                child: Icon(
                                  Icons.circle,
                                  size: 7,
                                  color: AppColors.brandRing,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  c.nameBn,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                              if (c.role != null) Pill(c.role!),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (d.priorTerms.isNotEmpty) ...[
                const SizedBox(height: 12),
                _card(
                  context,
                  t('আগের মেয়াদ', 'Earlier terms'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final term in d.priorTerms)
                        Pill(
                          t(
                                '${bn(term.parliamentNo)}ম সংসদ',
                                '${t.ord(term.parliamentNo)} Parliament',
                              ) +
                              (term.seatBn != null ? ', ${term.seatBn}' : ''),
                        ),
                    ],
                  ),
                ),
              ],
              if (d.socials.isNotEmpty ||
                  d.email != null ||
                  d.facebookNotice != null) ...[
                const SizedBox(height: 12),
                _card(
                  context,
                  t('যোগাযোগ ও লিংক', 'Contact and links'),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (d.email != null)
                        _linkRow(
                          context,
                          Icons.mail_outline_rounded,
                          d.email!,
                          () => _open('mailto:${d.email}'),
                        ),
                      for (final s in d.socials)
                        _linkRow(
                          context,
                          Icons.open_in_new_rounded,
                          s.unverified
                              ? '${s.label} ${t('(যাচাই করা হয়নি)', '(not verified)')}'
                              : s.label,
                          () => _open(s.url),
                        ),
                      // A page in dispute: no link, only the note.
                      if (d.facebookNotice != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.help_outline_rounded,
                                size: 18,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  d.facebookNotice!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: () => _open(Api.page('/mp/${d.brief.slug}')),
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
              const SizedBox(height: 4),
              Center(
                child: Text(
                  t(
                    'সূত্র: বাংলাদেশ জাতীয় সংসদ',
                    'Source: Parliament of Bangladesh',
                  ),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// "৩ বার" / "three times": how often the member has been elected.
  static String _times(int n) {
    if (!t.en) return '${bn(n)} বার';
    const words = {1: 'once', 2: 'twice', 3: 'three times', 4: 'four times'};
    return words[n] ?? '$n times';
  }

  Widget _card(BuildContext context, String title, Widget body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: AppColors.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }

  Widget _linkRow(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.brand),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}
