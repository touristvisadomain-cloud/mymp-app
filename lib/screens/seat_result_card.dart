import 'package:flutter/material.dart';

import '../i18n.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// A seat's 2026 result on the member's profile: the leading candidates by
/// votes, the winner marked, and the margin.
class SeatResultCard extends StatelessWidget {
  final String seatLabel;
  final SeatResult result;
  const SeatResultCard({
    super.key,
    required this.seatLabel,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final all = result.candidates;
    final total = all.fold<int>(0, (n, c) => n + c.votes);
    final shown = all.take(5).toList();
    final tied = shown.length > 1 && shown[0].votes == shown[1].votes;
    final margin = shown.length > 1 ? shown[0].votes - shown[1].votes : 0;

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
            t('$seatLabel আসনের ফল, ২০২৬', 'Result for $seatLabel, 2026'),
            style: text.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final (i, c) in shown.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'NotoSansBengali',
                            fontSize: 14,
                            fontWeight: i == 0 && !tied
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (i == 0 && !tied) ...[
                        Pill(t('বিজয়ী', 'Winner'), filled: true),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        t.group(c.votes),
                        style: const TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? c.votes / total : 0,
                      minHeight: 7,
                      color: AppColors.party(c.party),
                      backgroundColor: AppColors.sunk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${c.partyBn ?? c.party ?? t('দল জানা নেই', 'Party not known')}, ${t.pct(c.votes, total)}',
                    style: text.labelSmall,
                  ),
                ],
              ),
            ),
          if (all.length > shown.length)
            Text(
              t(
                'আরও ${t.n(all.length - shown.length)} জন প্রার্থী ছিলেন।',
                all.length - shown.length == 1
                    ? 'There was 1 more candidate.'
                    : 'There were ${all.length - shown.length} more candidates.',
              ),
              style: text.labelSmall,
            ),
          if (shown.length > 1 && !tied) ...[
            const SizedBox(height: 4),
            Text(
              t(
                '${t.group(margin)} ভোটের ব্যবধানে জয়।',
                'Won by a margin of ${t.group(margin)} ${plural(margin, 'vote', 'votes')}.',
              ),
              style: text.bodyMedium,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            t(
              'সূত্র: দ্য বিজনেস স্ট্যান্ডার্ড ও উইকিপিডিয়া; নির্বাচন কমিশনের গেজেটের সঙ্গে এখনো মিলিয়ে দেখা হয়নি।',
              'Source: The Business Standard and Wikipedia; not yet checked against the Election Commission’s gazette.',
            ),
            style: text.labelSmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
