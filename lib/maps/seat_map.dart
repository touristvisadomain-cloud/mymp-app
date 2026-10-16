import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/member.dart';
import '../i18n.dart';
import '../theme.dart';

/// A constituency on its district's map, as the website's SeatMap draws it
/// (src/components/SeatMap.tsx in the mymp repo), without the street map
/// beneath: the seat's upazilas and city wards filled in the party's colour,
/// solid where the seat holds the whole place and pale and dashed where it
/// holds only part of it, and the district's other places faint and named.
///
/// The map opens on what the seat holds; a pinch zooms it (out to the whole
/// district), a tap on a place says what it is and which seat it lies in, and
/// "বড় করে দেখুন" opens it full screen, where nothing else claims the gestures.
/// There is no "Am I in this seat?" button: the app asks for no location.
///
/// The boundaries are the website's own file, `/geo/<district>.json`, built
/// from OpenStreetMap's upazilas (ODbL), OCHA's city corporations (CC BY-IGO)
/// and geoBoundaries' city wards (CC BY 3.0 IGO); the line under the map says
/// so, as the website does.
class SeatMap extends StatefulWidget {
  final String districtSlug;
  final String seatSlug;

  /// The party's colour the seat is drawn in.
  final Color color;

  /// The seat's name for the bar above the map ("ঢাকা-১৭"); worked out from
  /// [districtName] and the slug when not given.
  final String? title;

  /// The district's name in the reader's language: the other seats are named
  /// from it ("ঢাকা-১৪"), and on English it names the city corporations.
  final String? districtName;

  /// The Election Commission's description of the seat, shown under the map
  /// when the seat holds only part of a place.
  final String? note;

  /// The map's height on the page.
  final double height;

  const SeatMap({
    super.key,
    required this.districtSlug,
    required this.seatSlug,
    required this.color,
    this.title,
    this.districtName,
    this.note,
    this.height = 340,
  });

  @override
  State<SeatMap> createState() => _SeatMapState();
}

const _grey = Color(0xFF6B7570);

class _SeatMapState extends State<SeatMap> {
  late Future<_MapData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  @override
  void didUpdateWidget(SeatMap old) {
    super.didUpdateWidget(old);
    if (old.districtSlug != widget.districtSlug ||
        old.seatSlug != widget.seatSlug) {
      _data = _load();
    }
  }

  Future<_MapData> _load() async {
    final places = await fetchDistrictGeo(widget.districtSlug);
    final namer = t.en
        ? _Namer.en(await upazilaNamesEn(), widget.districtName)
        : const _Namer.bn();
    return _MapData(places, namer, t.lang);
  }

  String _seatName(String slug) {
    final no = RegExp(r'-(\d+)$').firstMatch(slug)?.group(1);
    final d = widget.districtName;
    if (no == null || d == null) return slug;
    return '$d-${t.n(no)}';
  }

  String get _title => widget.title ?? _seatName(widget.seatSlug);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return FutureBuilder<_MapData>(
      future: _data,
      builder: (context, snap) {
        // A switch of language names the places again.
        final d = snap.data;
        if (d != null && d.lang != appLang.value) {
          _data = _load();
        }
        final places = d?.places ?? const <GeoPlace>[];
        final mine = places.where((p) => p.seats[widget.seatSlug] != null);
        final whole = mine
            .where((p) => p.seats[widget.seatSlug] == SeatPart.whole)
            .toList();
        final part = mine
            .where((p) => p.seats[widget.seatSlug] == SeatPart.part)
            .toList();
        final namer = d?.namer ?? const _Namer.bn();
        final summary = [
          ...namer.placeList(whole),
          ...namer.placeList(part).map((p) => t('$p-এর একাংশ', 'part of $p')),
        ].join(', ');

        Widget body;
        if (d != null && places.isNotEmpty) {
          body = _MapView(
            key: ValueKey('${widget.districtSlug}/${widget.seatSlug}'),
            places: places,
            seatSlug: widget.seatSlug,
            color: widget.color,
            namer: namer,
            seatName: _seatName,
            title: _title,
            summary: summary,
            height: widget.height,
            onLarger: () => _openLarge(context, d, summary),
          );
        } else if (snap.hasError || (d != null && places.isEmpty)) {
          body = _frame(
            context,
            summary: '',
            child: SizedBox(
              height: 120,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t(
                        'মানচিত্রটি আনা গেল না।',
                        'The map could not be fetched.',
                      ),
                      style: text.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => setState(() => _data = _load()),
                      child: Text(
                        t('আবার চেষ্টা করুন', 'Try again'),
                        style: const TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          body = _frame(
            context,
            summary: '',
            child: SizedBox(
              height: widget.height,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.brand),
              ),
            ),
          );
        }

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusCard),
            border: Border.all(color: AppColors.rule),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              body,
              if (part.isNotEmpty && widget.note != null)
                _NoteBox(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: t(
                            'নির্বাচন কমিশনের বর্ণনা:',
                            "The Election Commission's description:",
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: ' ${widget.note}'),
                        TextSpan(
                          text:
                              '\n${t('ইউনিয়নের, আর নতুন সিটি কর্পোরেশনগুলোর ওয়ার্ডের, আলাদা সীমানা প্রকাশিত নেই; সেখানে হালকা রঙে পুরো উপজেলা বা সিটি দেখানো হয়েছে।', 'No separate boundaries have been published for unions, or for the wards of the newer city corporations; there the whole upazila or city is shown in a paler colour.')}',
                          style: text.labelSmall?.copyWith(height: 1.6),
                        ),
                      ],
                    ),
                    style: text.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                      height: 1.55,
                    ),
                  ),
                ),
              _NoteBox(
                child: Text(
                  t(
                    'সীমানা নির্বাচন কমিশনের আসনের বর্ণনা থেকে; উপজেলা OpenStreetMap, সিটি কর্পোরেশন OCHA আর সিটি ওয়ার্ড geoBoundaries (BBS, ২০১৫)-এর মানচিত্রে; আনুমানিক।',
                    "Boundaries from the Election Commission's description of the seats, drawn on the maps of OpenStreetMap (upazilas), OCHA (city corporations) and geoBoundaries (city wards; BBS, 2015); approximate.",
                  ),
                  style: text.labelSmall?.copyWith(height: 1.55),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The bar above the map with nothing drawn yet.
  Widget _frame(
    BuildContext context, {
    required String summary,
    required Widget child,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Bar(color: widget.color, title: _title, detail: summary),
      child,
    ],
  );

  void _openLarge(BuildContext context, _MapData d, String summary) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: AppColors.paper,
          appBar: AppBar(
            title: Text(_title),
            leading: IconButton(
              tooltip: t('বন্ধ করুন', 'Close'),
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: LayoutBuilder(
            builder: (context, box) => _MapView(
              places: d.places,
              seatSlug: widget.seatSlug,
              color: widget.color,
              namer: d.namer,
              seatName: _seatName,
              title: _title,
              summary: summary,
              height: math.max(200, box.maxHeight - 64),
              large: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapData {
  final List<GeoPlace> places;
  final _Namer namer;
  final Lang lang;
  const _MapData(this.places, this.namer, this.lang);
}

/// A note under the map.
class _NoteBox extends StatelessWidget {
  final Widget child;
  const _NoteBox({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.rule)),
    ),
    child: child,
  );
}

/// The seat's colour, its name and the places it covers, or, after a tap, the
/// place tapped.
class _Bar extends StatelessWidget {
  final Color color;
  final String title;
  final String detail;
  final VoidCallback? onLarger;
  const _Bar({
    required this.color,
    required this.title,
    required this.detail,
    this.onLarger,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.rule)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 9),
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
              ],
            ),
          ),
          if (onLarger != null) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onLarger,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                t('বড় করে দেখুন', 'View larger'),
                style: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The map itself with its bar: pinch to zoom, tap a place to name it.
class _MapView extends StatefulWidget {
  final List<GeoPlace> places;
  final String seatSlug;
  final Color color;
  final _Namer namer;
  final String Function(String slug) seatName;
  final String title;
  final String summary;
  final double height;
  final VoidCallback? onLarger;
  final bool large;

  const _MapView({
    super.key,
    required this.places,
    required this.seatSlug,
    required this.color,
    required this.namer,
    required this.seatName,
    required this.title,
    required this.summary,
    required this.height,
    this.onLarger,
    this.large = false,
  });

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  final _zoom = TransformationController();
  _Projected? _shape;
  Size? _fitted;
  GeoPlace? _picked;

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  /// The places in the box's own coordinates, the whole district fitted in.
  _Projected _project(Size size) {
    final held = _shape;
    if (held != null && held.size == size && held.namer == widget.namer) {
      return held;
    }
    final p = _Projected(widget.places, size, widget.seatSlug, widget.namer);
    _shape = p;
    return p;
  }

  /// Opens on what the seat holds whole (Dhaka-14's wards, not all of Savar
  /// for the two unions it holds there); a seat of parts alone opens on them.
  void _fit(_Projected p) {
    final mine = <int>[];
    final whole = <int>[];
    for (var i = 0; i < widget.places.length; i++) {
      final s = widget.places[i].seats[widget.seatSlug];
      if (s != null) mine.add(i);
      if (s == SeatPart.whole) whole.add(i);
    }
    final focus = whole.isNotEmpty ? whole : mine;
    if (focus.isEmpty) {
      _zoom.value = Matrix4.identity();
      return;
    }
    var r = p.bounds[focus.first];
    for (final i in focus.skip(1)) {
      r = r.expandToInclude(p.bounds[i]);
    }
    final w = p.size.width;
    final h = p.size.height;
    final s =
        (math.min(w / math.max(r.width, 1), h / math.max(r.height, 1)) * 0.86)
            .clamp(1.0, _maxScale);
    final tx = (w / 2 - s * r.center.dx).clamp(w - s * w, 0.0);
    final ty = (h / 2 - s * r.center.dy).clamp(h - s * h, 0.0);
    _zoom.value = Matrix4.identity()
      ..scaleByDouble(s, s, 1, 1)
      ..setTranslationRaw(tx, ty, 0);
  }

  static const _maxScale = 40.0;

  void _tap(_Projected p, Offset at) {
    // A ward before the city or upazila around it; the smallest place wins.
    GeoPlace? hit;
    var area = double.infinity;
    for (var i = 0; i < widget.places.length; i++) {
      final b = p.bounds[i];
      if (!b.contains(at) || !p.paths[i].contains(at)) continue;
      final a = b.width * b.height;
      if (a < area) {
        area = a;
        hit = widget.places[i];
      }
    }
    setState(() => _picked = identical(hit, _picked) ? null : hit);
  }

  String _label(GeoPlace f) {
    final s = f.seats[widget.seatSlug];
    final where = s == SeatPart.whole
        ? t('পুরোটা এই আসনে', 'wholly in this seat')
        : s == SeatPart.part
        ? t('একাংশ এই আসনে', 'partly in this seat')
        : f.seats.keys.map(widget.seatName).join(', ');
    final name = widget.namer.placeName(f);
    return name == null ? where : '$name · $where';
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Bar(
          color: widget.color,
          title: widget.title,
          detail: picked != null ? _label(picked) : widget.summary,
          onLarger: widget.onLarger,
        ),
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, box) {
              final size = Size(box.maxWidth, box.maxHeight);
              final p = _project(size);
              if (_fitted != size) {
                _fitted = size;
                // After the frame: a zoom set while the viewer is being built
                // is not the one it draws with.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _fit(p);
                });
              }
              return ColoredBox(
                color: const Color(0xFFF7F8F5),
                child: Stack(
                  children: [
                    Semantics(
                      label: t(
                        '${widget.title} মানচিত্র',
                        'Map of ${widget.title}',
                      ),
                      child: InteractiveViewer(
                        transformationController: _zoom,
                        minScale: 1,
                        maxScale: _maxScale,
                        // Pinch and two-finger moves on the page; one finger
                        // too in the large view, where the page does not scroll.
                        panEnabled: widget.large,
                        child: GestureDetector(
                          onTapUp: (d) => _tap(p, d.localPosition),
                          child: CustomPaint(
                            size: size,
                            painter: _SeatPainter(
                              shape: p,
                              places: widget.places,
                              seatSlug: widget.seatSlug,
                              color: widget.color,
                              picked: picked,
                              zoom: _zoom,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Material(
                        color: AppColors.surface,
                        shape: const CircleBorder(),
                        elevation: 1,
                        child: IconButton(
                          tooltip: t('আসনে ফিরুন', 'Back to the seat'),
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.center_focus_strong_rounded,
                            size: 20,
                            color: AppColors.inkSoft,
                          ),
                          onPressed: () {
                            _fit(p);
                            setState(() => _picked = null);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The places as paths in the box's coordinates, with their bounds, label
/// points and the names written on them.
class _Projected {
  final Size size;
  final _Namer namer;
  final List<Path> paths = [];
  final List<Rect> bounds = [];
  final List<Offset> labelAt = [];
  final List<String?> names = [];

  _Projected(List<GeoPlace> places, this.size, String seatSlug, this.namer) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final f in places) {
      for (final poly in f.polygons) {
        for (final (x, y) in poly.first) {
          minX = math.min(minX, x);
          maxX = math.max(maxX, x);
          minY = math.min(minY, y);
          maxY = math.max(maxY, y);
        }
      }
    }
    // Longitude shrinks with latitude: about 0.92 of a degree of latitude in
    // Bangladesh, which keeps the districts' shapes true.
    final k = math.cos((minY + maxY) / 2 * math.pi / 180);
    const pad = 10.0;
    final spanX = math.max((maxX - minX) * k, 1e-9);
    final spanY = math.max(maxY - minY, 1e-9);
    final s = math.min(
      (size.width - 2 * pad) / spanX,
      (size.height - 2 * pad) / spanY,
    );
    final ox = (size.width - spanX * s) / 2;
    final oy = (size.height - spanY * s) / 2;
    Offset at(double lng, double lat) =>
        Offset(ox + (lng - minX) * k * s, oy + (maxY - lat) * s);

    for (final f in places) {
      final path = Path()..fillType = PathFillType.evenOdd;
      for (final poly in f.polygons) {
        for (final ring in poly) {
          path.addPolygon([for (final (x, y) in ring) at(x, y)], true);
        }
      }
      paths.add(path);
      bounds.add(path.getBounds());
      final (lx, ly) = _labelPoint(f);
      labelAt.add(at(lx, ly));
      names.add(namer.shortName(f));
    }
  }
}

/// Where a place's name sits: the centroid of its largest polygon, or the
/// middle of its outline when the centroid falls outside (a bent coast).
(double, double) _labelPoint(GeoPlace f) {
  var best = f.polygons.first.first;
  var bestArea = -1.0;
  for (final poly in f.polygons) {
    final ring = poly.first;
    var a = 0.0;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      a += ring[j].$1 * ring[i].$2 - ring[i].$1 * ring[j].$2;
    }
    if (a.abs() > bestArea) {
      bestArea = a.abs();
      best = ring;
    }
  }
  var a = 0.0, cx = 0.0, cy = 0.0;
  for (var i = 0, j = best.length - 1; i < best.length; j = i++) {
    final k = best[j].$1 * best[i].$2 - best[i].$1 * best[j].$2;
    a += k;
    cx += (best[j].$1 + best[i].$1) * k;
    cy += (best[j].$2 + best[i].$2) * k;
  }
  final c = a != 0 ? (cx / (3 * a), cy / (3 * a)) : best.first;
  if (_inRing(c, best)) return c;
  final mid = best[best.length ~/ 2];
  return ((best.first.$1 + mid.$1) / 2, (best.first.$2 + mid.$2) / 2);
}

bool _inRing((double, double) pt, List<(double, double)> ring) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final (xi, yi) = ring[i];
    final (xj, yj) = ring[j];
    if ((yi > pt.$2) != (yj > pt.$2) &&
        pt.$1 < (xj - xi) * (pt.$2 - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

class _SeatPainter extends CustomPainter {
  final _Projected shape;
  final List<GeoPlace> places;
  final String seatSlug;
  final Color color;
  final GeoPlace? picked;
  final TransformationController zoom;

  _SeatPainter({
    required this.shape,
    required this.places,
    required this.seatSlug,
    required this.color,
    required this.picked,
    required this.zoom,
  }) : super(repaint: zoom);

  /// Dashed outlines, made again only when the zoom has changed by half.
  static final _dashCache = Expando<Map<int, Path>>();

  static final _labels = <String, (TextPainter, TextPainter)>{};

  (TextPainter, TextPainter) _label(String text) =>
      _labels.putIfAbsent(text, () {
        TextPainter make(Paint? stroke) => TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: stroke == null ? AppColors.ink : null,
              foreground: stroke,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        return (
          make(
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.2
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.white,
          ),
          make(null),
        );
      });

  Path _dashed(Path path, double scale) {
    final bucket = (math.log(scale) / math.ln2 * 2).round();
    final cache = _dashCache[path] ??= {};
    return cache.putIfAbsent(bucket, () {
      final dash = 6 / math.pow(2, bucket / 2);
      final gap = 4.5 / math.pow(2, bucket / 2);
      final out = Path();
      for (final m in path.computeMetrics()) {
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
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = zoom.value.getMaxScaleOnAxis();
    canvas.clipRect(Offset.zero & size);
    final fill = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    // Other places first, then the parts, then the whole on top.
    final order = [
      for (var i = 0; i < places.length; i++)
        if (places[i].seats[seatSlug] == null) i,
      for (var i = 0; i < places.length; i++)
        if (places[i].seats[seatSlug] == SeatPart.part) i,
      for (var i = 0; i < places.length; i++)
        if (places[i].seats[seatSlug] == SeatPart.whole) i,
    ];
    for (final i in order) {
      final s = places[i].seats[seatSlug];
      final path = shape.paths[i];
      switch (s) {
        case SeatPart.whole:
          canvas.drawPath(path, fill..color = color.withValues(alpha: 0.2));
          canvas.drawPath(
            path,
            line
              ..color = color
              ..strokeWidth = 2.4 / scale,
          );
        case SeatPart.part:
          canvas.drawPath(path, fill..color = color.withValues(alpha: 0.08));
          canvas.drawPath(
            _dashed(path, scale),
            line
              ..color = color
              ..strokeWidth = 1.8 / scale,
          );
        case null:
          canvas.drawPath(path, fill..color = _grey.withValues(alpha: 0.04));
          canvas.drawPath(
            _dashed(path, scale),
            line
              ..color = _grey.withValues(alpha: 0.75)
              ..strokeWidth = 0.9 / scale,
          );
      }
    }
    final p = picked;
    if (p != null) {
      final i = places.indexOf(p);
      if (i >= 0) {
        canvas.drawPath(
          shape.paths[i],
          line
            ..color = AppColors.ink
            ..strokeWidth = 2 / scale,
        );
      }
    }

    // Names: the seat's own places first, then the district's upazilas and
    // cities, then wards; one that would run into another, or that does not
    // fit inside its place at this zoom, waits for a closer look.
    final placed = <Rect>[];
    final labelOrder = [...order.reversed]
      ..sort((a, b) {
        int rank(int i) =>
            (places[i].seats[seatSlug] != null ? 0 : 2) +
            (places[i].kind == 'ward' ? 1 : 0);
        return rank(a).compareTo(rank(b));
      });
    for (final i in labelOrder) {
      final name = shape.names[i];
      if (name == null || name.isEmpty) continue;
      final (halo, ink) = _label(name);
      final w = ink.width / scale;
      final h = ink.height / scale;
      final b = shape.bounds[i];
      if (w > b.width * 1.5 || h > b.height * 1.2) continue;
      final c = shape.labelAt[i];
      final r = Rect.fromCenter(center: c, width: w + 4 / scale, height: h);
      if (placed.any((o) => o.overlaps(r))) continue;
      placed.add(r);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(1 / scale);
      final at = Offset(-ink.width / 2, -ink.height / 2);
      halo.paint(canvas, at);
      ink.paint(canvas, at);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SeatPainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.picked != picked ||
      old.seatSlug != seatSlug;
}

/// How the map names its places: in Bangla, as the website does, or in
/// English (upazilas by the bootstrap's `upazilaEn` table, a city corporation
/// by its district's English name, a ward by its number). A place with no
/// English on record is left unnamed in English.
class _Namer {
  final Map<String, String>? _table;
  final String? _districtEn;

  const _Namer.bn() : _table = null, _districtEn = null;
  const _Namer.en(Map<String, String> table, String? districtEn)
    : _table = table,
      _districtEn = districtEn;

  bool get _en => _table != null;

  static String _cityShort(String s) =>
      s.replaceFirst(RegExp(r' সিটি কর্পোরেশন$'), ' সিটি');

  static String _latin(String s) => s.replaceAllMapped(
    RegExp('[০-৯]'),
    (m) => '${'০১২৩৪৫৬৭৮৯'.indexOf(m[0]!)}',
  );

  /// "ওয়ার্ড ৪৭" → "47"; null for a ward known only by its name.
  static String? _wardNo(String name) {
    final m = RegExp(r'^ওয়ার্ড ([০-৯\d]+)$').firstMatch(name);
    return m == null ? null : _latin(m.group(1)!);
  }

  /// "ঢাকা দক্ষিণ সিটি কর্পোরেশন" → "Dhaka South".
  String? _cityBase(String bnCity) {
    final d = _districtEn;
    if (d == null) return null;
    final rest = bnCity.replaceFirst(RegExp(r'\s*সিটি কর্পোরেশন$'), '').trim();
    final side = RegExp(r'\s(উত্তর|দক্ষিণ|দক্ষিন)$').firstMatch(rest)?.group(1);
    return side == null ? d : '$d ${side == 'উত্তর' ? 'North' : 'South'}';
  }

  String? _place(String name) => _table![bnKey(name)];

  String? _cityShortEn(String bnCity) {
    final b = _cityBase(bnCity);
    return b == null ? null : '$b City';
  }

  /// The place in full: "দোহার উপজেলা", "ওয়ার্ড ৪৭ (ঢাকা দক্ষিণ সিটি)".
  String? placeName(GeoPlace f) {
    if (!_en) {
      return switch (f.kind) {
        'city' => f.name,
        'ward' => '${f.name} (${_cityShort(f.city ?? '')})',
        _ => '${f.name} উপজেলা',
      };
    }
    switch (f.kind) {
      case 'city':
        final b = _cityBase(f.name);
        return b == null ? null : '$b City Corporation';
      case 'ward':
        final no = _wardNo(f.name);
        final name = no != null ? 'Ward $no' : _place(f.name);
        if (name == null) return null;
        final city = _cityShortEn(f.city ?? '');
        return city == null ? name : '$name ($city)';
      default:
        final name = _place(f.name);
        return name == null ? null : '$name upazila';
    }
  }

  /// The name written on the map.
  String? shortName(GeoPlace f) {
    if (!_en) return _cityShort(f.name);
    switch (f.kind) {
      case 'city':
        return _cityShortEn(f.name);
      case 'ward':
        final no = _wardNo(f.name);
        return no != null ? 'Ward $no' : _place(f.name);
      default:
        return _place(f.name);
    }
  }

  /// The places a seat holds, one city's wards gathered into one line.
  List<String> placeList(List<GeoPlace> fs) {
    final out = <String>[];
    final byCity = <String, (List<String>, List<String>)>{};
    for (final f in fs) {
      if (f.kind != 'ward') {
        final n = placeName(f);
        if (n != null) out.add(n);
        continue;
      }
      final city = _en
          ? (_cityShortEn(f.city ?? '') ?? '')
          : _cityShort(f.city ?? '');
      final c = byCity.putIfAbsent(city, () => (<String>[], <String>[]));
      if (_en) {
        final no = _wardNo(f.name);
        if (no != null) {
          c.$1.add(no);
        } else if (_place(f.name) case final n?) {
          c.$2.add(n);
        }
      } else if (f.name.startsWith('ওয়ার্ড ')) {
        c.$1.add(f.name.substring('ওয়ার্ড '.length));
      } else {
        c.$2.add(f.name);
      }
    }
    final lines = [
      for (final MapEntry(key: city, value: (nums, names)) in byCity.entries)
        if (nums.isNotEmpty || names.isNotEmpty)
          _en
              ? '${city.isEmpty ? '' : '$city '}${[if (nums.isNotEmpty) '${nums.length == 1 ? 'ward' : 'wards'} ${nums.join(', ')}', ...names].join(', ')}'
              : '$cityর ${[if (nums.isNotEmpty) 'ওয়ার্ড ${nums.join(', ')}', ...names].join(', ')}',
    ];
    return [...lines, ...out];
  }
}
