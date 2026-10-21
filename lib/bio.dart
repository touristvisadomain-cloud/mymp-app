import 'package:flutter/material.dart';

import 'i18n.dart';
import 'loading.dart';
import 'theme.dart';

/// "উইকিপিডিয়া (বাংলা)" for a cited address, the way the website names it.
String sourceLabel(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
  final wiki = RegExp(r'^(\w+)\.wikipedia\.org$').firstMatch(host);
  if (wiki != null) {
    final lang = wiki.group(1);
    final which = lang == 'bn'
        ? t('বাংলা', 'Bangla')
        : lang == 'en'
        ? t('ইংরেজি', 'English')
        : lang;
    return '${t('উইকিপিডিয়া', 'Wikipedia')} ($which)';
  }
  if (host.endsWith('parliament.gov.bd')) return t('জাতীয় সংসদ', 'Parliament');
  if (host.endsWith('cabinet.gov.bd')) {
    return t('মন্ত্রিপরিষদ বিভাগ', 'Cabinet Division');
  }
  return host;
}

/// A written biography: its paragraphs, then where it was written from. A
/// reader can open each source, which is the point of naming them. In English
/// the text is the site's translation of the Bangla, and says so, as the
/// website does.
class BioCard extends StatelessWidget {
  final String text;
  final List<String> sources;

  /// "পরিচিতি" / "Profile" when not given.
  final String? title;

  /// False leaves the title out, for a card under a section heading.
  final bool showTitle;

  /// Whether the text is a translation from Bangla; by default every English
  /// text is taken to be one.
  final bool? translated;

  /// The Bangla original on the website, linked as "Read the original" under
  /// a translation.
  final String? originalUrl;

  /// The sources' names as the site gives them, by address.
  final Map<String, String> sourceNames;

  /// Adds "ভুল দেখলে জানান।" after the sources, as the member page does.
  final bool askForCorrections;

  const BioCard({
    super.key,
    required this.text,
    this.sources = const [],
    this.title,
    this.showTitle = true,
    this.translated,
    this.originalUrl,
    this.sourceNames = const {},
    this.askForCorrections = false,
  });

  @override
  Widget build(BuildContext context) {
    final paragraphs = text
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: AppColors.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            Text(
              title ?? t('পরিচিতি', 'Profile'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
          ],
          for (var i = 0; i < paragraphs.length; i++) ...[
            if (i > 0) SizedBox(height: _isHeading(paragraphs[i]) ? 18 : 12),
            if (_isHeading(paragraphs[i]))
              _SubHeading(paragraphs[i].replaceFirst(RegExp(r'^###\s+'), ''))
            else
              Text(
                paragraphs[i],
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.75),
              ),
          ],
          if (t.en && (translated ?? true)) ...[
            const SizedBox(height: 10),
            TranslatedNote(originalUrl: originalUrl),
          ],
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                Text(
                  askForCorrections
                      ? t(
                          'সূত্র:',
                          sources.length == 1 ? 'Source:' : 'Sources:',
                        )
                      : t('সূত্র:', 'Sources:'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                for (final url in sources)
                  InkWell(
                    onTap: () => openLink(context, url),
                    child: Text(
                      sourceNames[url] ?? sourceLabel(url),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.brand,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.brand,
                      ),
                    ),
                  ),
                if (askForCorrections)
                  Text(
                    t('ভুল দেখলে জানান।', 'If you see a mistake, let us know.'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A one-line paragraph starting "### " is a sub-heading ("### রাজনৈতিক জীবন"), as on the website.
bool _isHeading(String p) => RegExp(r'^###\s+\S').hasMatch(p) && !p.contains('\n');

/// A sub-heading inside a biography: a short bar in the brand colour, then the title.
class _SubHeading extends StatelessWidget {
  final String text;
  const _SubHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 17,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Label-and-value rows, the shape every profile's facts take.
class FactsCard extends StatelessWidget {
  final String title;
  final List<({String label, String value})> facts;

  /// The facts (by label) marked with a star: taken from Wikipedia.
  final Set<String> starred;

  /// The facts (by label) written one part to a line at each ";"; every fact
  /// when not given.
  final Set<String>? lines;

  /// Under the rows: the note on the starred facts.
  final Widget? footer;

  const FactsCard({
    super.key,
    required this.title,
    required this.facts,
    this.starred = const {},
    this.lines,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: AppColors.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (var i = 0; i < facts.length; i++) ...[
            if (i > 0) const Divider(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  child: Text(
                    facts[i].label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  // Education is written as "school; college; university": one to a line.
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: lines == null || lines!.contains(facts[i].label)
                              ? facts[i].value.split(RegExp(r';\s*')).join('\n')
                              : facts[i].value,
                        ),
                        if (starred.contains(facts[i].label))
                          const TextSpan(
                            text: ' *',
                            style: TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ],
          if (footer != null) ...[const Divider(height: 18), footer!],
        ],
      ),
    );
  }
}

/// "Translated from Bangla. Read the original": under English text that is
/// the site's translation, as the website writes it. Nothing in Bangla.
class TranslatedNote extends StatelessWidget {
  /// The Bangla page on the website; without it only the first sentence.
  final String? originalUrl;
  const TranslatedNote({super.key, this.originalUrl});

  @override
  Widget build(BuildContext context) {
    if (!t.en) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.labelSmall;
    final url = originalUrl;
    return Wrap(
      spacing: 4,
      children: [
        Text('Translated from Bangla.', style: style),
        if (url != null)
          InkWell(
            onTap: () => openLink(context, url),
            child: Text(
              'Read the original',
              style: style?.copyWith(
                decoration: TextDecoration.underline,
                decorationColor: AppColors.muted,
              ),
            ),
          ),
      ],
    );
  }
}
