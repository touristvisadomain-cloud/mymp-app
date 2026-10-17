/// Google Maps under the app's maps, as on the website's election map, when
/// the build carries a key (owner, 2026-10-17); the app's own drawn maps
/// otherwise.
///
/// Whether there is a key is asked of the phone itself, once, before the
/// first frame: MainActivity (Android) and AppDelegate (iOS) answer on the
/// `bd.mymp.app/maps` channel whether the key the build put into the
/// manifest or Info.plist is non-empty. So the switch cannot disagree with
/// the build: a build without a key never creates a GoogleMap (the Maps SDK
/// stops the app when asked for a map with no key) and draws its own maps,
/// as before. The web build, the tests and any platform without the channel
/// answer "no".
///
/// `--dart-define=MAPS=0` turns Google Maps off in a build that has a key.
///
/// No location: the maps never ask where the phone is (no permission, no
/// "my location" layer), and nothing else is collected by the app.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

abstract final class GoogleMaps {
  static const _channel = MethodChannel('bd.mymp.app/maps');
  static const _define = String.fromEnvironment('MAPS');

  static bool _enabled = false;

  /// Whether the maps are Google's. Settled by [init] before the first frame.
  static bool get enabled => _enabled;

  /// For a test of the Google path, with a fake map platform underneath.
  @visibleForTesting
  static set debugEnabled(bool on) => _enabled = on;

  static Future<void> init() async {
    _enabled = false;
    if (kIsWeb || _define == '0') return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      _enabled = await _channel.invokeMethod<bool>('hasKey') ?? false;
    } catch (_) {
      // No channel (an older native side) or no answer: the drawn maps.
      _enabled = false;
    }
  }

  /// Bangladesh, south-west to north-east.
  static final bangladesh = LatLngBounds(
    southwest: const LatLng(20.6, 88.0),
    northeast: const LatLng(26.65, 92.7),
  );

  /// How far the camera's middle may wander: the country and a margin.
  static final around = CameraTargetBounds(
    LatLngBounds(
      southwest: const LatLng(19.0, 86.0),
      northeast: const LatLng(28.0, 94.5),
    ),
  );

  /// The map takes every gesture inside its box, as the website's map does
  /// ("greedy"); the page scrolls from outside it.
  static final greedy = <Factory<OneSequenceGestureRecognizer>>{
    Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
  };
}

/// The bounds of [points] (as lon/lat offsets); null when there are none.
LatLngBounds? boundsOf(Iterable<(double lon, double lat)> points) {
  var s = double.infinity, w = double.infinity;
  var n = -double.infinity, e = -double.infinity;
  for (final (lon, lat) in points) {
    s = math.min(s, lat);
    n = math.max(n, lat);
    w = math.min(w, lon);
    e = math.max(e, lon);
  }
  if (!s.isFinite) return null;
  return LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e));
}

/// The camera that shows [b] whole in a box of [size] logical pixels, with
/// [pad] pixels to spare on every side: Google's fitBounds, worked out here
/// so that it can be the map's first position (asking Android to fit bounds
/// before the map has its size fails) and keeps the fractional zoom that
/// fills the box, where a whole step would leave the country small.
///
/// The road map is Web Mercator in 256-pixel tiles: at zoom z the world is
/// 256·2^z pixels wide.
CameraPosition fitCamera(
  LatLngBounds b,
  Size size, {
  double pad = 0,
  double maxZoom = 16,
}) {
  double y(double lat) {
    final s = math.sin(lat * math.pi / 180).clamp(-0.9999, 0.9999);
    return 0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi);
  }

  double lat(double y) =>
      math.atan(_sinh(math.pi * (1 - 2 * y))) * 180 / math.pi;

  final w = math.max(size.width - 2 * pad, 1.0);
  final h = math.max(size.height - 2 * pad, 1.0);
  final dx = math.max(
    (b.northeast.longitude - b.southwest.longitude) / 360,
    1e-9,
  );
  final y0 = y(b.northeast.latitude);
  final y1 = y(b.southwest.latitude);
  final dy = math.max(y1 - y0, 1e-9);
  final zx = math.log(w / (256 * dx)) / math.ln2;
  final zy = math.log(h / (256 * dy)) / math.ln2;
  final zoom = math.min(zx, zy).clamp(2.0, maxZoom);
  return CameraPosition(
    target: LatLng(
      lat((y0 + y1) / 2),
      (b.southwest.longitude + b.northeast.longitude) / 2,
    ),
    zoom: zoom,
  );
}

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
