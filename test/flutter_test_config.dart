// Runs around every test file (flutter test picks it up by name).
//
// Members' photographs (MemberAvatar) go through cached_network_image, whose
// cache keeps its index in sqflite. A test has no sqflite: once a test lets
// real time pass (runAsync), the cache tried to open its database and the
// error failed the test, on Codemagic's faster Mac though not on Windows. In
// tests no photograph loads at all, so the avatar shows its letter, with no
// database and no cleanup timer left running.
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  CachedNetworkImageProvider.defaultCacheManager = _NoPhotos();
  await testMain();
}

/// A cache that has nothing: every photograph is an error, which the avatar
/// answers with the member's letter. Only getFileStream is called by
/// cached_network_image for a cache that is not an ImageCacheManager.
class _NoPhotos implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => Stream.error(StateError('no photographs in tests: $url'));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} in tests');
}
