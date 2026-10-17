import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api.dart';
import '../brand_header.dart';
import '../data/news.dart';
import '../i18n.dart';
import '../loading.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'news_range_picker.dart';
import 'story_list.dart';
import 'video_strip.dart';

/// Stories drawn at first, and added by each "আরও দেখুন".
const _page = 30;

/// A span's stories as they arrive, a page at a time.
class _Picked {
  final String key;
  final List<Story> stories;
  final String? next;
  final ({int news, int video})? counts;
  const _Picked(this.key, this.stories, this.next, this.counts);
}

/// The whole House's news, as the website's সংবাদ page (/songbad) has it:
/// today's figures, the months, the newest videos, the newest 400 stories with
/// their filters (kind, member, outlet, a headline search, a day or a span of
/// days), who is most in the news, and how the news is added.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen>
    with RefetchOnLang<NewsScreen> {
  late Future<List<Story>> _latest = fetchLatestNews();
  NewsCounts? _figures;

  String _kind = '';
  String _member = '';
  String _outlet = '';
  final _query = TextEditingController();
  DaySpan? _range;
  _Picked? _picked;
  String? _rangeFailed;
  bool _fetching = false;
  int _shown = _page;

  final _scroll = ScrollController();
  final _listTop = GlobalKey();
  final _keys = Expando<String>();

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The figures are a nicety: if they cannot be read the tab still lists
  /// the news.
  void _loadCounts() {
    fetchNewsCounts()
        .then((c) {
          if (mounted) setState(() => _figures = c.unavailable ? null : c);
        })
        .catchError((Object _) {});
  }

  void _reload() {
    setState(() => _latest = fetchLatestNews());
    _loadCounts();
    if (_range != null) _loadRange(_range!, keep: true);
  }

  /// Outlets and members are named in the new language; a picked outlet's
  /// old name would match nothing.
  @override
  void onLangChanged() {
    _outlet = '';
    _reload();
  }

  void _loadRange(DaySpan range, {bool keep = false}) {
    final key = spanKey(range);
    setState(() {
      _rangeFailed = null;
      if (!keep) _picked = null;
    });
    fetchNewsRange(range.from, range.to)
        .then((p) {
          if (!mounted || _range == null || spanKey(_range!) != key) return;
          setState(() => _picked = _Picked(key, p.stories, p.next, p.counts));
        })
        .catchError((Object _) {
          if (!mounted || _range == null || spanKey(_range!) != key) return;
          setState(() => _rangeFailed = key);
        });
  }

  /// The span's next page, added to the end; a story on the boundary is not
  /// shown twice.
  Future<void> _loadMore() async {
    final p = _picked;
    if (p == null || p.next == null || _fetching) return;
    setState(() => _fetching = true);
    final range = parseSpan(p.key)!;
    try {
      final next = await fetchNewsRange(range.from, range.to, before: p.next);
      final now = _picked;
      if (!mounted || now == null || now.key != p.key) return;
      final have = {for (final s in now.stories) s.id};
      setState(() {
        _picked = _Picked(
          p.key,
          [...now.stories, ...next.stories.where((s) => !have.contains(s.id))],
          next.next,
          now.counts,
        );
      });
    } catch (_) {
      // The button stays; another tap tries again.
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  void _setRange(DaySpan? range) {
    setState(() {
      _range = range;
      _shown = _page;
    });
    if (range != null) _loadRange(range);
  }

  void _clearAll() {
    _query.clear();
    setState(() {
      _member = '';
      _outlet = '';
      _kind = '';
      _range = null;
      _shown = _page;
    });
  }

  /// Brings the list's top into view: a month card, "সব ভিডিও" or a name in
  /// the side list changes what it shows.
  void _toList() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _listTop.currentContext;
      if (c != null && c.mounted) {
        Scrollable.ensureVisible(
          c,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String _key(Story s) => _keys[s] ??= storySearchKey(s);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          BrandHeader(
            title: t('সংবাদ', 'News'),
            subtitle: t('মিডিয়া ও সংবাদ', 'Media and news'),
          ),
          Expanded(
            child: Loaded<List<Story>>(
              future: _latest,
              onRetry: _reload,
              builder: (context, latest) => RefreshIndicator(
                color: AppColors.brand,
                onRefresh: () async {
                  _reload();
                  await settle(_latest);
                },
                child: SingleChildScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    AppSizes.pagePad,
                    16,
                    AppSizes.pagePad,
                    28 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: _body(context, latest),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, List<Story> latest) {
    final today = dhakaToday();
    final videos = latest.where((s) => s.isVideo).toList();
    final figures = _figures;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t(
            'সংসদ সদস্য ও আসন নিয়ে সংবাদমাধ্যমের শিরোনাম ও টেলিভিশনের ভিডিও, প্রতিটির সঙ্গে মূল সংবাদের লিংক। একই খবর কয়েকটি সংবাদমাধ্যমে এলে তা একসঙ্গে দেখানো হয়।',
            'Headlines from the news media and television videos about members of parliament and their seats, each with a link to the original story. When several outlets carry the same story, it is shown once, with all of them together.',
          ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (figures != null) ...[
          const SizedBox(height: 14),
          _Figures(figures: figures),
        ],
        if (figures != null && figures.months.isNotEmpty) ...[
          const SizedBox(height: 26),
          _MonthSection(
            months: figures.months,
            today: today,
            selected: _range == null ? null : spanKey(_range!),
            onPick: (span) {
              _setRange(span == null ? null : parseSpan(span));
              _toList();
            },
          ),
        ],
        if (videos.isNotEmpty) ...[
          const SizedBox(height: 26),
          VideoStrip(
            videos: videos,
            onSeeAll: () {
              setState(() {
                _kind = 'video';
                _shown = _page;
              });
              _toList();
            },
          ),
        ],
        SizedBox(key: _listTop, height: 22),
        if (latest.isEmpty)
          EmptyState(
            icon: Icons.article_outlined,
            title: t(
              'এখনো কোনো সংবাদ প্রকাশ করা হয়নি',
              'No news has been published yet',
            ),
            body: t(
              'অনুমোদিত সংবাদমাধ্যমের শিরোনাম যাচাইয়ের পর এখানে দেখানো হবে।',
              'Headlines from approved news outlets will be shown here once they have been checked.',
            ),
          )
        else
          _browser(context, latest, today),
        if (latest.isNotEmpty) ...[
          const SizedBox(height: 28),
          _MostInNews(
            members: _membersIn(latest),
            onPick: (slug) {
              setState(() {
                _member = slug;
                _shown = _page;
              });
              _toList();
            },
          ),
        ],
        const SizedBox(height: 16),
        _HowNewsIsAdded(outletCount: figures?.outletCount),
      ],
    );
  }

  /// Who is in the news, by number of stories, in the reader's language.
  List<({String slug, String name, int count})> _membersIn(List<Story> list) {
    final held = {
      for (final m in Api.instance.cached?.members ?? const <MemberBrief>[])
        m.slug: m,
    };
    final counts = <String, ({String slug, String name, int count})>{};
    for (final s in list) {
      for (final m in s.members) {
        final name = m.name.isNotEmpty ? m.name : held[m.slug]?.nameBn ?? '';
        if (name.isEmpty) continue;
        final e = counts[m.slug];
        counts[m.slug] = (
          slug: m.slug,
          name: e?.name ?? name,
          count: (e?.count ?? 0) + 1,
        );
      }
    }
    return counts.values.toList()..sort(
      (a, b) =>
          b.count != a.count ? b.count - a.count : a.name.compareTo(b.name),
    );
  }

  List<({String name, int count})> _outletsIn(List<Story> list) {
    final counts = <String, int>{};
    for (final s in list) {
      for (final src in [s.lead.source, ...s.also.map((a) => a.source)]) {
        if (src.isEmpty) continue;
        counts[src] = (counts[src] ?? 0) + 1;
      }
    }
    return [for (final e in counts.entries) (name: e.key, count: e.value)]
      ..sort(
        (a, b) =>
            b.count != a.count ? b.count - a.count : a.name.compareTo(b.name),
      );
  }

  /// "120 items (100 news, 20 videos), 30 shown" or
  /// "৩৯৫২টি (৩০৩৮ সংবাদ, ৯১৪ ভিডিও), ৩০০টি দেখানো হচ্ছে": a span's real
  /// totals, and how many have arrived while there are more to come.
  String _spanTotals(({int news, int video}) counts, int? shown) {
    final n =
        (_kind == 'video' ? 0 : counts.news) +
        (_kind == 'news' ? 0 : counts.video);
    if (t.en) {
      final noun = _kind == 'video'
          ? plural(n, 'video', 'videos')
          : _kind == 'news'
          ? plural(n, 'story', 'stories')
          : plural(n, 'item', 'items');
      final g = T.english.group;
      final parts = _kind.isEmpty
          ? ' (${g(counts.news)} news, ${g(counts.video)} ${plural(counts.video, 'video', 'videos')})'
          : '';
      return '${g(n)} $noun$parts${shown != null ? ', ${g(shown)} shown' : ''}';
    }
    final parts = _kind.isEmpty
        ? ' (${t.n(counts.news)} সংবাদ, ${t.n(counts.video)} ভিডিও)'
        : '';
    return '${t.n(n)}টি$parts${shown != null ? ', ${t.n(shown)}টি দেখানো হচ্ছে' : ''}';
  }

  Widget _browser(BuildContext context, List<Story> latest, String today) {
    final range = _range;
    final rangeKey = range == null ? '' : spanKey(range);
    final picked = _picked?.key == rangeKey ? _picked : null;
    final failed = range != null && _rangeFailed == rangeKey;
    final loading = range != null && picked == null && !failed;
    final stories = range == null ? latest : picked?.stories ?? const <Story>[];

    // The member and outlet lists follow what is shown: the span's, or the newest.
    final members = _membersIn(stories);
    final outlets = _outletsIn(stories);

    final q = _query.text;
    final filtered = [
      for (final s in stories)
        if (!(_kind == 'video' && !s.isVideo) &&
            !(_kind == 'news' && s.isVideo) &&
            (_member.isEmpty || s.members.any((m) => m.slug == _member)) &&
            (_outlet.isEmpty ||
                s.lead.source == _outlet ||
                s.also.any((a) => a.source == _outlet)) &&
            matchesQuery(_key(s), q))
          s,
    ];
    final visible = filtered.take(_shown).toList();
    final perDay = <String, int>{};
    for (final s in filtered) {
      perDay[s.date] = (perDay[s.date] ?? 0) + 1;
    }
    final days = <(String, String, List<Story>)>[];
    for (final s in visible) {
      if (days.isNotEmpty && days.last.$1 == s.date) {
        days.last.$3.add(s);
      } else {
        days.add((s.date, s.dateLabel, [s]));
      }
    }

    final filtering =
        _member.isNotEmpty ||
        _outlet.isNotEmpty ||
        _kind.isNotEmpty ||
        q.trim().isNotEmpty ||
        range != null;
    final videoCount = stories.where((s) => s.isVideo).length;

    final String status;
    final counts = picked?.counts;
    if (loading) {
      status = t('আনা হচ্ছে…', 'Loading…');
    } else if (range != null &&
        counts != null &&
        _member.isEmpty &&
        _outlet.isEmpty &&
        q.trim().isEmpty) {
      status = _spanTotals(
        counts,
        picked!.next != null ? filtered.length : null,
      );
    } else {
      final n = filtered.length;
      status = t.en
          ? '$n ${_kind == 'video' ? plural(n, 'video', 'videos') : plural(n, 'story', 'stories')}'
          : '${t.n(n)}টি ${_kind == 'video' ? 'ভিডিও' : 'খবর'}';
    }

    final memberName = members
        .where((m) => m.slug == _member)
        .map((m) => m.name)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (videoCount > 0) ...[
          ChipBar(
            padding: EdgeInsets.zero,
            options: [
              (label: t('সব', 'All'), value: ''),
              (label: t('সংবাদ', 'News'), value: 'news'),
              (
                label: t('ভিডিও (${t.n(videoCount)})', 'Videos ($videoCount)'),
                value: 'video',
              ),
            ],
            selected: _kind,
            onSelect: (v) => setState(() {
              _kind = v ?? '';
              _shown = _page;
            }),
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _query,
          onChanged: (_) => setState(() => _shown = _page),
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontFamily: 'NotoSansBengali', fontSize: 14.5),
          decoration: InputDecoration(
            isDense: true,
            hintText: t('শিরোনামে খুঁজুন', 'Search the headlines'),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: q.isEmpty
                ? null
                : IconButton(
                    tooltip: t('মুছুন', 'Clear'),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _query.clear();
                      setState(() => _shown = _page);
                    },
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ChoiceField(
                title: t('সংসদ সদস্য', 'Member of Parliament'),
                value: _member,
                fallback: _member.isEmpty
                    ? null
                    : memberName ??
                          Api.instance.cached?.members
                              .where((m) => m.slug == _member)
                              .map((m) => m.nameBn)
                              .firstOrNull,
                choices: [
                  (value: '', label: t('সব সংসদ সদস্য', 'All MPs')),
                  for (final m in members)
                    (value: m.slug, label: '${m.name} (${t.n(m.count)})'),
                ],
                onChanged: (v) => setState(() {
                  _member = v;
                  _shown = _page;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChoiceField(
                title: t('সংবাদমাধ্যম', 'News outlet'),
                value: _outlet,
                fallback: _outlet.isEmpty ? null : _outlet,
                choices: [
                  (value: '', label: t('সব সংবাদমাধ্যম', 'All outlets')),
                  for (final o in outlets)
                    (value: o.name, label: '${o.name} (${t.n(o.count)})'),
                ],
                onChanged: (v) => setState(() {
                  _outlet = v;
                  _shown = _page;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        NewsRangePicker(
          key: ValueKey(rangeKey),
          range: range,
          today: today,
          onPick: _setRange,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (range != null)
              Text(
                '${spanLabel(range.from, range.to)}:',
                style: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            Text(
              status,
              style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 14,
                color: AppColors.muted,
              ),
            ),
            if (filtering)
              TextButton(
                onPressed: _clearAll,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  t('সব খবর দেখুন', 'See all news'),
                  style: const TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (failed)
          ErrorView(
            message: t(
              'এই সময়ের খবর আনা গেল না।',
              'The news for this period could not be fetched.',
            ),
            onRetry: () => _loadRange(range),
          )
        else if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            ),
          )
        else if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Text(
              range != null
                  ? t(
                      'এই সময়ে কোনো খবর পাওয়া যায়নি।',
                      'No news found for this period.',
                    )
                  : t(
                      'এই খোঁজে কোনো খবর পাওয়া যায়নি।',
                      'No news found for this search.',
                    ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 15,
                color: AppColors.muted,
              ),
            ),
          )
        else
          for (final (date, label, items) in days) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 10),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: label.isNotEmpty
                          ? label
                          : RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)
                          ? dayLabel(date)
                          : '',
                    ),
                    const TextSpan(text: '  '),
                    TextSpan(
                      text: t(
                        '${t.n(perDay[date] ?? items.length)}টি',
                        '${perDay[date] ?? items.length}',
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            for (final s in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: StoryCard(story: s),
              ),
          ],
        if (!loading && !failed)
          MachineNote(
            // The headlines here and in the video row above.
            show:
                visible.any((s) => s.translated) ||
                latest.where((s) => s.isVideo).take(6).any((s) => s.translated),
            padding: const EdgeInsets.only(top: 2, bottom: 6),
          ),
        if (!loading &&
            !failed &&
            (filtered.length > visible.length || picked?.next != null)) ...[
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton(
              onPressed: _fetching
                  ? null
                  : () {
                      // Near the end of what is loaded, the span's next page
                      // is fetched too.
                      if (filtered.length <= visible.length + _page &&
                          picked?.next != null) {
                        _loadMore();
                      }
                      setState(() => _shown += _page);
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.ink),
                minimumSize: const Size(160, 48),
                shape: const StadiumBorder(),
              ),
              child: Text(
                _fetching
                    ? t('আনা হচ্ছে…', 'Loading…')
                    : t('আরও দেখুন', 'See more'),
                style: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Today's figures, each with its total underneath.
class _Figures extends StatelessWidget {
  final NewsCounts figures;
  const _Figures({required this.figures});

  @override
  Widget build(BuildContext context) {
    String total(int n) => t('মোট ${thousands(n)}', '${thousands(n)} in total');
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Stat(
              label: t('আজ খবর', 'News today'),
              value: t.n(figures.todayNews),
              note: total(figures.totalNews),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Stat(
              label: t('আজ ভিডিও', 'Videos today'),
              value: t.n(figures.todayVideo),
              note: total(figures.totalVideo),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Stat(
              label: t('আজ সংবাদমাধ্যম', 'Outlets today'),
              value: t.n(figures.todayOutlets),
              note: figures.outletCount > 0
                  ? t(
                      'তালিকায় ${t.n(figures.outletCount)}টি',
                      '${figures.outletCount} on the list',
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  const _Stat({required this.label, required this.value, this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecor.card(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.15,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 12,
                color: AppColors.muted,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "মাস অনুযায়ী সংবাদ ও ভিডিও": a card a month, two to a row. A tap shows the
/// month's stories in the list below; a second tap shows the newest again.
class _MonthSection extends StatelessWidget {
  final List<NewsMonth> months;
  final String today;

  /// The span the list shows, "2026-10-01~2026-10-17", if any.
  final String? selected;

  /// A month's span, or null to show the newest again.
  final ValueChanged<String?> onPick;

  const _MonthSection({
    required this.months,
    required this.today,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final most = math.max(1, months.map((m) => m.total).fold(0, math.max));
    final cards = [
      for (final m in months)
        _MonthCard(
          month: m,
          current: m.month == today.substring(0, 7),
          pct: math.max(3, (m.total / most * 100).round()),
          on: selected == monthSpan(m.month, today),
          onTap: () {
            final span = monthSpan(m.month, today);
            onPick(selected == span ? null : span);
          },
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t('মাস অনুযায়ী সংবাদ ও ভিডিও', 'News and videos by month'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          t(
            'ডিসেম্বর ২০২৫ থেকে, বর্তমান সংসদ সদস্যদের। মাসে চাপ দিলে সেই মাসের খবর।',
            "From December 2025, for the current members of parliament. Tap a month for that month's news.",
          ),
          style: const TextStyle(
            fontFamily: 'NotoSansBengali',
            fontSize: 13,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < cards.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: 10),
                Expanded(
                  child: i + 1 < cards.length
                      ? cards[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  final NewsMonth month;
  final bool current;
  final int pct;
  final bool on;
  final VoidCallback onTap;
  const _MonthCard({
    required this.month,
    required this.current,
    required this.pct,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = on ? Colors.white : AppColors.ink;
    final soft = on ? Colors.white.withValues(alpha: 0.88) : AppColors.muted;
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        color: on ? AppColors.brand : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          side: BorderSide(
            color: on || current ? AppColors.brand : AppColors.rule,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: monthLabel(month.month)),
                      if (current)
                        TextSpan(
                          text: ' ${t('· চলতি', '· current')}',
                          style: TextStyle(
                            color: on ? Colors.white : AppColors.brand,
                          ),
                        ),
                    ],
                  ),
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: soft,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  thousands(month.total),
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 6,
                    color: on
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppColors.ruleSoft,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: pct / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          color: on ? Colors.white : AppColors.brand,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t(
                    '${thousands(month.news)} সংবাদ · ${thousands(month.video)} ভিডিও',
                    '${thousands(month.news)} news · ${thousands(month.video)} ${month.video == 1 ? 'video' : 'videos'}',
                  ),
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 12.5,
                    color: on
                        ? Colors.white.withValues(alpha: 0.9)
                        : AppColors.inkSoft,
                    height: 1.35,
                  ),
                ),
                if (on) ...[
                  const SizedBox(height: 4),
                  Text(
                    t(
                      'দেখানো হচ্ছে · আবার চাপলে সব খবর',
                      'Showing · tap again for all news',
                    ),
                    style: const TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "সবচেয়ে বেশি খবরে": the eight members most in the newest stories; a tap
/// shows only their news.
class _MostInNews extends StatelessWidget {
  final List<({String slug, String name, int count})> members;
  final ValueChanged<String> onPick;
  const _MostInNews({required this.members, required this.onPick});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();
    final held = {
      for (final m in Api.instance.cached?.members ?? const <MemberBrief>[])
        m.slug: m,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('সবচেয়ে বেশি খবরে', 'Most in the news'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          for (final m in members.take(8))
            InkWell(
              onTap: () => onPick(m.slug),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    MemberAvatar(
                      member:
                          held[m.slug] ??
                          MemberBrief(id: m.slug, slug: m.slug, nameBn: m.name),
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t.count(m.count, 'টি খবর', 'story', 'stories'),
                      style: const TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            t(
              'নামে চাপ দিলে শুধু তাঁর খবর দেখাবে।',
              'Tap a name to see only their news.',
            ),
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 12.5,
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// "সংবাদ কীভাবে যুক্ত হয়", in the website's words.
class _HowNewsIsAdded extends StatelessWidget {
  /// How many outlets the site reads; the first point needs it.
  final int? outletCount;
  const _HowNewsIsAdded({required this.outletCount});

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(
      fontFamily: 'NotoSansBengali',
      fontSize: 14,
      color: AppColors.inkSoft,
      height: 1.55,
    );
    final n = outletCount;
    final points = <InlineSpan>[
      if (n != null && n > 0)
        TextSpan(
          text: t(
            'দেশি-বিদেশি ${t.n(n)}টি সংবাদমাধ্যমের তালিকা থেকে শিরোনাম নেওয়া হয়: যাদের ফিড বা নিউজ সাইটম্যাপ আছে সেখান থেকে সরাসরি, বাকিদের Google News-এর খোঁজ থেকে। ভিডিও আসে শুধু এই সংবাদমাধ্যমগুলোর নিজস্ব ইউটিউব চ্যানেল থেকে।',
            'Headlines are taken from a list of $n news outlets in Bangladesh and abroad: directly from those that have a feed or a news sitemap, and from Google News searches for the rest. Videos come only from these outlets’ own YouTube channels.',
          ),
        ),
      TextSpan(
        text: t(
          'একটি খবর সেই সংসদ সদস্যের পাতায় যায়, খবরটি যাঁকে নিয়ে: শিরোনামে তাঁর নাম বা শুধু তাঁরই পদ (প্রধানমন্ত্রী, স্পিকার…) থাকলে, অথবা প্রথম বাক্যে তিনিই মূল ব্যক্তি হলে। খবরে শুধু নাম উল্লেখ থাকলে যায় না।',
          'A story goes on the page of the member of parliament it is about: when the headline has their name or an office only they hold (Prime Minister, Speaker…), or when they are the main person in the first sentence. A story that only mentions their name does not.',
        ),
      ),
      TextSpan(
        children: [
          TextSpan(
            text: t(
              'মিল নিশ্চিত হলে শিরোনাম নিজে থেকে প্রকাশ হয়; সন্দেহ থাকলে একজন সম্পাদক দেখে অনুমোদন করার পরই আসে।',
              'When the match is certain, the headline is published automatically; when there is doubt, it appears only after an editor has looked at it and approved it.',
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          TextSpan(
            text:
                ' ${t('ভুল মিল চোখে পড়লে জানান, সম্পাদক তা সরিয়ে দেবেন।', 'If you spot a wrong match, let us know and an editor will remove it.')}',
          ),
        ],
      ),
      TextSpan(
        text: t(
          'শুধু শিরোনাম, সংবাদমাধ্যমের নাম, তারিখ ও মূল সংবাদের লিংক রাখা হয়। পুরো সংবাদ কপি করা হয় না।',
          "Only the headline, the outlet's name, the date and the link to the original story are kept. The full story is not copied.",
        ),
      ),
      // The machine translation is the English screens' alone.
      if (t.en)
        const TextSpan(
          text:
              'On these English screens, headlines are translated automatically from Bangla by Google Translate, so '
              'they may read awkwardly; a headline not yet translated is shown in Bangla. Open a story to read the original.',
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('সংবাদ কীভাবে যুক্ত হয়', 'How the news is added'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (var i = 0; i < points.length; i++) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.brandSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    t.n(i + 1),
                    style: const TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text.rich(points[i], style: body)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
