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
    // A banner in the brand green, so the way into the election stands out
    // from the white cards around it: what it holds as chips, and a button.
    const font = 'NotoSansBengali';
    void open() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ElectionScreen()));
    final chips = [
      (Icons.map_outlined, t('মানচিত্র', 'Map')),
      (Icons.bar_chart_rounded, t('ফলাফল', 'Results')),
      (Icons.groups_outlined, t('ভোটার', 'Voters')),
      (Icons.location_city_outlined, t('জেলাভিত্তিক আসন', 'Seats by district')),
    ];
    return Padding(
      padding: padding,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brand, AppColors.brandDark],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandDark.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: open,
            child: Stack(
              children: [
                // The ballot mark, large and faint, behind the words.
                Positioned(
                  right: -18,
                  top: -14,
                  child: Icon(
                    Icons.how_to_vote_rounded,
                    size: 132,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusPill,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.how_to_vote_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              t('নির্বাচন ২০২৬', 'Election 2026'),
                              style: const TextStyle(
                                fontFamily: font,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        t(
                          'ত্রয়োদশ জাতীয় সংসদ নির্বাচন',
                          'Election to the 13th Parliament',
                        ),
                        style: const TextStyle(
                          fontFamily: font,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t(
                          'কোন আসনে কে জিতেছে, কত ভোট পেয়েছে, দেখুন মানচিত্রে',
                          'Who won each seat and by how many votes, on the map',
                        ),
                        style: TextStyle(
                          fontFamily: font,
                          fontSize: 13.5,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final (icon, label) in chips)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.22),
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusPill,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon, size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      fontFamily: font,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusPill,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t('ফলাফল দেখুন', 'See the results'),
                              style: const TextStyle(
                                fontFamily: font,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brand,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 17,
                              color: AppColors.brand,
                            ),
                          ],
                        ),
                      ),
                    ],
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
