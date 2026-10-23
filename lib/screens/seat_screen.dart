import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../data/places.dart';
import '../i18n.dart';
import '../loading.dart';
import '../maps/seat_map.dart';
import '../models.dart';
import '../party_logo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'place_widgets.dart';

/// One constituency (the website's /ason/{slug}): who its member is, in the
/// sentence people search for ("ঢাকা-১৪ আসনের এমপি কে?"), the member's card
/// or that the seat is vacant, the seat's area and map, who held it before,
/// every published result, and the district's other seats.
class SeatScreen extends StatefulWidget {
  final String slug;
  const SeatScreen({super.key, required this.slug});

  @override
  State<SeatScreen> createState() => _SeatScreenState();
}

typedef _Data = ({SeatDetail seat, Bootstrap boot});

class _SeatScreenState extends State<SeatScreen>
    with RefetchOnLang<SeatScreen> {
  late Future<_Data> _future = _load();

  Future<_Data> _load() async {
    final r = await Future.wait([
      fetchSeat(widget.slug),
      Api.instance.loadBootstrap(),
    ]);
    return (seat: r[0] as SeatDetail, boot: r[1] as Bootstrap);
  }

  @override
  void onLangChanged() => setState(() => _future = _load());

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    await settle(f);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Data>(
      future: _future,
      builder: (context, snap) {
        final d = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(d?.seat.seat.name ?? t('আসন', 'Seat')),
            actions: [
              if (d != null)
                IconButton(
                  tooltip: t('শেয়ার', 'Share'),
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text:
                          '${_answer(d).sentence}\n${Api.page('/ason/${widget.slug}')}',
                      subject: d.seat.seat.name,
                    ),
                  ),
                ),
            ],
          ),
          body: Loaded<_Data>(
            future: _future,
            onRetry: () => setState(() => _future = _load()),
            builder: (context, d) => RefreshIndicator(
              color: AppColors.brand,
              onRefresh: _refresh,
              child: _body(context, d),
            ),
          ),
        );
      },
    );
  }

  /// The sentence that answers "who is the MP for this seat?", the same way
  /// the website's lede says it.
  ({String sentence}) _answer(_Data d) {
    final s = d.seat.seat;
    final m = d.seat.member;
    final seat = s.name;
    final abbr = m?.party;
    final party = abbr == null
        ? null
        : d.boot.parties.where((p) => p.abbr == abbr).firstOrNull?.nameBn ??
              m?.partyBn ??
              abbr;
    if (t.en) {
      final where = s.reserved ? seat : 'the $seat constituency';
      if (m == null) {
        final label = s.reserved ? seat : 'The $seat seat';
        return (
          sentence:
              '$label ${s.vacantSince != null ? 'has been vacant since ${t.date(s.vacantSince)}' : 'is vacant at present'}; it has no member in the 13th Parliament.',
        );
      }
      return (
        sentence:
            'In the 13th Parliament, the Member of Parliament for $where is ${m.nameBn}${party != null ? ', $party' : ''}.',
      );
    }
    final where = s.reserved ? '$seat-এর' : '$seat আসনের';
    if (m == null) {
      return (
        sentence:
            '$where আসনটি ${s.vacantSince != null ? '${t.date(s.vacantSince)} থেকে শূন্য' : 'এখন শূন্য'}; ত্রয়োদশ জাতীয় সংসদে এখানে কোনো সদস্য নেই।',
      );
    }
    return (
      sentence:
          'ত্রয়োদশ জাতীয় সংসদে $where সংসদ সদস্য ${m.nameBn}${party != null ? ', $party' : ''}।',
    );
  }

  Widget _body(BuildContext context, _Data d) {
    final detail = d.seat;
    final s = detail.seat;
    final text = Theme.of(context).textTheme;
    final vacant = s.vacant || detail.member == null;
    // The card shows the member listed for the seat: the sitting one, or the
    // one who resigned while the seat waits for a new member.
    final card = detail.member ?? detail.resignedMember;
    final districtSlug = s.districtSlug;
    final districtName = s.districtBn;
    final bnPath = '/ason/${s.slug}';
    final partyNames = {for (final p in d.boot.parties) p.abbr: p.nameBn};
    final otherName = t.en ? s.nameAlt : s.nameEn;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pagePad,
        12,
        AppSizes.pagePad,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        PlaceHero(
          eyebrow: t('ত্রয়োদশ জাতীয় সংসদ', '13th Parliament'),
          title: s.name,
          subtitle: [
            ?otherName,
            if (s.reserved)
              t('সংরক্ষিত নারী আসন', 'Reserved seat for women')
            else if (districtName != null)
              t('$districtName জেলা', '$districtName district'),
          ].join(' · '),
          lede: _answer(d).sentence,
        ),

        SectionHeading(
          vacant
              ? t('আসনটি শূন্য', 'The seat is vacant')
              : t('বর্তমান সংসদ সদস্য', 'Current Member of Parliament'),
        ),
        if (s.vacantSince != null && detail.resignedMember != null) ...[
          Text(
            t(
              'এই আসনে নির্বাচিত ${detail.resignedMember!.nameBn} ${t.date(s.vacantSince)} তারিখে পদত্যাগ করেছেন (সংসদ সচিবালয়ের তথ্য অনুযায়ী)। নতুন সদস্য নির্বাচিত হলে এখানে দেখা যাবে।',
              '${detail.resignedMember!.nameBn}, elected for this seat, resigned on ${t.date(s.vacantSince)} (according to the Parliament Secretariat). A new member will be shown here once elected.',
            ),
            style: text.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 12),
        ],
        if (card != null)
          _MemberCard(member: card, partyName: partyNames[card.party])
        else
          NoteBox(
            title: t(
              'সংসদের সদস্য তালিকায় এই আসনের কোনো সদস্য নেই।',
              "Parliament's list of members has no member for this seat.",
            ),
            body: t(
              'সংসদ সচিবালয় এই আসনে কাউকে সদস্য হিসেবে তালিকাভুক্ত করেনি; কারণ তাদের তথ্যভান্ডারে লেখা নেই। সদস্য যুক্ত হলে এখানে দেখা যাবে।',
              'The Parliament Secretariat has not listed anyone as the member for this seat; its database does not give the reason. A member will be shown here once one is added.',
            ),
          ),

        // A seat's area: the Election Commission's words, in Bangla, or
        // translated, or (on English, untranslated) a pointer to the Bangla.
        if (!s.reserved && (s.boundaryBn != null || t.en)) ...[
          SectionHeading(t('আসনের এলাকা', 'Area of the seat')),
          PlaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s.boundaryBn != null)
                  Text(
                    s.boundaryBn!,
                    style: text.bodyLarge?.copyWith(height: 1.65),
                  )
                else
                  InkWell(
                    onTap: () => openLink(context, '${Api.base}$bnPath'),
                    child: Text.rich(
                      const TextSpan(
                        text:
                            "The Election Commission's description of this seat's area is available in Bangla. ",
                        children: [
                          TextSpan(
                            text: 'Read it on the Bangla page',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                            ),
                          ),
                        ],
                      ),
                      style: text.bodyLarge?.copyWith(height: 1.65),
                    ),
                  ),
                if (s.boundaryBn != null && s.boundaryTranslated)
                  TranslatedNote(bnPath: bnPath),
              ],
            ),
          ),
          if (districtSlug != null) ...[
            const SizedBox(height: 12),
            SeatMap(
              districtSlug: districtSlug,
              seatSlug: s.slug,
              color: partyColour(card?.party),
              title: s.name,
              districtName: districtName,
            ),
          ],
        ],

        if (!s.reserved) ..._holders(context, detail),

        SectionHeading(t('নির্বাচনের ফল', 'Election results')),
        if (detail.results.isEmpty)
          NoteBox(
            title: t(
              'এই আসনের প্রার্থী তালিকা ও ভোটের সংখ্যা এখনো যোগ করা হয়নি।',
              'The list of candidates and the vote counts for this seat have not been added yet.',
            ),
            body: t(
              'সংসদের তথ্যভান্ডারে ভোটের সংখ্যা নেই। নির্বাচন কমিশনের গেজেট থেকে প্রার্থী ও প্রাপ্ত ভোট যাচাই করে যোগ করা হয়; যাচাই করা সংখ্যা ছাড়া কিছু দেখানো হবে না।',
              "Parliament's database has no vote counts. Candidates and the votes they received are added after checking them against the Election Commission's gazette; nothing is shown without checked figures.",
            ),
          )
        else
          for (final r in detail.results) ...[
            ResultCard(result: r),
            const SizedBox(height: 12),
          ],

        SectionHeading(t('আসন তথ্য', 'About the seat')),
        PlaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              InfoRow(label: t('আসন নম্বর', 'Seat number'), value: t.n(s.no)),
              if (districtSlug != null && districtName != null)
                InfoRow(
                  label: t('জেলা', 'District'),
                  value: districtName,
                  onTap: () => openDistrict(context, districtSlug),
                ),
              InfoRow(
                label: t('ধরন', 'Type'),
                value: s.reserved
                    ? t('সংরক্ষিত নারী আসন', 'Reserved seat for women')
                    : t('সাধারণ আসন', 'General seat'),
                last: true,
              ),
            ],
          ),
        ),

        if (detail.neighbours.isNotEmpty) ...[
          SectionHeading(
            t('$districtName জেলার আসন', 'Seats in $districtName district'),
          ),
          PlaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              children: [
                for (final n in detail.neighbours)
                  _NeighbourRow(
                    seat: n,
                    partyName: partyNames[n.member?.party],
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),
        SourceBox(
          text: t('বাংলাদেশ জাতীয় সংসদ।', 'Parliament of Bangladesh.'),
        ),
      ],
    );
  }

  List<Widget> _holders(BuildContext context, SeatDetail detail) {
    final holders = detail.holders;
    final text = Theme.of(context).textTheme;
    return [
      SectionHeading(
        t('এই আসনের আগের সদস্যরা', 'Earlier members for this seat'),
        count: holders.isEmpty ? null : '(${t.n(holders.length)})',
      ),
      if (holders.isEmpty)
        NoteBox(
          title: t(
            'সংসদের তথ্যভান্ডারে এই আসনের আগের সদস্যদের রেকর্ড পাওয়া যায়নি।',
            "No record of earlier members for this seat was found in Parliament's database.",
          ),
          body: t(
            'আসনটি একই জেলায় একই নম্বরে থাকলে তবেই আগের সংসদের সদস্যকে এখানে দেখানো হয়।',
            'A member of an earlier Parliament is shown here only when the seat had the same number in the same district.',
          ),
        )
      else ...[
        PlaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, h) in holders.indexed)
                _HolderRow(holder: h, last: i == holders.length - 1),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t(
                'সংসদের তথ্যভান্ডারে ৪র্থ, ৫ম ও ৭ম থেকে ১২শ সংসদের রেকর্ড আছে; ১ম থেকে ৩য় ও ৬ষ্ঠ সংসদের তালিকা সেখানে নেই।',
                "Parliament's database has the records of the 4th, 5th and 7th to 12th Parliaments; the lists of the 1st to 3rd and the 6th Parliaments are not in it.",
              ) +
              (detail.oldBoundary
                  ? t(
                      ' ২০০৮ সালের সীমানা পুনর্নির্ধারণের আগের আসনগুলো একই নম্বরের হলেও এলাকা ভিন্ন হতে পারে।',
                      ' Seats from before the 2008 redrawing of constituency boundaries may have covered a different area, even under the same number.',
                    )
                  : ''),
          style: text.labelSmall?.copyWith(height: 1.55),
        ),
      ],
    ];
  }
}

/// The member's card: photograph, name, party; opens the profile.
class _MemberCard extends StatelessWidget {
  final MemberBrief member;
  final String? partyName;
  const _MemberCard({required this.member, this.partyName});

  @override
  Widget build(BuildContext context) {
    final colour = partyColour(member.party);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => openMember(context, member),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colour, width: 1.5),
          ),
          child: Row(
            children: [
              MemberAvatar(member: member, size: 68),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.nameBn,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (member.party != null)
                      Row(
                        children: [
                          PartyLogo(abbr: member.party, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              partyName ?? member.partyBn ?? member.party!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    Text(
                      t('প্রোফাইল →', 'Profile →'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One earlier member: the parliament and party on a small line, the name
/// under it (a link when they sit in this parliament).
class _HolderRow extends StatelessWidget {
  final SeatHolder holder;
  final bool last;
  const _HolderRow({required this.holder, required this.last});

  @override
  Widget build(BuildContext context) {
    final h = holder;
    final cur = h.member;
    // A sitting member is shown under the name the site uses for them; the
    // source's own spelling for that year stays underneath.
    final String name;
    final String? sub;
    if (t.en) {
      name =
          cur?.nameBn ??
          h.nameBn ??
          titleCaseName(h.nameEn) ??
          'Name not recorded';
      sub = cur != null ? titleCaseName(h.nameEn) : null;
    } else {
      name = cur?.nameBn ?? h.nameBn ?? h.nameEn ?? 'নাম নেই';
      sub = cur != null
          ? titleCaseName(h.nameEn) ?? h.nameBn
          : h.nameBn != null
          ? titleCaseName(h.nameEn)
          : null;
    }
    final party = h.partyBn ?? h.partyAbbr ?? t('দল নেই', 'No party');
    return InkWell(
      onTap: cur == null ? null : () => openMember(context, cur),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.ruleSoft)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  h.labelBn,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PartyLogo(abbr: h.partyAbbr, size: 16),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          party,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cur != null ? AppColors.brand : AppColors.ink,
              ),
            ),
            if (sub != null && sub != name)
              Text(
                sub,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _NeighbourRow extends StatelessWidget {
  final SeatLink seat;
  final String? partyName;
  const _NeighbourRow({required this.seat, this.partyName});

  @override
  Widget build(BuildContext context) {
    final m = seat.member;
    return InkWell(
      onTap: () => openSeat(context, seat.slug),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            Text(
              seat.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 12),
            if (m != null) ...[
              Expanded(
                child: Text(
                  m.nameBn,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: AppColors.muted),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: partyName ?? m.party ?? '',
                child: PartyLogo(abbr: m.party, size: 18),
              ),
            ] else
              const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// One election's result for one seat, as the website's ResultCard draws it:
/// every candidate, votes and share, the winner marked, and where the figures
/// were read.
class ResultCard extends StatelessWidget {
  final ElectionResult result;
  const ResultCard({super.key, required this.result});

  /// The link's label, as the website's sourceOf names it.
  static String _linkLabel(String url) {
    if (RegExp('wikipedia\\.org', caseSensitive: false).hasMatch(url)) {
      return t('উইকিপিডিয়া', 'Wikipedia');
    }
    if (RegExp('tbsnews\\.net', caseSensitive: false).hasMatch(url)) {
      return t('মূল পাতা', 'Original page');
    }
    return t('গেজেট', 'Gazette');
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    final list = r.candidates;
    final cast = r.totalVotes ?? list.fold<int>(0, (n, c) => n + c.votes);
    final top = list.isEmpty || list.first.votes == 0 ? 1 : list.first.votes;
    final votesLine = [
      if (cast > 0)
        r.totalVotes != null
            ? t('${t.group(cast)} ভোট', '${t.group(cast)} votes')
            : t(
                'প্রার্থীদের মোট ${t.group(cast)} ভোট',
                "Candidates' total: ${t.group(cast)} votes",
              ),
    ].join();
    final turnout = r.turnout == null
        ? ''
        : t(', ভোট পড়েছে ${t.n(r.turnout)}%', ', turnout ${t.n(r.turnout)}%');
    final note = r.noteBn;
    final url = r.sourceUrl;

    return Container(
      width: double.infinity,
      decoration: AppDecor.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.labelBn, style: Theme.of(context).textTheme.titleMedium),
                if (votesLine.isNotEmpty || turnout.isNotEmpty)
                  Text(
                    '$votesLine$turnout',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final (i, c) in list.indexed)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                border: i == list.length - 1
                    ? null
                    : const Border(
                        bottom: BorderSide(color: AppColors.ruleSoft),
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name.isEmpty ? t('নাম নেই', 'Name not recorded') : c.name,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.ink,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (c.party != null)
                        Container(
                          padding: const EdgeInsets.fromLTRB(5, 2, 8, 2),
                          decoration: BoxDecoration(
                            color: AppColors.sunk,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PartyLogo(abbr: c.party, size: 15),
                              const SizedBox(width: 4),
                              Text(
                                t.en ? (c.partyBn ?? c.party!) : c.party!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (i == 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandSoft,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            t('বিজয়ী', 'Winner'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                      Text(
                        '${t.group(c.votes)}  ·  ${cast > 0 ? t.fixed(c.votes * 100 / cast) : t.n(0)}%',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    // The track the full width, the share in the party's
                    // colour from the start, as the election screen's bars.
                    child: Container(
                      height: 6,
                      width: double.infinity,
                      color: AppColors.sunk,
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor: (c.votes / top).clamp(0.0, 1.0),
                        heightFactor: 1,
                        child: ColoredBox(color: partyColour(c.party)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            color: AppColors.paper,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t('উৎস:', 'Source:')} ${r.sourceBn ?? ''}${note != null ? t('। $note', '. $note') : ''}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
                if (url != null)
                  InkWell(
                    onTap: () => openLink(context, url),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${_linkLabel(url)} ↗',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand,
                        ),
                      ),
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
