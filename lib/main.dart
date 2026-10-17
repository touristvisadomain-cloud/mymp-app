import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'disclaimer.dart';
import 'i18n.dart';
import 'screens/cabinet_screen.dart';
import 'screens/district_screen.dart';
import 'screens/election_parts.dart';
import 'screens/member_screen.dart';
import 'screens/members_screen.dart';
import 'screens/more_screen.dart';
import 'screens/news_screen.dart';
import 'screens/party_screen.dart';
import 'screens/reserved_screen.dart';
import 'screens/seat_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The reader's language before the first frame, so an English reader never
  // sees a flash of Bangla.
  await appLang.load();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  _wireLinks();
  runApp(const LangRoot(child: MyMpApp()));
}

/// Where a member's page links to: the app's own party, seat and district
/// screens (the page leaves a link out while its hook is unset).
void _wireLinks() {
  void open(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));
  MemberLinks.party = (context, slug) => open(context, PartyScreen.slug(slug));
  MemberLinks.seat = (context, slug) => open(context, SeatScreen(slug: slug));
  MemberLinks.district = (context, slug) =>
      open(context, DistrictScreen(slug: slug));
  // And the election page's.
  ElectionLinks.seat = MemberLinks.seat;
  ElectionLinks.district = MemberLinks.district;
  ElectionLinks.party = MemberLinks.party;
  ElectionLinks.reserved = (context) => open(context, const ReservedScreen());
}

class MyMpApp extends StatelessWidget {
  const MyMpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: t('আমার এমপি', 'My MP'),
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const Shell(),
      builder: (context, child) {
        // A reader who has made the system font large gets it, up to a point:
        // past 1.3 the Bengali headlines start breaking mid-word inside cards.
        final scale = MediaQuery.textScalerOf(
          context,
        ).clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3);
        final media = MediaQuery.of(context).copyWith(textScaler: scale);
        // On a tablet or a wide window the app keeps a phone's column, centred:
        // stretched across 1000 pixels a member card was one long thin line.
        const maxWidth = 600.0;
        if (media.size.width <= maxWidth) {
          return MediaQuery(data: media, child: child!);
        }
        return ColoredBox(
          color: const Color(0xFFE6E9E4),
          child: Center(
            child: ClipRect(
              child: SizedBox(
                width: maxWidth,
                child: MediaQuery(
                  data: media.copyWith(size: Size(maxWidth, media.size.height)),
                  child: child!,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  // Held in an IndexedStack, so a reader who scrolled the member list halfway
  // down and went to look at the news comes back to where they were.
  // The cabinet's "all members" chip switches to the members tab, and the
  // members tab's cabinet fact to the cabinet.
  late final _screens = [
    MembersScreen(onShowCabinet: () => setState(() => _index = 2)),
    const NewsScreen(),
    CabinetScreen(onShowMembers: () => setState(() => _index = 0)),
    const MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Once, on first launch: this is not a government app, and where its information comes from.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => showDisclaimerOnce(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Back on any other tab returns to the member list, as Android readers
    // expect; only from the first tab does it leave the app.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) setState(() => _index = 0);
      },
      child: _scaffold(),
    );
  }

  Widget _scaffold() {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.rule)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.groups_outlined),
              selectedIcon: const Icon(Icons.groups_rounded),
              label: t('সংসদ সদস্য', 'MPs'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.article_outlined),
              selectedIcon: const Icon(Icons.article_rounded),
              label: t('সংবাদ', 'News'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.account_balance_outlined),
              selectedIcon: const Icon(Icons.account_balance_rounded),
              label: t('মন্ত্রিসভা', 'Cabinet'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.more_horiz_rounded),
              selectedIcon: const Icon(Icons.more_horiz_rounded),
              label: t('আরও', 'More'),
            ),
          ],
        ),
      ),
    );
  }
}
