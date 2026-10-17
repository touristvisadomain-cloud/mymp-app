import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n.dart';
import 'loading.dart';
import 'maps/google.dart';
import 'theme.dart';
import 'widgets.dart';

/// Google Play asks an app that shows government information to say, in the
/// app and in its listing, that it does not represent the government, and to
/// name where the information comes from. This file is that statement, in one
/// place.
///
/// Every source is listed by name with a working link, and with what it
/// supplies. The first submission was rejected on 21 September 2026
/// ("Insufficient Sources Provided") because the wording then said results came
/// "from published results" and named no one: a phrase that admits to more
/// sources than it lists is what the Misleading Claims policy objects to.
///
/// The English is a faithful rendering of the Bangla, sentence for sentence:
/// it must claim no more and no less than the Bangla does.

String get kNotOfficial => t(
  'আমার এমপি একটি স্বাধীন, বেসরকারি তথ্যসেবা। এটি বাংলাদেশ জাতীয় সংসদ, নির্বাচন কমিশন, মন্ত্রিপরিষদ বিভাগ '
      'বা সরকারের কোনো দপ্তরের অ্যাপ নয়, কোনো সরকারি প্রতিষ্ঠানের প্রতিনিধিত্ব করে না এবং কারও সঙ্গে যুক্তও নয়।',
  'My MP is an independent, non-governmental information service. It is not an app of the Parliament of '
      'Bangladesh, the Election Commission, the Cabinet Division or any government office; it does not represent '
      'any government body and is not affiliated with any.',
);

/// The same statement, short, for the notice the app opens with (owner,
/// 2026-10-17: the long one was too much to read before anything else). It
/// still says the two things Play asks for: not the government's, and not
/// affiliated with it.
String get kNotOfficialShort => t(
  'আমার এমপি একটি স্বাধীন, বেসরকারি তথ্যসেবা। এটি সরকারি অ্যাপ নয় এবং কোনো সরকারি প্রতিষ্ঠানের সঙ্গে যুক্ত নয়।',
  'My MP is an independent, non-governmental information service. It is not a government app and is not '
      'affiliated with any government body.',
);

typedef InfoSource = ({String label, String what, String url});

/// The government sources, as the reader can check them.
List<InfoSource> get kOfficialSources => [
  (
    label: t(
      'বাংলাদেশ জাতীয় সংসদ: parliament.gov.bd',
      'Parliament of Bangladesh: parliament.gov.bd',
    ),
    what: t(
      'সংসদ সদস্যদের নাম, ছবি, আসন, দল, যোগাযোগ, সংসদীয় কমিটি, অধিবেশন ও সংসদ সচিবালয়ের প্রজ্ঞাপন',
      'Members of Parliament’s names, photos, seats, parties and contact details; parliamentary committees, '
          'sessions and Parliament Secretariat notifications',
    ),
    url: 'https://www.parliament.gov.bd',
  ),
  (
    label: t(
      'বাংলাদেশ নির্বাচন কমিশন: ecs.gov.bd',
      'Bangladesh Election Commission: ecs.gov.bd',
    ),
    what: t(
      'নিবন্ধিত ভোটার ও ভোটকেন্দ্রের সংখ্যা',
      'Numbers of registered voters and polling centres',
    ),
    url: 'https://www.ecs.gov.bd',
  ),
  (
    label: t(
      'মন্ত্রিপরিষদ বিভাগ: cabinet.gov.bd',
      'Cabinet Division: cabinet.gov.bd',
    ),
    what: t(
      'মন্ত্রী, প্রতিমন্ত্রী ও উপদেষ্টাদের তালিকা, কে কোন মন্ত্রণালয়ে',
      'The list of Ministers, State Ministers and Advisers, and who holds which ministry',
    ),
    url: 'https://cabinet.gov.bd',
  ),
];

/// The sources that are not government offices. Each is also named where its
/// information appears: under a seat's result, under a biography.
List<InfoSource> get kOtherSources => [
  (
    label: t(
      'দ্য বিজনেস স্ট্যান্ডার্ড: tbsnews.net',
      'The Business Standard: tbsnews.net',
    ),
    what: t(
      '২০২৬ সালের নির্বাচনের আসনভিত্তিক ভোটের ফল',
      'Seat-by-seat results of the 2026 election',
    ),
    url: 'https://www.tbsnews.net',
  ),
  (
    label: t(
      'বাংলা উইকিপিডিয়া: bn.wikipedia.org',
      'Bangla Wikipedia: bn.wikipedia.org',
    ),
    what: t(
      'ভোটের ফল মিলিয়ে দেখা, দলের ইতিহাস, কিছু সদস্যের শিক্ষা, জন্মস্থান ও জীবনী',
      'Cross-checking the election results; party histories; some members’ education, birthplaces and biographies',
    ),
    url: 'https://bn.wikipedia.org',
  ),
  (
    label: t(
      'ইংরেজি উইকিপিডিয়া: en.wikipedia.org',
      'English Wikipedia: en.wikipedia.org',
    ),
    what: t(
      'কিছু সদস্যের শিক্ষা, জন্মস্থান ও জীবনী',
      'Some members’ education, birthplaces and biographies',
    ),
    url: 'https://en.wikipedia.org',
  ),
];

String get kNewsLine => t(
  'সংবাদ অংশের প্রতিটি শিরোনামের পাশে সংবাদমাধ্যমের নাম লেখা থাকে; চাপ দিলে সেই সংবাদমাধ্যমের নিজের সাইটে খোলে। '
      'শিরোনাম আসে দেশি-বিদেশি সংবাদমাধ্যম থেকে; ভিডিও আসে শুধু এই সংবাদমাধ্যমগুলোর নিজস্ব ইউটিউব চ্যানেল থেকে। '
      'অ্যাপ নিজে কোনো সংবাদ লেখে না।',
  'In the News section, every headline is shown with the name of its news outlet; tapping it opens the story '
      'on that outlet’s own site. Headlines come from news outlets in Bangladesh and abroad; videos come only '
      'from these outlets’ own YouTube channels. The app itself writes no news. On the English screens the '
      'headlines are translated automatically from Bangla by Google Translate (on the website’s server; the app '
      'sends nothing), so they may read awkwardly; a headline not yet translated is shown in Bangla, and opening '
      'a story shows the original.',
);

TextStyle _bn(double size, FontWeight weight, Color color, {double? height}) =>
    TextStyle(
      fontFamily: 'NotoSansBengali',
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );

class _SourceRow extends StatelessWidget {
  const _SourceRow(this.source, {required this.icon});
  final InfoSource source;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openLink(context, source.url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 17, color: AppColors.brand),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.label,
                    style: _bn(13.5, FontWeight.w600, AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    source.what,
                    style: _bn(
                      12,
                      FontWeight.w400,
                      AppColors.muted,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _groupTitle(String text) => Padding(
  padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
  child: Text(text, style: _bn(12, FontWeight.w700, AppColors.muted)),
);

/// Google's privacy policy, which governs what its map service receives.
const kGooglePrivacyUrl = 'https://policies.google.com/privacy';

/// The maps, said plainly (owner, 2026-10-17): Google's, with what that
/// means. Shown only by a build whose maps are Google's (lib/maps/google.dart);
/// a build without a key draws its own maps and sends nothing to Google.
String get kMapsLine => t(
  'অ্যাপের মানচিত্রগুলো Google Maps-এর। আসন ও জেলার সীমানা আমার এমপির নিজের (OpenStreetMap, OCHA ও geoBoundaries-এর মানচিত্র থেকে), '
      'Google-এর মানচিত্রের ওপর আঁকা। মানচিত্র দেখানোর জন্য Google আপনার ফোন থেকে সাধারণ কারিগরি তথ্য পায় (যেমন IP ঠিকানা, '
      'ফোন ও অ্যাপের ধরন), যা Google-এর গোপনীয়তা নীতির অধীন। অ্যাপ নিজে কোনো অ্যাকাউন্ট খোলায় না, কিছু সংগ্রহ করে না, '
      'আপনার অবস্থানও জানতে চায় না।',
  'The app’s maps are Google Maps. The seat and district boundaries are My MP’s own (from the maps of OpenStreetMap, OCHA '
      'and geoBoundaries), drawn over Google’s map. To show the maps, Google receives the usual technical data from your phone '
      '(such as its IP address and the kind of phone and app), under Google’s privacy policy. The app itself has no account, '
      'collects nothing and does not ask where you are.',
);

/// Every source, grouped, each one a link. Used by the card on the "আরও" tab,
/// by the first-open notice and by the sheet the home screen's footnote opens.
class SourceList extends StatelessWidget {
  const SourceList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _groupTitle(t('সরকারি সূত্র', 'Government sources')),
        for (final s in kOfficialSources)
          _SourceRow(s, icon: Icons.account_balance_outlined),
        _groupTitle(t('অন্যান্য সূত্র', 'Other sources')),
        for (final s in kOtherSources)
          _SourceRow(s, icon: Icons.menu_book_outlined),
        Padding(
          padding: EdgeInsets.fromLTRB(14, 8, 14, GoogleMaps.enabled ? 0 : 12),
          child: Text(
            kNewsLine,
            style: _bn(12, FontWeight.w400, AppColors.muted, height: 1.5),
          ),
        ),
        if (GoogleMaps.enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Text(
              kMapsLine,
              style: _bn(12, FontWeight.w400, AppColors.muted, height: 1.5),
            ),
          ),
      ],
    );
  }
}

/// The sources on one line each, name and address, still a link: for the
/// first-open notice. The Business Standard (the seat results) is left out
/// here at the owner's wish (2026-10-17); it stays on the "আরও" tab and under
/// every seat's result, and the last line says the full list is there, so the
/// notice never reads as the whole list.
class SourceLinks extends StatelessWidget {
  const SourceLinks({super.key});

  @override
  Widget build(BuildContext context) {
    Widget row(InfoSource s, IconData icon) => InkWell(
      onTap: () => openLink(context, s.url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.brand),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.label,
                style: _bn(13, FontWeight.w600, AppColors.ink),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.open_in_new_rounded,
              size: 15,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _groupTitle(t('তথ্যের সূত্র', 'Sources')),
        for (final s in kOfficialSources)
          row(s, Icons.account_balance_outlined),
        for (final s in kOtherSources)
          if (!s.url.contains('tbsnews.net')) row(s, Icons.menu_book_outlined),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Text(
            t(
              'ভোটের ফলের সূত্রসহ সব সূত্রের তালিকা, আর কোনটি থেকে কী তথ্য: আরও ট্যাবে।',
              'The full list of sources, including the source of the election results, and what each '
                  'supplies: on the More tab.',
            ),
            style: _bn(12, FontWeight.w400, AppColors.muted, height: 1.45),
          ),
        ),
      ],
    );
  }
}

/// The statement with every source as a link, for the "আরও" tab.
class DisclaimerCard extends StatelessWidget {
  const DisclaimerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecor.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            color: AppColors.warnSoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.verified_user_outlined,
                    size: 19,
                    color: AppColors.warn,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t(
                      'স্বাধীন, বেসরকারি তথ্যসেবা। সংসদ, নির্বাচন কমিশন বা সরকারের কোনো দপ্তরের অ্যাপ নয়, কোনো সরকারি প্রতিষ্ঠানের প্রতিনিধিত্ব করে না।',
                      'An independent, non-governmental information service. Not an app of Parliament, the Election '
                          'Commission or any government office, and does not represent any government body.',
                    ),
                    style: _bn(
                      13.5,
                      FontWeight.w600,
                      AppColors.ink,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SourceList(),
        ],
      ),
    );
  }
}

/// The same statement and sources as a sheet, from anywhere in the app.
Future<void> showSourcesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Text(
                t('তথ্যের সূত্র', 'Sources'),
                style: _bn(18, FontWeight.w700, AppColors.ink),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: Text(
                kNotOfficial,
                style: _bn(13, FontWeight.w400, AppColors.ink, height: 1.55),
              ),
            ),
            const SourceList(),
          ],
        ),
      ),
    ),
  );
}

/// Shown once, the first time the app opens, before anything else is read:
/// what the app is not, and every source it draws on, each one a link; short,
/// with the details on the "আরও" tab.
Future<void> showDisclaimerOnce(BuildContext context) async {
  // v2: the sources are now listed one by one (Play review, 21 September 2026).
  const key = 'not_official_notice_v2';
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(key) == true || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      // The reader's language can be chosen here, before anything else is
      // read: the dialog redraws in place.
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              t('আমার এমপি সম্পর্কে', 'About My MP'),
              style: _bn(19, FontWeight.w700, AppColors.ink),
            ),
          ),
          const SizedBox(width: 8),
          const LangSwitch(compact: true),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  kNotOfficialShort,
                  style: _bn(14, FontWeight.w500, AppColors.ink, height: 1.55),
                ),
              ),
              const SizedBox(height: 4),
              const SourceLinks(),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            t('বুঝেছি', 'I understand'),
            style: _bn(14.5, FontWeight.w700, Colors.white),
          ),
        ),
      ],
    ),
  );
  await prefs.setBool(key, true);
}
