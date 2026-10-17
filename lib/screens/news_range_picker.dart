import 'package:flutter/material.dart';

import '../data/news.dart';
import '../i18n.dart';
import '../theme.dart';

/// A day or a span of days, as the website's RangePicker offers it: one tap
/// for the usual ones (আজ, গতকাল, গত ৭ দিন, গত ৩০ দিন, এই মাস), or a start and
/// an end from day, month and year menus that run from December 2025 to
/// today. Used by the news tab and by a member's news.
///
/// Closed with no span it is a button; closed with a span it shows the span
/// with "বদলান" and a cross to clear it; open it is a card.
class NewsRangePicker extends StatefulWidget {
  final DaySpan? range;

  /// Today in Dhaka, "2026-10-17".
  final String today;

  /// The span picked, or null when it was cleared.
  final ValueChanged<DaySpan?> onPick;

  const NewsRangePicker({
    super.key,
    required this.range,
    required this.today,
    required this.onPick,
  });

  @override
  State<NewsRangePicker> createState() => _NewsRangePickerState();
}

class _NewsRangePickerState extends State<NewsRangePicker> {
  bool _open = false;
  late String _from = widget.range?.from ?? addDays(widget.today, -6);
  late String _to = widget.range?.to ?? widget.today;

  List<(String, String, String)> get _quick {
    final today = widget.today;
    return [
      (t('আজ', 'Today'), today, today),
      (t('গতকাল', 'Yesterday'), addDays(today, -1), addDays(today, -1)),
      (t('গত ৭ দিন', 'Last 7 days'), addDays(today, -6), today),
      (t('গত ৩০ দিন', 'Last 30 days'), addDays(today, -29), today),
      (t('এই মাস', 'This month'), '${today.substring(0, 7)}-01', today),
    ];
  }

  bool _isQuick(String a, String b) =>
      widget.range?.from == a && widget.range?.to == b;

  void _pick(String a, String b) {
    setState(() => _open = false);
    widget.onPick(a.compareTo(b) <= 0 ? (from: a, to: b) : (from: b, to: a));
  }

  static const _label = TextStyle(
    fontFamily: 'NotoSansBengali',
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  @override
  Widget build(BuildContext context) {
    final range = widget.range;
    if (!_open) {
      if (range == null) {
        return Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _open = true),
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(t('তারিখ দিয়ে খুঁজুন', 'Find by date'), style: _label),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.rule),
              backgroundColor: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 38),
              shape: const StadiumBorder(),
            ),
          ),
        );
      }
      final quick = _quick
          .where((q) => _isQuick(q.$2, q.$3))
          .map((q) => q.$1)
          .firstOrNull;
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.only(left: 12, right: 2),
          constraints: const BoxConstraints(minHeight: 38),
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            border: Border.all(color: AppColors.brand),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: AppColors.brand,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  quick ?? spanLabel(range.from, range.to),
                  style: _label.copyWith(color: AppColors.brand),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _from = range.from;
                  _to = range.to;
                  _open = true;
                }),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  t('বদলান', 'Change'),
                  style: _label.copyWith(fontSize: 12.5),
                ),
              ),
              IconButton(
                onPressed: () => widget.onPick(null),
                tooltip: t('তারিখ সরান', 'Clear the date'),
                icon: const Icon(Icons.close_rounded, size: 16),
                color: AppColors.brand,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      );
    }

    final from = _from.compareTo(_to) <= 0 ? _from : _to;
    final to = _from.compareTo(_to) <= 0 ? _to : _from;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, a, b) in _quick)
                _Chip(
                  label: label,
                  on: _isQuick(a, b),
                  onTap: () => _pick(a, b),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            t('অথবা নির্দিষ্ট সময়', 'Or a period of your choice'),
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 13,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          _DateSelect(
            label: t('থেকে', 'From'),
            value: _from,
            today: widget.today,
            onChange: (d) => setState(() => _from = d),
          ),
          const SizedBox(height: 8),
          _DateSelect(
            label: t('পর্যন্ত', 'To'),
            value: _to,
            today: widget.today,
            onChange: (d) => setState(() => _to = d),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(
                onPressed: () => _pick(from, to),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: const StadiumBorder(),
                ),
                child: Text(t('দেখুন', 'Show'), style: _label),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _open = false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.rule),
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  t('বাতিল', 'Cancel'),
                  style: _label.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                spanLabel(from, to),
                style: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 12.5,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? AppColors.brandSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            border: Border.all(color: on ? AppColors.brand : AppColors.rule),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: on ? AppColors.brand : AppColors.ink,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// One day: day, month and year menus in the reader's language, stopping at
/// today and starting at December 2025.
class _DateSelect extends StatelessWidget {
  final String label;
  final String value;
  final String today;
  final ValueChanged<String> onChange;
  const _DateSelect({
    required this.label,
    required this.value,
    required this.today,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final tp = today.split('-').map(int.parse).toList();
    final (ty, tm, td) = (tp[0], tp[1], tp[2]);
    final vp = value.split('-').map(int.parse).toList();
    final (y, m, d) = (vp[0], vp[1], vp[2]);
    final minY = int.parse(feedFrom.substring(0, 4));
    final minM = int.parse(feedFrom.substring(5, 7));
    final firstMonth = y == minY ? minM : 1;
    final lastMonth = y == ty ? tm : 12;
    final lastDay = y == ty && m == tm ? td : daysIn(y, m);

    void set(int ny, int nm, int nd) {
      final mm = nm.clamp(ny == minY ? minM : 1, ny == ty ? tm : 12);
      final max = ny == ty && mm == tm ? td : daysIn(ny, mm);
      String two(int n) => n.toString().padLeft(2, '0');
      onChange('$ny-${two(mm)}-${two(nd.clamp(1, max))}');
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        _Menu(
          semantic: '$label: ${t('দিন', 'day')}',
          value: d.clamp(1, lastDay),
          items: [for (var n = 1; n <= lastDay; n++) (n, t.n(n))],
          onChanged: (n) => set(y, m, n),
        ),
        _Menu(
          semantic: '$label: ${t('মাস', 'month')}',
          value: m.clamp(firstMonth, lastMonth),
          items: [
            for (var n = firstMonth; n <= lastMonth; n++) (n, t.month(n)),
          ],
          onChanged: (n) => set(y, n, d),
        ),
        _Menu(
          semantic: '$label: ${t('বছর', 'year')}',
          value: y,
          items: [for (var n = ty; n >= minY; n--) (n, t.n(n))],
          onChanged: (n) => set(n, m, d),
        ),
      ],
    );
  }
}

class _Menu extends StatelessWidget {
  final String semantic;
  final int value;
  final List<(int, String)> items;
  final ValueChanged<int> onChanged;
  const _Menu({
    required this.semantic,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantic,
      child: Container(
        height: 38,
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          border: Border.all(color: AppColors.rule),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: value,
            isDense: true,
            borderRadius: BorderRadius.circular(12),
            menuMaxHeight: 360,
            icon: const Icon(Icons.expand_more_rounded, size: 18),
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 13.5,
              color: AppColors.ink,
            ),
            items: [
              for (final (v, label) in items)
                DropdownMenuItem(value: v, child: Text(label)),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}

/// One choice in a [ChoiceField]: the value ('' for "all") and its label.
typedef Choice = ({String value, String label});

/// A select box as the website draws one, for a phone: the chosen label in a
/// rounded field; a tap opens the choices in a sheet from the bottom.
class ChoiceField extends StatelessWidget {
  final String title;
  final String value;
  final List<Choice> choices;
  final ValueChanged<String> onChanged;

  /// Shown when the value is not among the choices.
  final String? fallback;

  const ChoiceField({
    super.key,
    required this.title,
    required this.value,
    required this.choices,
    required this.onChanged,
    this.fallback,
  });

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: t('বন্ধ করুন', 'Close'),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: EdgeInsets.only(
                  bottom: 16 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: choices.length,
                itemBuilder: (context, i) {
                  final c = choices[i];
                  final on = c.value == value;
                  return ListTile(
                    title: Text(
                      c.label,
                      style: TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 14.5,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                        color: on ? AppColors.brand : AppColors.ink,
                      ),
                    ),
                    trailing: on
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.brand,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(c.value),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final label =
        choices
            .where((c) => c.value == value)
            .map((c) => c.label)
            .firstOrNull ??
        fallback ??
        (choices.isEmpty ? '' : choices.first.label);
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: value.isEmpty ? AppColors.rule : AppColors.brand,
          ),
        ),
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.only(left: 12, right: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 14,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
