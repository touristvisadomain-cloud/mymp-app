import 'dart:async';

import 'package:flutter/material.dart';

import '../data/house.dart';
import '../i18n.dart';
import '../loading.dart';
import '../models.dart';
import '../party_logo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'house_widgets.dart';
import 'member_screen.dart';

const _font = 'NotoSansBengali';

/// The sessions of Parliament, as the website's /odhibeshon page has them:
/// the latest session told by the clock, every session's sittings with the
/// order of the day for each, its circulars, the Secretariat's notices, the
/// parliament's dates and the people who run the House.
class SessionsScreen extends StatefulWidget {
  /// The clock the countdown reads; the phone's own unless a test sets one.
  final DateTime Function()? clock;
  const SessionsScreen({super.key, this.clock});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen>
    with RefetchOnLang<SessionsScreen> {
  late Future<SessionsData> _future = fetchSessions();

  @override
  void onLangChanged() => setState(() => _future = fetchSessions());

  void _retry() => setState(() => _future = fetchSessions(force: true));

  Future<void> _refresh() async {
    _retry();
    await settle(_future);
  }

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('সংসদ অধিবেশন', 'Sessions of Parliament'))),
      body: Loaded<SessionsData>(
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

  Widget _page(BuildContext context, SessionsData data) {
    final current = data.sessions.firstOrNull;
    final ago = daysSinceDay(data.lastSittingDate, _now());
    final notices = data.generalNotices.take(25).toList();
    final items = <Widget>[
      HousePageHead(
        eyebrow: t('ত্রয়োদশ জাতীয় সংসদ', '13th Parliament'),
        title: t('সংসদ অধিবেশন', 'Sessions of Parliament'),
        lede: t(
          'প্রতিটি অধিবেশন, প্রতিটি বৈঠকের দিনের কার্যসূচি ও সংসদ সচিবালয়ের পরিপত্র, সংসদ যেভাবে প্রকাশ করে ঠিক সেভাবে। এখানে কিছুই সম্পাদনা বা সংক্ষেপ করা হয় না; প্রতিটি লিংক সংসদের নিজস্ব নথিতে যায়।',
          "Every session, the order of the day for every sitting and the Parliament Secretariat's circulars, exactly as Parliament publishes them. Nothing here is edited or shortened; every link goes to Parliament's own document.",
        ),
        stats: [
          (label: t('অধিবেশন', 'Sessions'), value: t.n(data.sessions.length)),
          (label: t('বৈঠক', 'Sittings'), value: t.n(data.sittingCount)),
          (
            label: t('শেষ বৈঠক', 'Last sitting'),
            value: ago == null
                ? t('তথ্য নেই', 'Not available')
                : ago == 0
                ? t('আজ', 'Today')
                : t(
                    '${t.n(ago)} দিন আগে',
                    '$ago ${plural(ago, 'day', 'days')} ago',
                  ),
          ),
        ],
      ),
      if (current?.startDate != null) ...[
        const SizedBox(height: 18),
        SessionCountdown(session: current!, clock: _now),
      ],
      const SizedBox(height: 22),
      if (data.sessions.isEmpty)
        EmptyState(
          icon: Icons.event_busy_outlined,
          title: t(
            'সংসদের তথ্যভান্ডারে এখনো কোনো অধিবেশন প্রকাশিত হয়নি।',
            "No session has been published in Parliament's database yet.",
          ),
        ),
      for (var i = 0; i < data.sessions.length; i++) ...[
        _SessionCard(session: data.sessions[i], latest: i == 0),
        const SizedBox(height: 16),
      ],
      const SizedBox(height: 8),
      SectionTitle(
        t('সংসদ সচিবালয়ের বিজ্ঞপ্তি', 'Parliament Secretariat notices'),
        count: t.count(data.generalNotices.length, 'টি', 'notice', 'notices'),
      ),
      if (notices.isEmpty)
        Text(
          t('কোনো সাধারণ বিজ্ঞপ্তি নেই।', 'There are no general notices.'),
          style: Theme.of(context).textTheme.bodyMedium,
        )
      else
        NoticeList(notices: notices, buttonLabel: 'PDF'),
      const SizedBox(height: 24),
      _ParliamentCard(dates: data.parliament),
      const SizedBox(height: 16),
      _OfficersCard(officers: data.officers),
      const SizedBox(height: 16),
      InfoNote(
        t(
          'তথ্যসূত্র: বাংলাদেশ জাতীয় সংসদ। প্রতিটি নথি সংসদের সার্ভার থেকে খোলে; আমার এমপি কোনো নথি নিজে রাখে না। হালনাগাদ ${t.date(data.version) ?? ''}।',
          "Source: Parliament of Bangladesh. Every document opens from Parliament's own server; My MP keeps no documents itself. Updated ${t.date(data.version) ?? ''}.",
        ),
      ),
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSizes.pagePad,
        8,
        AppSizes.pagePad,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: items,
    );
  }
}

/// The latest session, told by the clock: before it starts, the days, hours,
/// minutes and seconds left to its first day; while it sits, which day of it
/// this is; after, how long since its last sitting.
class SessionCountdown extends StatefulWidget {
  final HouseSession session;
  final DateTime Function() clock;
  const SessionCountdown({
    super.key,
    required this.session,
    required this.clock,
  });

  @override
  State<SessionCountdown> createState() => _SessionCountdownState();
}

class _SessionCountdownState extends State<SessionCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final st = sessionClockAt(
      widget.clock(),
      s.startDate,
      s.endDate,
      s.sittings.firstOrNull?.date,
    );
    if (st == null) return const SizedBox.shrink();
    final eyebrow = switch (st) {
      ClockSitting() => t('অধিবেশন চলছে', 'In session'),
      ClockAfter() => t('সর্বশেষ অধিবেশন', 'Latest session'),
      ClockBefore() => t('আসন্ন অধিবেশন', 'Upcoming session'),
    };
    final weekday = weekdayOfDay(s.startDate);
    final startText = t.date(s.startDate) ?? s.startDate ?? '';
    final held = s.sittings.length;
    final circular = s.firstCircular;
    final white = Colors.white.withValues(alpha: 0.85);

    return Semantics(
      label: t('অধিবেশনের সময়', 'Session timing'),
      container: true,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.brandDark,
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          boxShadow: AppDecor.shadow,
        ),
        child: Stack(
          children: [
            Positioned(
              right: -70,
              top: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: st is ClockSitting
                              ? AppColors.live
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          eyebrow,
                          style: TextStyle(
                            fontFamily: _font,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.75),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.title,
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      '${t('শুরু ', 'First day: ')}${weekday == null ? '' : '${t.weekday(weekday)}, '}$startText',
                      if (held > 0)
                        t(
                          '${t.n(held)}টি বৈঠক হয়েছে',
                          '$held ${plural(held, 'sitting', 'sittings')} held',
                        ),
                    ].join(' · '),
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: 14.5,
                      color: white,
                      height: 1.5,
                    ),
                  ),
                  if (circular?.pdfUrl != null) ...[
                    const SizedBox(height: 10),
                    Material(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: () => openLink(context, circular.pdfUrl!),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '${circular!.title ?? t('পরিপত্র', 'Circular')}${t(': বৈঠকের সময় ও সূচি', ': sitting times and schedule')}',
                                  style: const TextStyle(
                                    fontFamily: _font,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.open_in_new_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  switch (st) {
                    ClockSitting(:final day) => _sitting(day),
                    ClockAfter(:final days) => _after(days),
                    ClockBefore() => _before(st),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sitting(int day) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          t.en ? t.ord(day) : t.n(day),
          style: const TextStyle(
            fontFamily: _font,
            fontSize: 56,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            t('তম দিন\nঅধিবেশনের', 'day of\nthe session'),
            style: TextStyle(
              fontFamily: _font,
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _after(int days) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('${t.n(days)} দিন', '$days ${plural(days, 'day', 'days')}'),
          style: const TextStyle(
            fontFamily: _font,
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t(
            'শেষ বৈঠকের পর; পরের অধিবেশনের তারিখ এখনো ঘোষণা হয়নি',
            'since the last sitting; the date of the next session has not yet been announced',
          ),
          style: TextStyle(
            fontFamily: _font,
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.8),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _before(ClockBefore st) {
    String pad(int v) => t.n(v.toString().padLeft(2, '0'));
    final units = [
      (t('দিন', 'Days'), t.n(st.days)),
      (t('ঘণ্টা', 'Hours'), pad(st.hours)),
      (t('মিনিট', 'Minutes'), pad(st.minutes)),
      (t('সেকেন্ড', 'Seconds'), pad(st.seconds)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < units.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          units[i].$2,
                          style: const TextStyle(
                            fontFamily: _font,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          units[i].$1,
                          style: TextStyle(
                            fontFamily: _font,
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.75),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          t('শুরুর দিন পর্যন্ত বাকি', 'Left until the first day'),
          style: TextStyle(
            fontFamily: _font,
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.65),
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// One session: its name, its dates, its sittings three to a row (a tap opens
/// the order of the day), and its circulars.
class _SessionCard extends StatelessWidget {
  final HouseSession session;
  final bool latest;
  const _SessionCard({required this.session, required this.latest});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final text = Theme.of(context).textTheme;
    final dates =
        '${t('শুরু ', 'Start: ')}${t.date(s.startDate) ?? t('তারিখ নেই', 'no date')}'
        '${s.endDate != null ? t(', শেষ ${t.date(s.endDate)}', ', end: ${t.date(s.endDate)}') : ''}';
    final n = s.sittings.length;
    final rows = <List<Sitting>>[
      for (var i = 0; i < n; i += 3)
        s.sittings.sublist(i, i + 3 > n ? n : i + 3),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(s.title, style: text.titleLarge),
                    if (latest)
                      Pill(
                        n == 0
                            ? t('আসন্ন', 'Upcoming')
                            : t('সর্বশেষ', 'Latest'),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(dates, style: text.bodySmall),
                const SizedBox(height: 2),
                Text(
                  t.count(n, 'টি বৈঠক', 'sitting', 'sittings'),
                  style: text.titleSmall?.copyWith(color: AppColors.ink),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (n == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Text(
                t(
                  'এই অধিবেশনের কোনো বৈঠকের কার্যসূচি এখনো প্রকাশিত হয়নি।',
                  'No order of the day has been published yet for any sitting of this session.',
                ),
                style: text.bodyMedium,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (var r = 0; r < rows.length; r++) ...[
                    if (r > 0) const SizedBox(height: 8),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var c = 0; c < 3; c++) ...[
                            if (c > 0) const SizedBox(width: 8),
                            Expanded(
                              child: c < rows[r].length
                                  ? _SittingTile(
                                      sitting: rows[r][c],
                                      number: n - (r * 3 + c),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (s.circulars.isNotEmpty)
            Container(
              color: AppColors.paper.withValues(alpha: 0.6),
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('পরিপত্র', 'Circulars'),
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.muted,
                    ),
                  ),
                  for (final c in s.circulars)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text:
                                    c.title ??
                                    t(
                                      'পরিপত্র ${t.n(c.no ?? '')}',
                                      'Circular ${c.no ?? ''}',
                                    ).trim(),
                                children: [
                                  if (t.date(c.date) case final d?)
                                    TextSpan(
                                      text: ', $d',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                      ),
                                    ),
                                ],
                              ),
                              style: const TextStyle(
                                fontFamily: _font,
                                fontSize: 14,
                                color: AppColors.ink,
                                height: 1.45,
                              ),
                            ),
                          ),
                          if (c.pdfUrl != null) ...[
                            const SizedBox(width: 10),
                            DocButton(label: 'PDF', url: c.pdfUrl!),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SittingTile extends StatelessWidget {
  final Sitting sitting;
  final int number;
  const _SittingTile({required this.sitting, required this.number});

  @override
  Widget build(BuildContext context) {
    final o = sitting;
    final weekday = weekdayOfDay(o.date);
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(9, 8, 7, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${t('বৈঠক ', 'Sitting ')}${t.n(number)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 11.5,
                    color: AppColors.muted,
                    height: 1.3,
                  ),
                ),
              ),
              if (o.pdfUrl != null)
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 11,
                  color: AppColors.muted,
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            t.date(o.date) ?? o.title ?? '',
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              height: 1.35,
            ),
          ),
          if (weekday != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                t.weekday(weekday),
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: _font,
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.rule),
    );
    return Material(
      color: AppColors.paper.withValues(alpha: 0.6),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: o.pdfUrl == null
          ? body
          : Semantics(
              button: true,
              label: t('দিনের কার্যসূচি', o.title ?? 'Order of the day'),
              child: InkWell(
                onTap: () => openLink(context, o.pdfUrl!),
                child: body,
              ),
            ),
    );
  }
}

/// The parliament's own dates.
class _ParliamentCard extends StatelessWidget {
  final ParliamentDates dates;
  const _ParliamentCard({required this.dates});

  @override
  Widget build(BuildContext context) {
    Widget fact(String label, String? iso) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: _font,
            fontSize: 12.5,
            color: AppColors.muted,
            height: 1.35,
          ),
        ),
        Text(
          t.date(iso) ?? t('তথ্য নেই', 'Not available'),
          style: const TextStyle(
            fontFamily: _font,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            height: 1.4,
          ),
        ),
      ],
    );
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    );
    return HouseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('ত্রয়োদশ সংসদ', '13th Parliament'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          pair(
            fact(t('নির্বাচন', 'Election'), dates.electionDate),
            fact(t('গেজেট', 'Gazette'), dates.gazetteDate),
          ),
          const SizedBox(height: 12),
          pair(
            fact(t('শপথ', 'Oath'), dates.oathDate),
            fact(t('মেয়াদ শেষ', 'Term ends'), dates.endDate),
          ),
        ],
      ),
    );
  }
}

/// "সংসদ পরিচালনায়": the presiding officers, leaders and whips; a tap opens
/// the member's profile when the source links the officer to a member.
class _OfficersCard extends StatelessWidget {
  final List<HouseOfficer> officers;
  const _OfficersCard({required this.officers});

  @override
  Widget build(BuildContext context) {
    return HouseCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('সংসদ পরিচালনায়', 'Running the House'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < officers.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _OfficerRow(officer: officers[i]),
          ],
        ],
      ),
    );
  }
}

class _OfficerRow extends StatelessWidget {
  final HouseOfficer officer;
  const _OfficerRow({required this.officer});

  @override
  Widget build(BuildContext context) {
    final o = officer;
    final MemberBrief? m = o.member;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.name,
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: m == null ? AppColors.ink : AppColors.brandDark,
                    height: 1.4,
                  ),
                ),
                Text(
                  '${o.roleName}${o.tenure != null ? ', ${o.tenure}' : ''}',
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 12.5,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (m != null) ...[
            const SizedBox(width: 8),
            PartyLogo(abbr: m.party, size: 18),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.muted,
            ),
          ],
        ],
      ),
    );
    if (m == null) return row;
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => MemberScreen(member: m))),
      child: row,
    );
  }
}
