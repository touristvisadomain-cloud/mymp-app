/// The pieces the seat, district and reserved-seat screens share: the green
/// head of the page, a section heading, the dashed note the website shows
/// where it has nothing to list, a party's colour, and the ways to open a
/// seat, a district or a member.
library;

import 'package:flutter/material.dart';

import '../api.dart';
import '../i18n.dart';
import '../loading.dart';
import '../models.dart';
import '../party_logo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'district_screen.dart';
import 'member_screen.dart';
import 'seat_screen.dart';

/// A party's colour. The API names Jamaat "BJEI"; the palette in theme.dart
/// files it under "Jamaat".
Color partyColour(String? abbr) =>
    AppColors.party(abbr == 'BJEI' ? 'Jamaat' : abbr);

void openSeat(BuildContext context, String slug) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => SeatScreen(slug: slug)));

void openDistrict(BuildContext context, String slug) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => DistrictScreen(slug: slug)));

void openMember(BuildContext context, MemberBrief m) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => MemberScreen(member: m)));

/// The website page this screen matches, in the reader's language.
void openOnSite(BuildContext context, String path) =>
    openLink(context, Api.page(path));

/// The head of the page, in the green of the tabs' headers: a small line
/// above, the title, what follows it, and the figures.
class PlaceHero extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final String? lede;
  final List<({String value, String label, String? note})> stats;
  final Widget? footer;

  const PlaceHero({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.lede,
    this.stats = const [],
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    const white = TextStyle(fontFamily: 'NotoSansBengali', color: Colors.white);
    final soft = Colors.white.withValues(alpha: 0.85);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: AppDecor.headerGradient,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        boxShadow: AppDecor.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null)
            Text(
              eyebrow!,
              style: white.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: soft,
                letterSpacing: 0.4,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            title,
            style: white.copyWith(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: white.copyWith(fontSize: 14, color: soft, height: 1.4),
            ),
          ],
          if (lede != null) ...[
            const SizedBox(height: 10),
            Text(lede!, style: white.copyWith(fontSize: 14.5, height: 1.55)),
          ],
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in stats)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.value,
                          style: white.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          s.label,
                          style: white.copyWith(fontSize: 12, color: soft),
                        ),
                        if (s.note != null)
                          Text(
                            s.note!,
                            style: white.copyWith(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ],
      ),
    );
  }
}

/// A section's heading, with a count after it when there is one.
class SectionHeading extends StatelessWidget {
  final String text;
  final String? count;
  const SectionHeading(this.text, {super.key, this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            if (count != null)
              TextSpan(
                text: '  $count',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
          ],
        ),
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}

/// A white card.
class PlaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const PlaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: AppDecor.card(),
    child: child,
  );
}

/// What the website shows where it has nothing to list: a dashed box with a
/// reason.
class NoteBox extends StatelessWidget {
  final String title;
  final String? body;
  const NoteBox({super.key, required this.title, this.body});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return CustomPaint(
      painter: _DashedBorder(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.info_outline_rounded,
                size: 22,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall),
                  if (body != null) ...[
                    const SizedBox(height: 4),
                    Text(body!, style: text.bodySmall?.copyWith(height: 1.55)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.rule
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(AppSizes.radiusCard),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => false;
}

/// "Translated from Bangla." under text the site translated, with a link to
/// the Bangla page. English only.
class TranslatedNote extends StatelessWidget {
  final String bnPath;
  const TranslatedNote({super.key, required this.bnPath});

  @override
  Widget build(BuildContext context) {
    if (!t.en) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        onTap: () => openLink(context, '${Api.base}$bnPath'),
        child: Text.rich(
          TextSpan(
            text: 'Translated from Bangla. ',
            children: const [
              TextSpan(
                text: 'Read the original',
                style: TextStyle(decoration: TextDecoration.underline),
              ),
            ],
          ),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}

/// A row of a short list: a label on the left, a value on the right.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool last;
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.ruleSoft)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14.5, color: AppColors.muted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: onTap == null ? AppColors.ink : AppColors.brand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "তথ্যসূত্র" box at the foot of a seat page.
class SourceBox extends StatelessWidget {
  final String text;
  const SourceBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('তথ্যসূত্র', 'Source'),
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.brandDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

/// A source's English name in capitals ("TARIQUE RAHMAN") in title case, as
/// the website shows it; a name already in mixed case is left alone.
String? titleCaseName(String? s) {
  if (s == null || s.isEmpty) return null;
  if (s != s.toUpperCase() || !RegExp('[A-Z]{2}').hasMatch(s)) return s;
  return s.toLowerCase().replaceAllMapped(
    RegExp(r"(^|[\s.\-('])([a-z])"),
    (m) => '${m[1]}${m[2]!.toUpperCase()}',
  );
}

/// One member in a seat, district or reserved-seat list: the look of
/// widgets.dart's MemberTile, with the seat and party on lines that wrap, so
/// "Chapai Nawabganj-3" or "Women's Seat-12" in a large font never runs off a
/// small phone.
class PlaceMemberTile extends StatelessWidget {
  final MemberBrief member;
  const PlaceMemberTile({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final m = member;
    final colour = partyColour(m.party);
    const small = TextStyle(fontSize: 13, color: AppColors.muted, height: 1.3);
    return Container(
      decoration: AppDecor.card(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openMember(context, m),
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colour.withValues(alpha: 0.55),
                      width: 2,
                    ),
                  ),
                  child: MemberAvatar(member: m, size: 50),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.nameBn,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 10,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: 3),
                              Flexible(child: Text(m.seatLabel, style: small)),
                            ],
                          ),
                          if (m.party != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PartyLogo(abbr: m.party, size: 17),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    m.partyBn ?? m.party!,
                                    style: small.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (m.officeBn != null) ...[
                        const SizedBox(height: 6),
                        Pill(m.officeBn!, filled: true),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.rule,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
