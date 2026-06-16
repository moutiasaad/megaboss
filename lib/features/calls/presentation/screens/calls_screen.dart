import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/i18n/app_strings.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/mb_card.dart';
import '../../data/models/call_entry.dart';
import '../../data/models/call_log_model.dart';
import '../controllers/calls_history_controller.dart';

class CallsScreen extends ConsumerStatefulWidget {
  const CallsScreen({super.key});

  @override
  ConsumerState<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends ConsumerState<CallsScreen> {
  final _scrollCtrl = ScrollController();
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _reduceMotion = WidgetsBinding.instance
              .platformDispatcher.accessibilityFeatures.disableAnimations;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRedial(String phone) async {
    if (phone.isEmpty) return;
    await HapticFeedback.lightImpact();
    await launchUrl(Uri.parse('tel:$phone'));
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).languageCode;
    final s = AppStrings.of(locale);
    final callsAsync = ref.watch(callsHistoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentFilter = callsAsync.valueOrNull?.filter ?? CallFilter.all;
    final isOffline = callsAsync.valueOrNull?.offline ?? false;

    return Scaffold(
      backgroundColor: isDark ? mbDarkBg : mbSurface2,
      body: Column(
        children: [
          _CallsAppBar(strings: s),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
            child: _MbSegmented(
              selected: currentFilter,
              strings: s,
              onChanged: (f) =>
                  ref.read(callsHistoryProvider.notifier).setFilter(f),
            ),
          ),
          if (isOffline)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: _OfflineBanner(strings: s),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: callsAsync.when(
                data: (state) =>
                    _buildData(context, s, state, isDark),
                loading: () => _CallsSkeleton(key: const ValueKey('skeleton'), isDark: isDark),
                error: (_, __) => _buildError(s),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildData(
    BuildContext context,
    AppStrings s,
    CallsState state,
    bool isDark,
  ) {
    if (state.items.isEmpty) return _buildEmpty(s, state.filter);

    return KeyedSubtree(
      key: ValueKey(state.filter),
      child: RefreshIndicator(
        onRefresh: () => ref.read(callsHistoryProvider.notifier).refresh(),
        color: mbBlue,
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
          child: MbCard(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (int i = 0; i < state.items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark ? mbDarkLine2 : mbLine2,
                    ),
                  _CallRow(
                    key: ValueKey(state.items[i].id),
                    entry: state.items[i],
                    strings: s,
                    reduceMotion: _reduceMotion,
                    animDelay: Duration(milliseconds: 40 * i),
                    onRedial: () => _onRedial(state.items[i].phone),
                    onTap: state.items[i].shipmentId != null
                        ? () => context
                            .push('/shipments/${state.items[i].shipmentId}')
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(AppStrings s, CallFilter filter) {
    final filterLabel = switch (filter) {
      CallFilter.all => '',
      CallFilter.joined => s.callResultJoined.toLowerCase(),
      CallFilter.noAnswer => s.callResultNoAnswer.toLowerCase(),
      CallFilter.unreachable => s.callResultUnreachable.toLowerCase(),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MbSpacing.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_missed_outlined, size: 56, color: mbInk3),
            const SizedBox(height: MbSpacing.md),
            Text(
              s.callsEmptyTitle,
              style: MbTypography.h3(mbInk2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MbSpacing.xs),
            Text(
              s.callsEmptyBody(filterLabel),
              style: MbTypography.sub(mbInk3),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MbSpacing.lg),
            OutlinedButton(
              onPressed: () =>
                  ref.read(callsHistoryProvider.notifier).refresh(),
              child: Text(s.dashRefresh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(AppStrings s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MbSpacing.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: mbErr),
            const SizedBox(height: MbSpacing.md),
            Text(
              s.callsError,
              style: MbTypography.h3(mbErr),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MbSpacing.lg),
            FilledButton(
              onPressed: () =>
                  ref.read(callsHistoryProvider.notifier).refresh(),
              child: Text(s.dashRetry),
            ),
          ],
        ),
      ),
    );
  }
}

// ── App bar ────────────────────────────────────────────────────────────────────

class _CallsAppBar extends StatelessWidget {
  const _CallsAppBar({required this.strings});
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: mbBlue,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: strings.scanBack,
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      strings.isRtl
                          ? Icons.arrow_forward_ios
                          : Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Text(
                strings.callsTitle,
                style: GoogleFonts.archivo(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              // Filter action button — tap → advanced filter sheet (future)
              Semantics(
                button: true,
                label: 'Filtres avancés',
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(0x24),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Segmented control ──────────────────────────────────────────────────────────

class _MbSegmented extends StatelessWidget {
  const _MbSegmented({
    required this.selected,
    required this.strings,
    required this.onChanged,
  });
  final CallFilter selected;
  final AppStrings strings;
  final ValueChanged<CallFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final segments = [
      (CallFilter.all, strings.callsFilterAll),
      (CallFilter.joined, strings.callsFilterJoined),
      (CallFilter.noAnswer, strings.callsFilterNoAnswer),
      (CallFilter.unreachable, strings.callsFilterUnreachable),
    ];

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? mbDarkSurface2 : mbSurface3,
        borderRadius: BorderRadius.circular(11),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (int i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                button: true,
                selected: selected == segments[i].$1,
                label: segments[i].$2,
                child: GestureDetector(
                  onTap: () => onChanged(segments[i].$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: selected == segments[i].$1
                          ? (isDark ? mbDarkSurface : mbSurface)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: selected == segments[i].$1
                          ? [
                              BoxShadow(
                                color: Colors.black.withAlpha(0x18),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        segments[i].$2,
                        style: GoogleFonts.archivo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: selected == segments[i].$1
                              ? mbBlue
                              : (isDark ? mbDarkInk2 : mbInk2),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Offline banner ─────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.strings});
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: mbWarnBg,
        borderRadius: BorderRadius.circular(MbRadius.chip),
        border: Border.all(color: mbWarn.withAlpha(0x66), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: mbWarn, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              strings.callsOfflineCache,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: mbWarn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton loading ───────────────────────────────────────────────────────────

class _CallsSkeleton extends StatefulWidget {
  const _CallsSkeleton({super.key, required this.isDark});
  final bool isDark;

  @override
  State<_CallsSkeleton> createState() => _CallsSkeletonState();
}

class _CallsSkeletonState extends State<_CallsSkeleton>
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
    _anim = Tween(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isDark ? mbDarkSurface2 : mbSurface3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Opacity(
          opacity: _anim.value,
          child: Container(
            decoration: BoxDecoration(
              color: widget.isDark ? mbDarkSurface : mbSurface,
              borderRadius: BorderRadius.circular(MbRadius.card),
              border: Border.all(
                color: widget.isDark ? mbDarkLine : mbLine,
                width: 1,
              ),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (int i = 0; i < 5; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: widget.isDark ? mbDarkLine2 : mbLine2,
                    ),
                  _SkeletonRow(baseColor: baseColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.baseColor});
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 130,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Call row ───────────────────────────────────────────────────────────────────

class _CallRow extends StatefulWidget {
  const _CallRow({
    super.key,
    required this.entry,
    required this.strings,
    required this.reduceMotion,
    required this.animDelay,
    required this.onRedial,
    this.onTap,
  });
  final CallEntry entry;
  final AppStrings strings;
  final bool reduceMotion;
  final Duration animDelay;
  final VoidCallback onRedial;
  final VoidCallback? onTap;

  @override
  State<_CallRow> createState() => _CallRowState();
}

class _CallRowState extends State<_CallRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _slideY;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fade =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideY = Tween<double>(begin: 10.0, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    if (widget.reduceMotion || widget.animDelay == Duration.zero) {
      _ctrl.value = 1.0; // instant
    } else {
      Future.delayed(widget.animDelay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _resultLabel(AppStrings s) => switch (widget.entry.result) {
        CallResult.reached => s.callResultJoined,
        CallResult.noAnswer => s.callResultNoAnswer,
        _ => s.callResultUnreachable,
      };

  @override
  Widget build(BuildContext context) {
    final s = widget.entry;
    final strings = widget.strings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColors = Theme.of(context).extension<MbStatusColors>()!;

    final (resultBg, resultIcon, resultIconData) = switch (s.result) {
      CallResult.reached => (
          statusColors.okBg,
          statusColors.ok,
          Icons.phone_in_talk_outlined,
        ),
      CallResult.noAnswer => (
          statusColors.warnBg,
          statusColors.warn,
          Icons.phone_missed_outlined,
        ),
      _ => (
          statusColors.errBg,
          statusColors.err,
          Icons.phone_disabled_outlined,
        ),
    };

    final title = '${s.recipient} · ${s.tracking}';
    final resultText = _resultLabel(strings);
    final meta = '$resultText · ${s.time} · ${s.duration}';
    final semanticLabel =
        'Appel à ${s.recipient}, colis ${s.tracking}, $resultText, ${s.time}, durée ${s.duration}';

    Widget body = Semantics(
      label: semanticLabel,
      button: s.shipmentId != null,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              // Result icon (30×30, radius 9, tinted)
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: resultBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(resultIconData, color: resultIcon, size: 15),
              ),
              const SizedBox(width: 10),
              // Middle: title + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.archivo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? mbDarkInk : mbInk,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: GoogleFonts.splineSansMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? mbDarkInk3 : mbInk3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Redial button (48dp touch target wraps 30×30 visible button)
              _RedialButton(
                phone: s.phone,
                semanticLabel: '${strings.callsRedial} ${s.recipient}',
                onRedial: widget.onRedial,
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.reduceMotion) return body;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
          offset: Offset(0, _slideY.value),
          child: child,
        ),
      ),
      child: body,
    );
  }
}

// ── Redial button ─────────────────────────────────────────────────────────────

class _RedialButton extends StatefulWidget {
  const _RedialButton({
    required this.phone,
    required this.semanticLabel,
    required this.onRedial,
  });
  final String phone;
  final String semanticLabel;
  final VoidCallback onRedial;

  @override
  State<_RedialButton> createState() => _RedialButtonState();
}

class _RedialButtonState extends State<_RedialButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween(begin: 1.0, end: 0.85)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _launch() async {
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onRedial();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTap: _launch,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedBuilder(
              animation: _scale,
              builder: (ctx, child) => Transform.scale(
                scale: _scale.value,
                child: child,
              ),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: mbBlue, width: 1.5),
                ),
                child: const Icon(
                  Icons.phone_rounded,
                  color: mbBlue,
                  size: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
