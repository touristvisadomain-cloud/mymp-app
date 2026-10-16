/// The news area's data: the whole-site list and its figures
/// (/api/app/v1/news, /news/counts), a span of days a page at a time, and one
/// member's own feed (/api/feed/{slug}, the website's route). Everything is
/// parsed defensively, like lib/models.dart: a field the site adds later
/// must never crash a phone that has not been updated.
///
/// Also the calendar arithmetic the span picker and the month cards share,
/// done on the Bangladesh calendar (UTC+6 all year).
library;

import '../api.dart';
import '../i18n.dart';
import '../models.dart';

int _int(dynamic v) => v is num ? v.toInt() : 0;
String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;
List<Map<String, dynamic>> _maps(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

/// The first day the news is counted from: the window the site reads opens
/// on 1 December 2025 (src/lib/feed/window.ts).
const feedFrom = '2025-12-01';

// ---------------------------------------------------------------------------
// The whole-site figures.

/// One month on the news page: its headlines and videos.
class NewsMonth {
  /// "2026-09"
  final String month;
  final int news;
  final int video;
  const NewsMonth({
    required this.month,
    required this.news,
    required this.video,
  });

  int get total => news + video;

  factory NewsMonth.fromJson(Map<String, dynamic> j) => NewsMonth(
    month: j['month'] as String? ?? '',
    news: _int(j['news']),
    video: _int(j['video']),
  );
}

/// The news page's figures (/news/counts).
class NewsCounts {
  final int todayNews;
  final int todayVideo;
  final int todayOutlets;
  final int totalNews;
  final int totalVideo;

  /// Newest first.
  final List<NewsMonth> months;

  /// How many outlets are on the list the site reads.
  final int outletCount;
  final bool unavailable;

  const NewsCounts({
    this.todayNews = 0,
    this.todayVideo = 0,
    this.todayOutlets = 0,
    this.totalNews = 0,
    this.totalVideo = 0,
    this.months = const [],
    this.outletCount = 0,
    this.unavailable = false,
  });

  factory NewsCounts.fromJson(Map<String, dynamic> j) {
    final today = j['today'] is Map<String, dynamic>
        ? j['today'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final total = j['total'] is Map<String, dynamic>
        ? j['total'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return NewsCounts(
      todayNews: _int(today['news']),
      todayVideo: _int(today['video']),
      todayOutlets: _int(today['outlets']),
      totalNews: _int(total['news']),
      totalVideo: _int(total['video']),
      months: _maps(j['months'])
          .map(NewsMonth.fromJson)
          .where((m) => RegExp(r'^\d{4}-\d{2}$').hasMatch(m.month))
          .toList(),
      outletCount: _int(j['outletCount']),
      unavailable: j['unavailable'] == true,
    );
  }
}

Future<NewsCounts> fetchNewsCounts() async =>
    NewsCounts.fromJson(await Api.instance.getJson('/api/app/v1/news/counts'));

// ---------------------------------------------------------------------------
// The whole-site list.

List<Story> _stories(dynamic v) => _maps(v).map(Story.fromJson).toList();

/// The newest stories and videos together, as the website's news page reads
/// them (it hands its browser the newest 400).
Future<List<Story>> fetchLatestNews({int limit = 400}) async {
  final json = await Api.instance.getJson('/api/app/v1/news?limit=$limit');
  return _stories(json['stories']);
}

/// One page of a span's stories.
class NewsRangePage {
  final List<Story> stories;

  /// Pass as `before` for the next page; null on the last.
  final String? next;

  /// The span's totals; on the first page only.
  final ({int news, int video})? counts;
  const NewsRangePage({required this.stories, this.next, this.counts});

  factory NewsRangePage.fromJson(Map<String, dynamic> j) {
    final c = j['counts'];
    return NewsRangePage(
      stories: _stories(j['stories']),
      next: _str(j['next']),
      counts: c is Map<String, dynamic>
          ? (news: _int(c['news']), video: _int(c['video']))
          : null,
    );
  }
}

/// A span of days, both ends included, 300 stories a page, newest first.
Future<NewsRangePage> fetchNewsRange(
  String from,
  String to, {
  String? before,
}) async {
  final b = before == null ? '' : '&before=${Uri.encodeQueryComponent(before)}';
  return NewsRangePage.fromJson(
    await Api.instance.getJson('/api/app/v1/news?from=$from&to=$to$b'),
  );
}

// ---------------------------------------------------------------------------
// A member's own feed.

/// One item in a member's feed, in the website's own shape.
class FeedEntry {
  final int id;

  /// "news", "video", "press" or "social".
  final String type;
  final String title;
  final String url;
  final String? summary;

  /// Null on English when the site has no English name for the outlet.
  final String? outletName;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final String publishedAt;

  /// The same story in other outlets.
  final List<({String? outletName, String url})> alsoIn;
  final bool pinned;

  const FeedEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.url,
    this.summary,
    this.outletName,
    this.thumbnailUrl,
    this.durationSeconds,
    required this.publishedAt,
    this.alsoIn = const [],
    this.pinned = false,
  });

  bool get isVideo => type == 'video';

  factory FeedEntry.fromJson(Map<String, dynamic> j) => FeedEntry(
    id: _int(j['id']),
    type: j['type'] as String? ?? 'news',
    title: j['title'] as String? ?? '',
    url: j['url'] as String? ?? '',
    summary: j['summary'] is String
        ? _str((j['summary'] as String).trim())
        : null,
    outletName: _str(j['outletName']),
    thumbnailUrl: _str(j['thumbnailUrl']),
    durationSeconds: j['durationSeconds'] is num
        ? (j['durationSeconds'] as num).toInt()
        : null,
    publishedAt: j['publishedAt'] as String? ?? '',
    alsoIn: [
      for (final a in _maps(j['alsoIn']))
        (outletName: _str(a['outletName']), url: a['url'] as String? ?? ''),
    ],
    pinned: j['pinned'] == true,
  );
}

List<FeedEntry> _entries(dynamic v) =>
    _maps(v).map(FeedEntry.fromJson).toList();

/// A month's figures in a member's feed.
class FeedMonth {
  final String month;
  final int total;
  final int news;
  final int video;
  const FeedMonth({
    required this.month,
    required this.total,
    required this.news,
    required this.video,
  });

  factory FeedMonth.fromJson(Map<String, dynamic> j) => FeedMonth(
    month: j['month'] as String? ?? '',
    total: _int(j['total']),
    news: _int(j['news']),
    video: _int(j['video']),
  );
}

/// A member's feed as it first arrives: the current month, the pinned items,
/// every month's figures, the totals and the outlets that carried them.
class MemberFeedData {
  final String month;
  final List<FeedEntry> pinned;
  final List<FeedEntry> items;
  final List<FeedMonth> months;
  final int total;
  final int news;
  final int video;
  final List<String> outlets;
  final String? startsAt;
  final bool unavailable;

  const MemberFeedData({
    required this.month,
    this.pinned = const [],
    this.items = const [],
    this.months = const [],
    this.total = 0,
    this.news = 0,
    this.video = 0,
    this.outlets = const [],
    this.startsAt,
    this.unavailable = false,
  });

  factory MemberFeedData.fromJson(Map<String, dynamic> j) => MemberFeedData(
    month: j['month'] as String? ?? dhakaToday().substring(0, 7),
    pinned: _entries(j['pinned']),
    items: _entries(j['items']),
    months: _maps(j['months']).map(FeedMonth.fromJson).toList(),
    total: _int(j['total']),
    news: _int(j['news']),
    video: _int(j['video']),
    // An outlet with no English name comes as null on English; it cannot be
    // offered as a choice without showing the Bangla.
    outlets: j['outlets'] is List
        ? (j['outlets'] as List).whereType<String>().toList()
        : const [],
    startsAt: _str(j['startsAt']),
    unavailable: j['unavailable'] == true,
  );
}

String _typeParam(String? type) =>
    type == 'news' || type == 'video' ? '&type=$type' : '';

Future<MemberFeedData> fetchMemberFeed(String slug, {String? type}) async =>
    MemberFeedData.fromJson(
      await Api.instance.getJson('/api/feed/$slug?x=1${_typeParam(type)}'),
    );

Future<List<FeedEntry>> fetchMemberFeedMonth(
  String slug,
  String month, {
  String? type,
}) async {
  final json = await Api.instance.getJson(
    '/api/feed/$slug?m=$month${_typeParam(type)}',
  );
  return _entries(json['items']);
}

/// A span of days; `more` when the site stopped at its limit.
Future<({List<FeedEntry> items, bool more})> fetchMemberFeedRange(
  String slug,
  String from,
  String to, {
  String? type,
}) async {
  final json = await Api.instance.getJson(
    '/api/feed/$slug?from=$from&to=$to${_typeParam(type)}',
  );
  return (items: _entries(json['items']), more: json['more'] == true);
}

// ---------------------------------------------------------------------------
// Days and spans, on the Bangladesh calendar.

String _two(int n) => n.toString().padLeft(2, '0');
String _day(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// Today in Dhaka, "2026-10-17".
String dhakaToday({DateTime? now}) =>
    _day((now ?? DateTime.now()).toUtc().add(const Duration(hours: 6)));

/// The day [n] days after (or before) a "yyyy-mm-dd" day.
String addDays(String day, int n) {
  final p = day.split('-').map(int.parse).toList();
  return _day(DateTime.utc(p[0], p[1], p[2] + n));
}

/// The number of days in a month.
int daysIn(int y, int m) => DateTime.utc(y, m + 1, 0).day;

/// A month's first and last day, the last being today in the current month:
/// "2026-10-01~2026-10-17".
String monthSpan(String month, String today) {
  final y = int.parse(month.substring(0, 4));
  final m = int.parse(month.substring(5, 7));
  final last = '$month-${_two(daysIn(y, m))}';
  return '$month-01~${last.compareTo(today) < 0 ? last : today}';
}

/// A day or a span, earlier end first.
typedef DaySpan = ({String from, String to});

/// "2026-10-15" or "2026-10-10~2026-10-15" as a span, earlier end first.
DaySpan? parseSpan(String raw) {
  final parts = raw.split('~');
  final a = parts.first;
  final b = parts.length > 1 ? parts[1] : a;
  final ok = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  if (!ok.hasMatch(a) || !ok.hasMatch(b)) return null;
  return a.compareTo(b) <= 0 ? (from: a, to: b) : (from: b, to: a);
}

String spanKey(DaySpan s) => s.from == s.to ? s.from : '${s.from}~${s.to}';

/// "বুধবার, ১৫ অক্টোবর ২০২৬" / "Wednesday, 15 October 2026".
String dayLabel(String day) {
  final p = day.split('-').map(int.parse).toList();
  final d = DateTime.utc(p[0], p[1], p[2]);
  return t.en
      ? '${t.weekday(d.weekday)}, ${p[2]} ${t.month(p[1])} ${p[0]}'
      : '${t.weekday(d.weekday)}, ${t.n(p[2])} ${t.month(p[1])} ${t.n(p[0])}';
}

String _shortDay(String day, bool withYear) {
  final p = day.split('-').map(int.parse).toList();
  return '${t.n(p[2])} ${t.month(p[1])}${withYear ? ' ${t.n(p[0])}' : ''}';
}

/// "বুধবার, ১৫ অক্টোবর ২০২৬" for one day, "১০ অক্টোবর থেকে ১৫ অক্টোবর ২০২৬"
/// for a span; "10 October to 15 October 2026" in English.
String spanLabel(String from, String to) {
  if (from == to) return dayLabel(from);
  final a = _shortDay(from, from.substring(0, 4) != to.substring(0, 4));
  final b = _shortDay(to, true);
  return t('$a থেকে $b', '$a to $b');
}

/// "সেপ্টেম্বর ২০২৬" / "September 2026" for "2026-09".
String monthLabel(String month) {
  final y = int.tryParse(month.length >= 4 ? month.substring(0, 4) : '') ?? 0;
  final m = int.tryParse(month.length >= 7 ? month.substring(5, 7) : '') ?? 1;
  return '${t.month(m)} ${t.n(y)}';
}

/// A large figure as the newspapers print it, with a thousands comma:
/// "১৫,৯৩৪" / "15,934" (the news page's figures; not lakh grouping).
String thousands(int n) => t.n(
  n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ','),
);

// ---------------------------------------------------------------------------
// Searching the headlines.

final _joiners = RegExp('[​-‍﻿্]');
final _nonWord = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);

/// Headline text for matching, as the website folds it: whole words, vowel
/// signs kept, joiners and the hasanta dropped (outlets write
/// "বাক্‌স্বাধীনতা" and "বাকস্বাধীনতা" alike).
String foldHeadline(String s) =>
    s.replaceAll(_joiners, '').toLowerCase().replaceAll(_nonWord, ' ').trim();

/// Everything a story can be found by: its headlines and the members it names.
String storySearchKey(Story s) => foldHeadline(
  [
    s.lead.title,
    ...s.also.map((a) => a.title),
    ...s.members.map((m) => m.name),
  ].join(' '),
);

/// True when every word of [query] is in the story's [key].
bool matchesQuery(String key, String query) {
  final words = foldHeadline(query).split(' ').where((w) => w.isNotEmpty);
  return words.every(key.contains);
}
