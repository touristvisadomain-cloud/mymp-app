import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'bn.dart';
import 'i18n.dart';
import 'models.dart';
import 'party_logo.dart';
import 'theme.dart';

/// A member's photograph, or the first letter of their name on the party's
/// colour when the secretariat has published no picture.
class MemberAvatar extends StatelessWidget {
  final MemberBrief member;
  final double size;
  const MemberAvatar({super.key, required this.member, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final colour = AppColors.party(member.party);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: colour.withValues(alpha: 0.12),
      child: Text(
        initialOf(member.nameBn),
        style: TextStyle(
          fontFamily: 'NotoSansBengali',
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: colour,
        ),
      ),
    );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: member.photoUrl == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: member.photoUrl!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 180),
                placeholder: (_, _) => Container(color: AppColors.sunk),
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// The party's mark: a coloured dot and its short name, as on the website.
class PartyChip extends StatelessWidget {
  final String? abbr;
  final String? label;
  final bool compact;
  const PartyChip({super.key, this.abbr, this.label, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (abbr == null && label == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PartyLogo(abbr: abbr, size: compact ? 17 : 19),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label ?? abbr!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: compact ? 12.5 : 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

/// A small outlined label: an office, a seat, a category.
class Pill extends StatelessWidget {
  final String text;
  final Color? colour;
  final bool filled;
  const Pill(this.text, {super.key, this.colour, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final c = colour ?? AppColors.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(
          // A title long enough to wrap reads as a label, not a stadium.
          text.length > 22 ? 10 : AppSizes.radiusPill,
        ),
        border: Border.all(color: filled ? c : c.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'NotoSansBengali',
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: filled ? Colors.white : c,
        ),
      ),
    );
  }
}

/// One member in a list: photograph ringed in the party's colour, name, seat and
/// party, and the office they hold when they hold one.
class MemberTile extends StatelessWidget {
  final MemberBrief member;
  final VoidCallback onTap;
  const MemberTile({super.key, required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colour = AppColors.party(member.party);
    return Container(
      decoration: AppDecor.card(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
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
                  child: MemberAvatar(member: member, size: 50),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        member.nameBn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            member.seatLabel,
                            style: const TextStyle(
                              fontFamily: 'NotoSansBengali',
                              fontSize: 13,
                              color: AppColors.muted,
                              height: 1.3,
                            ),
                          ),
                          if (member.party != null) ...[
                            const SizedBox(width: 10),
                            Flexible(
                              child: PartyChip(
                                abbr: member.party,
                                label: member.partyBn,
                                compact: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (member.officeBn != null) ...[
                        const SizedBox(height: 6),
                        Pill(member.officeBn!, filled: true),
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

/// What a screen shows when it has nothing: a reason and, where there is one,
/// a way out.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.brandSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.brand, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The bar of choices above a list. One row, scrolls sideways when the labels
/// outgrow the screen, which they do on a small phone in Bangla. On the green
/// header (`onDark`) the chips are drawn in white.
class ChipBar extends StatelessWidget {
  final List<({String label, String? value})> options;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final bool onDark;
  final EdgeInsets padding;

  /// A mark before an option's label, such as a party's logo.
  final Widget? Function(String? value)? leading;
  const ChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.onDark = false,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSizes.pagePad),
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final o = options[i];
          final on = o.value == selected;
          final Color bg;
          final Color fg;
          final Color line;
          if (onDark) {
            bg = on ? Colors.white : Colors.white.withValues(alpha: 0.12);
            fg = on ? AppColors.brandDark : Colors.white;
            line = on ? Colors.white : Colors.white.withValues(alpha: 0.22);
          } else {
            bg = on ? AppColors.brand : AppColors.surface;
            fg = on ? Colors.white : AppColors.inkSoft;
            line = on ? AppColors.brand : AppColors.rule;
          }
          // A button to a screen reader, and says which filter is on.
          return Semantics(
            button: true,
            selected: on,
            child: GestureDetector(
              onTap: () => onSelect(o.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                  border: Border.all(color: line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leading?.call(o.value) case final mark?) ...[
                      // On the selected green chip the logo sits on a white disc.
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: mark,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      o.label,
                      style: TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: fg,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The message shown when a fetch failed, with the one button that helps.
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.wifi_off_rounded,
    title: t('তথ্য আনা গেল না', 'Could not fetch the information'),
    body: message,
    actionLabel: t('আবার চেষ্টা করুন', 'Try again'),
    onAction: onRetry,
  );
}

/// বাংলা | English: the reader's language, two segments, the chosen one
/// filled. Each label is written in its own language, so a reader who cannot
/// read the other one can still find theirs. [onDark] draws it in white for
/// the green header; [compact] is the small one on the first-run notice.
class LangSwitch extends StatelessWidget {
  final bool onDark;
  final bool compact;
  const LangSwitch({super.key, this.onDark = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final current = T.watch(context).lang;
    final line = onDark ? Colors.white.withValues(alpha: 0.5) : AppColors.rule;
    Widget segment(Lang lang, String label) {
      final on = lang == current;
      final Color bg;
      final Color fg;
      if (onDark) {
        bg = on ? Colors.white : Colors.transparent;
        fg = on ? AppColors.brandDark : Colors.white;
      } else {
        bg = on ? AppColors.brand : AppColors.surface;
        fg = on ? Colors.white : AppColors.inkSoft;
      }
      return Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => appLang.choose(lang),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 16,
              vertical: compact ? 4 : 8,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: compact ? 12.5 : 14,
                fontWeight: FontWeight.w700,
                color: fg,
                height: 1.25,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        border: Border.all(color: line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [segment(Lang.bn, 'বাংলা'), segment(Lang.en, 'English')],
      ),
    );
  }
}
