import 'package:flutter/material.dart';

import 'i18n.dart';
import 'theme.dart';

/// The parties whose logo ships with the app, the same files the website shows
/// (Wikimedia Commons and Bangla Wikipedia; credited on the আরও tab). Bundled,
/// so a party's mark is there with no signal.
const _logos = {
  'BNP': 'assets/party/bnp.png',
  'BJEI': 'assets/party/bjei.png',
  'NCP': 'assets/party/ncp.png',
  'BKM': 'assets/party/bkm.png',
  'IMB': 'assets/party/imb.png',
  'GOP': 'assets/party/gop.png',
  'BJP': 'assets/party/bjp.png',
  'KM': 'assets/party/km.png',
  'PSM': 'assets/party/psm.png',
  'JAGPA': 'assets/party/jagpa.png',
};

/// The 2026 results spell two parties differently from the parliament.
const _aliases = {'IAB': 'IMB', 'GSA': 'PSM'};

bool hasPartyLogo(String? abbr) =>
    abbr != null && _logos.containsKey(_aliases[abbr] ?? abbr);

/// A party beside its name: its logo where one is on record, a person for an
/// independent, the party colour for anyone else. Always a square of [size],
/// so names in a list line up.
class PartyLogo extends StatelessWidget {
  final String? abbr;
  final double size;
  const PartyLogo({super.key, required this.abbr, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final key = _aliases[abbr] ?? abbr;
    final asset = _logos[key];
    if (asset != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          semanticLabel: null,
          excludeFromSemantics: true,
        ),
      );
    }
    if (abbr == 'Ind') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.party(abbr).withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person_rounded,
          size: size * 0.72,
          color: AppColors.party(abbr),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Container(
          width: size * 0.5,
          height: size * 0.5,
          decoration: BoxDecoration(
            color: AppColors.party(abbr),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Where the logos came from; three of them are CC BY and must name their author.
String get partyLogoCredit => t(
  'দলের লোগো উইকিমিডিয়া কমন্স ও বাংলা উইকিপিডিয়া থেকে, শুধু দল চেনানোর জন্য। '
      'বিজেপির লোগো: Darkedgeblood (CC BY-SA 4.0); খেলাফত মজলিস: Emad.najid (CC BY 4.0); '
      'গণসংহতি আন্দোলন: NahidHossain (CC BY-SA 4.0); বিএনপি CC0; অন্যগুলো পাবলিক ডোমেইন বা অ-মুক্ত লোগো।',
  'Party logos are from Wikimedia Commons and Bangla Wikipedia, used only to identify the parties. '
      'BJP logo: Darkedgeblood (CC BY-SA 4.0); Khelafat Majlis: Emad.najid (CC BY 4.0); '
      'Ganosamhati Andolan: NahidHossain (CC BY-SA 4.0); BNP CC0; the others are public domain or non-free logos.',
);
