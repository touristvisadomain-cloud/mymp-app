import 'package:flutter/material.dart';

import '../data/house.dart';
import '../i18n.dart';
import '../loading.dart';
import '../models.dart';
import '../party_logo.dart';
import '../theme.dart';
import '../widgets.dart';

/// The pieces the sessions, committee and party screens share: the page's
/// head with its figures, section titles, a white card, the source's
/// document button, notes and notices. The look is the website's.

const _font = 'NotoSansBengali';

/// The head of a page: a small line above the title, the title, a lede, and
/// the page's figures in a row of boxes under it.
class HousePageHead extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? lede;
  final List<({String label, String value})> stats;
  final Widget? mark;

  const HousePageHead({
    super.key,
    this.eyebrow,
    required this.title,
    this.lede,
    this.stats = const [],
    this.mark,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (mark != null) ...[mark!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null && eyebrow!.isNotEmpty)
                    Text(
                      eyebrow!,
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand,
                        height: 1.3,
                      ),
                    ),
                  Text(title, style: text.headlineSmall),
                ],
              ),
            ),
          ],
        ),
        if (lede != null && lede!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(lede!, style: text.bodyMedium?.copyWith(height: 1.6)),
        ],
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: StatBox(label: stats[i].label, value: stats[i].value),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// A figure and what it counts.
class StatBox extends StatelessWidget {
  final String label;
  final String value;
  const StatBox({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: AppDecor.card(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.25,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 12,
              color: AppColors.muted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// A section's title, with its count beside it when there is one.
class SectionTitle extends StatelessWidget {
  final String text;
  final String? count;
  final Color? bar;
  const SectionTitle(this.text, {super.key, this.count, this.bar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (bar != null) ...[
            Container(
              width: 5,
              height: 18,
              decoration: BoxDecoration(
                color: bar,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 9),
          ],
          Flexible(
            child: Text.rich(
              TextSpan(
                text: text,
                children: [
                  if (count != null)
                    TextSpan(
                      text: ' ($count)',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                ],
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
    );
  }
}

/// A white card on the page.
class HouseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const HouseCard({
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

/// A document on the source's own server: a small green button that opens it.
class DocButton extends StatelessWidget {
  final String label;
  final String url;
  const DocButton({super.key, required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      link: true,
      child: Material(
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
                    fontFamily: _font,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brand,
                    height: 1.2,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 13,
                  color: AppColors.brand,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A list of notices, each with its date and the document button.
class NoticeList extends StatelessWidget {
  final List<HouseNotice> notices;

  /// The button's label: "PDF" on the sessions page, "বিজ্ঞপ্তি" on a committee's.
  final String buttonLabel;
  const NoticeList({
    super.key,
    required this.notices,
    required this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecor.card(),
      child: Column(
        children: [
          for (var i = 0; i < notices.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notices[i].title ?? t('বিজ্ঞপ্তি', 'Notice'),
                          style: const TextStyle(
                            fontFamily: _font,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.ink,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.date(notices[i].date) ?? t('তারিখ নেই', 'No date'),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  if (notices[i].pdfUrl != null) ...[
                    const SizedBox(width: 10),
                    DocButton(label: buttonLabel, url: notices[i].pdfUrl!),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The page's quiet note: where its facts come from.
class InfoNote extends StatelessWidget {
  final String text;
  const InfoNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 13,
                color: AppColors.brandDark,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A warning in the website's amber: a list not yet updated, and why.
class WarnNotice extends StatelessWidget {
  final String title;
  final String body;
  const WarnNotice({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warnSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: AppColors.warn.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppColors.warn,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 13.5,
              color: AppColors.inkSoft,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// One fact in a card: its label on the left, the value on the right; a
/// value too long for the line drops under the label.
class FactLine extends StatelessWidget {
  final String label;
  final Widget value;
  final bool last;
  const FactLine({
    super.key,
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.ruleSoft)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.start,
        spacing: 12,
        runSpacing: 2,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 14,
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
          DefaultTextStyle.merge(
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
              height: 1.45,
            ),
            textAlign: TextAlign.end,
            child: value,
          ),
        ],
      ),
    );
  }
}

/// Text that opens a link when tapped, in the brand's green.
class LinkText extends StatelessWidget {
  final String text;
  final String url;
  final double size;
  final bool underline;
  const LinkText(
    this.text, {
    super.key,
    required this.url,
    this.size = 14.5,
    this.underline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openLink(context, url),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: _font,
            fontSize: size,
            fontWeight: FontWeight.w600,
            color: AppColors.brand,
            height: 1.5,
            decoration: underline ? TextDecoration.underline : null,
            decorationColor: AppColors.brand.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// A member as the website's committee and party pages list one: photo,
/// name, and the seat and party on one line under it, with the party's
/// colour down the left edge. A tap opens the member.
class HouseMemberRow extends StatelessWidget {
  final MemberBrief member;
  final VoidCallback onTap;
  const HouseMemberRow({super.key, required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = member;
    final colour = AppColors.party(m.party);
    final under = [m.seatLabel, ?m.partyBn].join(', ');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: AppDecor.card(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: colour, width: 3)),
            ),
            padding: const EdgeInsets.fromLTRB(11, 10, 8, 10),
            child: Row(
              children: [
                MemberAvatar(member: m, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.nameBn,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: _font,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          height: 1.35,
                        ),
                      ),
                      Row(
                        children: [
                          if (m.party != null) ...[
                            PartyLogo(abbr: m.party, size: 15),
                            const SizedBox(width: 5),
                          ],
                          Expanded(
                            child: Text(
                              under,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: _font,
                                fontSize: 13,
                                color: AppColors.muted,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A line of small print with links in it ("Sources: Wikipedia, …"): the
/// plain words wrap like any text, each link stays whole and opens on a tap.
class InlineLinks extends StatelessWidget {
  /// Each piece's text, and the address it opens, or null for plain text.
  final List<(String, String?)> parts;
  const InlineLinks(this.parts, {super.key});

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6);
    return Text.rich(
      TextSpan(
        children: [
          for (final (text, url) in parts)
            if (url == null)
              TextSpan(text: text)
            else
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: LinkText(text, url: url, size: 13, underline: true),
              ),
        ],
      ),
      style: small,
    );
  }
}
