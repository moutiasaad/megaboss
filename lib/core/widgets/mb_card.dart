import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

class MbCard extends StatelessWidget {
  const MbCard({
    super.key,
    required this.child,
    this.accentColor,
    this.onTap,
    this.padding = const EdgeInsets.all(MbSpacing.md2),
  });

  /// Start-side accent border (3 px). Null = standard card. Flips to end-side in RTL.
  final Color? accentColor;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? mbDarkSurface : mbSurface;
    final borderColor = isDark ? mbDarkLine : mbLine;
    Widget body;
    if (accentColor != null) {
      // Stack instead of IntrinsicHeight+Row — compatible with LayoutBuilder descendants.
      // The non-positioned content determines the stack height; the accent bar fills it.
      body = Stack(
        children: [
          Padding(
            padding: EdgeInsetsDirectional.only(start: kMbCardAccentBorder).add(padding),
            child: child,
          ),
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: kMbCardAccentBorder,
            child: ColoredBox(color: accentColor!),
          ),
        ],
      );
    } else {
      body = Padding(padding: padding, child: child);
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x1F142850),
            blurRadius: 18,
            spreadRadius: -10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(MbRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MbRadius.card),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MbRadius.card),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MbRadius.card),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
