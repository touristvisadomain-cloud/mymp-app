import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../bn.dart';
import '../i18n.dart';
import '../loading.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'story_list.dart';

/// A channel's hourly bulletin names the Prime Minister in passing; it is not a
/// video about a member, so it goes after the ones that are.
final _bulletin = RegExp(
  r'headlines|bulletin|শিরোনাম|২৪\s*ঘণ্টা|\bnews at\b|\blive\b|সরাসরি',
  caseSensitive: false,
);

/// Newest first, but varied: videos about a member before bulletins, and at most
/// two about the same member, so one busy day does not fill the row. The same
/// rule the website's home page uses.
List<Story> pickVideos(List<Story> videos, {int count = 8}) {
  final withPicture = videos.where((v) => v.thumbnail != null).toList();
  final ordered = [
    ...withPicture.where((v) => !_bulletin.hasMatch(v.lead.title)),
    ...withPicture.where((v) => _bulletin.hasMatch(v.lead.title)),
  ];
  final perMember = <String, int>{};
  final out = <Story>[];
  for (final v in ordered) {
    final key = v.members.isNotEmpty ? v.members.first.slug : v.id;
    if ((perMember[key] ?? 0) >= 2) continue;
    perMember[key] = (perMember[key] ?? 0) + 1;
    out.add(v);
    if (out.length == count) break;
  }
  return out;
}

/// The newest videos as a row that scrolls sideways, above the news list, as
/// the website's news page has it: "ভিডিও", how many of the newest stories
/// are videos, and the first six. A card opens the video on the channel that
/// published it; the app links to a broadcaster's video and never hosts or
/// embeds it.
class VideoStrip extends StatelessWidget {
  final List<Story> videos;
  final VoidCallback onSeeAll;
  const VideoStrip({super.key, required this.videos, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final shown = videos.take(6).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: t('ভিডিও', 'Videos')),
                    const TextSpan(text: '  '),
                    TextSpan(
                      text: t(
                        '${bn(videos.length)}টি সর্বশেষ',
                        'latest ${videos.length}',
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brand,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: Text(
                t('সব ভিডিও', 'All videos'),
                style: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 204,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: shown.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _VideoCard(story: shown[i]),
          ),
        ),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  final Story story;
  const _VideoCard({required this.story});

  @override
  Widget build(BuildContext context) {
    final length = durationBn(story.durationSeconds);
    final person = story.members.where((m) => m.name.isNotEmpty).firstOrNull;
    return Container(
      width: 262,
      decoration: AppDecor.card(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openLink(context, story.lead.url),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 158,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (story.thumbnail case final thumb?)
                      ClipRect(
                        child: Transform.scale(
                          scale: thumb.contains('ytimg.com') ? 1.22 : 1.0,
                          child: CachedNetworkImage(
                            imageUrl: thumb,
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                Container(color: AppColors.sunk),
                            errorWidget: (_, _, _) =>
                                Container(color: AppColors.brandDark),
                          ),
                        ),
                      )
                    else
                      Container(color: AppColors.brandDark),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00000000),
                            Color(0x22000000),
                            Color(0xD9000000),
                          ],
                          stops: [0, 0.4, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE62117),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              t('ভিডিও', 'Video'),
                              style: const TextStyle(
                                fontFamily: 'NotoSansBengali',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (length != null)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
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
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Text(
                        story.lead.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // The footer takes the rest of the card, its line centred in it.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: person != null
                            ? GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () =>
                                    openMemberBySlug(context, person.slug),
                                child: PartyChip(
                                  abbr: person.party,
                                  label: person.name,
                                  compact: true,
                                ),
                              )
                            : Text(
                                story.lead.source,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          story.lead.source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFamily: 'NotoSansBengali',
                            fontSize: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
