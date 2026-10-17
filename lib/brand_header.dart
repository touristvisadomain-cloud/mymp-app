import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'i18n.dart';
import 'theme.dart';

/// The green head of every tab: the page's name, a line under it, the mymp
/// mark, and whatever belongs up there (the search box, the filter chips).
/// The status bar over it is drawn in white.
class BrandHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? bottom;
  final Widget? trailing;

  const BrandHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.bottom,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppDecor.headerGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
        ),
        child: Stack(
          children: [
            // A faint ring behind the title, so the band is not a flat slab of green.
            Positioned(
              right: -60,
              top: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.pagePad,
                  12,
                  AppSizes.pagePad,
                  bottom == null ? 22 : 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontFamily: 'NotoSansBengali',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.3,
                                ),
                              ),
                              if (subtitle != null)
                                Text(
                                  subtitle!,
                                  style: TextStyle(
                                    fontFamily: 'NotoSansBengali',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.82),
                                    height: 1.4,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        trailing ?? const BrandMark(),
                      ],
                    ),
                    if (bottom != null) ...[
                      const SizedBox(height: 14),
                      bottom!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The mymp mark on a white tile.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
    );
  }
}

/// A number and its label, in white on the header.
class HeaderStat extends StatelessWidget {
  final String value;
  final String label;
  const HeaderStat({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.25,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The search box as it sits on the green header: white, no outline.
class HeaderSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const HeaderSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          fontFamily: 'NotoSansBengali',
          fontSize: 15,
          color: AppColors.ink,
        ),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.brand,
            size: 22,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: t('মুছুন', 'Clear'),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.muted,
                  ),
                  onPressed: onClear,
                ),
          filled: true,
          fillColor: Colors.white,
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }
}
