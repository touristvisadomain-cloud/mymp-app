import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../bn.dart';
import '../data/cabinet.dart';
import '../i18n.dart';
import '../loading.dart';
import '../theme.dart';
import 'cabinet_screen.dart';

/// A cabinet member from outside Parliament, an adviser to the Prime Minister
/// or a technocrat minister, as the website's page for them
/// (`/ministers/<slug>`) shows it: who they are, the profile and where it was
/// written from, the facts, and what they are responsible for.
class AdviserScreen extends StatefulWidget {
  final String slug;

  /// The name as the opening screen had it, shown until the profile arrives.
  final String nameBn;
  final String? photoUrl;

  /// Opened from the cabinet: "পুরো মন্ত্রিসভা" goes back to it rather than
  /// opening it again.
  final bool fromCabinet;
  const AdviserScreen({
    super.key,
    required this.slug,
    this.nameBn = '',
    this.photoUrl,
    this.fromCabinet = false,
  });

  @override
  State<AdviserScreen> createState() => _AdviserScreenState();
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

class _AdviserScreenState extends State<AdviserScreen>
    with RefetchOnLang<AdviserScreen> {
  late Future<AdviserProfile> _future = fetchAdviser(widget.slug);

  @override
  void onLangChanged() => _reload();

  void _reload() => setState(() {
    _future = fetchAdviser(widget.slug);
  });

  Future<void> _refresh() async {
    _reload();
    await settle(_future);
  }

  /// The page on the website in Bangla, which an English reader is pointed
  /// to for what is not translated yet.
  String get _bnPage => '${Api.base}/ministers/${widget.slug}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<AdviserProfile>(
          future: _future,
          builder: (context, snap) => Text(
            snap.data?.roleBn ?? t('মন্ত্রিসভা', 'Cabinet'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          IconButton(
            tooltip: t('শেয়ার', 'Share'),
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              // The name in the reader's language once the page has it.
              var name = widget.nameBn;
              try {
                final a = await _future;
                name = a.nameBn ?? a.roleBn;
              } catch (_) {}
              await SharePlus.instance.share(
                ShareParams(
                  text: '$name\n${Api.page('/ministers/${widget.slug}')}',
                  subject: name,
                ),
              );
            },
          ),
        ],
      ),
      body: Loaded<AdviserProfile>(
        future: _future,
        onRetry: _reload,
        builder: (context, a) => RefreshIndicator(
          color: AppColors.brand,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSizes.pagePad,
              8,
              AppSizes.pagePad,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _header(context, a),
              const SizedBox(height: 22),
              _profile(context, a),
              if (_facts(a) case final facts when facts.isNotEmpty) ...[
                const SizedBox(height: 14),
                _FactsRows(facts: facts),
              ],
              const SizedBox(height: 14),
              _posts(context, a),
            ],
          ),
        ),
      ),
    );
  }

  String? _name(AdviserProfile a) =>
      a.nameBn ?? (widget.nameBn.isEmpty ? null : widget.nameBn);

  Widget _header(BuildContext context, AdviserProfile a) {
    final photo = a.photoUrl ?? widget.photoUrl;
    final name = _name(a);
    final initial = initialOf(name ?? '');
    final fallback = Container(
      color: AppColors.brandSoft,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: _st(34, weight: FontWeight.w700, colour: AppColors.brand),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: SizedBox(
            width: 96,
            height: 96,
            child: photo == null
                ? fallback
                : CachedNetworkImage(
                    imageUrl: photo,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: AppColors.sunk),
                    errorWidget: (_, _, _) => fallback,
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          a.roleBn,
          style: _st(
            12.5,
            weight: FontWeight.w700,
            colour: AppColors.brand,
          ).copyWith(letterSpacing: t.en ? 1.2 : 0.4),
        ),
        const SizedBox(height: 4),
        Text(
          name ?? t('নাম জানা নেই', 'Name given only in Bangla'),
          style: _st(26, weight: FontWeight.w700, height: 1.3),
        ),
        const SizedBox(height: 6),
        Text(
          t.en
              ? (a.rankBn != null ? '${a.rankBn} · Not an MP' : 'Not an MP')
              : '${a.rankBn ?? 'উপদেষ্টা'} · সংসদ সদস্য নন',
          style: _st(14.5, colour: AppColors.inkSoft),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: AppDecor.card(),
    child: child,
  );

  Widget _profile(BuildContext context, AdviserProfile a) {
    final paragraphs = (a.bioBn ?? '')
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final link = _st(
      12.5,
      weight: FontWeight.w600,
      colour: AppColors.brand,
    ).copyWith(decoration: TextDecoration.underline);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('পরিচিতি', 'Profile'),
            style: _st(19, weight: FontWeight.w700, height: 1.3),
          ),
          const SizedBox(height: 10),
          for (final (i, p) in paragraphs.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            Text(p, style: _st(15, height: 1.8)),
          ],
          if (t.en && a.bioBn != null && a.bioTranslated) ...[
            const SizedBox(height: 10),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Translated from Bangla. ',
                  style: _st(12.5, colour: AppColors.muted),
                ),
                InkWell(
                  onTap: () => openLink(context, _bnPage),
                  child: Text(
                    'Read the original',
                    style: link.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (t.en && a.bioBn == null)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'This profile is written in Bangla and has not been translated yet. ',
                  style: _st(15, colour: AppColors.inkSoft, height: 1.8),
                ),
                InkWell(
                  onTap: () => openLink(context, _bnPage),
                  child: Text(
                    'Read it in Bangla',
                    style: link.copyWith(fontSize: 15, height: 1.8),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.ruleSoft),
          const SizedBox(height: 10),
          _SourcesLine(profile: a),
        ],
      ),
    );
  }

  /// The facts in the reader's language; a fact with no English yet is left
  /// out on English.
  List<({String label, String value})> _facts(AdviserProfile a) => [
    if (a.rankBn != null) (label: t('পদমর্যাদা', 'Rank'), value: a.rankBn!),
    if (a.partyRoleBn != null)
      (label: t('দলীয় পদ', 'Party post'), value: a.partyRoleBn!),
    if (a.professionBn != null)
      (label: t('পেশা', 'Profession'), value: a.professionBn!),
    if (a.educationBn != null)
      (label: t('শিক্ষা', 'Education'), value: a.educationBn!),
    if (a.birthPlaceBn != null)
      (label: t('জন্মস্থান', 'Birthplace'), value: a.birthPlaceBn!),
  ];

  Widget _posts(BuildContext context, AdviserProfile a) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('দায়িত্ব', 'Responsibilities'),
            style: _st(18, weight: FontWeight.w700, height: 1.3),
          ),
          const SizedBox(height: 10),
          if (a.posts.isEmpty)
            Text(
              t(
                'মন্ত্রিপরিষদ বিভাগের তালিকায় এখন কোনো দায়িত্ব নেই।',
                'The Cabinet Division’s list gives no responsibility at present.',
              ),
              style: _st(14, colour: AppColors.muted),
            )
          else
            for (final (i, p) in a.posts.indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              Text(
                p.ministryBn ?? p.title ?? a.roleBn,
                style: _st(14.5, weight: FontWeight.w600, height: 1.4),
              ),
              if (t.date(p.fromDate) case final from?)
                Text(
                  t('$from থেকে', 'Since $from'),
                  style: _st(12.5, colour: AppColors.muted, height: 1.4),
                ),
            ],
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              if (widget.fromCabinet) {
                Navigator.of(context).maybePop();
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CabinetScreen()),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t('পুরো মন্ত্রিসভা', 'The whole Cabinet'),
                    style: _st(
                      14,
                      weight: FontWeight.w600,
                      colour: AppColors.brand,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.brand,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label-and-value rows, as the website lists an adviser's facts: no
/// heading, one fact to a row, education one place to a line.
class _FactsRows extends StatelessWidget {
  final List<({String label, String value})> facts;
  const _FactsRows({required this.facts});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: AppDecor.card(),
      child: Column(
        children: [
          for (final (i, f) in facts.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.ruleSoft),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      f.label,
                      style: _st(14, colour: AppColors.muted),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f.value.split(RegExp(r';\s*')).join('\n'),
                      style: _st(14.5, weight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "সূত্র: …; দায়িত্বের তালিকা মন্ত্রিপরিষদ বিভাগের। … পর্যন্ত মিলিয়ে দেখা।
/// ভুল দেখলে জানান।", each source and "জানান" a link, as the website writes it.
class _SourcesLine extends StatefulWidget {
  final AdviserProfile profile;
  const _SourcesLine({required this.profile});

  @override
  State<_SourcesLine> createState() => _SourcesLineState();
}

class _SourcesLineState extends State<_SourcesLine> {
  final _taps = <TapGestureRecognizer>[];

  TapGestureRecognizer _tap(String url) {
    final r = TapGestureRecognizer()..onTap = () => openLink(context, url);
    _taps.add(r);
    return r;
  }

  void _clearTaps() {
    for (final r in _taps) {
      r.dispose();
    }
    _taps.clear();
  }

  @override
  void dispose() {
    _clearTaps();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clearTaps();
    final a = widget.profile;
    final base = _st(12.5, colour: AppColors.muted, height: 1.6);
    final link = base.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: AppColors.muted,
    );
    final checked = t.date(a.checkedOn);
    final sources = <InlineSpan>[
      for (final (i, s) in a.sources.indexed) ...[
        if (i > 0) const TextSpan(text: ', '),
        TextSpan(text: s.label, style: link, recognizer: _tap(s.url)),
      ],
    ];
    final contact = Api.page('/jogajog');
    final spans = t.en
        ? <InlineSpan>[
            if (sources.isNotEmpty) ...[
              const TextSpan(text: 'Sources: '),
              ...sources,
              const TextSpan(
                text:
                    '; the list of responsibilities is the Cabinet Division’s.',
              ),
            ] else
              const TextSpan(
                text: 'The list of responsibilities is the Cabinet Division’s.',
              ),
            if (checked != null) TextSpan(text: ' Checked up to $checked.'),
            const TextSpan(text: ' If you see a mistake, '),
            TextSpan(
              text: 'let us know',
              style: link,
              recognizer: _tap(contact),
            ),
            const TextSpan(text: '.'),
          ]
        : <InlineSpan>[
            if (sources.isNotEmpty) ...[
              const TextSpan(text: 'সূত্র: '),
              ...sources,
              const TextSpan(text: '; '),
            ],
            const TextSpan(text: 'দায়িত্বের তালিকা মন্ত্রিপরিষদ বিভাগের।'),
            if (checked != null)
              TextSpan(text: ' $checked পর্যন্ত মিলিয়ে দেখা।'),
            const TextSpan(text: ' ভুল দেখলে '),
            TextSpan(text: 'জানান', style: link, recognizer: _tap(contact)),
            const TextSpan(text: '।'),
          ];
    return Text.rich(TextSpan(children: spans), style: base);
  }
}
