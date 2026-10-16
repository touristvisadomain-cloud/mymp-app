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
  const BioCard({
    super.key,
    required this.text,
    this.sources = const [],
    this.title,
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
          Text(
            title ?? t('পরিচিতি', 'Profile'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < paragraphs.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Text(
              paragraphs[i],
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.75),
            ),
          ],
          if (t.en) ...[
            const SizedBox(height: 10),
            Text(
              'Translated from Bangla.',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontStyle: FontStyle.italic),
            ),
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
                  t('সূত্র:', 'Sources:'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                for (final url in sources)
                  InkWell(
                    onTap: () => openLink(context, url),
                    child: Text(
                      sourceLabel(url),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.brand,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.brand,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Label-and-value rows, the shape every profile's facts take.
class FactsCard extends StatelessWidget {
  final String title;
  final List<({String label, String value})> facts;
  const FactsCard({super.key, required this.title, required this.facts});

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
                  child: Text(
                    facts[i].value.split(RegExp(r';\s*')).join('\n'),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
