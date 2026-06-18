import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/app_strings.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/mb_card.dart';
import '../../../../core/widgets/mb_chip.dart';
import '../../../../core/widgets/mb_offline_banner.dart';
import '../../../../core/widgets/mb_segmented.dart';
import '../../../../core/widgets/mb_status_badge.dart';
import '../../../../core/widgets/mb_tri_progress.dart';
import '../../data/models/runsheet_model.dart';
import '../controllers/runsheet_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────

class RunsheetsScreen extends ConsumerStatefulWidget {
  const RunsheetsScreen({super.key});

  @override
  ConsumerState<RunsheetsScreen> createState() => _RunsheetsScreenState();
}

class _RunsheetsScreenState extends ConsumerState<RunsheetsScreen> {
  final _scroll = ScrollController();
  RunsheetPeriod _selectedPeriod = RunsheetPeriod.today;
  int _slideDirection = 1; // +1 = slide from right, -1 = slide from left

  static const _periodOrder = [
    RunsheetPeriod.today,
    RunsheetPeriod.week,
    RunsheetPeriod.month,
    RunsheetPeriod.custom,
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 200) {
      ref.read(runsheetsPageProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() =>
      ref.read(runsheetsPageProvider.notifier).refresh();

  Future<void> _onPeriodChanged(RunsheetPeriod p) async {
    if (p == _selectedPeriod) return;
    final oldIdx = _periodOrder.indexOf(_selectedPeriod);
    final newIdx = _periodOrder.indexOf(p);
    // Update direction + selected period immediately so the animation fires
    // at tap time, not when the async data eventually loads.
    setState(() {
      _slideDirection = newIdx > oldIdx ? 1 : -1;
      _selectedPeriod = p;
    });

    if (p == RunsheetPeriod.custom) {
      final now = DateTime.now();
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 1),
        lastDate: now,
        initialDateRange: DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        ),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: mbBlue),
          ),
          child: child!,
        ),
      );
      if (range == null || !mounted) return;
      String fmtDate(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      await ref.read(runsheetsPageProvider.notifier).setPeriod(
            RunsheetPeriod.custom,
            from: fmtDate(range.start),
            to: fmtDate(range.end),
          );
    } else {
      await ref.read(runsheetsPageProvider.notifier).setPeriod(p);
    }
    if (mounted) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final s = AppStrings.of(locale.languageCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageAsync = ref.watch(runsheetsPageProvider);
    final pendingOps = ref.watch(pendingOpsCountProvider).valueOrNull ?? 0;

    final isOffline = pageAsync.valueOrNull?.offline ?? false;

    return Column(
      children: [
        // ── App bar ─────────────────────────────────────────────────────────
        _AppBar(s: s),

        // ── Period segmented control ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: MbSegmented<RunsheetPeriod>(
            selected: _selectedPeriod,
            onChanged: _onPeriodChanged,
            items: [
              MbSegmentedItem(value: RunsheetPeriod.today, label: s.rsPeriodToday),
              MbSegmentedItem(value: RunsheetPeriod.week,  label: s.rsPeriodWeek),
              MbSegmentedItem(value: RunsheetPeriod.month, label: s.rsPeriodMonth),
              MbSegmentedItem(value: RunsheetPeriod.custom,label: s.rsPeriodCustom),
            ],
          ),
        ),

        // ── Offline banner ───────────────────────────────────────────────────
        if (isOffline)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: MbOfflineBanner(strings: s, pendingCount: pendingOps),
          ),

        // ── Body ─────────────────────────────────────────────────────────────
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              final isIncoming = child.key == ValueKey(_selectedPeriod);
              final dx = isIncoming
                  ? _slideDirection.toDouble()
                  : -_slideDirection.toDouble();
              return SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(dx, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                    parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_selectedPeriod),
              child: pageAsync.when(
                loading: () => _SkeletonList(isDark: isDark),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(MbSpacing.xl2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: mbErr),
                        const SizedBox(height: MbSpacing.md),
                        Text(
                          s.rsErrorTitle,
                          style: MbTypography.h2(mbErr),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: MbSpacing.lg),
                        FilledButton(
                          onPressed: _onRefresh,
                          child: Text(s.dashRetry),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (data) {
                  if (data.items.isEmpty) {
                    return _EmptyBody(s: s, onRefresh: _onRefresh);
                  }
                  return RefreshIndicator(
                    color: mbBlue,
                    onRefresh: _onRefresh,
                    child: ListView.separated(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
                      itemCount: data.items.length + 1, // +1 for footer
                      separatorBuilder: (_, __) => const SizedBox(height: 13),
                      itemBuilder: (context, i) {
                        if (i == data.items.length) {
                          return _ListFooter(data: data);
                        }
                        final rs = data.items[i];
                        return _RunsheetRow(
                          key: ValueKey(rs.id),
                          runsheet: rs,
                          strings: s,
                          index: i,
                          onTap: () => context.push('/runsheets/${rs.id}'),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  const _AppBar({required this.s});
  final AppStrings s;

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
              Text(s.rsTitle, style: MbTypography.h2(Colors.white)),
              const Spacer(),
              Semantics(
                label: s.rsFilter,
                child: Material(
                  color: const Color(0x24FFFFFF),
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () {},
                    child: const SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                    ),
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

// ── Runsheet row ──────────────────────────────────────────────────────────────

class _RunsheetRow extends StatefulWidget {
  const _RunsheetRow({
    super.key,
    required this.runsheet,
    required this.strings,
    required this.index,
    required this.onTap,
  });

  final RunsheetModel runsheet;
  final AppStrings strings;
  final int index;
  final VoidCallback onTap;

  @override
  State<_RunsheetRow> createState() => _RunsheetRowState();
}

class _RunsheetRowState extends State<_RunsheetRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    final delay = Duration(milliseconds: (widget.index * 55).clamp(0, 280));
    if (delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rs = widget.runsheet;
    final isActive = rs.isActive;

    final statusLabel = switch (rs.status) {
      RunsheetStatus.inProgress => widget.strings.rsStatusInProgress,
      RunsheetStatus.closed => widget.strings.rsStatusClosed,
      RunsheetStatus.cancelled => widget.strings.rsStatusCancelled,
      _ => widget.strings.rsStatusUpcoming,
    };

    final title = rs.name.isNotEmpty && rs.name != rs.label ? rs.name : null;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Semantics(
          label: 'Runsheet ${rs.label}'
              '${title != null ? ', $title' : ''}'
              ', $statusLabel'
              ', ${widget.strings.rsLineSummary(
                total: rs.totalShipments,
                delivered: rs.deliveredCount,
                failed: rs.failedCount,
                remaining: rs.pendingCount,
              )}',
          button: true,
          child: MbCard(
            accentColor: isActive ? mbRed : null,
            onTap: widget.onTap,
            padding: const EdgeInsets.all(MbSpacing.md2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1 — reference chip + title + status badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isActive)
                      MbChip.red(label: rs.label)
                    else
                      _NeutralChip(label: rs.label, isDark: isDark),
                    if (title != null) ...[
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          title,
                          style: MbTypography.bodyBold(
                            isDark ? mbDarkInk : mbInk,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    const SizedBox(width: 8),
                    MbStatusBadge(status: rs.status, label: statusLabel),
                  ],
                ),

                // Row 2 — summary sub-line
                if (rs.totalShipments > 0) ...[
                  const SizedBox(height: 7),
                  Text(
                    widget.strings.rsLineSummary(
                      total: rs.totalShipments,
                      delivered: rs.deliveredCount,
                      failed: rs.failedCount,
                      remaining: rs.pendingCount,
                    ),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? mbDarkInk2 : mbInk2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Row 3 — mini progress bar
                  const SizedBox(height: 8),
                  MbTriProgress(
                    delivered: rs.deliveredCount,
                    failed: rs.failedCount,
                    total: rs.totalShipments,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Neutral chip (non-active runsheet reference) ──────────────────────────────

class _NeutralChip extends StatelessWidget {
  const _NeutralChip({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? mbDarkSurface2 : mbSurface3,
        borderRadius: BorderRadius.circular(MbRadius.chip),
        border: Border.all(
          color: isDark ? mbDarkLine : mbLine,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.splineSansMono(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? mbDarkInk2 : mbInk2,
        ),
      ),
    );
  }
}

// ── List footer (load-more indicator) ────────────────────────────────────────

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.data});
  final RunsheetsPageData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        if (data.isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: MbSpacing.md),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: mbBlue,
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.s, required this.onRefresh});
  final AppStrings s;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 56,
                  color: isDark ? mbDarkInk3 : mbInk3,
                ),
                const SizedBox(height: MbSpacing.md),
                Text(
                  s.rsEmptyTitle,
                  style: MbTypography.h2(isDark ? mbDarkInk : mbInk),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: MbSpacing.xs),
                Text(
                  s.rsEmptyBody,
                  style: MbTypography.sub(isDark ? mbDarkInk2 : mbInk2),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: MbSpacing.lg),
                OutlinedButton(
                  onPressed: onRefresh,
                  child: Text(s.dashRefresh),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  const _SkeletonList({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 13),
      itemBuilder: (_, i) => _SkeletonRow(isDark: isDark, wide: i == 0),
    );
  }
}

class _SkeletonRow extends StatefulWidget {
  const _SkeletonRow({required this.isDark, required this.wide});
  final bool isDark;
  final bool wide;

  @override
  State<_SkeletonRow> createState() => _SkeletonRowState();
}

class _SkeletonRowState extends State<_SkeletonRow>
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
    _anim = Tween(begin: 0.4, end: 1.0).animate(
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
    final bg = widget.isDark ? mbDarkSurface : mbSurface;
    final sh = widget.isDark ? mbDarkSurface2 : mbSurface3;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          padding: const EdgeInsets.all(MbSpacing.md2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(MbRadius.card),
            border: Border.all(
              color: widget.isDark ? mbDarkLine : mbLine,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 22,
                    decoration: BoxDecoration(
                      color: sh,
                      borderRadius: BorderRadius.circular(MbRadius.chip),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: widget.wide ? 140 : 100,
                    height: 14,
                    decoration: BoxDecoration(
                      color: sh,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 72,
                    height: 22,
                    decoration: BoxDecoration(
                      color: sh,
                      borderRadius: BorderRadius.circular(MbRadius.pill),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                height: 11,
                decoration: BoxDecoration(
                  color: sh,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 9,
                decoration: BoxDecoration(
                  color: sh,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
