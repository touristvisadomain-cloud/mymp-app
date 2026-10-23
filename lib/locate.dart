/// Where the phone is, asked only when the reader taps "আমি কি এই আসনে?" or
/// "আমার আসন কোনটি?" (owner, 2026-10-23), as the website's map does.
///
/// The point is checked against the seats' boundaries on the phone itself
/// (`placeAt` in lib/data/member.dart): it is not sent to mymp.bd, to Google
/// or to anyone else, and it is not kept. The website asks OpenStreetMap for
/// the place's name; the app does not need to, since it has the boundaries.
///
/// Approximate accuracy is enough to find an upazila or a city ward, so the
/// app asks for no more; a reader who allows only the approximate location
/// on Android 12 and later still gets an answer.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'i18n.dart';

/// The phone's position, or why there is none.
class Located {
  final double lat;
  final double lon;
  const Located(this.lat, this.lon);
}

class LocateResult {
  final Located? at;

  /// Why there is no position, in the reader's language.
  final String? message;

  /// The permission was refused for good: only the phone's settings can
  /// give it now, so the screen offers to open them.
  final bool needsSettings;

  const LocateResult.found(Located this.at)
    : message = null,
      needsSettings = false;
  const LocateResult.failed(String this.message, {this.needsSettings = false})
    : at = null;
}

/// A test's own answer in place of the phone's.
@visibleForTesting
Future<LocateResult> Function()? debugLocate;

String get _typeInstead => t(
  'উপজেলা, ইউনিয়ন বা থানার নাম লিখেও খুঁজতে পারেন।',
  'You can also search by the name of an upazila, union or thana.',
);

/// Asks the phone where it is, asking the reader's permission first if it
/// has not been given.
Future<LocateResult> locateMe() async {
  final test = debugLocate;
  if (test != null) return test();
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocateResult.failed(
        t(
          'ফোনের লোকেশন বন্ধ আছে। চালু করে আবার চেষ্টা করুন। $_typeInstead',
          'Location is turned off on the phone. Turn it on and try again. $_typeInstead',
        ),
      );
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.deniedForever) {
      return LocateResult.failed(
        t(
          'অবস্থানের অনুমতি বন্ধ করা আছে; ফোনের সেটিংসে “আমার এমপি”-র জন্য চালু করা যায়। $_typeInstead',
          'Permission to use your location is turned off; it can be turned on for My MP in the phone’s settings. $_typeInstead',
        ),
        needsSettings: true,
      );
    }
    if (p == LocationPermission.denied ||
        p == LocationPermission.unableToDetermine) {
      return LocateResult.failed(
        t(
          'অবস্থান দেওয়ার অনুমতি দেওয়া হয়নি। $_typeInstead',
          'Permission to use your location was not given. $_typeInstead',
        ),
      );
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return LocateResult.found(Located(pos.latitude, pos.longitude));
  } catch (_) {
    // A timeout, or a platform that cannot tell.
    return LocateResult.failed(
      t(
        'অবস্থান পাওয়া যায়নি। $_typeInstead',
        'Your location could not be found. $_typeInstead',
      ),
    );
  }
}

/// The phone's settings page for this app, where a refused permission can
/// be given again.
Future<void> openLocationSettings() async {
  try {
    await Geolocator.openAppSettings();
  } catch (_) {}
}
