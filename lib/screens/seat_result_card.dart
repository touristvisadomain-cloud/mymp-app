import 'package:flutter/material.dart';

import '../data/member.dart';
import '../i18n.dart';
import '../loading.dart';
import '../party_logo.dart';
import '../theme.dart';

/// A seat's general-election result, as the website's result card draws it
/// (src/components/results.tsx): every candidate by votes, the winner marked,
/// each one's share, and where the numbers were read.
class SeatResultCard extends StatelessWidget {
  final ProfileResult result;

  /// "ত্রয়োদশ সংসদ, ২০২৬" / "13th Parliament, 2026".
  final String parliamentLabel;
  const SeatResultCard({
    super.key,
    required this.result,
    required this.parliamentLabel,
  });

  /// The link's name, as the website words it by where it points.
  static String linkLabel(String url) {
    if (RegExp(r'wikipedia\.org', caseSensitive: false).hasMatch(url)) {
      return t('উইকিপিডিয়া', 'Wikipedia');
    }
    if (RegExp(r'tbsnews\.net', caseSensitive: false).hasMatch(url)) {
      return t('মূল পাতা', 'Original page');
    }
    return t('গেজেট', 'Gazette');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final all = result.candidates;
    final cast = all.fold<int>(0, (n, c) => n + c.votes);
    final top = all.isEmpty || all.first.votes == 0 ? 1 : all.first.votes;
    final source = result.sourceBn;
    final note = result.noteBn;
    final url = result.sourceUrl;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: AppColors.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Text(parliamentLabel, style: text.titleMedium),
                if (cast > 0)
                  Text(
                    t(
                      'প্রার্থীদের মোট ${t.group(cast)} ভোট',
                      "Candidates' total: ${t.group(cast)} votes",
                    ),
                    style: text.bodySmall,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final (i, c) in all.indexed) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The name has a line of its own; party, votes and share
                  // follow on the next, as on the website on a phone.
                  Text(
                    c.name ?? '—',
                    style: TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 14.5,
                      height: 1.35,
                      fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (c.party != null)
                              Container(
                                padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
                                decoration: BoxDecoration(
                                  color: AppColors.sunk,
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusPill,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PartyLogo(abbr: c.party, size: 15),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        c.partyBn ?? c.party!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'NotoSansBengali',
                                          fontSize: 12,
                                          color: AppColors.inkSoft,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (i == 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandSoft,
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusPill,
                                  ),
                                ),
                                child: Text(
                                  t('বিজয়ী', 'Winner'),
                                  style: const TextStyle(
                                    fontFamily: 'NotoSansBengali',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.group(c.votes),
                        style: const TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 50,
                        child: Text(
                          '${t.fixed(cast > 0 ? c.votes * 100 / cast : 0)}%',
                          textAlign: TextAlign.end,
                          style: text.labelSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: c.votes / top,
                      minHeight: 6,
                      color: AppColors.party(c.party),
                      backgroundColor: AppColors.sunk,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Container(
            color: AppColors.paper.withValues(alpha: 0.6),
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      t('উৎস:', 'Source:'),
                      if (source != null)
                        note != null
                            ? t('$source। $note', '$source. $note')
                            : source,
                    ].join(' '),
                    style: text.labelSmall?.copyWith(height: 1.55),
                  ),
                ),
                if (url != null) ...[
                  const SizedBox(width: 10),
                  DocButton(label: linkLabel(url), url: url),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A link to a document elsewhere: a source's page, a notice's PDF.
class DocButton extends StatelessWidget {
  final String label;
  final String url;
  const DocButton({super.key, required this.label, required this.url});

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.brandSoft,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => openLink(context, url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.open_in_new_rounded,
              size: 13,
              color: AppColors.brand,
            ),
          ],
        ),
      ),
    ),
  );
}
