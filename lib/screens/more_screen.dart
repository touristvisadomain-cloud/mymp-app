import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../brand_header.dart';
import '../disclaimer.dart';
import '../bn.dart';
import '../i18n.dart';
import '../models.dart';
import '../party_logo.dart';
import '../loading.dart';
import '../maps/google.dart';
import '../theme.dart';
import '../version.dart';
import '../widgets.dart';

import 'leaders_strip.dart';
import 'party_screen.dart';
import 'sessions_screen.dart';
import 'statistics_screen.dart';
import 'seats_screen.dart';
import 'reserved_screen.dart';
import 'committees_screen.dart';

/// The parties, and the handful of things a reader looks for once: where the
/// figures come from, what the app stores, how to report a mistake.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  @override
  void initState() {
    super.initState();
    // Built with the other tabs at launch, often before the member list has
    // arrived. The party rows follow the list wherever it is fetched, so a
    // first launch offline gets them once the members tab retries.
    Api.instance.loadBootstrap().ignore();
  }

  Future<void> _open(String url) => openLink(context, url);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Bootstrap?>(
      valueListenable: Api.instance.bootstrap,
      builder: (context, data, _) =>
          _page(context, data ?? Api.instance.cached),
    );
  }

  Widget _page(BuildContext context, Bootstrap? data) {
    final parties = data?.parties ?? const <PartyBrief>[];
    return Scaffold(
      body: Column(
        children: [
          BrandHeader(
            title: t('আরও', 'More'),
            subtitle: t(
              'নির্বাচন, সংসদ, দল ও অ্যাপ সম্পর্কে',
              'The election, Parliament, parties and the app',
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePad,
                18,
                AppSizes.pagePad,
                32,
              ),
              children: [
                // First, so a reader who cannot read the current language
                // finds the other one without scrolling.
                const _LanguageCard(),
                const SizedBox(height: 18),

                // What a reader comes here for first: the election, the House
                // and the parties. The sources and the disclaimer are below.
                const ElectionCard(padding: EdgeInsets.zero),
                const SizedBox(height: 18),

                // The House, as the website's menu has it: seats, reserved
                // seats, committees and sessions.
                Text(
                  t('সংসদ', 'Parliament'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                // Tiles rather than a list, so the House's pages are seen:
                // the statistics across the width, the rest two to a row.
                _HouseTile(
                  wide: true,
                  icon: Icons.bar_chart_rounded,
                  title: t('পরিসংখ্যান', 'Statistics'),
                  note: t(
                    'বয়স, শিক্ষা, পেশা, নারী সদস্য ও অভিজ্ঞতা',
                    'Age, education, professions, women and experience',
                  ),
                  onTap: () => _push(context, const StatisticsScreen()),
                ),
                const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _HouseTile(
                          icon: Icons.map_outlined,
                          title: t('সব আসন', 'All seats'),
                          note: t(
                            'প্রতিটি আসনের এমপি',
                            'The MP for every seat',
                          ),
                          onTap: () => _push(context, const SeatsScreen()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HouseTile(
                          icon: Icons.woman_outlined,
                          title: t('সংরক্ষিত নারী আসন', 'Reserved seats'),
                          note: t('৫০টি নারী আসন', '50 seats for women'),
                          onTap: () => _push(context, const ReservedScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _HouseTile(
                          icon: Icons.groups_outlined,
                          title: t('কমিটি', 'Committees'),
                          note: t(
                            'সভাপতি, সদস্য ও দায়িত্ব',
                            'Chairs, members and duties',
                          ),
                          onTap: () => _push(context, const CommitteesScreen()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HouseTile(
                          icon: Icons.event_note_outlined,
                          title: t('অধিবেশন', 'Sessions'),
                          note: t(
                            'বৈঠক ও দিনের কার্যসূচি',
                            'Sittings and orders of the day',
                          ),
                          onTap: () => _push(context, const SessionsScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                if (parties.isNotEmpty) ...[
                  Text(
                    t('দল', 'Parties'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  for (final p in parties) ...[
                    _PartyRow(party: p),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    partyLogoCredit,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 18),
                ],

                Text(
                  t('সম্পর্কে', 'About'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: AppDecor.card(),
                  child: Column(
                    children: [
                      _row(
                        context,
                        Icons.info_outline_rounded,
                        t('আমার এমপি সম্পর্কে', 'About My MP'),
                        () => _open(Api.page('/somporke')),
                      ),
                      const Divider(height: 1),
                      _row(
                        context,
                        Icons.verified_outlined,
                        t('তথ্যের সূত্র', 'Sources'),
                        () => _open(Api.page('/sutro')),
                      ),
                      const Divider(height: 1),
                      _row(
                        context,
                        Icons.lock_outline_rounded,
                        t('গোপনীয়তা নীতি', 'Privacy policy'),
                        () => _open(Api.page('/gopaniyota')),
                      ),
                      const Divider(height: 1),
                      _row(
                        context,
                        Icons.mail_outline_rounded,
                        t(
                          'ভুল জানান / যোগাযোগ',
                          'Report a correction / Contact',
                        ),
                        () => _open(Api.page('/jogajog')),
                      ),
                      const Divider(height: 1),
                      _row(
                        context,
                        Icons.public_rounded,
                        t('ওয়েবসাইট: mymp.bd', 'Website: mymp.bd'),
                        () => _open(Api.page('/')),
                      ),
                      const Divider(height: 1),
                      _row(
                        context,
                        Icons.share_outlined,
                        t('অ্যাপটি শেয়ার করুন', 'Share the app'),
                        () => SharePlus.instance.share(
                          ShareParams(
                            text: t(
                              'আমার এমপি: বাংলাদেশের সংসদ সদস্যদের তথ্য, ${Api.base}',
                              'My MP: information on Bangladesh’s Members of Parliament, ${Api.page('/')}',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                // Who runs the app, and where every figure comes from.
                const DisclaimerCard(),

                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('এই অ্যাপ কী রাখে', 'What this app keeps'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t(
                          'কোনো অ্যাকাউন্ট লাগে না, অ্যাপ নিজে কিছু জমা নেয় না। শুধু সংসদ সদস্যদের তালিকাটি ফোনেই রেখে দেওয়া হয়, '
                              'যাতে নেটওয়ার্ক না থাকলেও অ্যাপ খোলে। সব তথ্য mymp.bd থেকে আসে। মানচিত্রে “আমি কি এই আসনে?” চাপলে তবেই '
                              'অ্যাপ আপনার অবস্থান জানতে চায়; তা ফোনেই আসনের সীমানার সঙ্গে মেলানো হয়, কোথাও পাঠানো বা রাখা হয় না।',
                          'No account is needed, and the app itself collects nothing. Only the list of Members of Parliament '
                              'is kept on the phone, so that the app opens even with no network. All information comes from mymp.bd. '
                              'The app asks where you are only when you tap “Am I in this seat?” on a map; it checks it against the '
                              'seats’ boundaries on the phone and does not send or keep it.',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      // The one thing that leaves the phone for anyone but
                      // mymp.bd (owner, 2026-10-17), said where the reader
                      // looks for it.
                      if (GoogleMaps.enabled) ...[
                        const SizedBox(height: 8),
                        Text(
                          t(
                            'মানচিত্রগুলো Google Maps-এর। মানচিত্র দেখানোর জন্য Google আপনার ফোন থেকে সাধারণ কারিগরি তথ্য পায় '
                                '(যেমন IP ঠিকানা, ফোন ও অ্যাপের ধরন), যা Google-এর গোপনীয়তা নীতির অধীন। আপনার অবস্থান Google-কে দেওয়া হয় না।',
                            'The maps are Google Maps. To show them, Google receives the usual technical data from your phone '
                                '(such as its IP address and the kind of phone and app), under Google’s privacy policy. '
                                'Your location is not given to Google.',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: () => _open(kGooglePrivacyUrl),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: AppColors.brand,
                            ),
                            child: Text(
                              t(
                                'Google-এর গোপনীয়তা নীতি',
                                'Google’s privacy policy',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Center(
                  child: Text(
                    data == null
                        ? t('সংস্করণ ${t.n(appVersion)}', 'Version $appVersion')
                        : t(
                            'সংস্করণ ${t.n(appVersion)}, ${parliamentBn(data.parliamentNo)} জাতীয় সংসদ',
                            'Version $appVersion, ${t.ord(data.parliamentNo)} Parliament',
                          ),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.brand),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
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

/// The reader's language, at the top of the tab.
class _LanguageCard extends StatelessWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: AppDecor.card(),
      child: Row(
        children: [
          const Icon(Icons.translate_rounded, size: 20, color: AppColors.brand),
          const SizedBox(width: 12),
          Expanded(
            // Both names, so the row is found in either language.
            child: Text(
              'ভাষা / Language',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const LangSwitch(),
        ],
      ),
    );
  }
}

class _PartyRow extends StatelessWidget {
  final PartyBrief party;
  const _PartyRow({required this.party});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSizes.radiusCard),
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => PartyScreen(party: party))),
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: AppDecor.card(),
          child: Row(
            children: [
              PartyLogo(abbr: party.abbr, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      party.shortBn,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (party.nameBn != party.shortBn)
                      Text(
                        party.nameBn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
              Text(
                t.count(party.seats, ' আসন', 'seat', 'seats'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
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

/// Opens one of the app's own screens.
void _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

/// One of the House's pages as a tile: an icon in a green circle, the name,
/// and a line on what it holds. The wide one sits on the brand's soft green.
class _HouseTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String note;
  final VoidCallback onTap;
  final bool wide;
  const _HouseTile({
    required this.icon,
    required this.title,
    required this.note,
    required this.onTap,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    const font = 'NotoSansBengali';
    final mark = Container(
      width: wide ? 46 : 40,
      height: wide ? 46 : 40,
      decoration: BoxDecoration(
        color: wide ? AppColors.brand : AppColors.brandSoft,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: wide ? 24 : 21,
        color: wide ? Colors.white : AppColors.brand,
      ),
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: font,
            fontSize: wide ? 17 : 15,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          note,
          style: const TextStyle(
            fontFamily: font,
            fontSize: 12.5,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: wide
            ? BoxDecoration(
                color: AppColors.brandSoft,
                border: Border.all(color: AppColors.brandRing),
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              )
            : AppDecor.card(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: wide
                  ? Row(
                      children: [
                        mark,
                        const SizedBox(width: 12),
                        Expanded(child: words),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: AppColors.brand,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [mark, const SizedBox(height: 10), words],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
