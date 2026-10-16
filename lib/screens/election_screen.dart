import 'package:flutter/material.dart';

import '../api.dart';
import '../bn.dart';
import '../i18n.dart';
import '../loading.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'member_screen.dart';

int _n(dynamic v) => v is num ? v.toInt() : 0;
List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

/// A string field, or null when the server sent anything else: one odd value
/// must not turn the whole screen into an error.
String? _str(dynamic v) => v is String ? v : null;
Map<String, dynamic> _map(dynamic v) =>
    v is Map<String, dynamic> ? v : const {};

/// ত্রয়োদশ জাতীয় সংসদ নির্বাচন in figures: the House by party, the voters,
/// the votes, the closest and widest wins, and who the members are.
class ElectionScreen extends StatefulWidget {
  const ElectionScreen({super.key});

  @override
  State<ElectionScreen> createState() => _ElectionScreenState();
}

class _ElectionScreenState extends State<ElectionScreen>
    with RefetchOnLang<ElectionScreen> {
  late Future<Map<String, dynamic>> _future = Api.instance.election();

  @override
  void onLangChanged() => setState(() {
    _future = Api.instance.election();
  });

  Future<void> _refresh() async {
    final f = Api.instance.election(force: true);
    setState(() {
      _future = f;
    });
    await settle(f);
  }

  void _openMember(MemberBrief m) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => MemberScreen(member: m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('নির্বাচন পরিসংখ্যান', 'Election statistics')),
      ),
      body: Loaded<Map<String, dynamic>>(
        future: _future,
        onRetry: () => setState(() {
          _future = Api.instance.election();
        }),
        builder: (context, e) => RefreshIndicator(
          color: AppColors.brand,
          onRefresh: _refresh,
          child: _body(e),
        ),
      ),
    );
  }

  Widget _body(Map<String, dynamic> e) {
    final dates = _map(e['dates']);
    final house = _map(e['house']);
    final voters = _map(e['voters']);
    final results = _map(e['results']);
    final people = _map(e['members']);
    final text = Theme.of(context).textTheme;

    final total = _n(house['total']);
    final majority = _n(house['majority']);
    final parties = _list(house['parties']);
    final totalVotes = _n(results['totalVotes']);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pagePad,
        14,
        AppSizes.pagePad,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _Hero(
          parliamentNo: _n(e['parliamentNo']),
          electionDate: _str(dates['election']),
          total: total,
          seatsCounted: _n(results['seatsCounted']),
        ),
        const SizedBox(height: 12),
        _Section(
          title: t('গুরুত্বপূর্ণ তারিখ', 'Key dates'),
          child: _Grid(
            items: [
              for (final (label, key) in [
                (t('ভোটগ্রহণ', 'Polling day'), 'election'),
                (t('গেজেট', 'Gazette'), 'gazette'),
                (t('শপথ', 'Oath'), 'oath'),
                (t('মেয়াদ শেষ', 'Term ends'), 'end'),
              ])
                (
                  value: t.date(_str(dates[key])) ?? t('তারিখ নেই', 'No date'),
                  label: label,
                ),
            ],
            valueSize: 15,
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: t('সংসদের গঠন', 'Make-up of Parliament'),
          subtitle: t(
            'সংরক্ষিত আসনসহ ${bn(total)} জন। কালো দাগ সংখ্যাগরিষ্ঠতার ${bn(majority)} আসন।',
            '$total members, including the reserved seats. The black line marks a majority: $majority seats.',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StackBar(
                parts: [
                  for (final p in parties)
                    (
                      color: AppColors.party(_str(p['abbr'])),
                      value: _n(p['seats']),
                    ),
                ],
                total: total,
                marker: total > 0 ? majority / total : null,
              ),
              const SizedBox(height: 14),
              for (final p in parties)
                _PartyRow(
                  abbr: _str(p['abbr']),
                  label: _str(p['labelBn']) ?? '',
                  value: t.count(_n(p['seats']), ' আসন', 'seat', 'seats'),
                  note: t(
                    'সাধারণ আসনে ${bn(_n(p['seatsTerritorial']))}',
                    '${_n(p['seatsTerritorial'])} in general seats',
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: t('ভোটার ও ভোটকেন্দ্র', 'Voters and polling centres'),
          subtitle: t('সারা দেশের হিসাব', 'Figures for the whole country'),
          footer: _votersSource(voters),
          child: Column(
            children: [
              _Grid(
                items: [
                  (
                    value: t.group(_n(voters['registered'])),
                    label: t('মোট ভোটার', 'Total voters'),
                  ),
                  (
                    value: t.group(_n(voters['pollingCentres'])),
                    label: t('ভোটকেন্দ্র', 'Polling centres'),
                  ),
                  (
                    value: t.group(_n(voters['male'])),
                    label: t('পুরুষ ভোটার', 'Male voters'),
                  ),
                  (
                    value: t.group(_n(voters['female'])),
                    label: t('নারী ভোটার', 'Female voters'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StackBar(
                parts: [
                  (color: const Color(0xFF7FA99A), value: _n(voters['male'])),
                  (color: AppColors.brand, value: _n(voters['female'])),
                ],
                total: _n(voters['registered']),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${t('পুরুষ', 'Male')} ${t.pct(_n(voters['male']), _n(voters['registered']))}',
                    style: text.labelSmall,
                  ),
                  const Spacer(),
                  Text(
                    '${t('নারী', 'Female')} ${t.pct(_n(voters['female']), _n(voters['registered']))}',
                    style: text.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (totalVotes > 0) ...[
          const SizedBox(height: 12),
          _Section(
            title: t('দলভিত্তিক ভোট', 'Votes by party'),
            subtitle: t(
              '${bn(_n(results['seatsCounted']))}টি আসনে প্রার্থীরা মোট ${bnGroup(totalVotes)} ভোট পেয়েছেন',
              'Candidates won ${t.group(totalVotes)} votes in all across ${t.count(_n(results['seatsCounted']), '', 'seat', 'seats')}',
            ),
            footer: _str(results['sourceBn']),
            child: Column(
              children: [
                for (final v in _list(results['voteShare']))
                  _ShareRow(
                    abbr: _str(v['abbr']),
                    label: _str(v['labelBn']) ?? '',
                    votes: _n(v['votes']),
                    total: totalVotes,
                  ),
              ],
            ),
          ),
        ],
        if (_list(results['closest']).isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: t('সবচেয়ে কম ব্যবধানে জয়', 'Narrowest wins'),
            child: _MarginList(
              rows: _list(results['closest']),
              onOpen: _openMember,
            ),
          ),
        ],
        if (_list(results['widest']).isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: t('সবচেয়ে বড় ব্যবধানে জয়', 'Widest wins'),
            child: _MarginList(
              rows: _list(results['widest']),
              onOpen: _openMember,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _Section(
          title: t('নির্বাচিত সদস্যরা', 'The members elected'),
          subtitle: t(
            'বর্তমান ${bn(total)} জন সংসদ সদস্যের তথ্য থেকে',
            'From the records of the $total current MPs',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Grid(
                items: [
                  (
                    value: _people(_n(people['women'])),
                    label: t('নারী সদস্য', 'Women members'),
                  ),
                  (
                    value: people['medianAge'] is num
                        ? _years(_n(people['medianAge']))
                        : t('তথ্য নেই', 'No data'),
                    label: t('বয়সের মধ্যক', 'Median age'),
                  ),
                  (
                    value: _people(_n(people['firstTime'])),
                    label: t('প্রথমবার সংসদে', 'First time in Parliament'),
                  ),
                  (
                    value: _people(_n(people['freedomFighters'])),
                    label: t('মুক্তিযোদ্ধা', 'Freedom fighters'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                t(
                  'নারী সদস্যদের ${bn(_n(people['womenTerritorial']))} জন সাধারণ আসনে নির্বাচিত, ${bn(_n(people['womenReserved']))} জন সংরক্ষিত আসনে।',
                  'Of the women members, ${_n(people['womenTerritorial'])} were elected to general seats and ${_n(people['womenReserved'])} hold reserved seats.',
                ),
                style: text.labelSmall?.copyWith(height: 1.5),
              ),
              for (final (key, label) in [
                ('youngest', t('সর্বকনিষ্ঠ', 'Youngest')),
                ('oldest', t('সর্বজ্যেষ্ঠ', 'Oldest')),
              ])
                if (people[key] is Map<String, dynamic>)
                  _PersonRow(
                    label: label,
                    member: MemberBrief.fromJson(
                      _map(_map(people[key])['member']),
                    ),
                    trailing: _years(_n(_map(people[key])['age'])),
                    onOpen: _openMember,
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: t('বয়স', 'Age'),
          child: _Bars(
            rows: [
              for (final b in _list(people['ageBands']))
                (label: _str(b['label']) ?? '', count: _n(b['count'])),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: t('সংসদে অভিজ্ঞতা', 'Experience in Parliament'),
          subtitle: t(
            '${bn(_n(people['firstTime']))} জন এবারই প্রথম, ${bn(_n(people['returning']))} জন আগেও সদস্য ছিলেন',
            '${_n(people['firstTime'])} for the first time, ${_n(people['returning'])} were members before',
          ),
          child: _Bars(
            rows: [
              for (final b in _list(people['experience']))
                (label: _str(b['label']) ?? '', count: _n(b['count'])),
            ],
            labelWidth: 118,
          ),
        ),
        if (_list(people['professions']).isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: t('পেশা', 'Profession'),
            subtitle: t(
              'সংসদের তথ্যভান্ডারে লিপিবদ্ধ পেশা অনুযায়ী',
              'By the profession recorded in Parliament’s database',
            ),
            child: _Bars(
              rows: [
                for (final b in _list(people['professions']))
                  (label: _str(b['label']) ?? '', count: _n(b['count'])),
              ],
              labelWidth: 118,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          t(
            'সদস্যদের তথ্য জাতীয় সংসদের ওয়েবসাইট থেকে, ভোটার সংখ্যা নির্বাচন কমিশন থেকে। আমার এমপি একটি স্বাধীন, বেসরকারি তথ্যসেবা।',
            'Members’ information is from Parliament’s website, voter numbers from the Election Commission. '
                'My MP is an independent, non-governmental information service.',
          ),
          textAlign: TextAlign.center,
          style: text.labelSmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

/// "সূত্র: নির্বাচন কমিশন, পড়া হয়েছে ১ জানুয়ারি ২০২৬" under the voter figures.
String _votersSource(Map<String, dynamic> voters) {
  final source =
      _str(voters['sourceBn']) ?? t('নির্বাচন কমিশন', 'Election Commission');
  final read = t.date(_str(voters['readOn']));
  return t(
    'সূত্র: $source${read != null ? ', পড়া হয়েছে $read' : ''}',
    'Source: $source${read != null ? ', read on $read' : ''}',
  );
}

/// "৪৫ জন" / "45": a number of people, as a figure in the grid.
String _people(int n) => t('${bn(n)} জন', '$n');

/// "৫৫ বছর" / "55 years".
String _years(int n) => t('${bn(n)} বছর', '$n ${plural(n, 'year', 'years')}');

class _Hero extends StatelessWidget {
  final int parliamentNo;
  final String? electionDate;
  final int total;
  final int seatsCounted;
  const _Hero({
    required this.parliamentNo,
    required this.electionDate,
    required this.total,
    required this.seatsCounted,
  });

  @override
  Widget build(BuildContext context) {
    const white = TextStyle(fontFamily: 'NotoSansBengali', color: Colors.white);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: AppDecor.headerGradient,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        boxShadow: AppDecor.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.how_to_vote_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                t.date(electionDate) ?? t.n(2026),
                style: white.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            t(
              '${parliamentBn(parliamentNo)} জাতীয় সংসদ নির্বাচন',
              'Election to the ${t.ord(parliamentNo)} Parliament',
            ),
            style: white.copyWith(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _heroStat(t.n(300), t('সাধারণ আসন', 'General seats')),
              _heroStat(t.n(50), t('সংরক্ষিত আসন', 'Reserved seats')),
              _heroStat(t.n(total), t('বর্তমান সদস্য', 'Current members')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'NotoSansBengali',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'NotoSansBengali',
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? footer;
  final Widget child;
  const _Section({
    required this.title,
    this.subtitle,
    this.footer,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: text.labelSmall?.copyWith(height: 1.45)),
          ],
          const SizedBox(height: 14),
          child,
          if (footer != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.ruleSoft),
            const SizedBox(height: 10),
            Text(footer!, style: text.labelSmall?.copyWith(height: 1.5)),
          ],
        ],
      ),
    );
  }
}

/// Two columns of big figures.
class _Grid extends StatelessWidget {
  final List<({String value, String label})> items;
  final double valueSize;
  const _Grid({required this.items, this.valueSize = 19});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final i in items)
              Container(
                width: w,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.value,
                      style: TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: valueSize,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        height: 1.3,
                      ),
                    ),
                    Text(
                      i.label,
                      style: const TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One bar split by share, with an optional line at the majority mark.
class _StackBar extends StatelessWidget {
  final List<({Color color, int value})> parts;
  final int total;
  final double? marker;
  const _StackBar({required this.parts, required this.total, this.marker});

  @override
  Widget build(BuildContext context) {
    final rest = total - parts.fold<int>(0, (n, p) => n + p.value);
    return LayoutBuilder(
      builder: (context, box) => SizedBox(
        height: 30,
        child: Stack(
          children: [
            Positioned.fill(
              top: 4,
              bottom: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    for (final p in parts)
                      if (p.value > 0)
                        Expanded(
                          flex: p.value,
                          child: Container(
                            color: p.color,
                            margin: const EdgeInsets.only(right: 1),
                          ),
                        ),
                    if (rest > 0)
                      Expanded(
                        flex: rest,
                        child: Container(color: AppColors.sunk),
                      ),
                  ],
                ),
              ),
            ),
            if (marker != null)
              Positioned(
                left: (box.maxWidth * marker!).clamp(0, box.maxWidth - 2),
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: AppColors.ink),
              ),
          ],
        ),
      ),
    );
  }
}

class _PartyRow extends StatelessWidget {
  final String? abbr;
  final String label;
  final String value;
  final String? note;
  const _PartyRow({
    required this.abbr,
    required this.label,
    required this.value,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PartyChip(abbr: abbr, label: label),
                if (note != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Text(note!, style: text.labelSmall),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  final String? abbr;
  final String label;
  final int votes;
  final int total;
  const _ShareRow({
    required this.abbr,
    required this.label,
    required this.votes,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final colour = AppColors.party(abbr == 'other' ? null : abbr);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PartyChip(
                  abbr: abbr == 'other' ? null : abbr,
                  label: label,
                ),
              ),
              Text(
                t.pct(votes, total),
                style: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? votes / total : 0,
              minHeight: 8,
              color: colour,
              backgroundColor: AppColors.sunk,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            t.en
                ? '${t.group(votes)} ${plural(votes, 'vote', 'votes')}'
                : '${t.group(votes)} ভোট',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  final List<({String label, int count})> rows;
  final double labelWidth;
  const _Bars({required this.rows, this.labelWidth = 78});

  @override
  Widget build(BuildContext context) {
    final max = rows.fold<int>(1, (m, r) => r.count > m ? r.count : m);
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    r.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 13,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: r.count / max,
                      minHeight: 12,
                      color: AppColors.brand,
                      backgroundColor: AppColors.sunk,
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    bn(r.count),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MarginList extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final void Function(MemberBrief) onOpen;
  const _MarginList({required this.rows, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final r in rows)
          if (r['member'] is Map<String, dynamic>)
            _PersonRow(
              label: _str(r['seatBn']) ?? '',
              member: MemberBrief.fromJson(_map(r['member'])),
              trailing: t(
                '${t.group(_n(r['margin']))} ভোটে',
                'by ${t.group(_n(r['margin']))}',
              ),
              note: r['runnerUpParty'] != null
                  ? '${t('নিকটতম: ', 'Runner-up: ')}${r['runnerUpParty']}'
                  : null,
              onOpen: onOpen,
            ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  final String label;
  final MemberBrief member;
  final String trailing;
  final String? note;
  final void Function(MemberBrief) onOpen;
  const _PersonRow({
    required this.label,
    required this.member,
    required this.trailing,
    this.note,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => onOpen(member),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            MemberAvatar(member: member, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: text.labelSmall),
                  Text(
                    member.nameBn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  if (note != null) Text(note!, style: text.labelSmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailing,
              style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.brand,
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
