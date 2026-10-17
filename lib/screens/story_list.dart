import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../bn.dart';
import '../i18n.dart';
import '../loading.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'member_screen.dart';

/// A list of headlines and videos, used both on the news tab and inside a
/// member's page. Every item opens the outlet's own page: the app links to the
/// press, it does not reproduce it.
class StoryList extends StatelessWidget {
  final Future<List<Story>> future;
  final String emptyTitle;
  final String emptyBody;
  final VoidCallback onRetry;
  final Widget? header;
  final Future<void> Function()? onRefresh;

  const StoryList({
    super.key,
    required this.future,
    required this.emptyTitle,
    required this.emptyBody,
    required this.onRetry,
    this.header,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Loaded<List<Story>>(
      future: future,
      onRetry: onRetry,
      builder: (context, stories) {
        final list = ListView.separated(
          // Clear of the system navigation bar on a pushed page; on a tab the
          // app's own bar has already taken that inset.
          padding: EdgeInsets.fromLTRB(
            AppSizes.pagePad,
            12,
            AppSizes.pagePad,
            28 + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount:
              stories.length +
              (header != null ? 1 : 0) +
              (stories.isEmpty ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (header != null && i == 0) return header!;
            final index = i - (header != null ? 1 : 0);
            if (stories.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.article_outlined,
                  title: emptyTitle,
                  body: emptyBody,
                ),
              );
            }
            return StoryCard(story: stories[index]);
          },
        );
        return onRefresh == null
            ? list
            : RefreshIndicator(
                color: AppColors.brand,
                onRefresh: onRefresh!,
                child: list,
              );
      },
    );
  }
}

/// When a story was published, as the website writes it: the date and the
/// Dhaka clock time, and while it is under a week old how long ago,
/// "১৭ অক্টোবর ২০২৬, রাত ১২:৫৯ · ১৬ মিনিট আগে". Only the date when the site
/// sent no time; the site's own label when it sent no date at all. In pieces
/// that a narrow card may wrap between but never inside.
List<String> storyWhen(Story story, {DateTime? now}) {
  final at = story.publishedAt;
  final parts = t.whenParts(
    at != null && at.isNotEmpty ? at : story.date,
    now: now,
  );
  if (parts.isNotEmpty) return parts;
  // The website's own label, minus the weekday it starts with.
  final l = story.dateLabel;
  final label = l.contains(',') ? l.split(',').last.trim() : l;
  return label.isEmpty ? const [] : [label];
}

/// Opens a member's page from a story, when the member is in the list the
/// app holds (a story about someone no longer in the House opens nothing).
void openMemberBySlug(BuildContext context, String slug) {
  final brief = Api.instance.cached?.members
      .where((m) => m.slug == slug)
      .firstOrNull;
  if (brief == null) return;
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => MemberScreen(member: brief)));
}

/// An outlet's name, or its web address when the site has no name for it in
/// the reader's language (an English answer sends null rather than Bangla).
String outletLabel(String source, String url) {
  if (source.isNotEmpty) return source;
  final host = Uri.tryParse(url)?.host ?? '';
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// "ভিডিও", "প্রজ্ঞাপন" or "সংবাদ" in a small outlined box, as the website
/// marks a story's kind.
class KindBadge extends StatelessWidget {
  final String kind;
  const KindBadge(this.kind, {super.key});

  @override
  Widget build(BuildContext context) {
    final video = kind == 'video';
    final String label;
    if (video) {
      label = t('ভিডিও', 'Video');
    } else if (kind == 'press') {
      label = t('প্রজ্ঞাপন', 'Notification');
    } else {
      label = t('সংবাদ', 'News');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: video ? AppColors.brandRing : AppColors.rule),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'NotoSansBengali',
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: video ? AppColors.brand : AppColors.inkSoft,
          height: 1.35,
        ),
      ),
    );
  }
}

/// One headline, as the website's story card draws it: a "ভিডিও" or
/// "প্রজ্ঞাপন" mark, the outlet and when, the headline, the other outlets that
/// ran the same story (each opens there), and the members it is about (each
/// opens their page); the outlet's picture on the right where it published
/// one. A picture that will not load shows the outlet's initial instead of an
/// empty grey box.
class StoryCard extends StatelessWidget {
  final Story story;
  const StoryCard({super.key, required this.story});

  static const _whenStyle = TextStyle(
    fontFamily: 'NotoSansBengali',
    fontSize: 12,
    color: AppColors.muted,
    height: 1.3,
  );

  @override
  Widget build(BuildContext context) {
    final when = storyWhen(story);
    final length = durationBn(story.durationSeconds);
    // On English a member with no English name comes without one; the
    // Bangla is not shown in its place.
    final people = story.members.where((m) => m.name.isNotEmpty).toList();
    final source = story.lead.source;
    final marked = story.isVideo || story.kind == 'press';

    return Container(
      decoration: AppDecor.card(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openLink(context, story.lead.url),
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The outlet, then the date and time; with the time
                          // and "আগে" the line no longer fits a narrow card,
                          // so it wraps between its pieces.
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (marked) ...[
                                    KindBadge(story.kind),
                                    const SizedBox(width: 6),
                                  ],
                                  if (source.isNotEmpty)
                                    Flexible(
                                      child: Text(
                                        source,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'NotoSansBengali',
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.brand,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  if (when.isNotEmpty &&
                                      (source.isNotEmpty || marked))
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        left: 6,
                                        right: 2,
                                      ),
                                      child: Icon(
                                        Icons.circle,
                                        size: 3.5,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                ],
                              ),
                              for (final piece in when)
                                Text(piece, style: _whenStyle),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            story.lead.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'NotoSansBengali',
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (story.thumbnail != null || story.isVideo) ...[
                      const SizedBox(width: 12),
                      _thumbnail(length),
                    ],
                  ],
                ),
                if (story.also.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      'একই খবর আরও ${bn(story.also.length)}টি সংবাদমাধ্যমে',
                      'The same story in ${story.also.length} more ${plural(story.also.length, 'outlet', 'outlets')}',
                    ),
                    style: const TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final a in story.also)
                        _AlsoChip(
                          label: outletLabel(a.source, a.url),
                          onTap: () => openLink(context, a.url),
                        ),
                    ],
                  ),
                ],
                if (people.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final m in people.take(3))
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => openMemberBySlug(context, m.slug),
                          child: PartyChip(
                            abbr: m.party,
                            label: m.name,
                            compact: true,
                          ),
                        ),
                      if (people.length > 3)
                        Text(
                          t(
                            'আরও ${bn(people.length - 3)} জন',
                            '${people.length - 3} more',
                          ),
                          style: const TextStyle(
                            fontFamily: 'NotoSansBengali',
                            fontSize: 12.5,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _monogram() {
    final letter = story.lead.source.isEmpty
        ? '•'
        : story.lead.source.characters.first;
    return Container(
      color: AppColors.brandSoft,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontFamily: 'NotoSansBengali',
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.brand,
        ),
      ),
    );
  }

  Widget _thumbnail(String? length) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 96,
        height: 76,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (story.thumbnail != null)
              CachedNetworkImage(
                imageUrl: story.thumbnail!,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: AppColors.sunk),
                errorWidget: (_, _, _) => _monogram(),
              )
            else
              _monogram(),
            if (story.isVideo)
              Container(
                color: Colors.black.withValues(alpha: 0.18),
                alignment: Alignment.center,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 19,
                    color: Color(0xFFE62117),
                  ),
                ),
              ),
            if (length != null)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    length,
                    style: const TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Another outlet that ran the same story; opens it there.
class _AlsoChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AlsoChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.rule)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.inkSoft,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}
