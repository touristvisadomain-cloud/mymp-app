import 'package:flutter/material.dart';

import '../api.dart';
import '../brand_header.dart';
import '../i18n.dart';
import '../loading.dart';
import '../models.dart';
import '../widgets.dart';
import 'story_list.dart';
import 'video_strip.dart';

/// The whole house's news: every headline and video the site has attached to a
/// member, newest first, with a filter for news or videos alone. The unfiltered
/// view opens with a row of the newest member videos, as the website's home does.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen>
    with RefetchOnLang<NewsScreen> {
  String? _type;
  late Future<List<Story>> _future = Api.instance.news(type: 'news');
  late Future<List<Story>> _videos = Api.instance.news(
    type: 'video',
    limit: 30,
  );

  void _load({String? type}) {
    setState(() {
      _type = type;
      // "সব" shows the video row and then the news; the video chip shows videos only.
      _future = Api.instance.news(type: type ?? 'news');
      if (type == null) _videos = Api.instance.news(type: 'video', limit: 30);
    });
  }

  /// Headlines stay in Bangla, but the outlets and members beside them change.
  @override
  void onLangChanged() => _load(type: _type);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          BrandHeader(
            title: t('সংবাদ', 'News'),
            subtitle: t(
              'সংসদ সদস্যদের নিয়ে শিরোনাম ও ভিডিও',
              'Headlines and videos about MPs',
            ),
            bottom: ChipBar(
              onDark: true,
              padding: EdgeInsets.zero,
              options: [
                (label: t('সব', 'All'), value: null),
                (label: t('সংবাদ', 'News'), value: 'news'),
                (label: t('ভিডিও', 'Videos'), value: 'video'),
              ],
              selected: _type,
              onSelect: (v) => _load(type: v),
            ),
          ),
          Expanded(
            child: StoryList(
              // A new filter starts clean; a refresh keeps the stories on screen.
              key: ValueKey(_type),
              future: _future,
              header: _type == null
                  ? FutureBuilder<List<Story>>(
                      future: _videos,
                      // The row is extra: if videos fail to load, the news below still shows.
                      builder: (context, snap) => snap.hasData
                          ? VideoStrip(
                              videos: snap.data!,
                              onSeeAll: () => _load(type: 'video'),
                            )
                          : const SizedBox.shrink(),
                    )
                  : null,
              emptyTitle: t('এখন কোনো খবর নেই', 'No news right now'),
              emptyBody: t(
                'নতুন শিরোনাম এলে এখানে দেখা যাবে।',
                'New headlines will appear here.',
              ),
              onRetry: () => _load(type: _type),
              onRefresh: () async {
                _load(type: _type);
                await settle(_future);
              },
            ),
          ),
        ],
      ),
    );
  }
}
