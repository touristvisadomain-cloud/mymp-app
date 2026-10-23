import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mymp/version.dart';

/// The "আরও" tab shows [appVersion]; it must be the release in pubspec.yaml,
/// or a reader sees an old number (1.3.6 showed in 1.3.8's screenshots).
void main() {
  test('appVersion is the version in pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final name = line.split(':')[1].trim().split('+').first;
    expect(appVersion, name);
  });
}
