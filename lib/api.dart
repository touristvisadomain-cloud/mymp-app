import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n.dart';
import 'models.dart';

/// Everything the app knows comes from here, and it is all public: no account,
/// no key, nothing sent up. The only thing stored on the phone is a copy of
/// what was fetched, so the app opens with content on a train with no signal.
class Api {
  Api._() {
    appLang.addListener(_languageChanged);
  }
  static final Api instance = Api._();

  /// The site, overridable for testing against a local copy:
  ///   flutter run --dart-define=MYMP_BASE=http://localhost:3000
  static const base = String.fromEnvironment(
    'MYMP_BASE',
    defaultValue: 'https://mymp.bd',
  );

  /// A page of the website in the reader's language: "/mp/x" in Bangla,
  /// "/en/mp/x" in English. For "ওয়েবসাইটে দেখুন" and shared links.
  static String page(String path) {
    final p = t.href(path);
    return p == '/' ? base : '$base$p';
  }

  static const _userAgent = 'mymp-app/1.0 (Android; +https://mymp.bd)';

  // Everything held is tagged with the language it was fetched in, so nothing
  // depends on which listener hears of a switch first.
  Bootstrap? _bootstrap;
  Lang? _bootstrapLang;
  Bootstrap? get _held => _bootstrapLang == appLang.value ? _bootstrap : null;

  /// The member list as it stands, for screens that redraw when it changes:
  /// a quiet refresh, a pull, or a first fetch that succeeds after a failure.
  final bootstrap = ValueNotifier<Bootstrap?>(null);

  // Renamed when the list gains a field: a copy saved by an older version
  // lacks it and would stand until the site's data next changed. One copy
  // per language: the English list is the same JSON with English text.
  static String _bootstrapKey(Lang lang) =>
      lang == Lang.en ? 'bootstrap_v4_en' : 'bootstrap_v4';

  /// The list in hand: the current language's once it has arrived, the other
  /// language's until then.
  Bootstrap? get cached => _held ?? bootstrap.value;

  /// Keyed "bn/slug", "en/slug".
  final _memberCache = <String, MemberDetail>{};

  /// After a switch the list is fetched in the new language (from the phone
  /// when it was saved before); the screens refetch their own data.
  void _languageChanged() => loadBootstrap().ignore();

  /// Any read-only route of the site, in the reader's language
  /// (`lang=en` is added in English). For the screens' own data files
  /// (lib/data/*.dart), which parse what they need from it; see the site's
  /// docs/app-api.md for every route and its shape.
  Future<Map<String, dynamic>> getJson(String path, {Duration timeout = const Duration(seconds: 20)}) =>
      _getJson(path, timeout: timeout);

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    // Every route answers in English when asked; without `lang` it answers in
    // Bangla, as it always has.
    final url = t.en
        ? '$base$path${path.contains('?') ? '&' : '?'}lang=en'
        : '$base$path';
    final http.Response res;
    try {
      res = await http
          .get(
            Uri.parse(url),
            headers: const {
              'accept': 'application/json',
              'user-agent': _userAgent,
            },
          )
          .timeout(timeout);
    } on TimeoutException {
      throw ApiException(
        t(
          'সংযোগ খুব ধীর, সময়মতো উত্তর আসেনি। একটু পরে আবার চেষ্টা করুন।',
          'The connection is too slow; no answer came in time. Please try again in a little while.',
        ),
      );
    } catch (_) {
      // No signal, no data plan, or the site unreachable: the reader cannot
      // act on a socket error's text, only on what it means.
      throw ApiException(
        t(
          'ইন্টারনেট সংযোগ পাওয়া যাচ্ছে না। সংযোগ দেখে আবার চেষ্টা করুন।',
          'There is no internet connection. Check your connection and try again.',
        ),
      );
    }
    if (res.statusCode == 404) {
      throw ApiException(
        t(
          'এই তথ্যটি এখন আর পাওয়া যাচ্ছে না।',
          'This information is no longer available.',
        ),
      );
    }
    if (res.statusCode != 200) {
      throw ApiException(
        t(
          'সার্ভার এই মুহূর্তে সাড়া দিচ্ছে না। একটু পরে আবার চেষ্টা করুন।',
          'The server is not responding right now. Please try again in a little while.',
        ),
      );
    }
    try {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        t(
          'তথ্য পড়া গেল না। একটু পরে আবার চেষ্টা করুন।',
          'The information could not be read. Please try again in a little while.',
        ),
      );
    }
  }

  /// The member list, from the phone first and the network second.
  ///
  /// The stored copy is shown immediately even when it is old, and replaced
  /// quietly once the fetch returns; a slow connection then costs the reader
  /// nothing. [force] skips the stored copy, for pull-to-refresh.
  Future<Bootstrap> loadBootstrap({bool force = false}) {
    final held = _held;
    if (held != null && !force) return Future.value(held);
    // Several tabs ask at launch; they share the one request.
    if (!force && _loading != null && _loadingLang == appLang.value) {
      return _loading!;
    }
    final loading = _loadBootstrap(force);
    if (!force) {
      _loading = loading;
      _loadingLang = appLang.value;
      loading.whenComplete(() {
        if (identical(_loading, loading)) _loading = null;
      }).ignore();
    }
    return loading;
  }

  Future<Bootstrap>? _loading;
  Lang? _loadingLang;

  Future<Bootstrap> _loadBootstrap(bool force) async {
    // The language this load is for. A reader who switches while it is in
    // flight gets the new language's load; this one must not overwrite it.
    final lang = appLang.value;
    final key = _bootstrapKey(lang);
    final prefs = await SharedPreferences.getInstance();
    // Copies saved under older keys are never read again.
    for (final old in const ['bootstrap', 'bootstrap_v2', 'bootstrap_v3']) {
      if (prefs.containsKey(old)) unawaited(prefs.remove(old));
    }
    if (!force) {
      final saved = prefs.getString(key);
      if (saved != null) {
        try {
          final stored = Bootstrap.fromJson(
            jsonDecode(saved) as Map<String, dynamic>,
          );
          if (lang == appLang.value) {
            _bootstrap = stored;
            _bootstrapLang = lang;
            bootstrap.value = stored;
            unawaited(_refreshBootstrap(prefs, lang));
          }
          return stored;
        } catch (_) {
          await prefs.remove(key);
        }
      }
    }

    final json = await _getJson('/api/app/v1/bootstrap');
    await prefs.setString(key, jsonEncode(json));
    final fresh = Bootstrap.fromJson(json);
    if (lang == appLang.value) {
      _bootstrap = fresh;
      _bootstrapLang = lang;
      bootstrap.value = fresh;
    }
    return fresh;
  }

  /// Fetched behind a shown-from-storage list; a failure here changes nothing.
  Future<void> _refreshBootstrap(SharedPreferences prefs, Lang lang) async {
    try {
      final json = await _getJson('/api/app/v1/bootstrap');
      final fresh = Bootstrap.fromJson(json);
      if (lang != appLang.value) return;
      if (fresh.version != _held?.version && fresh.members.isNotEmpty) {
        await prefs.setString(_bootstrapKey(lang), jsonEncode(json));
        _bootstrap = fresh;
        _bootstrapLang = lang;
        bootstrap.value = fresh;
      }
    } catch (_) {
      // Offline, or the site is being deployed. The stored copy stands.
    }
  }

  /// [force] skips the copy held for this session, for pull-to-refresh.
  Future<MemberDetail> member(String slug, {bool force = false}) async {
    final key = '${appLang.value.name}/$slug';
    final held = _memberCache[key];
    if (held != null && !force) return held;
    final json = await _getJson('/api/app/v1/mp/$slug');
    final detail = MemberDetail.fromJson(json);
    _memberCache[key] = detail;
    return detail;
  }

  Future<AdviserDetail> adviser(String slug) async {
    final json = await _getJson('/api/app/v1/adviser/$slug');
    return AdviserDetail.fromJson(json);
  }

  Future<List<CabinetPost>> cabinet() async {
    final json = await _getJson('/api/app/v1/cabinet');
    return (json['posts'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(CabinetPost.fromJson)
        .toList();
  }

  final _election = <Lang, Map<String, dynamic>>{};

  /// The election and the House it produced; kept for the session once read.
  Future<Map<String, dynamic>> election({bool force = false}) async {
    final lang = appLang.value;
    final held = _election[lang];
    if (held != null && !force) return held;
    final json = await _getJson('/api/app/v1/election');
    _election[lang] = json;
    return json;
  }

  Future<List<Story>> news({String? type, int limit = 200}) async {
    final query = StringBuffer('?limit=$limit');
    if (type != null) query.write('&type=$type');
    final json = await _getJson('/api/app/v1/news$query');
    return (json['stories'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Story.fromJson)
        .toList();
  }

  /// One member's own news and videos, from the same route the website's
  /// profile page reads.
  Future<List<Story>> memberFeed(String slug) async {
    // The newest 60 whatever their month: the plain route sends only this
    // month, and a member whose news was all from February showed nothing.
    final json = await _getJson('/api/feed/$slug?recent=60');
    final items = <Story>[];
    for (final key in const ['pinned', 'items']) {
      for (final raw
          in (json[key] as List? ?? []).whereType<Map<String, dynamic>>()) {
        items.add(feedEntryToStory(raw));
      }
    }
    return items;
  }

  /// The member feed answers in the website's own shape; this is the one place
  /// that knows the difference.
  static Story feedEntryToStory(Map<String, dynamic> j) {
    final published = j['publishedAt'] as String? ?? '';
    return Story(
      id: 'feed-${j['id']}',
      date: dhakaDate(published),
      publishedAt: published.isEmpty ? null : published,
      dateLabel: '',
      lead: StoryLink(
        title: j['title'] as String? ?? '',
        source: j['outletName'] as String? ?? '',
        url: j['url'] as String? ?? '',
      ),
      kind: j['type'] as String? ?? 'news',
      thumbnail: j['thumbnailUrl'] as String?,
      durationSeconds: (j['durationSeconds'] as num?)?.toInt(),
    );
  }
}

/// The calendar day in Bangladesh of an instant the feed gives in UTC: a story
/// published at 05:00 in Dhaka is 23:00 the day before in UTC, and read as
/// "গতকাল" it was a day out.
String dhakaDate(String iso) {
  final at = DateTime.tryParse(iso);
  if (at == null) return iso.length >= 10 ? iso.substring(0, 10) : iso;
  final d = at.toUtc().add(const Duration(hours: 6));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
