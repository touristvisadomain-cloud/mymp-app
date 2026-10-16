/// The pieces the election and statistics screens share: the page head, the
/// section shortcuts, cards, bars and the links out to other screens.
library;

import 'package:flutter/material.dart';

import '../data/election.dart';
import '../i18n.dart';
import '../models.dart';
import '../theme.dart';
import 'member_screen.dart';

/// Opens a screen for a slug: a seat ("dhaka-17"), a district ("dhaka") or a
/// party ("bnp").
typedef SlugOpener = void Function(BuildContext context, String slug);

/// Where the election screens' links go. The seat, district and party
/// screens belong to other parts of the app; they are wired here at start-up
/// (main.dart or wherever the lead wires navigation), and a link with no
/// screen behind it is simply not shown.
class ElectionLinks {
  ElectionLinks._();

  /// A seat's page (the website's `/ason/<slug>`).
  static SlugOpener? seat;

  /// A district's page (`/jela/<slug>`).
  static SlugOpener? district;

  /// A party's page (`/dol/<slug>`; the slug is the abbreviation in lower case).
  static SlugOpener? party;

  /// The members for the reserved seats for women (/sangrakkhito-ason).
  static void Function(BuildContext context)? reserved;
}

/// A member's profile, the screen the rest of the app opens.
void openMember(BuildContext context, MemberBrief m) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => MemberScreen(member: m)));

const _font = 'NotoSansBengali';

TextStyle figureStyle(double size, {Color color = AppColors.ink}) => TextStyle(
  fontFamily: _font,
  fontSize: size,
  fontWeight: FontWeight.w800,
  color: color,
  height: 1.2,
);

const mutedStyle = TextStyle(
  fontFamily: _font,
  fontSize: 13,
  color: AppColors.muted,
  height: 1.5,
);

/// The page's heading, as the website's PageHead: a small line above, the
/// title, and a paragraph.
class PageHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String lede;
  const PageHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.lede,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            fontFamily: _font,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.brand,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: text.headlineSmall),
        const SizedBox(height: 6),
        Text(lede, style: text.bodyMedium?.copyWith(height: 1.6)),
      ],
    );
  }
}

/// A figure with its label, the website's Stat: a small card.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  final double valueSize;
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.valueSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: AppDecor.card(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: figureStyle(valueSize)),
          ),
          if (note != null) ...[
            const SizedBox(height: 3),
            Text(
              note!,
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 12,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tiles two to a row, each row as tall as its tallest tile.
class TileGrid extends StatelessWidget {
  final List<Widget> tiles;
  final double gap;
  const TileGrid({super.key, required this.tiles, this.gap = 10});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (i > 0) rows.add(SizedBox(height: gap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[i]),
              SizedBox(width: gap),
              Expanded(
                child: i + 1 < tiles.length
                    ? tiles[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// The row of shortcuts under a page's heading; a tap scrolls to the section.
class SectionShortcuts extends StatelessWidget {
  final List<(GlobalKey, String)> sections;
  const SectionShortcuts({super.key, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (key, label) in sections)
          Semantics(
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              onTap: () {
                final c = key.currentContext;
                if (c != null) {
                  Scrollable.ensureVisible(
                    c,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                  border: Border.all(color: AppColors.rule),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A section's title with a short note under it and a rule below, the
/// website's SectionHead.
class SectionHead extends StatelessWidget {
  final String title;
  final String? note;
  const SectionHead({super.key, required this.title, this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (note != null) Text(note!, style: mutedStyle),
        ],
      ),
    );
  }
}

/// A white card with the page's padding.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Panel({
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

/// A card's title and the line under it.
class PanelTitle extends StatelessWidget {
  final String title;
  final String? note;
  const PanelTitle(this.title, {super.key, this.note});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      if (note != null) Text(note!, style: mutedStyle),
    ],
  );
}

/// A note at a card's foot, under a hairline.
class PanelFoot extends StatelessWidget {
  final String text;
  const PanelFoot(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.only(top: 10),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.rule)),
    ),
    child: Text(text, style: mutedStyle),
  );
}

/// A small coloured dot.
class Dot extends StatelessWidget {
  final Color colour;
  final double size;
  const Dot(this.colour, {super.key, this.size = 10});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
  );
}

/// Labelled horizontal bars, one series: the longest in full colour, the
/// others lighter; with [total], each row's share beside its count.
class BandBars extends StatelessWidget {
  final List<({String label, int count})> rows;
  final int? total;
  final double labelWidth;

  /// The longest bar in full colour and the others lighter; off, all full.
  final bool emphasiseLargest;
  const BandBars({
    super.key,
    required this.rows,
    this.total,
    this.labelWidth = 86,
    this.emphasiseLargest = true,
  });

  @override
  Widget build(BuildContext context) {
    final max = rows.fold<int>(1, (m, r) => r.count > m ? r.count : m);
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    r.label,
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 13,
                      color: AppColors.inkSoft,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.sunk,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: (r.count / max).clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: r.count == max || !emphasiseLargest
                              ? AppColors.brand
                              : AppColors.brand.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 38,
                  child: Text(
                    t.n(r.count),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (total != null && total! > 0)
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${t.n((r.count * 100 / total!).round())}%',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One whole in two parts, side by side, each with its count and, when
/// [shares], its share: the website's Split.
class SplitBar extends StatelessWidget {
  final ({String label, int n, Color colour}) a;
  final ({String label, int n, Color colour}) b;
  final bool shares;
  final String semantics;
  const SplitBar({
    super.key,
    required this.a,
    required this.b,
    required this.semantics,
    this.shares = true,
  });

  @override
  Widget build(BuildContext context) {
    final sum = a.n + b.n == 0 ? 1 : a.n + b.n;
    Widget part(({String label, int n, Color colour}) x) => Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: Dot(x.colour),
            ),
          ),
          TextSpan(text: '${x.label} '),
          TextSpan(
            text: t.group(x.n),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (shares)
            TextSpan(
              text: ' (${t.n((x.n * 100 / sum).round())}%)',
              style: const TextStyle(color: AppColors.muted),
            ),
        ],
      ),
      style: const TextStyle(
        fontFamily: _font,
        fontSize: 13,
        color: AppColors.ink,
        height: 1.4,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: semantics,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (a.n > 0)
                    Expanded(
                      flex: a.n,
                      child: Container(color: a.colour),
                    ),
                  if (a.n > 0 && b.n > 0) const SizedBox(width: 2),
                  if (b.n > 0)
                    Expanded(
                      flex: b.n,
                      child: Container(color: b.colour),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [part(a), part(b)],
        ),
      ],
    );
  }
}

/// The website's Empty: a dashed box with an i, a title and a paragraph.
class NoteBox extends StatelessWidget {
  final String title;
  final String body;
  const NoteBox({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: AppColors.rule, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.muted,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 13.5,
                    color: AppColors.muted,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The House as one bar: the four largest parties and the rest, with the
/// majority marked; then each part named. The website's CompositionBar.
class CompositionBar extends StatelessWidget {
  final List<HouseParty> parties;
  final int total;
  final int majority;

  /// A party's full name in the reader's language, by abbreviation.
  final String Function(HouseParty p) nameOf;
  const CompositionBar({
    super.key,
    required this.parties,
    required this.total,
    required this.majority,
    required this.nameOf,
  });

  @override
  Widget build(BuildContext context) {
    final top = parties.take(4).toList();
    final rest = parties.skip(4).fold<int>(0, (n, p) => n + p.seats);
    final rows = <({String label, String abbr, int seats})>[
      for (final p in top) (label: nameOf(p), abbr: p.abbr, seats: p.seats),
      if (rest > 0)
        (
          label: t(
            'অন্য ${t.n(parties.length - 4)} দল',
            '${parties.length - 4} other parties',
          ),
          abbr: 'other',
          seats: rest,
        ),
    ];
    final mark = total > 0 ? majority / total : 0.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final x = w * mark;
            const labelW = 120.0;
            return SizedBox(
              height: 52,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: (x - labelW / 2).clamp(0.0, w - labelW),
                    width: labelW,
                    top: 0,
                    child: Text(
                      '${t('সংখ্যাগরিষ্ঠতা', 'Majority')} ${t.n(majority)}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.2,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 30,
                    child: Semantics(
                      label: rows
                          .map((r) => '${r.label} ${t.n(r.seats)}')
                          .join(', '),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          children: [
                            for (final (i, r) in rows.indexed) ...[
                              if (i > 0) const SizedBox(width: 2),
                              Expanded(
                                flex: r.seats,
                                child: Container(
                                  color: partyColour(
                                    r.abbr == 'other' ? null : r.abbr,
                                  ),
                                  alignment: AlignmentDirectional.centerStart,
                                  padding: const EdgeInsetsDirectional.only(
                                    start: 8,
                                  ),
                                  child: total > 0 && r.seats / total > 0.06
                                      ? Text(
                                          t.n(r.seats),
                                          maxLines: 1,
                                          overflow: TextOverflow.clip,
                                          style: TextStyle(
                                            fontFamily: _font,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: r.abbr == 'BJEI'
                                                ? AppColors.ink
                                                : Colors.white,
                                            height: 1.2,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: x.clamp(0.0, w - 1.5),
                    top: 16,
                    bottom: 0,
                    child: const _DashedLine(),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: partyColour(r.abbr == 'other' ? null : r.abbr),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 14,
                      color: AppColors.ink,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  t.n(r.seats),
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The majority mark: a dashed upright line.
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size(1.5, double.infinity), painter: _Dashes());
}

class _Dashes extends CustomPainter {
  const _Dashes();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 1.5;
    for (var y = 0.0; y < size.height; y += 6) {
      canvas.drawLine(
        Offset(0.75, y),
        Offset(0.75, (y + 3).clamp(0, size.height)),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Dashes oldDelegate) => false;
}
