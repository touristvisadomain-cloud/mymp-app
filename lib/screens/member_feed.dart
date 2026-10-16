import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../bn.dart';
import '../data/news.dart';
import '../i18n.dart';
import '../loading.dart';
import '../theme.dart';
import '../widgets.dart';
import 'news_range_picker.dart';
import 'story_list.dart';

/// Items drawn at first, and added by each "আরও দেখুন".
const _step = 30;

/// A member's সংবাদ ও ভিডিও, as the website's member page has it
/// (src/components/MemberFeed.tsx): the totals; সব / সংবাদ / ভিডিও; the
/// outlets, when there are two or more; a day or a span of days; the items
/// the editors pinned ("নির্বাচিত"); this month's items 30 at a time; every
/// earlier month with its figures, opened on a tap.
///
/// It does not scroll on its own: the member page places it inside its own
/// scrolling view. Every item opens on the outlet's own site (a video on its
/// channel); the app links to the press and never embeds it.
class MemberFeed extends StatefulWidget {
  final String slug;
  const MemberFeed({super.key, required this.slug});

  @override
  State<MemberFeed> createState() => _MemberFeedState();
}

class _MemberFeedState extends State<MemberFeed>
    with RefetchOnLang<MemberFeed> {
  String _type = '';
  String _outlet = '';
  MemberFeedData? _data;
  bool _failed = false;

  DaySpan? _range;
  ({String key, List<FeedEntry> items, bool more})? _rangeData;
  String? _rangeFailed;

  String? _openMonth;
  final _months = <String, List<FeedEntry>>{};
  final _monthsFailed = <String>{};

  /// How many of a list are drawn, by the list: "current", "range", a month.
  final _shown = <String, int>{};

  /// Bumped on every reload, so an answer to an older question is dropped.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MemberFeed old) {
    super.didUpdateWidget(old);
    if (old.slug != widget.slug) _reset();
  }

  /// Outlets are named in the new language; a picked one would match nothing.
  @override
  void onLangChanged() => _reset();

  void _reset() {
    _outlet = '';
    _months.clear();
    _monthsFailed.clear();
    _rangeData = null;
    _load();
    if (_range != null) _loadRange(_range!);
  }

  void _load() {
    final gen = ++_generation;
    setState(() {
      _data = null;
      _failed = false;
      _shown.clear();
    });
    fetchMemberFeed(widget.slug, type: _type)
        .then((d) {
          if (mounted && gen == _generation) setState(() => _data = d);
        })
        .catchError((Object _) {
          if (mounted && gen == _generation) setState(() => _failed = true);
        });
    final open = _openMonth;
    if (open != null) _loadMonth(open);
  }

  String _monthKey(String month) => '$month/$_type';

  void _loadMonth(String month) {
    final key = _monthKey(month);
    if (_months.containsKey(key)) return;
    setState(() => _monthsFailed.remove(key));
    fetchMemberFeedMonth(widget.slug, month, type: _type)
        .then((items) {
          if (mounted) setState(() => _months[key] = items);
        })
        .catchError((Object _) {
          if (mounted) setState(() => _monthsFailed.add(key));
        });
  }

  String _rangeKey(DaySpan r) => '${spanKey(r)}/$_type';

  void _loadRange(DaySpan range) {
    final key = _rangeKey(range);
    setState(() => _rangeFailed = null);
    fetchMemberFeedRange(widget.slug, range.from, range.to, type: _type)
        .then((r) {
          if (!mounted || _range == null || _rangeKey(_range!) != key) return;
          setState(() => _rangeData = (key: key, items: r.items, more: r.more));
        })
        .catchError((Object _) {
          if (!mounted || _range == null || _rangeKey(_range!) != key) return;
          setState(() => _rangeFailed = key);
        });
  }

  void _setType(String type) {
    if (type == _type) return;
    _type = type;
    _rangeData = null;
    _load();
    if (_range != null) _loadRange(_range!);
  }

  void _setRange(DaySpan? range) {
    setState(() {
      _range = range;
      _shown.remove('range');
    });
    if (range != null) _loadRange(range);
  }

  List<FeedEntry> _byOutlet(List<FeedEntry> items) => _outlet.isEmpty
      ? items
      : items.where((i) => i.outletName == _outlet).toList();

  /// "২০৫টি: ১৯০ সংবাদ, ১৫ ভিডিও" ("205 items: 190 news, 15 videos"), or just
  /// the one kind when the other is nil.
  String _countLabel(int total, int news, int video) {
    if (t.en) {
      if (total == 0) return 'No news';
      final g = T.english.group;
      final parts = [
        if (news > 0) '${g(news)} news',
        if (video > 0) '${g(video)} ${plural(video, 'video', 'videos')}',
      ];
      return parts.length > 1
          ? '${g(total)} ${plural(total, 'item', 'items')}: ${parts.join(', ')}'
          : parts.first;
    }
    if (total == 0) return 'কোনো সংবাদ নেই';
    final parts = [
      if (news > 0) '${t.n(news)} সংবাদ',
      if (video > 0) '${t.n(video)} ভিডিও',
    ];
    return parts.length > 1
        ? '${t.n(total)}টি: ${parts.join(', ')}'
        : parts.first;
  }

  static const _muted = TextStyle(
    fontFamily: 'NotoSansBengali',
    fontSize: 13,
    color: AppColors.muted,
    height: 1.45,
  );

  /// A list drawn [_step] at a time, with "আরও দেখুন (Nটি বাকি)".
  Widget _paged(String key, List<FeedEntry> items) {
    final shown = _shown[key] ?? _step;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length && i < shown; i++) ...[
          if (i > 0) const Divider(height: 1),
          _FeedRow(item: items[i]),
        ],
        if (items.length > shown) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => setState(() => _shown[key] = shown + _step),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brand,
              side: const BorderSide(color: AppColors.rule),
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              t(
                'আরও দেখুন (${t.n(items.length - shown)}টি বাকি)',
                'See more (${items.length - shown} left)',
              ),
              style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(
              'সংবাদ ও ভিডিও এখন দেখানো যাচ্ছে না। একটু পরে আবার দেখুন।',
              'News and videos cannot be shown right now. Please check again a little later.',
            ),
            style: _muted.copyWith(fontSize: 14.5),
          ),
          TextButton(
            onPressed: _load,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brand,
              padding: EdgeInsets.zero,
            ),
            child: Text(
              t('আবার চেষ্টা করুন', 'Try again'),
              style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }
    final data = _data;
    if (data == null) {
      return Text(
        t('সংবাদ ও ভিডিও আনা হচ্ছে…', 'Loading news and videos…'),
        style: _muted.copyWith(fontSize: 14.5),
      );
    }

    final current = data.months.where((m) => m.month == data.month).firstOrNull;
    final earlier = data.months.where((m) => m.month != data.month).toList();
    final items = _byOutlet(data.items);
    final range = _range;
    final rangeData = range != null && _rangeData?.key == _rangeKey(range)
        ? _rangeData
        : null;
    final rangeItems = rangeData == null ? null : _byOutlet(rangeData.items);
    final g = T.english.group;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          t(
            'মোট ${t.n(data.total)}টি, ${t.n(data.news)}টি সংবাদ, ${t.n(data.video)}টি ভিডিও',
            '${g(data.total)} in total, ${g(data.news)} news, ${g(data.video)} ${plural(data.video, 'video', 'videos')}',
          ),
          style: _muted,
        ),
        const SizedBox(height: 12),
        ChipBar(
          padding: EdgeInsets.zero,
          options: [
            (label: t('সব', 'All'), value: ''),
            (label: t('সংবাদ', 'News'), value: 'news'),
            (label: t('ভিডিও', 'Videos'), value: 'video'),
          ],
          selected: _type,
          onSelect: (v) => _setType(v ?? ''),
        ),
        if (data.outlets.length > 1) ...[
          const SizedBox(height: 10),
          ChoiceField(
            title: t('সংবাদমাধ্যম', 'News outlet'),
            value: _outlet,
            fallback: _outlet.isEmpty ? null : _outlet,
            choices: [
              (value: '', label: t('সব সংবাদমাধ্যম', 'All outlets')),
              for (final o in data.outlets) (value: o, label: o),
            ],
            onChanged: (v) => setState(() {
              _outlet = v;
              _shown.clear();
            }),
          ),
        ],
        const SizedBox(height: 10),
        NewsRangePicker(
          key: ValueKey(range == null ? '' : spanKey(range)),
          range: range,
          today: dhakaToday(),
          onPick: _setRange,
        ),
        if (range != null) ...[
          const SizedBox(height: 14),
          _Box(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: spanLabel(range.from, range.to)),
                      if (rangeItems != null && rangeItems.isNotEmpty)
                        TextSpan(
                          text:
                              '   ${_countLabel(rangeItems.length, rangeItems.where((i) => !i.isVideo).length, rangeItems.where((i) => i.isVideo).length)}',
                          style: _muted.copyWith(fontWeight: FontWeight.w400),
                        ),
                    ],
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (rangeData != null && rangeData.more) ...[
                  const SizedBox(height: 4),
                  Text(
                    t(
                      'এই সময়ের সর্বশেষ ${t.n(rangeData.items.length)}টি দেখানো হচ্ছে; আরও আগেরগুলো দেখতে সময় ছোট করুন।',
                      'Showing the latest ${g(rangeData.items.length)} from this period; to see earlier ones, choose a shorter period.',
                    ),
                    style: _muted.copyWith(fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 4),
                if (_rangeFailed == _rangeKey(range))
                  _retry(
                    t(
                      'এই সময়ের সংবাদ আনা গেল না।',
                      'The news for this period could not be fetched.',
                    ),
                    () => _loadRange(range),
                  )
                else if (rangeItems == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(t('আনা হচ্ছে…', 'Loading…'), style: _muted),
                  )
                else if (rangeItems.isNotEmpty)
                  _paged('range', rangeItems)
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      t(
                        '${range.from == range.to ? 'এই দিনে' : 'এই সময়ে'} কোনো সংবাদ বা ভিডিও নেই${_outlet.isNotEmpty ? ' ($_outlet)' : ''}।',
                        'No news or videos ${range.from == range.to ? 'on this day' : 'in this period'}${_outlet.isNotEmpty ? ' ($_outlet)' : ''}.',
                      ),
                      style: _muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (data.pinned.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Box(
            strong: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < data.pinned.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _FeedRow(item: data.pinned[i]),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: monthLabel(data.month)),
              if (current != null)
                TextSpan(
                  text:
                      '   ${_countLabel(current.total, current.news, current.video)}',
                  style: _muted.copyWith(fontWeight: FontWeight.w400),
                ),
            ],
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        if (items.isNotEmpty)
          _paged('current', items)
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              data.total == 0
                  ? t(
                      'এখনো কোনো সংবাদ বা ভিডিও পাওয়া যায়নি। মনোনয়নপত্র জমার তারিখ থেকে খোঁজা হচ্ছে।',
                      'No news or videos have been found yet. The search runs from the date nomination papers were submitted.',
                    )
                  : t('এই মাসে কোনো সংবাদ নেই।', 'No news this month.'),
              style: _muted.copyWith(fontSize: 14),
            ),
          ),
        if (current != null &&
            current.total > items.length &&
            _outlet.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              t(
                'এই মাসে মোট ${t.n(current.total)}টি; বাছাই সরালে সবগুলো দেখা যাবে।',
                '${g(current.total)} in total this month; clear the filter to see them all.',
              ),
              style: _muted.copyWith(fontSize: 12.5),
            ),
          ),
        if (earlier.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          for (final m in earlier) ...[_monthRow(m), const Divider(height: 1)],
        ],
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: t(
                  'সংবাদ ও ভিডিও বিভিন্ন সংবাদমাধ্যম ও ইউটিউব থেকে স্বয়ংক্রিয়ভাবে সংগ্রহ করা। শিরোনামে ক্লিক করলে মূল উৎসে যাবেন। কোনো সংবাদ ভুলভাবে যুক্ত হলে ',
                  'News and videos are collected automatically from various news outlets and YouTube. Clicking a headline takes you to the original source. If a story has been added wrongly, ',
                ),
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: () => openLink(context, Api.page('/jogajog')),
                  child: Text(
                    t('জানান', 'let us know'),
                    style: _muted.copyWith(
                      fontSize: 12.5,
                      color: AppColors.inkSoft,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.rule,
                    ),
                  ),
                ),
              ),
              TextSpan(text: t('।', '.')),
            ],
          ),
          style: _muted.copyWith(fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _retry(String message, VoidCallback onRetry) => Row(
    children: [
      Expanded(child: Text(message, style: _muted)),
      TextButton(
        onPressed: onRetry,
        style: TextButton.styleFrom(foregroundColor: AppColors.brand),
        child: Text(
          t('আবার চেষ্টা করুন', 'Try again'),
          style: const TextStyle(
            fontFamily: 'NotoSansBengali',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  Widget _monthRow(FeedMonth m) {
    final open = _openMonth == m.month;
    final key = _monthKey(m.month);
    final list = _months[key];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          child: InkWell(
            onTap: () {
              setState(() => _openMonth = open ? null : m.month);
              if (!open) _loadMonth(m.month);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Text(
                    monthLabel(m.month),
                    style: const TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _countLabel(m.total, m.news, m.video),
                      textAlign: TextAlign.right,
                      style: _muted.copyWith(fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: open ? 0.25 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _monthsFailed.contains(key)
                ? _retry(
                    t(
                      'এই মাসের সংবাদ আনা গেল না।',
                      "This month's news could not be fetched.",
                    ),
                    () => _loadMonth(m.month),
                  )
                : list == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(t('আনা হচ্ছে…', 'Loading…'), style: _muted),
                  )
                : _byOutlet(list).isNotEmpty
                ? _paged('month/$key', _byOutlet(list))
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      t('কোনো সংবাদ নেই।', 'No news.'),
                      style: _muted,
                    ),
                  ),
          ),
      ],
    );
  }
}

/// A tinted box: the span's items, and the pinned ones.
class _Box extends StatelessWidget {
  final Widget child;
  final bool strong;
  const _Box({required this.child, this.strong = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.brandSoft.withValues(alpha: strong ? 0.6 : 0.35),
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: AppColors.brandRing),
      ),
      child: child,
    );
  }
}

/// One item: the outlet's picture, the headline, the outlet's summary when it
/// gave one, and a line with the kind, the outlet, when, the length, the other
/// outlets that ran it and "নির্বাচিত" for a pinned one.
class _FeedRow extends StatelessWidget {
  final FeedEntry item;
  const _FeedRow({required this.item});

  static const _meta = TextStyle(
    fontFamily: 'NotoSansBengali',
    fontSize: 12.5,
    color: AppColors.muted,
    height: 1.35,
  );

  @override
  Widget build(BuildContext context) {
    final when = t.whenParts(item.publishedAt);
    final length = durationBn(item.durationSeconds);
    final also = item.alsoIn.length;
    return InkWell(
      onTap: () => openLink(context, item.url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _thumb(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      height: 1.45,
                    ),
                  ),
                  if (item.summary case final summary?) ...[
                    const SizedBox(height: 3),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 13,
                        color: AppColors.inkSoft,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      KindBadge(item.type),
                      if (item.outletName case final outlet?)
                        Text(outlet, style: _meta),
                      // The date and time in pieces a narrow row may wrap
                      // between but never inside.
                      if (when.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          children: [
                            for (final p in when) Text(p, style: _meta),
                          ],
                        ),
                      if (length != null) Text(length, style: _meta),
                      if (also > 0)
                        Text(
                          t(
                            'আরও ${t.n(also)}টি সংবাদমাধ্যমে',
                            'in $also more ${plural(also, 'outlet', 'outlets')}',
                          ),
                          style: _meta,
                        ),
                      if (item.pinned)
                        Text(
                          t('নির্বাচিত', 'Selected'),
                          style: _meta.copyWith(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb() {
    final icon = Icon(
      item.isVideo ? Icons.play_arrow_rounded : Icons.description_outlined,
      size: 20,
      color: AppColors.muted,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 92,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.paper,
          border: Border.all(color: AppColors.ruleSoft),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The icon stays underneath, so a picture that will not load
            // leaves it showing.
            Center(child: icon),
            if (item.thumbnailUrl case final url?)
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            if (item.isVideo)
              Container(
                color: Colors.black.withValues(alpha: 0.18),
                alignment: Alignment.center,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 17,
                    color: AppColors.ink,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
