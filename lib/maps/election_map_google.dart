part of 'election_map.dart';

/// The election map on Google Maps, as the website draws it when it has a
/// key (src/components/ElectionMap.tsx): the districts as a layer over the
/// road map, faint under the seats or in the leading party's colour; every
/// seat a marker wearing its party's symbol (a plain disc in the party's
/// colour where there is no symbol); the picked seat's area drawn over it.
///
/// The geometry is the same the drawn map uses: the districts and seat
/// points of /geo/overview.json and the seat's places from
/// `/geo/<district>.json`. Only the picture underneath is Google's.
class _GoogleBox extends StatefulWidget {
  final GeoOverview geo;
  final List<ElectionSeat> seats;
  final _Mode mode;
  final bool Function(String? party) hidden;

  /// The parties picked, as one string, so a change of pick rebuilds the
  /// markers.
  final String filter;
  final ElectionSeat? picked;
  final String? pickedDistrict;
  final List<SeatArea> areas;
  final Map<String, ui.Image> discs;
  final Map<String, List<({String abbr, String name, int seats})>> lead;
  final void Function(ElectionSeat seat) onSeat;
  final void Function(String slug) onDistrict;
  final VoidCallback onEmpty;

  const _GoogleBox({
    super.key,
    required this.geo,
    required this.seats,
    required this.mode,
    required this.hidden,
    required this.filter,
    required this.picked,
    required this.pickedDistrict,
    required this.areas,
    required this.discs,
    required this.lead,
    required this.onSeat,
    required this.onDistrict,
    required this.onEmpty,
  });

  @override
  State<_GoogleBox> createState() => _GoogleBoxState();
}

/// A marker's size on screen, in logical pixels; larger when picked.
const _gSmall = 26.0;
const _gBig = 36.0;

class _GoogleBoxState extends State<_GoogleBox> {
  GoogleMapController? _map;
  Size _size = Size.zero;
  CameraPosition? _first;
  MapType _type = MapType.normal;

  /// Each marker picture as PNG bytes, by [_iconKey].
  Map<String, Uint8List> _pngs = const {};
  Map<String, ui.Image>? _pngsFor;
  final _icons = <String, BitmapDescriptor>{};

  @override
  void initState() {
    super.initState();
    _drawIcons();
  }

  @override
  void didUpdateWidget(_GoogleBox old) {
    super.didUpdateWidget(old);
    if (!identical(old.discs, widget.discs)) _drawIcons();
  }

  // --- what the parent's buttons and picks ask for ---

  void home() => _move(
    CameraUpdate.newCameraPosition(
      fitCamera(GoogleMaps.bangladesh, _size, pad: 8),
    ),
  );

  void zoomBy(double factor) =>
      _move(CameraUpdate.zoomBy(math.log(factor) / math.ln2));

  void toggleType() => setState(
    () => _type = _type == MapType.normal ? MapType.hybrid : MapType.normal,
  );

  /// What the seat holds whole, or everything for a seat of parts.
  void frame(List<SeatArea> areas) {
    final whole = areas.where((a) => a.whole).toList();
    final b = boundsOf(
      (whole.isEmpty ? areas : whole)
          .expand((a) => a.rings)
          .expand((r) => r)
          .map((p) => (p.dx, p.dy)),
    );
    if (b == null || _size.isEmpty) return;
    _move(
      CameraUpdate.newCameraPosition(fitCamera(b, _size, pad: 28, maxZoom: 14)),
    );
  }

  /// A seat with no area to draw: its point, close enough to see the town.
  void toPoint(Offset lonLat) =>
      _move(CameraUpdate.newLatLngZoom(LatLng(lonLat.dy, lonLat.dx), 10));

  void _move(CameraUpdate u) {
    final m = _map;
    if (m == null || _size.isEmpty) return;
    m.animateCamera(u).catchError((_) {});
  }

  // --- the markers' pictures ---

  String _iconKey(ElectionSeat s) {
    if (s.member == null) return 'vacant';
    final p = s.party;
    if (p != null && widget.discs.containsKey(p)) return p;
    return 'c${partyColour(p).toARGB32()}';
  }

  Future<void> _drawIcons() async {
    final discs = widget.discs;
    _pngsFor = discs;
    final out = <String, Uint8List>{};
    Future<void> add(String key, ui.Image img) async {
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes != null) out[key] = bytes.buffer.asUint8List();
    }

    for (final MapEntry(:key, :value) in discs.entries) {
      await add(key, value);
    }
    // A plain disc for every colour that has no symbol, and for a vacancy.
    final plain = <String, Color>{};
    for (final s in widget.seats) {
      final k = _iconKey(s);
      if (out.containsKey(k)) continue;
      plain[k] = s.member == null ? AppColors.rule : partyColour(s.party);
    }
    for (final MapEntry(:key, :value) in plain.entries) {
      final img = await _plainDisc(value);
      await add(key, img);
      img.dispose();
    }
    if (!mounted || !identical(_pngsFor, discs)) return;
    setState(() {
      _pngs = out;
      _icons.clear();
    });
  }

  static Future<ui.Image> _plainDisc(Color c) {
    const size = 72.0;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    const mid = Offset(size / 2, size / 2);
    canvas.drawCircle(mid, size / 2 - 1, Paint()..color = Colors.white);
    canvas.drawCircle(mid, size / 2 - 9, Paint()..color = c);
    return rec.endRecording().toImage(size.toInt(), size.toInt());
  }

  // --- the map's contents ---

  Set<Marker> _markers() {
    if (widget.mode != _Mode.seats || _pngs.isEmpty) return const {};
    // Kept between builds: a new descriptor would count as a new picture
    // and send every marker to the map again.
    BitmapDescriptor icon(String key, bool big) => _icons.putIfAbsent(
      '$key/$big',
      () => BitmapDescriptor.bytes(
        _pngs[key]!,
        width: big ? _gBig : _gSmall,
        height: big ? _gBig : _gSmall,
      ),
    );
    final out = <Marker>{};
    for (final s in widget.seats) {
      if (widget.hidden(s.party)) continue;
      final at = widget.geo.seats[s.slug];
      final key = _iconKey(s);
      if (at == null || !_pngs.containsKey(key)) continue;
      final on = widget.picked?.slug == s.slug;
      out.add(
        Marker(
          markerId: MarkerId(s.slug),
          position: LatLng(at.dy, at.dx),
          icon: icon(key, on),
          anchor: const Offset(0.5, 0.5),
          zIndexInt: on ? 1000 : 1,
          consumeTapEvents: true,
          onTap: () => widget.onSeat(s),
        ),
      );
    }
    return out;
  }

  /// The districts, made again only when what they show changes.
  Set<Polygon>? _districts;
  String? _districtsFor;

  Set<Polygon> _districtLayer() {
    final key =
        '${widget.mode}/${widget.pickedDistrict}/${identityHashCode(widget.geo)}/${identityHashCode(widget.seats)}';
    final held = _districts;
    if (held != null && _districtsFor == key) return held;
    final out = <Polygon>{};
    final dv = widget.mode == _Mode.districts;
    final picked = widget.pickedDistrict;
    for (final d in widget.geo.districts) {
      final on = picked == d.slug;
      Color fill, stroke;
      int width;
      if (dv) {
        final ps = widget.lead[d.slug] ?? const [];
        final a = ps.isNotEmpty ? ps[0] : null;
        final b = ps.length > 1 ? ps[1] : null;
        final tie = a != null && b != null && a.seats == b.seats;
        final alpha = picked != null && !on ? 0.3 : 0.55;
        fill =
            (a == null
                    ? const Color(0xFF9A9A9A)
                    : partyColour(tie ? b.abbr : a.abbr))
                .withValues(alpha: alpha);
        // A tie: one party's colour inside, the other's as the outline.
        stroke = on
            ? AppColors.ink
            : tie
            ? partyColour(a.abbr)
            : Colors.white;
        width = on || tie ? 3 : 1;
      } else {
        fill = AppColors.brand.withValues(alpha: on ? 0.08 : 0);
        stroke = on ? AppColors.ink : const Color(0x995F6B64);
        width = on ? 2 : 1;
      }
      for (final (i, ring) in d.rings.indexed) {
        out.add(
          Polygon(
            polygonId: PolygonId('d/${d.slug}/$i'),
            points: [for (final p in ring) LatLng(p.dy, p.dx)],
            fillColor: fill,
            strokeColor: stroke,
            strokeWidth: width,
            zIndex: on ? 2 : 1,
            // In the seats view a tap on the land falls through to the map
            // (which closes the card); in the district view it picks.
            consumeTapEvents: dv,
            onTap: dv ? () => widget.onDistrict(d.slug) : null,
          ),
        );
      }
    }
    _districtsFor = key;
    return _districts = out;
  }

  Color get _areaColour {
    final p = widget.picked;
    return p == null || p.member == null
        ? AppColors.muted
        : partyColour(p.party);
  }

  Set<Polygon> _areaPolygons() {
    if (widget.picked == null) return const {};
    final c = _areaColour;
    return {
      for (final (i, a) in widget.areas.indexed)
        for (final (j, ring) in a.rings.indexed)
          Polygon(
            polygonId: PolygonId('a/$i/$j'),
            points: [for (final p in ring) LatLng(p.dy, p.dx)],
            fillColor: c.withValues(alpha: a.whole ? 0.28 : 0.1),
            strokeColor: c,
            // A part's outline is dashed, below.
            strokeWidth: a.whole ? 3 : 0,
            zIndex: 3,
          ),
    };
  }

  /// Where the seat holds only part of a place, its outline dashed, as on
  /// the drawn map: Google draws a polygon's outline only solid.
  Set<Polyline> _areaDashes() {
    if (widget.picked == null) return const {};
    final c = _areaColour.withValues(alpha: 0.75);
    return {
      for (final (i, a) in widget.areas.indexed)
        if (!a.whole)
          for (final (j, ring) in a.rings.indexed)
            Polyline(
              polylineId: PolylineId('a/$i/$j'),
              points: [
                for (final p in ring) LatLng(p.dy, p.dx),
                LatLng(ring.first.dy, ring.first.dx),
              ],
              color: c,
              width: 2,
              patterns: [PatternItem.dash(10), PatternItem.gap(6)],
              zIndex: 4,
            ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        _size = Size(box.maxWidth, box.maxHeight);
        final first = _first ??= fitCamera(
          GoogleMaps.bangladesh,
          _size,
          pad: 8,
        );
        return GoogleMap(
          initialCameraPosition: first,
          onMapCreated: (c) => _map = c,
          mapType: _type,
          gestureRecognizers: GoogleMaps.greedy,
          cameraTargetBounds: GoogleMaps.around,
          minMaxZoomPreference: const MinMaxZoomPreference(5, 18),
          // The app's own buttons zoom; nothing that asks for the phone's
          // place, and nothing tappable of Google's own.
          zoomControlsEnabled: false,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          indoorViewEnabled: false,
          buildingsEnabled: false,
          trafficEnabled: false,
          markers: _markers(),
          polygons: {..._districtLayer(), ..._areaPolygons()},
          polylines: _areaDashes(),
          onTap: (_) {
            if (widget.mode == _Mode.seats) widget.onEmpty();
          },
        );
      },
    );
  }
}
