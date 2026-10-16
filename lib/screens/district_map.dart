import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/member.dart';
import '../i18n.dart';
import '../theme.dart';

/// A district's seats on its map, as the website's district page draws it
/// (src/components/SeatMap.tsx with `colors`): each upazila and city ward in
/// the colour of the party holding its seat, solid where one seat holds the
/// whole place and pale where it is shared; a tap opens the seat. Drawn from
/// the website's own boundary file (`/geo/<district>.json`), with no street
/// map beneath; read through lib/data/member.dart's [fetchDistrictGeo], the
/// same file the seat map reads.
class DistrictMap extends StatefulWidget {
  final String districtSlug;

  /// Each seat's colour, by seat slug.
  final Map<String, Color> colours;

  /// Each seat's name in the reader's language, by slug.
  final Map<String, String> seatNames;
  final ValueChanged<String> onSeat;

  const DistrictMap({
    super.key,
    required this.districtSlug,
    required this.colours,
    required this.seatNames,
    required this.onSeat,
  });

  @override
  State<DistrictMap> createState() => _DistrictMapState();
}

class _Shape {
  final GeoPlace place;
  final Path path;
  const _Shape(this.place, this.path);
}

class _Projected {
  final List<_Shape> shapes;
  final Rect bounds;
  const _Projected(this.shapes, this.bounds);
}

/// Longitude and latitude to a flat plane: longitude scaled by the cosine of
/// the district's latitude, latitude upwards. Plenty for a district.
_Projected _project(List<GeoPlace> places) {
  var minLat = 90.0, maxLat = -90.0;
  for (final p in places) {
    for (final poly in p.polygons) {
      for (final (_, lat) in poly.first) {
        minLat = math.min(minLat, lat);
        maxLat = math.max(maxLat, lat);
      }
    }
  }
  final k = math.cos((minLat + maxLat) / 2 * math.pi / 180);
  Rect? bounds;
  final shapes = <_Shape>[];
  // Cities under wards, so a ward is drawn and tapped over its city.
  int order(GeoPlace p) => switch (p.kind) {
    'city' => 0,
    'upazila' => 1,
    _ => 2,
  };
  final sorted = [...places]..sort((a, b) => order(a).compareTo(order(b)));
  for (final p in sorted) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final poly in p.polygons) {
      for (final ring in poly) {
        for (final (i, (lng, lat)) in ring.indexed) {
          final x = lng * k;
          final y = -lat;
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
      }
    }
    final b = path.getBounds();
    bounds = bounds == null ? b : bounds.expandToInclude(b);
    shapes.add(_Shape(p, path));
  }
  return _Projected(shapes, bounds ?? Rect.zero);
}

class _DistrictMapState extends State<DistrictMap> {
  late Future<_Projected> _future = _load();

  Future<_Projected> _load() async =>
      _project(await fetchDistrictGeo(widget.districtSlug));

  @override
  void didUpdateWidget(DistrictMap old) {
    super.didUpdateWidget(old);
    if (old.districtSlug != widget.districtSlug) _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Projected>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null || data.shapes.isEmpty) {
          return Container(
            height: 200,
            alignment: Alignment.center,
            decoration: AppDecor.card(),
            child: snap.hasError || (data != null && data.shapes.isEmpty)
                ? TextButton(
                    onPressed: () => setState(() => _future = _load()),
                    child: Text(
                      t(
                        'মানচিত্র আনা গেল না। আবার চেষ্টা করুন',
                        'The map could not be fetched. Try again',
                      ),
                    ),
                  )
                : const CircularProgressIndicator(color: AppColors.brand),
          );
        }
        return _map(context, data);
      },
    );
  }

  Widget _map(BuildContext context, _Projected data) {
    final seatsShown = widget.seatNames.keys.toList();
    return Container(
      decoration: AppDecor.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final aspect = data.bounds.height / data.bounds.width;
              final h = (w * aspect).clamp(220.0, 440.0);
              final size = Size(w, h);
              return GestureDetector(
                onTapUp: (e) {
                  final hit = _hit(data, size, e.localPosition);
                  if (hit != null) widget.onSeat(hit);
                },
                child: CustomPaint(
                  size: size,
                  painter: _Painter(data, widget.colours),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final slug in seatsShown)
                  InkWell(
                    onTap: () => widget.onSeat(slug),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: AppColors.rule),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: widget.colours[slug] ?? AppColors.muted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            widget.seatNames[slug]!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(
              t(
                'সীমানা: উপজেলা © OpenStreetMap অবদানকারীরা (ODbL); সিটি কর্পোরেশন: OCHA (CC BY-IGO); সিটি ওয়ার্ড: geoBoundaries (CC BY 3.0 IGO)। মানচিত্রে চাপ দিলে আসনের পাতা খুলবে।',
                'Boundaries: upazilas © OpenStreetMap contributors (ODbL); city corporations: OCHA (CC BY-IGO); city wards: geoBoundaries (CC BY 3.0 IGO). Tap the map to open a seat.',
              ),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(height: 1.45, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  /// The seat of the place under a tap: the topmost place there that names
  /// a seat; a shared place opens the seat that holds the most of it.
  String? _hit(_Projected data, Size size, Offset at) {
    final f = _fit(data.bounds, size);
    final p = (at - f.offset) / f.scale;
    for (final s in data.shapes.reversed) {
      if (s.place.seats.isEmpty || !s.path.contains(p)) continue;
      final whole = s.place.seats.entries
          .where((e) => e.value == SeatPart.whole)
          .map((e) => e.key)
          .firstOrNull;
      return whole ?? s.place.seats.keys.first;
    }
    return null;
  }
}

({double scale, Offset offset}) _fit(Rect b, Size size) {
  const pad = 10.0;
  if (b.width <= 0 || b.height <= 0) return (scale: 1, offset: Offset.zero);
  final scale = math.min(
    (size.width - pad * 2) / b.width,
    (size.height - pad * 2) / b.height,
  );
  final offset = Offset(
    (size.width - b.width * scale) / 2 - b.left * scale,
    (size.height - b.height * scale) / 2 - b.top * scale,
  );
  return (scale: scale, offset: offset);
}

class _Painter extends CustomPainter {
  final _Projected data;
  final Map<String, Color> colours;
  _Painter(this.data, this.colours);

  @override
  void paint(Canvas canvas, Size size) {
    final f = _fit(data.bounds, size);
    canvas.save();
    canvas.translate(f.offset.dx, f.offset.dy);
    canvas.scale(f.scale);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 / f.scale
      ..color = Colors.white;
    for (final s in data.shapes) {
      final seats = s.place.seats;
      Color fill;
      if (seats.isEmpty) {
        fill = AppColors.sunk;
      } else {
        final whole = seats.length == 1 && seats.values.first == SeatPart.whole;
        final c = colours[seats.keys.first] ?? AppColors.muted;
        fill = c.withValues(alpha: whole ? 0.82 : 0.45);
      }
      canvas.drawPath(s.path, Paint()..color = fill);
      canvas.drawPath(s.path, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Painter old) =>
      old.data != data || old.colours != colours;
}
