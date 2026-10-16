import 'package:flutter/material.dart';

import '../api.dart';
import '../i18n.dart';
import '../models.dart';
import '../party_logo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'member_screen.dart';

/// Everyone elected for one party, in seat order. Read from the list already on
/// the phone, so it opens with no wait and works with no signal.
class PartyScreen extends StatelessWidget {
  final PartyBrief party;
  const PartyScreen({super.key, required this.party});

  @override
  Widget build(BuildContext context) {
    // Redrawn when the list changes, which it does after a language switch:
    // the party and its members are then read again in the new language.
    return ValueListenableBuilder<Bootstrap?>(
      valueListenable: Api.instance.bootstrap,
      builder: (context, _, _) => _page(context),
    );
  }

  Widget _page(BuildContext context) {
    final data = Api.instance.cached;
    final party =
        data?.parties.where((p) => p.abbr == this.party.abbr).firstOrNull ??
        this.party;
    final members =
        (data?.members ?? const <MemberBrief>[])
            .where((m) => m.party == party.abbr)
            .toList()
          ..sort((a, b) => (a.seatNo ?? 9999).compareTo(b.seatNo ?? 9999));
    final colour = AppColors.party(party.abbr);

    return Scaffold(
      appBar: AppBar(title: Text(party.nameBn)),
      body: members.isEmpty
          ? EmptyState(
              icon: Icons.group_outlined,
              title: t('কোনো সদস্য নেই', 'No members'),
              body: t(
                'এই দলের কোনো নির্বাচিত সদস্য তালিকায় নেই।',
                'No elected member of this party is on the list.',
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                AppSizes.pagePad,
                12,
                AppSizes.pagePad,
                28 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: members.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colour.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                      border: Border.all(color: colour.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        PartyLogo(abbr: party.abbr, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t.count(
                              members.length,
                              ' জন সংসদ সদস্য',
                              'Member of Parliament',
                              'Members of Parliament',
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final m = members[i - 1];
                return MemberTile(
                  member: m,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => MemberScreen(member: m)),
                  ),
                );
              },
            ),
    );
  }
}
