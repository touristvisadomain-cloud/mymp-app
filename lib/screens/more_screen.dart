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
              'দল, তথ্যের সূত্র ও অ্যাপ সম্পর্কে',
              'Parties, sources and about the app',
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

                const DisclaimerCard(),
                const SizedBox(height: 18),

                const ElectionCard(padding: EdgeInsets.zero),
                const SizedBox(height: 18),

                // The House, as the website's menu has it: seats, reserved
                // seats, committees and sessions.
                Text(
                  t('সংসদ', 'Parliament'),
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
                        Icons.bar_chart_rounded,
                        t('পরিসংখ্যান', 'Statistics'),
                        () => _push(context, const StatisticsScreen()),
                      ),
                      const Divider(height: 1),
                      _row(
                        context,
                        Icons.map_outlined,
                        t('সব আসন', 'All seats'),
                        () => _push(context, const SeatsScreen()),
                      ),
                      const Divider(height: 1),
                      _row(
                        context,
                        Icons.woman_outlined,
                        t('সংরক্ষিত নারী আসন', 'Reserved seats for women'),
                        () => _push(context, const ReservedScreen()),
                      ),
                      const Divider(height: 1),
                      _row(
                        context,
                        Icons.groups_outlined,
                        t('কমিটি', 'Committees'),
                        () => _push(context, const CommitteesScreen()),
                      ),
                      const Divider(height: 1),
                      _row(
                        context,
                        Icons.event_note_outlined,
                        t('অধিবেশন', 'Sessions'),
                        () => _push(context, const SessionsScreen()),
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
                          'কোনো অ্যাকাউন্ট লাগে না, কিছু জমা নেওয়া হয় না। শুধু সংসদ সদস্যদের তালিকাটি ফোনেই রেখে দেওয়া হয়, '
                              'যাতে নেটওয়ার্ক না থাকলেও অ্যাপ খোলে। সব তথ্য mymp.bd থেকে আসে।',
                          'No account is needed and nothing is collected. Only the list of Members of Parliament is kept '
                              'on the phone, so that the app opens even with no network. All information comes from mymp.bd.',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
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
