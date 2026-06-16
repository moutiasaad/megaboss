import 'package:flutter/material.dart';
import '../i18n/app_strings.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

// ── Loading skeleton ───────────────────────────────────────────────────────────

class MbLoadingView extends StatelessWidget {
  const MbLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        _PulseBox(height: 140),
        SizedBox(height: MbSpacing.md),
        _PulseBox(height: 90),
        SizedBox(height: MbSpacing.md),
        _PulseBox(height: 70),
      ],
    );
  }
}

class _PulseBox extends StatefulWidget {
  const _PulseBox({required this.height});
  final double height;

  @override
  State<_PulseBox> createState() => _PulseBoxState();
}

class _PulseBoxState extends State<_PulseBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: isDark ? mbDarkSurface : mbSurface3,
            borderRadius: BorderRadius.circular(MbRadius.card),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class MbEmptyView extends StatelessWidget {
  const MbEmptyView({
    super.key,
    required this.strings,
    required this.onRefresh,
  });

  final AppStrings strings;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MbSpacing.xl2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 56,
            color: isDark ? mbDarkInk3 : mbInk3,
          ),
          const SizedBox(height: MbSpacing.md),
          Text(
            strings.dashEmptyTitle,
            style: MbTypography.h2(isDark ? mbDarkInk : mbInk),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MbSpacing.xs),
          Text(
            strings.dashEmptyBody,
            style: MbTypography.sub(isDark ? mbDarkInk2 : mbInk2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MbSpacing.lg),
          OutlinedButton(
            onPressed: onRefresh,
            child: Text(strings.dashRefresh),
          ),
        ],
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────────

class MbErrorView extends StatelessWidget {
  const MbErrorView({
    super.key,
    required this.strings,
    required this.onRetry,
    this.detail,
  });

  final AppStrings strings;
  final VoidCallback onRetry;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MbSpacing.xl2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: mbErr),
          const SizedBox(height: MbSpacing.md),
          Text(
            strings.dashErrorTitle,
            style: MbTypography.h2(mbErr),
            textAlign: TextAlign.center,
          ),
          if (detail != null) ...[
            const SizedBox(height: MbSpacing.sm),
            Text(
              detail!,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF888888),
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: MbSpacing.lg),
          FilledButton(
            onPressed: onRetry,
            child: Text(strings.dashRetry),
          ),
        ],
      ),
    );
  }
}
