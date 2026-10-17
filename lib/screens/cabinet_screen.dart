import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../brand_header.dart';
import '../data/cabinet.dart';
import '../i18n.dart';
import '../loading.dart';
import '../models.dart';
import '../party_logo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'adviser_screen.dart';
import 'house_overview.dart' show CabinetSummary;
import 'member_screen.dart';
import 'members_screen.dart';

/// The cabinet, as the website's মন্ত্রিসভা / Cabinet page shows it: the ranks
/// with their counts, when the list was last checked and where it comes from,
/// a search and a ministry filter, the cabinet by party, the Prime Minister,
/// every rank's people with their ministries and since when, and what changed
/// on the list. Someone who is not a member of Parliament is shown too, and
/// plainly marked as one.
class CabinetScreen extends StatefulWidget {
  /// What "সব সংসদ সদস্য" does: the shell can switch to the members tab.
  /// Without it the member list opens as a page of its own.
  final VoidCallback? onShowMembers;
  const CabinetScreen({super.key, this.onShowMembers});

  @override
  State<CabinetScreen> createState() => _CabinetScreenState();
}

TextStyle _st(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color colour = AppColors.ink,
  double height = 1.45,
}) => TextStyle(
  fontFamily: 'NotoSansBengali',
  fontSize: size,
  fontWeight: weight,
  color: colour,
  height: height,
);

class _CabinetScreenState extends State<CabinetScreen>
    with RefetchOnLang<CabinetScreen> {
  late Future<CabinetData> _future = fetchCabinet();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  String? _ministry;

  /// Each rank's section, so its tile can jump to it.
  final _sections = {for (final r in cabinetRanks) r.bn: GlobalKey()};

  @override
  void onLangChanged() {
    // A ministry is chosen by its name in the language it was shown in.
    _ministry = null;
    _reload();
  }

  void _reload() => setState(() {
    _future = fetchCabinet();
  });

  Future<void> _refresh() async {
    _reload();
    await settle(_future);
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
    _search.clear();
    _query = '';
    _ministry = null;
  });

  void _jumpTo(CabinetRank r) {
    if (_query.isNotEmpty || _ministry != null) _clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _sections[r.bn]?.currentContext;
      if (c == null || !c.mounted) return;
      Scrollable.ensureVisible(
        c,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pushed = ModalRoute.of(context)?.canPop ?? false;
    return Scaffold(
      body: Column(
        children: [
          BrandHeader(
            title: t('মন্ত্রিসভা', 'Cabinet'),
            subtitle: t(
              'কে কোন মন্ত্রণালয়ের দায়িত্বে, কবে থেকে, আর কে কোন আসনের সংসদ সদস্য।',
              'Who is in charge of which ministry, since when, and which seat each one holds as a Member of Parliament.',
            ),
            trailing: pushed
                ? IconButton(
                    tooltip: t('বন্ধ করুন', 'Close'),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                : null,
          ),
          Expanded(
            child: Loaded<CabinetData>(
              future: _future,
              onRetry: _reload,
              builder: _page,
            ),
          ),
        ],
      ),
    );
  }

  Widget _page(BuildContext context, CabinetData data) {
    if (data.posts.isEmpty && data.pending.isEmpty) {
      return EmptyState(
        icon: Icons.account_balance_outlined,
        title: t(
          'মন্ত্রিসভার তালিকা পাওয়া যায়নি',
          'The Cabinet list was not found',
        ),
        body: t(
          'তালিকা প্রকাশিত হলে এখানে দেখা যাবে।',
          'It will appear here once the list is published.',
        ),
        actionLabel: t('আবার চেষ্টা করুন', 'Try again'),
        onAction: _reload,
      );
    }
    final cabinet = Cabinet.of(data);
    final q = _query.trim().toLowerCase();
    final ministry = cabinet.ministries
        .where((m) => m.key == _ministry)
        .firstOrNull;
    final filtering = ministry != null || q.isNotEmpty;
    final shown = [
      for (final g in cabinet.groups)
        MinisterGroup(
          title: g.title,
          rank: g.rank,
          people: g.people
              .where(
                (p) =>
                    (ministry == null ||
                        p.ministries.any((m) => m.key == ministry.key)) &&
                    p.matches(q),
              )
              .toList(),
        ),
    ];
    final total = shown.fold(0, (n, g) => n + g.people.length);
    final pm = shown.firstWhere(
      (g) => g.isPrimeMinister,
      orElse: () => const MinisterGroup(title: '', people: []),
    );
    final rest = shown.where((g) => !g.isPrimeMinister).toList();

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _refresh,
      child: SingleChildScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSizes.pagePad,
          16,
          AppSizes.pagePad,
          28 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The page opens on the cabinet at a glance, then its head.
            _Summary(
              cabinet: cabinet,
              data: data,
              onTap: _jumpTo,
              onSource: data.sourceUrl == null
                  ? null
                  : () => openLink(context, data.sourceUrl!),
            ),
            const SizedBox(height: 10),
            _chips(context, data),
            if (!filtering && pm.people.isNotEmpty) ...[
              const SizedBox(height: 18),
              Column(
                key: _sections[cabinetRanks.first.bn],
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final p in pm.people) _LeaderCard(p: p, label: pm.label),
                ],
              ),
            ],
            const SizedBox(height: 22),
            _finder(context, cabinet, ministry, total, filtering),
            if (!filtering) ...[
              const SizedBox(height: 12),
              _Composition(people: cabinet.everyone),
            ],
            const SizedBox(height: 26),
            // While searching, the Prime Minister is one of the results.
            if (filtering && pm.people.isNotEmpty)
              Column(
                key: _sections[cabinetRanks.first.bn],
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final p in pm.people) ...[
                    _LeaderCard(p: p, label: pm.label),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 14),
                ],
              ),
            if (filtering && total == 0) ...[
              _Dashed(
                child: Text(
                  t(
                    '“${q.isNotEmpty ? _query.trim() : ministry?.label}” দিয়ে কাউকে পাওয়া যায়নি। অন্য বানানে বা মন্ত্রণালয়ের নামে খুঁজে দেখুন।',
                    'Nobody found for “${q.isNotEmpty ? _query.trim() : ministry?.label}”. Try another spelling or the ministry’s name.',
                  ),
                  textAlign: TextAlign.center,
                  style: _st(14.5, colour: AppColors.muted, height: 1.6),
                ),
              ),
              const SizedBox(height: 24),
            ],
            for (final g in rest)
              if (!filtering || g.people.isNotEmpty)
                _RankSection(
                  key: g.rank == null ? null : _sections[g.rank!.bn],
                  group: g,
                ),
            const SizedBox(height: 10),
            _Changes(data: data),
          ],
        ),
      ),
    );
  }

  /// Under the summary: who is still being checked, and the way to every MP.
  /// When the list was checked and where from are in the summary itself.
  Widget _chips(BuildContext context, CabinetData data) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (data.pending.isNotEmpty)
          _Chip(
            icon: Icons.schedule_rounded,
            text: t(
              '${t.n(data.pending.length)} জন সংসদ সদস্য কিনা যাচাই হচ্ছে',
              '${t.count(data.pending.length, '', 'person', 'people')} being checked for whether they are MPs',
            ),
            background: AppColors.warnSoft,
            colour: AppColors.ink,
          ),
        _Chip(
          text: t('সব সংসদ সদস্য', 'All MPs'),
          trailingIcon: Icons.arrow_forward_rounded,
          background: Colors.transparent,
          colour: AppColors.brand,
          bold: true,
          onTap:
              widget.onShowMembers ??
              () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const MembersScreen())),
        ),
      ],
    );
  }

  Widget _finder(
    BuildContext context,
    Cabinet cabinet,
    MinistryOption? ministry,
    int total,
    bool filtering,
  ) {
    final number = t.n(total);
    final noun = t.en ? ' ${plural(total, 'person', 'people')}' : ' জন';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            style: _st(15),
            decoration: InputDecoration(
              hintText: t(
                'নাম, মন্ত্রণালয় বা আসন খুঁজুন',
                'Search by name, ministry or seat',
              ),
              isDense: true,
              fillColor: AppColors.paper,
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.muted,
                size: 21,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: t('মুছুন', 'Clear'),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.muted,
                      ),
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            button: true,
            label: t('মন্ত্রণালয় বা বিভাগ', 'Ministry or division'),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _pickMinistry(context, cabinet.ministries),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ministry == null ? AppColors.rule : AppColors.brand,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance_outlined,
                      size: 19,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ministry?.label ??
                            t(
                              'সব মন্ত্রণালয় ও বিভাগ',
                              'All ministries and divisions',
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _st(14.5),
                      ),
                    ),
                    const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (ministry != null)
                          TextSpan(text: '${ministry.label}: '),
                        TextSpan(
                          text: number,
                          style: _st(14, weight: FontWeight.w700),
                        ),
                        TextSpan(text: noun),
                      ],
                    ),
                    style: _st(14, colour: AppColors.muted),
                  ),
                ),
              ),
              if (filtering) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _clear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brand,
                    side: const BorderSide(color: AppColors.rule),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    t('সবাইকে দেখুন', 'Show everyone'),
                    style: _st(
                      13.5,
                      weight: FontWeight.w600,
                      colour: AppColors.brand,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickMinistry(
    BuildContext context,
    List<MinistryOption> ministries,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                t('মন্ত্রণালয় বা বিভাগ', 'Ministry or division'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _option(
              context,
              '',
              t('সব মন্ত্রণালয় ও বিভাগ', 'All ministries and divisions'),
              _ministry == null,
            ),
            for (final m in ministries)
              _option(
                context,
                m.key,
                '${m.label} (${t.n(m.count)})',
                m.key == _ministry,
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _ministry = picked.isEmpty ? null : picked);
  }

  Widget _option(BuildContext context, String key, String label, bool on) =>
      ListTile(
        dense: true,
        selected: on,
        selectedColor: AppColors.brand,
        title: Text(
          label,
          style: _st(
            14.5,
            weight: on ? FontWeight.w600 : FontWeight.w400,
            colour: on ? AppColors.brand : AppColors.ink,
          ),
        ),
        trailing: on
            ? const Icon(Icons.check_rounded, color: AppColors.brand)
            : null,
        onTap: () => Navigator.of(context).pop(key),
      );
}

/// A rounded label in the row under the tiles.
class _Chip extends StatelessWidget {
  final IconData? icon;
  final IconData? trailingIcon;
  final String text;
  final Color background;
  final Color colour;
  final bool bold;
  final VoidCallback? onTap;
  const _Chip({
    this.icon,
    this.trailingIcon,
    required this.text,
    required this.background,
    required this.colour,
    this.bold = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: colour),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              style: _st(
                13,
                weight: bold ? FontWeight.w600 : FontWeight.w500,
                colour: colour,
                height: 1.35,
              ),
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 5),
            Icon(trailingIcon, size: 14, color: colour),
          ],
        ],
      ),
    );
    if (onTap == null) return body;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        onTap: onTap,
        child: body,
      ),
    );
  }
}

/// The cabinet at a glance: how many there are in all, each rank's count as a
/// cell that jumps to its people (a rank nobody holds is one quiet line, not a
/// tile), and when the list was last checked against the Cabinet Division.
class _Summary extends StatelessWidget {
  final Cabinet cabinet;
  final CabinetData data;
  final ValueChanged<CabinetRank> onTap;
  final VoidCallback? onSource;
  const _Summary({
    required this.cabinet,
    required this.data,
    required this.onTap,
    this.onSource,
  });

  @override
  Widget build(BuildContext context) {
    // The Prime Minister has a card of their own just below.
    final ranks = cabinetRanks.skip(1).where((r) => cabinet.count(r) > 0);
    final empty = cabinetRanks.skip(1).where((r) => cabinet.count(r) == 0);
    // Each person once, however many posts they hold, as the Members tab counts.
    final total = CabinetSummary.of(data).size;
    final checked = t.date(data.checkedAt);

    Widget cell(CabinetRank r) => Expanded(
      child: Semantics(
        button: true,
        child: Material(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTap(r),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.n(cabinet.count(r)),
                    style: _st(
                      26,
                      weight: FontWeight.w800,
                      colour: AppColors.brandDark,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          t(r.bn, r.enPlural),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _st(
                            12.5,
                            weight: FontWeight.w600,
                            colour: AppColors.inkSoft,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_downward_rounded,
                        size: 13,
                        color: AppColors.brand,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final cells = <Widget>[];
    for (final r in ranks) {
      if (cells.isNotEmpty) cells.add(const SizedBox(width: 8));
      cells.add(cell(r));
    }

    return Container(
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    t('মন্ত্রিসভায় মোট', 'In the Cabinet'),
                    style: _st(
                      14,
                      weight: FontWeight.w700,
                      colour: AppColors.inkSoft,
                    ),
                  ),
                ),
                Text(
                  t('${t.n(total)} জন', t.count(total, '', 'person', 'people')),
                  style: _st(22, weight: FontWeight.w800, height: 1.1),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cells,
              ),
            ),
          ),
          if (empty.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                t(
                  '${empty.map((r) => r.bn).join(', ')}: এখন কেউ নেই',
                  '${empty.map((r) => r.enPlural).join(', ')}: none at present',
                ),
                style: _st(12, colour: AppColors.muted),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            decoration: const BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(AppSizes.radiusCard),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 16,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    checked == null
                        ? t(
                            'মন্ত্রিপরিষদ বিভাগের তালিকা থেকে',
                            'From the Cabinet Division’s list',
                          )
                        : t('সর্বশেষ যাচাই $checked', 'Last checked $checked'),
                    style: _st(
                      12.5,
                      weight: FontWeight.w600,
                      colour: AppColors.brandDark,
                    ),
                  ),
                ),
                if (onSource != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                    onTap: onSource,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t('সূত্র', 'Source'),
                            style: _st(
                              12.5,
                              weight: FontWeight.w700,
                              colour: AppColors.brand,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.open_in_new_rounded,
                            size: 14,
                            color: AppColors.brand,
                          ),
                        ],
                      ),
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

/// A dashed, quiet box: an empty rank, or nothing found.
class _Dashed extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final CrossAxisAlignment align;
  const _Dashed({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    this.align = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedBorder(),
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: align,
        mainAxisSize: MainAxisSize.min,
        children: [child],
      ),
    ),
  );
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.rule
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(AppSizes.radiusCard),
        ),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The whole cabinet by party in one bar, so its make-up is plain before the
/// names; those who are not MPs are one grey, apart.
class _Composition extends StatelessWidget {
  final List<MinisterPerson> people;
  const _Composition({required this.people});

  @override
  Widget build(BuildContext context) {
    final list = compositionOf(people);
    final total = people.isEmpty ? 1 : people.length;
    Color shade(CabinetShare s) =>
        s.outside ? s.colour.withValues(alpha: 0.45) : s.colour;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: AppColors.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(
                t('মন্ত্রিসভা দল অনুযায়ী', 'The Cabinet by party'),
                style: _st(15, weight: FontWeight.w700),
              ),
              Text(
                t.count(people.length, ' জন', 'person', 'people'),
                style: _st(13, colour: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label: list.map((s) => '${s.label} ${t.n(s.count)}').join(', '),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              child: SizedBox(
                height: 12,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final s in list)
                      Expanded(
                        flex: (1000 * s.count / total).round().clamp(1, 1000),
                        child: ColoredBox(color: shade(s)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final s in list)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: shade(s),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '${s.label} '),
                            TextSpan(
                              text: t.n(s.count),
                              style: _st(13, colour: AppColors.muted),
                            ),
                          ],
                        ),
                        style: _st(13, colour: AppColors.inkSoft),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opens the person's own page: a member's profile, or the profile of
/// someone from outside Parliament.
VoidCallback? _openPerson(BuildContext context, MinisterPerson p) {
  final m = p.member;
  if (m != null) {
    return () => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MemberScreen(member: m)));
  }
  final slug = p.adviserSlug;
  if (slug != null) {
    return () => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdviserScreen(
          slug: slug,
          nameBn: p.name ?? '',
          photoUrl: p.photoUrl,
          fromCabinet: true,
        ),
      ),
    );
  }
  return null;
}

/// A photograph, or the first letter of the name in its place.
class _Photo extends StatelessWidget {
  final String? url;
  final String initial;
  final double size;
  final Color colour;
  const _Photo({
    required this.url,
    required this.initial,
    required this.size,
    required this.colour,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: colour.withValues(alpha: 0.12),
      child: Text(
        initial,
        style: _st(
          size * 0.38,
          weight: FontWeight.w700,
          colour: colour,
          height: 1.2,
        ),
      ),
    );
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 180),
                placeholder: (_, _) => Container(color: AppColors.sunk),
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// The photo in a ring of the party's colour, so a page of faces reads by
/// party at a glance.
class _Portrait extends StatelessWidget {
  final MinisterPerson p;
  final double size;
  const _Portrait({required this.p, required this.size});

  @override
  Widget build(BuildContext context) {
    final ring = p.colour ?? AppColors.rule;
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
          ),
          child: _Photo(
            url: p.photoUrl,
            initial: p.initial,
            size: size,
            colour: p.colour ?? AppColors.brand,
          ),
        ),
      ),
    );
  }
}

/// Party, seat, "not an MP" and the rank the post carries, under the name.
class _Who extends StatelessWidget {
  final MinisterPerson p;
  const _Who({required this.p});

  @override
  Widget build(BuildContext context) {
    final muted = _st(13, colour: AppColors.muted, height: 1.4);
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (p.partyName != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PartyLogo(abbr: p.party, size: 16),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  p.partyName!,
                  style: _st(
                    13,
                    weight: FontWeight.w600,
                    colour: AppColors.inkSoft,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        if (p.seat != null) Text(p.seat!, style: muted),
        if (!p.isMp)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.rule),
            ),
            child: Text(
              p.pending
                  ? t('সংসদ সদস্য কিনা যাচাই হচ্ছে', 'Being checked: MP or not')
                  : t('সংসদ সদস্য নন', 'Not an MP'),
              style: _st(12, colour: AppColors.muted, height: 1.4),
            ),
          ),
        if (p.rankNote != null) Text(p.rankNote!, style: muted),
      ],
    );
  }
}

/// "সূত্র ↗": the Cabinet Division's page the row was read from.
class _Source extends StatelessWidget {
  final MinisterPerson p;
  const _Source({required this.p});

  @override
  Widget build(BuildContext context) {
    final url = p.sourceUrl;
    if (url == null) return const SizedBox.shrink();
    return Tooltip(
      message: t('মন্ত্রিপরিষদ বিভাগের তালিকা', 'The Cabinet Division’s list'),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => openLink(context, url),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('সূত্র', 'Source'),
                style: _st(12, colour: AppColors.muted, height: 1.4),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.north_east_rounded,
                size: 12,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// On English, the ministries that have no English name yet: counted, with
/// the way to the Bangla page that names them, rather than left out silently.
class _Unnamed extends StatelessWidget {
  final MinisterPerson p;
  const _Unnamed({required this.p});

  @override
  Widget build(BuildContext context) {
    final n = p.ministries.where((m) => m.name == null).length;
    if (!t.en || n == 0) return const SizedBox.shrink();
    final all = n == p.ministries.length;
    final what = all
        ? (n == 1 ? 'Ministry' : '$n ministries')
        : n == 1
        ? 'One more ministry'
        : '$n more ministries';
    return InkWell(
      onTap: () => openLink(context, '${Api.base}/ministers'),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$what, named so far only on the '),
            TextSpan(
              text: 'Bangla page',
              style: _st(
                12.5,
                colour: AppColors.muted,
              ).copyWith(decoration: TextDecoration.underline),
            ),
          ],
        ),
        style: _st(12.5, colour: AppColors.muted, height: 1.4),
      ),
    );
  }
}

String _since(String since) => t('$since থেকে', 'Since $since');

/// The head of government: a larger portrait, the rank above the name, every
/// portfolio, and the way to the full profile.
class _LeaderCard extends StatelessWidget {
  final MinisterPerson p;
  final String label;
  const _LeaderCard({required this.p, required this.label});

  @override
  Widget build(BuildContext context) {
    final open = _openPerson(context, p);
    final named = p.ministries.where((m) => m.name != null).toList();
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandSoft, AppColors.surface, AppColors.surface],
          stops: [0, 0.55, 1],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: AppColors.brandRing),
        boxShadow: AppDecor.shadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // On a phone the site stacks it: the portrait, then the rank above
          // the name.
          GestureDetector(
            onTap: open,
            child: _Portrait(p: p, size: 96),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: _st(
                    12,
                    weight: FontWeight.w700,
                    colour: AppColors.brand,
                  ).copyWith(letterSpacing: 0.6),
                ),
              ),
              _Source(p: p),
            ],
          ),
          const SizedBox(height: 2),
          GestureDetector(
            onTap: open,
            child: Text(
              p.shownName,
              style: _st(26, weight: FontWeight.w700, height: 1.3),
            ),
          ),
          const SizedBox(height: 6),
          _Who(p: p),
          const SizedBox(height: 14),
          Text(
            t.count(
              p.ministries.length,
              'টি দায়িত্ব',
              'responsibility',
              'responsibilities',
            ),
            style: _st(12.5, weight: FontWeight.w600, colour: AppColors.muted),
          ),
          const SizedBox(height: 8),
          for (final m in named) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.rule),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name!,
                    style: _st(14.5, weight: FontWeight.w600, height: 1.4),
                  ),
                  if (m.since != null)
                    Text(
                      _since(m.since!),
                      style: _st(12.5, colour: AppColors.muted, height: 1.4),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          _Unnamed(p: p),
          if (open != null) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: open,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: Text(
                t(
                  'পুরো পরিচিতি, সংবাদ ও ভিডিও',
                  'Full profile, news and videos',
                ),
                style: _st(
                  13.5,
                  weight: FontWeight.w600,
                  colour: Colors.white,
                  height: 1.3,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One person in a rank: portrait, name, party and seat, and their
/// ministries under a rule of the party's colour, each with since when.
class _PersonCard extends StatelessWidget {
  final MinisterPerson p;
  const _PersonCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final open = _openPerson(context, p);
    final named = p.ministries.where((m) => m.name != null).toList();
    return Container(
      decoration: AppDecor.card(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: open,
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Portrait(p: p, size: 50),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.shownName,
                            style: _st(
                              16.5,
                              weight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _Who(p: p),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    _Source(p: p),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: p.colour ?? AppColors.rule,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, m) in named.indexed) ...[
                        if (i > 0) const SizedBox(height: 8),
                        Text(
                          m.name!,
                          style: _st(
                            14.5,
                            weight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        if (m.since != null)
                          Text(
                            _since(m.since!),
                            style: _st(
                              12.5,
                              colour: AppColors.muted,
                              height: 1.4,
                            ),
                          ),
                      ],
                      if (named.length < p.ministries.length) ...[
                        if (named.isNotEmpty) const SizedBox(height: 8),
                        _Unnamed(p: p),
                      ],
                      if (p.ministries.isEmpty)
                        Text(
                          t('মন্ত্রণালয় লেখা নেই', 'No ministry listed'),
                          style: _st(13.5, colour: AppColors.muted),
                        ),
                    ],
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

/// A rank: its name and count, what the rank means, and its people.
class _RankSection extends StatelessWidget {
  final MinisterGroup group;
  const _RankSection({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final g = group;
    final r = g.rank;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.rule)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      g.label,
                      style: _st(21, weight: FontWeight.w700, height: 1.3),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandSoft,
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusPill,
                        ),
                      ),
                      child: Text(
                        t.count(g.people.length, ' জন', 'person', 'people'),
                        style: _st(
                          13,
                          weight: FontWeight.w600,
                          colour: AppColors.brand,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                if (r != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    t(r.noteBn, r.noteEn),
                    style: _st(13.5, colour: AppColors.muted, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (g.people.isEmpty)
            _Dashed(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              align: CrossAxisAlignment.start,
              child: Text(
                t(
                  'মন্ত্রিপরিষদ বিভাগের তালিকায় এখন কোনো ${g.title} নেই।',
                  'The Cabinet Division’s list has no ${g.label.toLowerCase()} at present.',
                ),
                style: _st(14.5, colour: AppColors.muted, height: 1.6),
              ),
            )
          else
            for (final (i, p) in g.people.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              _PersonCard(p: p),
            ],
        ],
      ),
    );
  }
}

/// পরিবর্তন: what changed on the Cabinet Division's list, and when.
class _Changes extends StatelessWidget {
  final CabinetData data;
  const _Changes({required this.data});

  MemberBrief _member(String slug, String? name) {
    for (final r in data.posts) {
      if (r.member?.slug == slug) return r.member!;
    }
    for (final m in Api.instance.cached?.members ?? const <MemberBrief>[]) {
      if (m.slug == slug) return m;
    }
    return MemberBrief(id: '', slug: slug, nameBn: name ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final log = data.changes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t('পরিবর্তন', 'Changes'),
          style: _st(22, weight: FontWeight.w700, height: 1.3),
        ),
        const SizedBox(height: 2),
        Text(
          t(
            'মন্ত্রিপরিষদ বিভাগের তালিকায় যেদিন যা বদলেছে।',
            'What changed on the Cabinet Division’s list, and when.',
          ),
          style: _st(13.5, colour: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: AppDecor.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (log.isEmpty)
                Text(
                  t(
                    'এখনো কোনো পরিবর্তন লেখা হয়নি।',
                    'No changes recorded yet.',
                  ),
                  style: _st(14.5, colour: AppColors.muted),
                )
              else
                for (final (i, c) in log.indexed)
                  _change(context, c, last: i == log.length - 1),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.rule),
              const SizedBox(height: 10),
              Text(
                t(
                  'দায়িত্ব পাওয়ার তারিখ মন্ত্রিপরিষদ বিভাগের তালিকার বণ্টনের তারিখ। কারও নাম তালিকা থেকে সরে গেলে যেদিন তা ধরা পড়ে, সেদিনকে দায়িত্ব শেষের তারিখ ধরা হয়।',
                  'The date of taking charge is the date of allocation on the Cabinet Division’s list. When someone’s name leaves the list, the day that is noticed is taken as the day their responsibility ended.',
                ),
                style: _st(12.5, colour: AppColors.muted, height: 1.55),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _change(BuildContext context, CabinetChange c, {required bool last}) {
    final ended = c.kind == 'end';
    final slug = c.memberSlug;
    final name = c.nameBn ?? t('নাম জানা নেই', 'Name given only in Bangla');
    final line = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: ended ? AppColors.rule : AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 4.5, top: 2),
                      width: 1,
                      color: AppColors.ruleSoft,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (t.date(c.date) case final d?)
                    Text(
                      d,
                      style: _st(12.5, colour: AppColors.muted, height: 1.4),
                    ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: name,
                          style: _st(
                            14.5,
                            weight: FontWeight.w600,
                            colour: slug != null
                                ? AppColors.brandDark
                                : AppColors.ink,
                            height: 1.6,
                          ),
                        ),
                        if (c.textBn != null) ...[
                          const TextSpan(text: ', '),
                          TextSpan(
                            text: c.textBn,
                            style: _st(
                              14.5,
                              colour: ended ? AppColors.muted : AppColors.ink,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ],
                    ),
                    style: _st(14.5, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (slug == null) return line;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MemberScreen(member: _member(slug, c.nameBn)),
        ),
      ),
      child: line,
    );
  }
}
