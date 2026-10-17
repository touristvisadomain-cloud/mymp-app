import 'package:flutter/material.dart';

import '../i18n.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'election_screen.dart';
import 'member_screen.dart';

/// শীর্ষ নেতৃত্ব: the Prime Minister, Speaker, Deputy, Opposition Leader and
/// Chief Whip, each a card that opens the member's profile.
class LeadersStrip extends StatelessWidget {
  final Bootstrap data;
  const LeadersStrip({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final byId = {for (final m in data.members) m.id: m};
    final leaders = [
      for (final l in data.leaders)
        if (byId[l.memberId] != null)
          (role: l.roleBn, member: byId[l.memberId]!),
    ];
    if (leaders.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePad),
            child: Text(
              t('শীর্ষ নেতৃত্ব', 'Leadership'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 192,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePad),
              itemCount: leaders.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) =>
                  _LeaderCard(role: leaders[i].role, member: leaders[i].member),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderCard extends StatelessWidget {
  final String role;
  final MemberBrief member;
  const _LeaderCard({required this.role, required this.member});

  @override
  Widget build(BuildContext context) {
    final colour = AppColors.party(member.party);
    return Container(
      width: 150,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppDecor.card(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MemberScreen(member: member)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colour, width: 2.5),
                  ),
                  child: MemberAvatar(member: member, size: 62),
                ),
                const SizedBox(height: 8),
                Text(
                  member.nameBn,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                  ),
                  child: Text(
                    role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                    ),
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

/// The way into the election figures, under the leaders.
class ElectionCard extends StatelessWidget {
  final EdgeInsets padding;
  const ElectionCard({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(
      AppSizes.pagePad,
      4,
      AppSizes.pagePad,
      0,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Container(
        decoration: AppDecor.card(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.radiusCard),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ElectionScreen())),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.brandSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.how_to_vote_rounded,
                      color: AppColors.brand,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('ত্রয়োদশ নির্বাচন', '2026 Election'),
                          style: text.titleMedium,
                        ),
                        Text(
                          t(
                            'মানচিত্র, ফলাফল, ভোটার ও জেলা অনুযায়ী আসন',
                            'Map, results, voters and seats by district',
                          ),
                          style: text.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
