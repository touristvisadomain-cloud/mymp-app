import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'i18n.dart';
import 'theme.dart';
import 'widgets.dart';

/// A fetched screen that keeps what it has shown.
///
/// A refresh, a retry or a quiet background update hands in a new [future];
/// until it lands, the last good data stays on screen, so a pull on a bus
/// with no signal does not swap 348 members for an error page. A spinner or
/// the error page appears only when there is nothing to show yet. When a
/// refresh fails over good data, a short note says so once.
class Loaded<D> extends StatefulWidget {
  final Future<D> future;
  final Widget Function(BuildContext context, D data) builder;
  final VoidCallback onRetry;

  /// What the spinner sits in: a sliver list needs a box, a tab needs a centre.
  final Widget Function(Widget child)? wrap;

  const Loaded({
    super.key,
    required this.future,
    required this.builder,
    required this.onRetry,
    this.wrap,
  });

  @override
  State<Loaded<D>> createState() => _LoadedState<D>();
}

class _LoadedState<D> extends State<Loaded<D>> {
  D? _last;
  bool _hasLast = false;
  Future<D>? _noted;

  @override
  Widget build(BuildContext context) {
    final wrap = widget.wrap ?? (Widget c) => c;
    return FutureBuilder<D>(
      future: widget.future,
      builder: (context, snap) {
        if (snap.hasData) {
          _last = snap.data as D;
          _hasLast = true;
        }
        if (snap.connectionState == ConnectionState.waiting && !_hasLast) {
          return wrap(
            const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            ),
          );
        }
        if (snap.hasError && !_hasLast) {
          return wrap(
            ErrorView(message: '${snap.error}', onRetry: widget.onRetry),
          );
        }
        if (snap.hasError && !identical(_noted, widget.future)) {
          _noted = widget.future;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(
                content: Text(
                  t(
                    'হালনাগাদ করা গেল না; আগের তথ্য দেখানো হচ্ছে।',
                    'Could not update; showing the earlier information.',
                  ),
                  style: const TextStyle(fontFamily: 'NotoSansBengali'),
                ),
              ),
            );
          });
        }
        return widget.builder(context, _last as D);
      },
    );
  }
}

/// Opens a link in the reader's browser or mail app, and says so when the
/// phone has nothing that can open it, rather than doing nothing.
Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
  }
  if (ok || !context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(
        url.startsWith('mailto:')
            ? t(
                'ফোনে কোনো ইমেইল অ্যাপ পাওয়া যায়নি।',
                'No email app was found on the phone.',
              )
            : t('লিংকটি খোলা যায়নি।', 'The link could not be opened.'),
        style: const TextStyle(fontFamily: 'NotoSansBengali'),
      ),
    ),
  );
}

/// Awaits a refresh so the pull indicator stays until it lands; a failure is
/// reported by the screen that shows the data, not thrown into the gesture.
Future<void> settle(Future<Object?> f) async {
  try {
    await f;
  } catch (_) {}
}
