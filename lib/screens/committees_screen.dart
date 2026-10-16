import 'package:flutter/material.dart';

import '../data/house.dart';
import '../i18n.dart';
import '../loading.dart';
import '../party_logo.dart';
import '../theme.dart';
import 'committee_screen.dart';
import 'house_widgets.dart';

const _font = 'NotoSansBengali';

/// Parliament's committees, as the website's /committee page lists them: the
/// committees whose member list is up to date for this parliament, with what
/// each does and who chairs it, then those still awaiting their new list.
class CommitteesScreen extends StatefulWidget {
  const CommitteesScreen({super.key});

  @override
  State<CommitteesScreen> createState() => _CommitteesScreenState();
}

/// A committee type counted in English: "26 parliamentary committees".
const _typeCountEn = {
  'Parliamentary Committee': (
    'parliamentary committee',
    'parliamentary committees',
  ),
  'Ministry Related Standing Committee': (
    'standing committee on a ministry',
    'standing committees on ministries',
  ),
};

class _CommitteesScreenState extends State<CommitteesScreen>
    with RefetchOnLang<CommitteesScreen> {
  late Future<CommitteesData> _future = fetchCommittees();

  @override
  void onLangChanged() => setState(() => _future = fetchCommittees());

  void _retry() => setState(() => _future = fetchCommittees(force: true));

  Future<void> _refresh() async {
    _retry();
    await settle(_future);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('সংসদীয় কমিটি', 'Parliamentary committees')),
      ),
      body: Loaded<CommitteesData>(
        future: _future,
        onRetry: _retry,
        builder: (context, data) => RefreshIndicator(
          color: AppColors.brand,
          onRefresh: _refresh,
          child: _page(context, data),
        ),
      ),
    );
  }

  String _lede(CommitteesData data) {
    final all = data.committees;
    final byType = <String, int>{};
    for (final c in all) {
      final key = t.en ? (c.type ?? '') : (c.typeName ?? 'অন্যান্য');
      byType[key] = (byType[key] ?? 0) + 1;
    }
    final counts = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = all.length;
    if (!t.en) {
      return 'মোট ${t.n(total)}টি কমিটি: '
          '${counts.map((e) => '${e.key} ${t.n(e.value)}টি').join(', ')}। '
          'প্রতিটি কমিটি কী কাজ করে, তা নামের নিচে লেখা; বিস্তারিত কমিটির পাতায়।';
    }
    String countEn(MapEntry<String, int> e) {
      final words = _typeCountEn[e.key];
      if (words != null) {
        return '${e.value} ${plural(e.value, words.$1, words.$2)}';
      }
      final name = all
          .firstWhere((c) => (c.type ?? '') == e.key)
          .typeName
          ?.toLowerCase();
      return '${e.value} ${e.key.isEmpty ? 'other' : (name ?? e.key.toLowerCase())}';
    }

    return '$total committees in all: ${counts.map(countEn).join(', ')}. '
        "What each committee does is written under its name; the details are on the committee's page.";
  }

  Widget _page(BuildContext context, CommitteesData data) {
    final current = data.committees.where((c) => c.rosterCurrent).toList();
    final pending = data.committees.where((c) => !c.rosterCurrent).toList();
    final total = data.committees.length;
    final items = <Widget>[
      HousePageHead(
        eyebrow: t('ত্রয়োদশ জাতীয় সংসদ', '13th Parliament'),
        title: t('সংসদীয় কমিটি', 'Parliamentary committees'),
        lede: _lede(data),
        stats: [
          (
            label: t('তালিকা হালনাগাদ', 'Lists up to date'),
            value: t.n(current.length),
          ),
          if (pending.isNotEmpty)
            (label: t('অপেক্ষমাণ', 'Pending'), value: t.n(pending.length))
          else
            (
              label: t('কমিটিতে সদস্য', 'MPs on committees'),
              value: t.n(data.membersOnCommittees),
            ),
        ],
      ),
      const SizedBox(height: 22),
      SectionTitle(
        t('হালনাগাদ কমিটি', 'Up-to-date committees'),
        count: t.n(current.length),
      ),
      for (final c in current) ...[
        _CurrentTile(committee: c),
        const SizedBox(height: 10),
      ],
      if (pending.isNotEmpty) ...[
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SectionTitle(
                t(
                  'যেসব কমিটির তালিকা এখনো হালনাগাদ হয়নি',
                  'Committees whose member lists are not yet updated',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warnSoft,
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              ),
              child: Text(
                t('${t.n(pending.length)}টি', '${pending.length}'),
                style: const TextStyle(
                  fontFamily: _font,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warn,
                ),
              ),
            ),
          ],
        ),
        WarnNotice(
          title: t(
            'এই কমিটিগুলোর সদস্য তালিকায় এখনো দ্বাদশ সংসদের সদস্যদের নাম আছে',
            'The member lists of these committees still carry the names of members of the 12th Parliament',
          ),
          body: t(
            'সংসদের তথ্যভান্ডারে ${t.n(total)}টির মধ্যে ${t.n(pending.length)}টি কমিটির সদস্য তালিকা '
                'ত্রয়োদশ সংসদের জন্য এখনো হালনাগাদ হয়নি। যাঁরা এখন আর সংসদ সদস্য নন, তাঁদের নাম বর্তমান কমিটির '
                'সদস্য হিসেবে আমরা দেখাই না। তালিকা হালনাগাদ হলে সদস্যরা আপনাআপনি যুক্ত হবে।',
            "In Parliament's database, the member lists of ${pending.length} of the $total committees have "
                'not yet been updated for the 13th Parliament. We do not show people who are no longer Members of Parliament '
                'as members of a current committee. Once the lists are updated, the members will be added automatically.',
          ),
        ),
        const SizedBox(height: 12),
        for (final c in pending) ...[
          _PendingTile(committee: c),
          const SizedBox(height: 10),
        ],
      ],
      const SizedBox(height: 10),
      Text(
        '${t('তথ্যসূত্র: বাংলাদেশ জাতীয় সংসদ | হালনাগাদ ', 'Source: Parliament of Bangladesh | Updated ')}'
        '${t.date(data.version) ?? ''}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSizes.pagePad,
        8,
        AppSizes.pagePad,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
    );
  }
}

void _open(BuildContext context, CommitteeSummary c) =>
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommitteeScreen(slug: c.slug, name: c.name),
      ),
    );

/// A tappable card.
class _Tile extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Tile({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    decoration: AppDecor.card(),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

/// A committee with an up-to-date list: name, what it does, its chair and how
/// many sit on it.
class _CurrentTile extends StatelessWidget {
  final CommitteeSummary committee;
  const _CurrentTile({required this.committee});

  @override
  Widget build(BuildContext context) {
    final c = committee;
    final formed = c.startDate == null
        ? ''
        : t(', গঠিত ${t.date(c.startDate)}', 'Formed ${t.date(c.startDate)}');
    final under = t.en ? formed : '${c.nameEn ?? ''}$formed';
    final chair = c.chair;
    return _Tile(
      onTap: () => _open(context, c),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.4,
                      ),
                    ),
                    _badge(t('হালনাগাদ', 'Up to date')),
                  ],
                ),
                if (under.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    under.replaceFirst(RegExp(r'^, '), ''),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (c.summary != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    c.summary!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                ],
                if (chair != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('সভাপতি', 'Chair'),
                        style: const TextStyle(
                          fontFamily: _font,
                          fontSize: 13.5,
                          color: AppColors.muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: PartyLogo(abbr: chair.party, size: 16),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: chair.nameBn,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            children: [
                              if (chair.seatBn != null)
                                TextSpan(
                                  text: ', ${chair.seatBn}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.muted,
                                  ),
                                ),
                            ],
                          ),
                          style: const TextStyle(
                            fontFamily: _font,
                            fontSize: 13.5,
                            color: AppColors.ink,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                t.n(c.memberCount),
                style: const TextStyle(
                  fontFamily: _font,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  height: 1.1,
                ),
              ),
              Text(
                t('সদস্য', plural(c.memberCount, 'member', 'members')),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A committee still listing the previous parliament's members.
class _PendingTile extends StatelessWidget {
  final CommitteeSummary committee;
  const _PendingTile({required this.committee});

  @override
  Widget build(BuildContext context) {
    final c = committee;
    return _Tile(
      onTap: () => _open(context, c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            c.name,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.4,
            ),
          ),
          if (!t.en && c.nameEn != null)
            Text(c.nameEn!, style: Theme.of(context).textTheme.bodySmall),
          if (c.summary != null) ...[
            const SizedBox(height: 6),
            Text(
              c.summary!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            t(
              'সদস্য তালিকা হালনাগাদের অপেক্ষায়',
              'Member list awaiting update',
            ),
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.warn,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _badge(String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
  decoration: BoxDecoration(
    color: AppColors.brandSoft,
    borderRadius: BorderRadius.circular(AppSizes.radiusPill),
  ),
  child: Text(
    text,
    style: const TextStyle(
      fontFamily: _font,
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: AppColors.brand,
      height: 1.3,
    ),
  ),
);
