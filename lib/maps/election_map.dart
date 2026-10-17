/// Who won where, on a map of the country: the website's ElectionMap
/// (src/components/ElectionMap.tsx), drawn by the phone itself.
///
/// - আসন ও প্রতীক: every seat a disc at its place wearing its party's symbol,
///   on the districts' outlines. A tap draws the seat's own area (solid where
///   the seat holds a place whole, dashed where only part) and opens the
///   member below the map: photo, profession, party, votes, lead, runner-up.
///   A name in the search box jumps to its seat; party chips pick which
///   parties show.
/// - জেলার রং: each district in the colour of the party holding most of its
///   seats, two colours where it is a tie; a tap lists the district's seats.
///
/// No tiles, no map service: the outlines are the website's own
/// /geo/overview.json, painted with a CustomPainter inside an
/// InteractiveViewer. The party symbols (assets/party) are drawn into one
/// small disc image per party, once, and every seat reuses it.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../data/election.dart';
import '../i18n.dart';
import '../models.dart';
import '../party_logo.dart';
import '../theme.dart';
import '../widgets.dart';

const _font = 'NotoSansBengali';

/// The symbols that ship with the app (lib/party_logo.dart), by party.
const _symbolAssets = {
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

/// The website's sheet: an equirectangular drawing of the country.
const _k = 140.0;
const _lon0 = 88.0;
const _lat0 = 26.7;
final _cos = math.cos(23.7 * math.pi / 180);
Offset _project(Offset lonLat) =>
    Offset((lonLat.dx - _lon0) * _k * _cos, (_lat0 - lonLat.dy) * _k);

/// A seat's disc on screen, whatever the zoom; bigger when picked.
const _r = 6.5;
const _rPicked = 9.5;
const _maxScale = 40.0;

/// The long Bangla name shortened on the map, as on the website.
const _shortBn = {'chapainawabganj': 'চাঁপাইনবাবগঞ্জ'};

enum _Mode { seats, districts }

/// Each party's disc, drawn once for the whole app: the symbol in a white
/// circle ringed in the party's colour.
Map<String, ui.Image>? _discsDone;
Future<Map<String, ui.Image>>? _discsDrawing;
Future<Map<String, ui.Image>> _partyDiscs() {
  final done = _discsDone;
  if (done != null) return Future.value(done);
  return _discsDrawing ??= () async {
    try {
      return _discsDone = await _drawDiscs();
    } finally {
      _discsDrawing = null;
    }
  }();
}

Future<Map<String, ui.Image>> _drawDiscs() async {
  const size = 72.0;
  final out = <String, ui.Image>{};
  for (final MapEntry(key: abbr, value: asset) in _symbolAssets.entries) {
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 128,
      );
      final symbol = (await codec.getNextFrame()).image;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      const mid = Offset(size / 2, size / 2);
      c.drawCircle(mid, size / 2 - 1, Paint()..color = partyColour(abbr));
      c.drawCircle(mid, size / 2 - 6, Paint()..color = Colors.white);
      c.save();
      c.clipPath(
        Path()..addOval(Rect.fromCircle(center: mid, radius: size / 2 - 7)),
      );
      final w = symbol.width.toDouble();
      final h = symbol.height.toDouble();
      // Contained rather than cropped: the phone's disc is smaller than the
      // website's marker, and a cropped symbol stops being recognisable.
      final s = math.min((size - 16) / w, (size - 16) / h);
      c.drawImageRect(
        symbol,
        Rect.fromLTWH(0, 0, w, h),
        Rect.fromCenter(center: mid, width: w * s, height: h * s),
        Paint()..filterQuality = FilterQuality.medium,
      );
      c.restore();
      out[abbr] = await rec.endRecording().toImage(size.toInt(), size.toInt());
      symbol.dispose();
    } catch (_) {
      // A symbol that does not load leaves its party in plain colour.
    }
  }
  return out;
}

/// The map, its controls and the card below it.
class ElectionMap extends StatefulWidget {
  final List<ElectionSeat> seats;

  /// The districts' names in the reader's language, by slug.
  final Map<String, String> districtNames;

  /// A party's full name in the reader's language, by abbreviation, where
  /// one is known.
  final String? Function(String abbr) partyName;

  /// Set while a finger on the zoomed-in map is moving it, so the page
  /// holding the map does not scroll under it.
  final ValueNotifier<bool>? holdPage;

  final void Function(MemberBrief member) onMember;

  /// The seat's and the district's own pages, when the app has them.
  final void Function(String slug)? onSeatPage;
  final void Function(String slug)? onDistrictPage;

  const ElectionMap({
    super.key,
    required this.seats,
    required this.districtNames,
    required this.partyName,
    required this.onMember,
    this.holdPage,
    this.onSeatPage,
    this.onDistrictPage,
  });

  @override
  State<ElectionMap> createState() => _ElectionMapState();
}

class _ElectionMapState extends State<ElectionMap>
    with SingleTickerProviderStateMixin {
  late Future<GeoOverview> _overview = fetchOverview();
  GeoOverview? _geo;
  Map<String, ui.Image> _discs = const {};

  _Mode _mode = _Mode.seats;
  final Set<String> _only = {};
  ElectionSeat? _picked;
  String? _pickedDistrict;
  List<SeatArea> _areas = const [];

  final _query = TextEditingController();
  final _focus = FocusNode();
  final _tc = TransformationController();
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  Animation<Matrix4>? _zoom;
  final _cardKey = GlobalKey();
  int _fingers = 0;

  /// The drawing's geometry for the box it was last laid out in.
  _Sheet? _sheet;

  @override
  void initState() {
    super.initState();
    _overview.then((g) {
      if (mounted) setState(() => _geo = g);
    }, onError: (_) {});
    _partyDiscs().then((d) {
      if (mounted) setState(() => _discs = d);
    });
    _anim.addListener(() {
      final z = _zoom;
      if (z != null) _tc.value = z.value;
    });
    _query.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(ElectionMap old) {
    super.didUpdateWidget(old);
    // A new language or a refresh: the picked seat is looked up again.
    final p = _picked;
    if (p != null && !identical(old.seats, widget.seats)) {
      _picked = widget.seats.where((s) => s.slug == p.slug).firstOrNull;
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _tc.dispose();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _retry() => setState(() {
    _overview = fetchOverview();
    _overview.then((g) {
      if (mounted) setState(() => _geo = g);
    }, onError: (_) {});
  });

  bool _hidden(String? party) =>
      _only.isNotEmpty && !_only.contains(party ?? '');

  /// The parties holding seats, most seats first.
  List<({String abbr, String name, int n})> get _parties {
    final m = <String, ({String abbr, String name, int n})>{};
    for (final s in widget.seats) {
      final p = s.party;
      if (p == null || s.member == null) continue;
      final e = m[p];
      m[p] = (abbr: p, name: s.partyShort ?? p, n: (e?.n ?? 0) + 1);
    }
    final list = m.values.toList()..sort((a, b) => b.n.compareTo(a.n));
    return list;
  }

  /// Each district's parties by seats held, most first.
  Map<String, List<({String abbr, String name, int seats})>> get _lead {
    final out =
        <String, Map<String, ({String abbr, String name, int seats})>>{};
    for (final s in widget.seats) {
      final p = s.party;
      if (p == null || s.member == null) continue;
      final d = out.putIfAbsent(s.districtSlug, () => {});
      final e = d[p];
      d[p] = (abbr: p, name: s.partyShort ?? p, seats: (e?.seats ?? 0) + 1);
    }
    return {
      for (final MapEntry(:key, :value) in out.entries)
        key: value.values.toList()..sort((a, b) => b.seats.compareTo(a.seats)),
    };
  }

  String _districtName(String slug, {bool short = false}) {
    final named = widget.districtNames[slug];
    if (t.en && named != null) return named;
    if (short && _shortBn[slug] != null) return _shortBn[slug]!;
    return _geo?.districts.where((d) => d.slug == slug).firstOrNull?.name ??
        named ??
        slug;
  }

  // --- picking ---

  void _close() => setState(() {
    _picked = null;
    _pickedDistrict = null;
    _areas = const [];
  });

  void _open(ElectionSeat s) {
    setState(() {
      _mode = _Mode.seats;
      _picked = s;
      _pickedDistrict = s.districtSlug;
      _areas = const [];
    });
    _query.clear();
    _focus.unfocus();
    _revealCard();
    // Without its area (the district's file missing, or no signal), the view
    // goes to the seat's point.
    void toPoint() {
      final at = _sheet?.seat(s.slug);
      if (at != null) {
        _zoomTo(Rect.fromCenter(center: at, width: 50, height: 50));
      }
    }

    fetchSeatAreas(s.districtSlug, s.slug).then((areas) {
      if (!mounted || _picked?.slug != s.slug) return;
      final sheet = _sheet;
      if (areas.isEmpty || sheet == null) return toPoint();
      setState(() => _areas = areas);
      // Frame what the seat holds whole, or everything for a seat of parts.
      final whole = areas.where((a) => a.whole).toList();
      final frame = (whole.isEmpty ? areas : whole)
          .expand((a) => a.rings)
          .expand((r) => r)
          .map(sheet.toLocal);
      _zoomTo(_bounds(frame));
    }, onError: (_) => toPoint());
  }

  void _pickDistrict(String slug) {
    setState(() {
      _pickedDistrict = slug;
      _picked = null;
      _areas = const [];
    });
    _revealCard();
  }

  void _revealCard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _cardKey.currentContext;
      if (c == null || !c.mounted) return;
      Scrollable.ensureVisible(
        c,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  void _setMode(_Mode m) {
    setState(() {
      _mode = m;
      _picked = null;
      _pickedDistrict = null;
      _areas = const [];
    });
    _home();
  }

  // --- zoom ---

  double get _scale => _tc.value.getMaxScaleOnAxis();

  void _animateTo(Matrix4 to) {
    _zoom = Matrix4Tween(
      begin: _tc.value.clone(),
      end: to,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOutCubic));
    _anim.forward(from: 0);
  }

  /// The view that shows [r] (in the drawing's coordinates) in the middle,
  /// as large as the box allows with some room around it.
  void _zoomTo(Rect r) {
    final sheet = _sheet;
    if (sheet == null || r == Rect.zero) return;
    final box = sheet.size;
    final w = math.max(r.width * 1.7, box.width / 40);
    final h = math.max(r.height * 1.7, box.height / 40);
    final k = math.min(box.width / w, box.height / h).clamp(1.0, _maxScale);
    _animateTo(_matrix(k, r.center, box));
  }

  Matrix4 _matrix(double k, Offset centre, Size box) {
    final tx = (box.width / 2 - k * centre.dx).clamp(
      box.width - k * box.width,
      0.0,
    );
    final ty = (box.height / 2 - k * centre.dy).clamp(
      box.height - k * box.height,
      0.0,
    );
    return Matrix4.diagonal3Values(k, k, 1)..setTranslationRaw(tx, ty, 0);
  }

  void _zoomBy(double f) {
    final sheet = _sheet;
    if (sheet == null) return;
    final box = sheet.size;
    final inverse = Matrix4.inverted(_tc.value);
    final centre = MatrixUtils.transformPoint(
      inverse,
      Offset(box.width / 2, box.height / 2),
    );
    final k = (_scale * f).clamp(1.0, _maxScale);
    _animateTo(_matrix(k, centre, box));
  }

  void _home() {
    _animateTo(Matrix4.identity());
  }

  // --- gestures ---

  void _onTap(TapUpDetails d) {
    final sheet = _sheet;
    if (sheet == null) return;
    final p = d.localPosition;
    final scale = _scale;
    if (_mode == _Mode.seats) {
      ElectionSeat? best;
      var bestD = double.infinity;
      // Within a fingertip of the disc, in screen terms.
      final reach = 16 / scale;
      for (final s in widget.seats) {
        if (_hidden(s.party)) continue;
        final at = sheet.seat(s.slug);
        if (at == null) continue;
        final dist = (at - p).distance;
        if (dist < reach && dist < bestD) {
          best = s;
          bestD = dist;
        }
      }
      if (best != null) {
        _open(best);
      } else if (_picked != null) {
        _close();
      }
      return;
    }
    final hit = sheet.districtAt(p);
    if (hit != null) _pickDistrict(hit);
  }

  void _pointerDown(PointerDownEvent _) {
    _fingers++;
    // One finger on the whole country scrolls the page; on a zoomed map, or
    // with two fingers, the map takes it.
    if (_fingers >= 2 || _scale > 1.02) widget.holdPage?.value = true;
  }

  void _pointerUp(PointerEvent _) {
    _fingers = math.max(0, _fingers - 1);
    if (_fingers == 0) widget.holdPage?.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final parties = _parties;
    final lead = _lead;
    final hits = _query.text.trim().length < 2
        ? const <ElectionSeat>[]
        : widget.seats.where((s) => s.matches(_query.text)).take(8).toList();
    final screenH = MediaQuery.sizeOf(context).height;
    final mapH = (screenH * 0.6).clamp(340.0, 560.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ModeButton(
              label: t('আসন ও প্রতীক', 'Seats and symbols'),
              on: _mode == _Mode.seats,
              onTap: () => _setMode(_Mode.seats),
            ),
            _ModeButton(
              label: t('জেলার রং', 'District colours'),
              on: _mode == _Mode.districts,
              onTap: () => _setMode(_Mode.districts),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _query,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontFamily: _font, fontSize: 14.5),
          decoration: InputDecoration(
            isDense: true,
            hintText: t(
              'এমপি, আসন বা জেলার নাম…',
              'Name of an MP, seat or district…',
            ),
            hintStyle: const TextStyle(
              fontFamily: _font,
              fontSize: 14,
              color: AppColors.muted,
            ),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: t('মুছুন', 'Clear'),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: _query.clear,
                  ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          onSubmitted: (_) {
            if (hits.isNotEmpty) _open(hits.first);
          },
        ),
        if (hits.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: AppDecor.card(radius: 12),
            child: Column(
              children: [
                for (final s in hits)
                  InkWell(
                    onTap: () => _open(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.member?.nameBn ??
                                  t('আসনটি শূন্য', 'Seat vacant'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: _font,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            s.name,
                            style: const TextStyle(
                              fontFamily: _font,
                              fontSize: 12.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (_mode == _Mode.seats) ...[
          const SizedBox(height: 10),
          // One row that scrolls sideways: wrapped, eleven parties took six
          // rows of a phone above the map.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (i, chip) in [
                  _PartyChip(
                    label: t('সব দল', 'All parties'),
                    on: _only.isEmpty,
                    dimmed: false,
                    colour: AppColors.ink,
                    onTap: () => setState(_only.clear),
                  ),
                  for (final p in parties)
                    _PartyChip(
                      label: p.name,
                      count: p.n,
                      abbr: p.abbr,
                      on: _only.contains(p.abbr),
                      dimmed: _only.isNotEmpty && !_only.contains(p.abbr),
                      colour: partyColour(p.abbr),
                      // A tap shows only this party; more taps add parties; a tap
                      // on a picked one takes it away.
                      onTap: () => setState(() {
                        if (!_only.remove(p.abbr)) _only.add(p.abbr);
                        final picked = _picked;
                        if (picked != null && _hidden(picked.party)) {
                          _picked = null;
                          _areas = const [];
                        }
                      }),
                    ),
                ].indexed) ...[if (i > 0) const SizedBox(width: 6), chip],
              ],
            ),
          ),
          if (_only.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                () {
                  final n = widget.seats.where((s) => !_hidden(s.party)).length;
                  return t(
                    '${t.n(n)}টি আসন দেখানো হচ্ছে',
                    'Showing $n ${plural(n, 'seat', 'seats')}',
                  );
                }(),
                style: const TextStyle(
                  fontFamily: _font,
                  fontSize: 12.5,
                  color: AppColors.muted,
                ),
              ),
            ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: mapH,
          child: Container(
            decoration: AppDecor.card(),
            clipBehavior: Clip.antiAlias,
            child: Semantics(
              label: _mode == _Mode.seats
                  ? t(
                      'বাংলাদেশের ৩০০ সংসদীয় আসন, দলের প্রতীকে',
                      'Bangladesh’s 300 parliamentary seats, by party symbol',
                    )
                  : t(
                      'বাংলাদেশের ৬৪ জেলা, দলের রঙে',
                      'Bangladesh’s 64 districts, in party colours',
                    ),
              child: _mapBox(lead),
            ),
          ),
        ),
        if (_picked != null ||
            (_mode == _Mode.districts && _pickedDistrict != null))
          Padding(
            key: _cardKey,
            padding: const EdgeInsets.only(top: 12),
            child: _picked != null
                ? _SeatCard(
                    seat: _picked!,
                    districtName: _districtName(_picked!.districtSlug),
                    partyName: _picked!.party == null
                        ? null
                        : widget.partyName(_picked!.party!),
                    partOnly: _areas.any((a) => !a.whole),
                    onClose: _close,
                    onMember: widget.onMember,
                    onSeatPage: widget.onSeatPage,
                  )
                : _DistrictCard(
                    name: _districtName(_pickedDistrict!),
                    slug: _pickedDistrict!,
                    seats:
                        widget.seats
                            .where((s) => s.districtSlug == _pickedDistrict)
                            .toList()
                          ..sort((a, b) => a.no.compareTo(b.no)),
                    lead: lead[_pickedDistrict!] ?? const [],
                    onClose: _close,
                    onSeat: _open,
                    onDistrictPage: widget.onDistrictPage,
                  ),
          ),
        const SizedBox(height: 10),
        Text(
          t.en
              ? 'District boundaries from OCHA’s map; each seat’s area is worked out from the boundaries of its upazilas and wards, and is approximate. ${_mode == _Mode.districts ? 'Each district is in the colour of the party whose current Members of Parliament hold most of its seats; two colours mean a tie.' : 'Tap a symbol to see the seat’s area and its Member of Parliament.'}'
              : 'জেলার সীমানা OCHA-র মানচিত্রে; আসনের জায়গা তার উপজেলা ও ওয়ার্ডের সীমানা থেকে হিসাব করা, আনুমানিক। ${_mode == _Mode.districts ? 'রং সেই জেলার বেশিরভাগ আসন যে দলের বর্তমান সংসদ সদস্যদের; দুই রং মানে সমান সমান।' : 'প্রতীকে চাপ দিলে আসনের এলাকা ও সংসদ সদস্য।'}',
          style: const TextStyle(
            fontFamily: _font,
            fontSize: 12.5,
            color: AppColors.muted,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  Widget _mapBox(
    Map<String, List<({String abbr, String name, int seats})>> lead,
  ) {
    final geo = _geo;
    return Stack(
      children: [
        Positioned.fill(
          child: geo == null
              ? FutureBuilder<GeoOverview>(
                  future: _overview,
                  builder: (context, snap) => Center(
                    child: snap.hasError
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t(
                                  'মানচিত্র আনা গেল না',
                                  'The map could not be fetched',
                                ),
                                style: _mutedStyle,
                              ),
                              TextButton(
                                onPressed: _retry,
                                child: Text(t('আবার চেষ্টা করুন', 'Try again')),
                              ),
                            ],
                          )
                        : Text(
                            t('মানচিত্র আসছে…', 'Loading the map…'),
                            style: _mutedStyle,
                          ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, box) {
                    final size = Size(box.maxWidth, box.maxHeight);
                    final sheet = _sheet =
                        _sheet != null &&
                            _sheet!.size == size &&
                            identical(_sheet!.geo, geo)
                        ? _sheet!
                        : _Sheet(geo, size);
                    return Listener(
                      onPointerDown: _pointerDown,
                      onPointerUp: _pointerUp,
                      onPointerCancel: _pointerUp,
                      child: InteractiveViewer(
                        transformationController: _tc,
                        minScale: 1,
                        maxScale: _maxScale,
                        clipBehavior: Clip.hardEdge,
                        onInteractionStart: (_) => _anim.stop(),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: _onTap,
                          child: RepaintBoundary(
                            child: CustomPaint(
                              size: size,
                              painter: _MapPainter(
                                sheet: sheet,
                                view: _tc,
                                mode: _mode,
                                seats: widget.seats,
                                hidden: _hidden,
                                picked: _picked,
                                pickedDistrict: _pickedDistrict,
                                areas: _areas,
                                discs: _discs,
                                lead: lead,
                                labelOf: (slug) =>
                                    _districtName(slug, short: true),
                                lang: appLang.value,
                                filter: (_only.toList()..sort()).join(','),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (geo != null)
          Positioned(
            right: 10,
            top: 10,
            child: Column(
              children: [
                _ZoomButton(
                  icon: Icons.add_rounded,
                  tip: t('বড় করুন', 'Zoom in'),
                  onTap: () => _zoomBy(1.6),
                ),
                const SizedBox(height: 6),
                _ZoomButton(
                  icon: Icons.remove_rounded,
                  tip: t('ছোট করুন', 'Zoom out'),
                  onTap: () => _zoomBy(1 / 1.6),
                ),
                const SizedBox(height: 6),
                _ZoomButton(
                  icon: Icons.home_outlined,
                  tip: t('পুরো দেশ', 'Whole country'),
                  onTap: () {
                    _close();
                    _home();
                  },
                ),
              ],
            ),
          ),
        if (geo != null)
          Positioned(
            left: 10,
            bottom: 10,
            right: 60,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                    border: Border.all(color: AppColors.rule),
                  ),
                  child: Text(
                    t(
                      'স্ক্রল বা দুই আঙুলে zoom, টেনে সরান',
                      'Scroll or pinch to zoom, drag to move',
                    ),
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 11.5,
                      color: AppColors.muted,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

const _mutedStyle = TextStyle(
  fontFamily: _font,
  fontSize: 14,
  color: AppColors.muted,
);

Rect _bounds(Iterable<Offset> pts) {
  var x0 = double.infinity, y0 = double.infinity;
  var x1 = -double.infinity, y1 = -double.infinity;
  for (final p in pts) {
    x0 = math.min(x0, p.dx);
    y0 = math.min(y0, p.dy);
    x1 = math.max(x1, p.dx);
    y1 = math.max(y1, p.dy);
  }
  return x0.isFinite ? Rect.fromLTRB(x0, y0, x1, y1) : Rect.zero;
}

/// The drawing laid out in a box: the country fitted to it, every outline a
/// path and every seat a point, in the box's own coordinates. Made once per
/// box size; the zoom only transforms it.
class _Sheet {
  final GeoOverview geo;
  final Size size;
  late final double _s;
  late final Offset _off;
  late final Map<String, Path> paths;
  late final Map<String, List<List<Offset>>> _rings;
  late final Map<String, Offset> labels;
  late final Map<String, Offset> _seats;

  _Sheet(this.geo, this.size) {
    final all = _bounds(
      geo.districts.expand((d) => d.rings).expand((r) => r).map(_project),
    );
    const pad = 10.0;
    final w = math.max(all.width, 1.0);
    final h = math.max(all.height, 1.0);
    _s = math.min((size.width - 2 * pad) / w, (size.height - 2 * pad) / h);
    _off = Offset(
      (size.width - w * _s) / 2 - all.left * _s,
      (size.height - h * _s) / 2 - all.top * _s,
    );
    _rings = {
      for (final d in geo.districts)
        d.slug: [
          for (final ring in d.rings) [for (final p in ring) toLocal(p)],
        ],
    };
    paths = {
      for (final MapEntry(:key, :value) in _rings.entries)
        key: () {
          final path = Path();
          for (final ring in value) {
            path.addPolygon(ring, true);
          }
          return path;
        }(),
    };
    labels = {for (final d in geo.districts) d.slug: toLocal(d.center)};
    _seats = {
      for (final MapEntry(:key, :value) in geo.seats.entries)
        key: toLocal(value),
    };
  }

  Offset toLocal(Offset lonLat) => _off + _project(lonLat) * _s;

  Offset? seat(String slug) => _seats[slug];

  /// The district under a point. Counted by hand (even-odd crossings) rather
  /// than with Path.contains, which on the web build missed every tap.
  String? districtAt(Offset p) {
    for (final MapEntry(:key, :value) in _rings.entries) {
      if (!paths[key]!.getBounds().contains(p)) continue;
      var inside = false;
      for (final ring in value) {
        for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
          final a = ring[i], b = ring[j];
          if ((a.dy > p.dy) != (b.dy > p.dy) &&
              p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
            inside = !inside;
          }
        }
      }
      if (inside) return key;
    }
    return null;
  }
}

class _MapPainter extends CustomPainter {
  final _Sheet sheet;
  final TransformationController view;
  final _Mode mode;
  final List<ElectionSeat> seats;
  final bool Function(String? party) hidden;
  final ElectionSeat? picked;
  final String? pickedDistrict;
  final List<SeatArea> areas;
  final Map<String, ui.Image> discs;
  final Map<String, List<({String abbr, String name, int seats})>> lead;
  final String Function(String slug) labelOf;
  final Lang lang;

  /// The parties picked, as one string, so a change of pick repaints.
  final String filter;

  _MapPainter({
    required this.sheet,
    required this.view,
    required this.mode,
    required this.seats,
    required this.hidden,
    required this.picked,
    required this.pickedDistrict,
    required this.areas,
    required this.discs,
    required this.lead,
    required this.labelOf,
    required this.lang,
    required this.filter,
  }) : super(repaint: view);

  /// District names, laid out once per painter and language.
  final _labels = <String, (TextPainter, TextPainter)>{};

  (TextPainter, TextPainter) _label(String slug, double size) {
    final key = '$slug/$size';
    return _labels[key] ??= () {
      final text = labelOf(slug);
      final onColour = mode == _Mode.districts;
      TextPainter make(Paint? stroke) => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: _font,
            fontSize: size,
            fontWeight: FontWeight.w600,
            height: 1.1,
            color: stroke == null
                ? (onColour ? Colors.white : AppColors.muted)
                : null,
            foreground: stroke,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      final halo = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = onColour ? const Color(0x59000000) : AppColors.surface;
      return (make(halo), make(null));
    }();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = view.value.getMaxScaleOnAxis();
    final hair = 1 / scale;

    // Districts.
    var i = 0;
    for (final d in sheet.geo.districts) {
      final path = sheet.paths[d.slug];
      if (path == null) continue;
      final on = pickedDistrict == d.slug;
      final fill = Paint()..style = PaintingStyle.fill;
      if (mode == _Mode.districts) {
        final ps = lead[d.slug] ?? const [];
        final a = ps.isNotEmpty ? ps[0] : null;
        final b = ps.length > 1 ? ps[1] : null;
        final alpha = pickedDistrict != null && !on ? 0.45 : 0.9;
        if (a != null && b != null && a.seats == b.seats) {
          final r = path.getBounds();
          fill.shader = ui.Gradient.linear(
            r.topLeft,
            r.bottomRight,
            [
              partyColour(a.abbr).withValues(alpha: alpha),
              partyColour(a.abbr).withValues(alpha: alpha),
              partyColour(b.abbr).withValues(alpha: alpha),
              partyColour(b.abbr).withValues(alpha: alpha),
            ],
            const [0, 0.5, 0.5, 1],
          );
        } else {
          fill.color = (a != null ? partyColour(a.abbr) : AppColors.ruleSoft)
              .withValues(alpha: alpha);
        }
      } else {
        fill.color = i.isOdd ? AppColors.ruleSoft : AppColors.surface;
      }
      canvas.drawPath(path, fill);
      i++;
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..color = mode == _Mode.districts ? Colors.white : AppColors.rule
      ..strokeWidth = 1.2 * hair;
    for (final p in sheet.paths.values) {
      canvas.drawPath(p, line);
    }
    final pd = pickedDistrict;
    if (pd != null && sheet.paths[pd] != null) {
      canvas.drawPath(
        sheet.paths[pd]!,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.ink
          ..strokeWidth = 2 * hair,
      );
    }

    // The picked seat's area.
    final current = picked;
    if (current != null && areas.isNotEmpty) {
      final c = current.member == null
          ? AppColors.muted
          : partyColour(current.party);
      for (final a in areas) {
        final path = Path();
        for (final ring in a.rings) {
          path.addPolygon([for (final p in ring) sheet.toLocal(p)], true);
        }
        canvas.drawPath(
          path,
          Paint()..color = c.withValues(alpha: a.whole ? 0.3 : 0.12),
        );
        final stroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..color = c
          ..strokeWidth = 2.5 * hair;
        canvas.drawPath(
          a.whole ? path : _dashed(path, 6 * hair, 4 * hair),
          stroke,
        );
      }
    }

    // District names: always in the district view; on the seats, once the
    // map is zoomed enough for them not to cover the symbols.
    final showLabels = mode == _Mode.districts || scale >= 1.6;
    if (showLabels) {
      final fontSize = scale < 1.6 ? 8.5 : 10.5;
      for (final MapEntry(key: slug, value: at) in sheet.labels.entries) {
        final (halo, fill) = _label(slug, fontSize);
        canvas.save();
        canvas.translate(at.dx, at.dy + (mode == _Mode.seats ? 13 * hair : 0));
        canvas.scale(hair);
        final o = Offset(-fill.width / 2, -fill.height / 2);
        halo.paint(canvas, o);
        fill.paint(canvas, o);
        canvas.restore();
      }
    }

    if (mode != _Mode.seats) return;

    // The seats, each in its party's disc; the picked one last, on top.
    final dimPaint = Paint()
      ..color = const Color(0x26000000)
      ..filterQuality = FilterQuality.medium;
    final fullPaint = Paint()..filterQuality = FilterQuality.medium;
    void drawSeat(ElectionSeat s, bool on) {
      final at = sheet.seat(s.slug);
      if (at == null) return;
      final dim = hidden(s.party);
      final r = (on ? _rPicked : _r) * hair;
      final disc = s.member != null ? discs[s.party] : null;
      final alpha = dim ? 0.15 : 1.0;
      if (disc != null) {
        canvas.drawImageRect(
          disc,
          Rect.fromLTWH(0, 0, disc.width.toDouble(), disc.height.toDouble()),
          Rect.fromCircle(center: at, radius: r),
          dim ? dimPaint : fullPaint,
        );
      } else {
        final colour = s.member == null ? AppColors.rule : partyColour(s.party);
        canvas.drawCircle(
          at,
          r,
          Paint()..color = Colors.white.withValues(alpha: alpha),
        );
        canvas.drawCircle(
          at,
          r - 1.6 * hair,
          Paint()..color = colour.withValues(alpha: alpha),
        );
      }
      if (on) {
        canvas.drawCircle(
          at,
          r + 0.5 * hair,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = AppColors.ink
            ..strokeWidth = 2.5 * hair,
        );
      }
    }

    for (final s in seats) {
      if (s.slug != current?.slug) drawSeat(s, false);
    }
    if (current != null) drawSeat(current, true);
  }

  static Path _dashed(Path source, double dash, double gap) {
    final out = Path();
    for (final m in source.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        out.addPath(
          m.extractPath(d, math.min(d + dash, m.length)),
          Offset.zero,
        );
        d += dash + gap;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      !identical(old.sheet, sheet) ||
      old.mode != mode ||
      !identical(old.seats, seats) ||
      old.picked?.slug != picked?.slug ||
      old.pickedDistrict != pickedDistrict ||
      !identical(old.areas, areas) ||
      !identical(old.discs, discs) ||
      old.lang != lang ||
      old.filter != filter;
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _ModeButton({
    required this.label,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        color: on ? AppColors.brand : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: on ? AppColors.brand : AppColors.rule),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: _font,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: on ? Colors.white : AppColors.ink,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PartyChip extends StatelessWidget {
  final String label;
  final int? count;
  final String? abbr;
  final bool on;
  final bool dimmed;
  final Color colour;
  final VoidCallback onTap;
  const _PartyChip({
    required this.label,
    required this.on,
    required this.dimmed,
    required this.colour,
    required this.onTap,
    this.count,
    this.abbr,
  });

  @override
  Widget build(BuildContext context) {
    final fg = on ? Colors.white : AppColors.ink;
    return Semantics(
      button: true,
      selected: on,
      child: Opacity(
        opacity: dimmed ? 0.55 : 1,
        child: Material(
          color: on ? colour : AppColors.surface,
          shape: StadiumBorder(
            side: BorderSide(color: on ? colour : AppColors.rule),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(abbr == null ? 12 : 5, 5, 10, 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (abbr != null) ...[
                    Container(
                      padding: const EdgeInsets.all(1),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: hasPartyLogo(abbr)
                          ? PartyLogo(abbr: abbr, size: 16)
                          : _Dot(colour, size: 14),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: 13,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: fg,
                      height: 1.25,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 5),
                    Text(
                      t.n(count),
                      style: TextStyle(
                        fontFamily: _font,
                        fontSize: 12.5,
                        color: on
                            ? Colors.white.withValues(alpha: 0.85)
                            : AppColors.muted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color colour;
  final double size;
  const _Dot(this.colour, {this.size = 10});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
  );
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  const _ZoomButton({
    required this.icon,
    required this.tip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: Material(
        color: AppColors.surface,
        elevation: 1,
        shadowColor: const Color(0x3317201B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.rule),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 20, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

/// The member for the picked seat, under the map.
class _SeatCard extends StatelessWidget {
  final ElectionSeat seat;
  final String districtName;
  final String? partyName;
  final bool partOnly;
  final VoidCallback onClose;
  final void Function(MemberBrief) onMember;
  final void Function(String slug)? onSeatPage;
  const _SeatCard({
    required this.seat,
    required this.districtName,
    required this.partyName,
    required this.partOnly,
    required this.onClose,
    required this.onMember,
    required this.onSeatPage,
  });

  @override
  Widget build(BuildContext context) {
    final m = seat.member;
    final ru = seat.runnerUp;
    return _CardShell(
      onClose: onClose,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (m != null)
              MemberAvatar(member: m, size: 56)
            else
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.ruleSoft,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '—',
                  style: TextStyle(fontSize: 20, color: AppColors.muted),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m?.nameBn ?? t('আসনটি এখন শূন্য', 'This seat is vacant'),
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.35,
                      ),
                    ),
                    _Profession(
                      prefix:
                          '${seat.name} · $districtName${t(' জেলা', ' district')}',
                      slug: m?.slug,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (m != null && seat.party != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 3, 10, 3),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hasPartyLogo(seat.party)
                          ? Colors.white
                          : partyColour(seat.party),
                      shape: BoxShape.circle,
                    ),
                    child: hasPartyLogo(seat.party)
                        ? PartyLogo(abbr: seat.party, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      partyName ?? seat.partyShort ?? seat.party!,
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Figure(
                label: t('প্রাপ্ত ভোট', 'Votes received'),
                value: seat.votes != null ? t.group(seat.votes!) : '—',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Figure(
                label: t('ব্যবধান', 'Margin'),
                value: seat.margin != null ? t.group(seat.margin!) : '—',
              ),
            ),
          ],
        ),
        if (ru != null) ...[
          const SizedBox(height: 10),
          Text(
            '${t('নিকটতম: ', 'Runner-up: ')}${ru.name}'
            '${(ru.partyLabel ?? ru.party) != null ? ' (${ru.partyLabel ?? ru.party})' : ''}, '
            '${t.group(ru.votes)}${t(' ভোট', plural(ru.votes, ' vote', ' votes'))}',
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 12.5,
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            if (m != null)
              Expanded(
                child: FilledButton(
                  onPressed: () => onMember(m),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: Text(
                    t('প্রোফাইল', 'Profile'),
                    style: const TextStyle(
                      fontFamily: _font,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (m != null && onSeatPage != null) const SizedBox(width: 8),
            if (onSeatPage != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onSeatPage!(seat.slug),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    minimumSize: const Size(0, 40),
                    side: const BorderSide(color: AppColors.rule, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: Text(
                    t('আসনের পাতা', 'Seat page'),
                    style: const TextStyle(
                      fontFamily: _font,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (partOnly) ...[
          const SizedBox(height: 10),
          Text(
            t(
              'হালকা জায়গার একাংশ এই আসনে।',
              'Only part of each lightly shaded area is in this seat.',
            ),
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 11.5,
              color: AppColors.muted,
            ),
          ),
        ],
      ],
    );
  }
}

/// "ঢাকা-১৭ · ঢাকা জেলা · ব্যবসা": the profession comes from the member's
/// own record, which the app keeps once read.
class _Profession extends StatefulWidget {
  final String prefix;
  final String? slug;
  const _Profession({required this.prefix, required this.slug});

  @override
  State<_Profession> createState() => _ProfessionState();
}

class _ProfessionState extends State<_Profession> {
  String? _profession;
  String? _for;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(_Profession old) {
    super.didUpdateWidget(old);
    if (old.slug != widget.slug) _fetch();
  }

  void _fetch() {
    final slug = widget.slug;
    final key = '${appLang.value.name}/$slug';
    if (_for == key) return;
    _for = key;
    _profession = null;
    if (slug == null) return;
    Api.instance.member(slug).then((d) {
      if (mounted && _for == key) {
        setState(() => _profession = d.professionBn);
      }
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final p = _profession;
    return Text(
      p == null ? widget.prefix : '${widget.prefix} · $p',
      style: const TextStyle(
        fontFamily: _font,
        fontSize: 13,
        color: AppColors.muted,
        height: 1.45,
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  const _Figure({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: _font,
            fontSize: 11.5,
            color: AppColors.muted,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The district's seats, under the map in the district view.
class _DistrictCard extends StatelessWidget {
  final String name;
  final String slug;
  final List<ElectionSeat> seats;
  final List<({String abbr, String name, int seats})> lead;
  final VoidCallback onClose;
  final void Function(ElectionSeat) onSeat;
  final void Function(String slug)? onDistrictPage;
  const _DistrictCard({
    required this.name,
    required this.slug,
    required this.seats,
    required this.lead,
    required this.onClose,
    required this.onSeat,
    required this.onDistrictPage,
  });

  @override
  Widget build(BuildContext context) {
    final summary = lead.map((p) => '${p.name} ${t.n(p.seats)}').join(', ');
    return _CardShell(
      onClose: onClose,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 24),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 10,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleLarge),
              if (onDistrictPage != null)
                InkWell(
                  onTap: () => onDistrictPage!(slug),
                  child: Text(
                    t('জেলার পাতা →', 'District page →'),
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brand,
                      height: 1.6,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Text(
          '${t.count(seats.length, 'টি আসন', 'seat', 'seats')}: '
          '${summary.isEmpty ? t('ফল নেই', 'no results') : summary}',
          style: const TextStyle(
            fontFamily: _font,
            fontSize: 13,
            color: AppColors.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        for (final (i, s) in seats.indexed)
          Container(
            decoration: BoxDecoration(
              border: i == 0
                  ? null
                  : const Border(top: BorderSide(color: AppColors.ruleSoft)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _Dot(
                    s.member == null ? AppColors.rule : partyColour(s.party),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => onSeat(s),
                        child: Text(
                          s.name,
                          style: const TextStyle(
                            fontFamily: _font,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand,
                            height: 1.4,
                          ),
                        ),
                      ),
                      Text(
                        s.member?.nameBn ??
                            t('আসনটি এখন শূন্য', 'This seat is vacant'),
                        style: TextStyle(
                          fontFamily: _font,
                          fontSize: 14,
                          fontWeight: s.member == null
                              ? FontWeight.w400
                              : FontWeight.w600,
                          color: s.member == null
                              ? AppColors.muted
                              : AppColors.ink,
                          height: 1.4,
                        ),
                      ),
                      Text(
                        [
                          if (s.member != null) ?s.partyShort,
                          if (s.votes != null)
                            t(
                              '${t.group(s.votes!)} ভোট',
                              '${t.group(s.votes!)} ${plural(s.votes!, 'vote', 'votes')}',
                            ),
                          if (s.margin != null && s.margin! > 0)
                            t(
                              'ব্যবধান ${t.group(s.margin!)}',
                              'margin ${t.group(s.margin!)}',
                            ),
                        ].join(' · '),
                        style: const TextStyle(
                          fontFamily: _font,
                          fontSize: 12.5,
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  final VoidCallback onClose;
  final List<Widget> children;
  const _CardShell({required this.onClose, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecor.card(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
          PositionedDirectional(
            end: -8,
            top: -8,
            child: IconButton(
              tooltip: t('বন্ধ করুন', 'Close'),
              onPressed: onClose,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
