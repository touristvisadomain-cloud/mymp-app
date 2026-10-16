import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../data/house.dart';
import '../i18n.dart';
import '../loading.dart';
import '../models.dart';
import '../theme.dart';
import 'house_widgets.dart';
import 'member_screen.dart';

const _font = 'NotoSansBengali';

/// One committee, as the website's /committee/{slug} page has it: what it
/// does under the Rules of Procedure (asked and answered), its chair and
/// members, its meeting notices, and the facts about it.
class CommitteeScreen extends StatefulWidget {
  final String slug;

  /// The name shown in the bar until the committee arrives, when the caller
  /// has it.
  final String? name;
  const CommitteeScreen({super.key, required this.slug, this.name});

  @override
  State<CommitteeScreen> createState() => _CommitteeScreenState();
}

class _CommitteeScreenState extends State<CommitteeScreen>
    with RefetchOnLang<CommitteeScreen> {
  late Future<CommitteeDetail> _future = fetchCommittee(widget.slug);

  @override
  void onLangChanged() => setState(() => _future = fetchCommittee(widget.slug));

  void _retry() =>
      setState(() => _future = fetchCommittee(widget.slug, force: true));

  Future<void> _refresh() async {
    _retry();
    await settle(_future);
  }

  Future<void> _share() async {
    var name = widget.name ?? '';
    try {
      name = (await _future).name;
    } catch (_) {}
    await SharePlus.instance.share(
      ShareParams(
        text: '$name\n${Api.page('/committee/${widget.slug}')}',
        subject: name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('কমিটি', 'Committee')),
        actions: [
          IconButton(
            tooltip: t('শেয়ার', 'Share'),
            icon: const Icon(Icons.share_outlined),
            onPressed: _share,
          ),
        ],
      ),
      body: Loaded<CommitteeDetail>(
        future: _future,
        onRetry: _retry,
        builder: (context, c) => RefreshIndicator(
          color: AppColors.brand,
          onRefresh: _refresh,
          child: _page(context, c),
        ),
      ),
    );
  }

  Widget _page(BuildContext context, CommitteeDetail c) {
    final text = Theme.of(context).textTheme;
    final chair = c.chair;
    final rest = c.rest;
    final lede = t.en
        ? (c.startDate != null ? 'Formed ${t.date(c.startDate)}' : '')
        : [
            ?c.nameEn,
            if (c.startDate != null) 'গঠিত ${t.date(c.startDate)}',
          ].join(', ');

    void openMember(MemberBrief m) => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MemberScreen(member: m)));

    final items = <Widget>[
      HousePageHead(eyebrow: c.typeName, title: c.name, lede: lede),
      const SizedBox(height: 20),
      if (c.duty != null) ...[
        _DutySection(duty: c.duty!, name: c.name),
        const SizedBox(height: 22),
      ],
      if (!c.rosterCurrent)
        WarnNotice(
          title: t(
            'এই কমিটির সদস্য তালিকা ত্রয়োদশ সংসদের জন্য এখনো হালনাগাদ হয়নি',
            "This committee's member list has not yet been updated for the 13th Parliament",
          ),
          body: t(
            'সংসদের তথ্যভান্ডারে এই কমিটির তালিকায় এখনো দ্বাদশ সংসদের সদস্যদের নাম রয়েছে। যাঁরা এখন আর '
                'সংসদ সদস্য নন, তাঁদের বর্তমান সদস্য হিসেবে দেখানো ভুল হবে, তাই তালিকা হালনাগাদ না হওয়া '
                'পর্যন্ত আমরা সদস্যদের নাম দেখাচ্ছি না।',
            "In Parliament's database, this committee's list still carries the names of members of the 12th "
                'Parliament. Showing people who are no longer Members of Parliament as current members would be wrong, so '
                "we are not showing the members' names until the list is updated.",
          ),
        )
      else ...[
        if (chair != null) ...[
          SectionTitle(chair.roleName),
          HouseMemberRow(
            member: chair.member,
            onTap: () => openMember(chair.member),
          ),
          const SizedBox(height: 22),
        ],
        if (rest.isNotEmpty) ...[
          SectionTitle(t('সদস্য', 'Members'), count: t.n(rest.length)),
          for (final s in rest) ...[
            // A role other than member (a vice-chair, a member-secretary) sits
            // above the card rather than over a name a phone may already cut.
            if (s.role != 'Member')
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _roleBadge(s.roleName),
                ),
              ),
            HouseMemberRow(member: s.member, onTap: () => openMember(s.member)),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
        ],
      ],
      if (!c.rosterCurrent) const SizedBox(height: 22),
      SectionTitle(
        t('বৈঠক ও বিজ্ঞপ্তি', 'Meetings and notices'),
        count: c.notices.isEmpty ? null : t.n(c.notices.length),
      ),
      if (c.notices.isNotEmpty)
        NoticeList(notices: c.notices, buttonLabel: t('বিজ্ঞপ্তি', 'Notice'))
      else
        HouseCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(
                  'এই কমিটির কোনো বৈঠকের বিজ্ঞপ্তি সংসদ সচিবালয় এখনো প্রকাশ করেনি।',
                  'The Parliament Secretariat has not yet published any meeting notice for this committee.',
                ),
                style: text.titleSmall?.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                t(
                  'কমিটির বৈঠক ডাকা হলে সংসদ সচিবালয়ের বিজ্ঞপ্তি প্রতিদিন এখানে যুক্ত হয়।',
                  "When a meeting of the committee is called, the Parliament Secretariat's notice appears here; the list is updated every day.",
                ),
                style: text.bodyMedium,
              ),
            ],
          ),
        ),
      const SizedBox(height: 22),
      _InfoBox(committee: c),
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

Widget _roleBadge(String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  decoration: BoxDecoration(
    color: AppColors.brandSoft,
    borderRadius: BorderRadius.circular(AppSizes.radiusPill),
  ),
  child: Text(
    text,
    style: const TextStyle(
      fontFamily: _font,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.brand,
      height: 1.3,
    ),
  ),
);

/// "কমিটির কাজ": the committee's duty, as a question and its answer, from
/// Parliament's Rules of Procedure.
class _DutySection extends StatelessWidget {
  final CommitteeDutyInfo duty;
  final String name;
  const _DutySection({required this.duty, required this.name});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final parent = duty.parent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          t('কমিটির কাজ', 'What the committee does'),
          bar: AppColors.brand,
        ),
        HouseCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('$name-এর কাজ কী?', 'What does the $name do?'),
                style: const TextStyle(
                  fontFamily: _font,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 6),
              if (duty.summary.isNotEmpty)
                Text(
                  duty.summary,
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    height: 1.6,
                  ),
                ),
              if (parent != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text(
                      t('মূল কমিটি:', 'Parent committee:'),
                      style: text.bodyMedium,
                    ),
                    Semantics(
                      link: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CommitteeScreen(
                              slug: parent.slug,
                              name: parent.name,
                            ),
                          ),
                        ),
                        child: Text(
                          parent.name,
                          style: const TextStyle(
                            fontFamily: _font,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (duty.duties.isNotEmpty) const SizedBox(height: 10),
              for (final d in duty.duties)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 9, right: 10),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.brand,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          d,
                          style: text.bodyLarge?.copyWith(
                            color: AppColors.inkSoft,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (duty.note != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Text(duty.note!, style: text.bodyMedium?.copyWith(height: 1.6)),
              ],
              const SizedBox(height: 12),
              InlineLinks([
                ('${t('সূত্র:', 'Source:')} ', null),
                (
                  t(
                    'জাতীয় সংসদের কার্যপ্রণালী বিধি',
                    'Rules of Procedure of Parliament',
                  ),
                  duty.rulesUrl,
                ),
                if (duty.rule != null) (', ${duty.rule}', null),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

/// "কমিটি তথ্য": its type, how many are listed, its notices, and the source.
class _InfoBox extends StatelessWidget {
  final CommitteeDetail committee;
  const _InfoBox({required this.committee});

  @override
  Widget build(BuildContext context) {
    final c = committee;
    final facts = <(String, String)>[
      if (c.typeName != null) (t('ধরন', 'Type'), c.typeName!),
      (t('তালিকাভুক্ত সদস্য', 'Members listed'), t.n(c.memberCount)),
      (t('বৈঠকের বিজ্ঞপ্তি', 'Meeting notices'), t.n(c.notices.length)),
      (
        t('তথ্যসূত্র', 'Source'),
        '${t('বাংলাদেশ জাতীয় সংসদ', 'Parliament of Bangladesh')}, ${t.date(c.version) ?? ''}',
      ),
    ];
    return HouseCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('কমিটি তথ্য', 'About the committee'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < facts.length; i++)
            FactLine(
              label: facts[i].$1,
              value: Text(facts[i].$2),
              last: i == facts.length - 1,
            ),
        ],
      ),
    );
  }
}
