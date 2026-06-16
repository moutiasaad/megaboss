import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/app_strings.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/mb_card.dart';
import '../../../../core/widgets/mb_segmented.dart';
import '../../data/models/stats_model.dart';
import '../controllers/stats_controller.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatCod(double value, String locale) {
  final decSep = locale == 'en' ? '.' : ',';
  if (value >= 1000) {
    final k = value / 1000;
    final frac = ((k * 10).round() % 10);
    if (frac == 0) return '${k.floor()}k';
    return '${k.floor()}$decSep${frac}k';
  }
  return value.toInt().toString();
}

String _dayLabel(DateTime date, String locale) => switch (locale) {
      'ar' => ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'][date.weekday - 1],
      'en' => ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1],
      _ => ['L', 'M', 'M', 'J', 'V', 'S', 'D'][date.weekday - 1],
    };

// Returns index of bar to highlight (highest delivered), or -1 if all zero.
int _highlightIndex(List<DailyStatModel> stats) {
  if (stats.isEmpty) return -1;
  int best = 0;
  for (int i = 1; i < stats.length; i++) {
    if (stats[i].delivered >= stats[best].delivered) best = i;
  }
  return stats[best].delivered == 0 ? -1 : best;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  StatsParams _params = const StatsParams(period: StatsPeriod.week);
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    final conn = ref.read(connectivityProvider);
    try {
      final result = await conn.checkConnectivity();
      _applyConn(result);
    } catch (_) {}
    _connSub = conn.onConnectivityChanged.listen(_applyConn);
  }

  void _applyConn(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (mounted) setState(() => _isOffline = !online);
  }

  Future<void> _refresh() =>
      ref.read(statsProvider(_params).notifier).refresh();

  Future<void> _onPeriodChanged(String period) async {
    if (period == StatsPeriod.custom) {
      await _pickDateRange();
      return;
    }
    setState(() => _params = StatsParams(period: period));
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 6)),
        end: now,
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: mbBlue),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _params = StatsParams(
          period: StatsPeriod.custom,
          from: picked.start.toIso8601String().substring(0, 10),
          to: picked.end.toIso8601String().substring(0, 10),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).languageCode;
    final s = AppStrings.of(locale);
    final async = ref.watch(statsProvider(_params));

    return Scaffold(
      backgroundColor: mbSurface2,
      body: Column(
        children: [
          _AppBar(title: s.statsTitle),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: mbBlue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
                      child: MbSegmented<String>(
                        selected: _params.period,
                        onChanged: _onPeriodChanged,
                        items: [
                          MbSegmentedItem(
                            value: StatsPeriod.today,
                            label: s.statsPeriodToday,
                          ),
                          MbSegmentedItem(
                            value: StatsPeriod.week,
                            label: s.statsPeriodWeek,
                          ),
                          MbSegmentedItem(
                            value: StatsPeriod.month,
                            label: s.statsPeriodMonth,
                          ),
                          MbSegmentedItem(
                            value: StatsPeriod.custom,
                            label: s.statsPeriodCustom,
                          ),
                        ],
                      ),
                    ),
                    if (_isOffline)
                      _OfflineBanner(label: s.statsOfflineCache),
                    async.when(
                      data: (stats) => _StatsBody(
                        stats: stats,
                        strings: s,
                        locale: locale,
                      ),
                      loading: () => const _LoadingSkeleton(),
                      error: (_, __) =>
                          _ErrorView(strings: s, onRetry: _refresh),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  const _AppBar({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: mbBlue,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 9,
        bottom: 9,
        left: 14,
        right: 14,
      ),
      child: Text(title, style: MbTypography.h2(Colors.white)),
    );
  }
}

// ── Offline banner ────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: mbWarnBg,
        borderRadius: BorderRadius.circular(MbRadius.chip),
        border: Border.all(color: mbWarn.withAlpha(0x66)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: mbWarn, size: 15),
          const SizedBox(width: MbSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.hankenGrotesk(
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

// ── Stats body (data loaded) ──────────────────────────────────────────────────

class _StatsBody extends StatelessWidget {
  const _StatsBody({
    required this.stats,
    required this.strings,
    required this.locale,
  });

  final StatsModel stats;
  final AppStrings strings;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final sorted = [...stats.topFailureReasons]
      ..sort((a, b) => b.count.compareTo(a.count));
    final top5 = sorted.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // (C) KPI grid
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: _KpiGrid(stats: stats, strings: s, locale: locale),
        ),
        // (D) Bar chart
        const SizedBox(height: MbSpacing.lg),
        _SectionLabel(s.statsChartTitle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: MbCard(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 26),
            child: stats.dailyStats.isEmpty
                ? _ChartEmpty(label: s.statsEmpty)
                : _BarChart(dailyStats: stats.dailyStats, locale: locale),
          ),
        ),
        // (E) Failure reasons
        const SizedBox(height: MbSpacing.lg),
        _SectionLabel(s.statsTopFailTitle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: MbCard(
            padding: EdgeInsets.zero,
            child: top5.isEmpty
                ? _NoFailures(label: s.statsNoFailures)
                : _FailureTable(reasons: top5),
          ),
        ),
      ],
    );
  }
}

// ── KPI grid ──────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.stats,
    required this.strings,
    required this.locale,
  });

  final StatsModel stats;
  final AppStrings strings;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final codStr = _formatCod(stats.codCollected, locale);
    final reachStr = '${(stats.reachabilityRate * 100).round()}%';

    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.55,
      crossAxisSpacing: 9,
      mainAxisSpacing: 9,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _KpiCard(
          value: '${stats.deliveredCount}',
          label: s.statsKpiSuccess,
          color: mbOk,
          a11y: '${s.statsKpiSuccess}, ${stats.deliveredCount}',
        ),
        _KpiCard(
          value: '${stats.failedCount}',
          label: s.statsKpiFailed,
          color: mbErr,
          a11y: '${s.statsKpiFailed}, ${stats.failedCount}',
        ),
        _KpiCard(
          value: codStr,
          label: s.statsKpiCod(stats.codCurrency),
          color: mbBlue,
          a11y: '${s.statsKpiCod(stats.codCurrency)}, $codStr',
        ),
        _KpiCard(
          value: reachStr,
          label: s.statsKpiReachRate,
          color: mbInk,
          a11y: '${s.statsKpiReachRate}, $reachStr',
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.value,
    required this.label,
    required this.color,
    required this.a11y,
  });

  final String value;
  final String label;
  final Color color;
  final String a11y;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: a11y,
      excludeSemantics: true,
      child: MbCard(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: MbTypography.stat(color)),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: mbInk3,
                letterSpacing: 0.315,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: Text(
        text,
        style: GoogleFonts.hankenGrotesk(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: mbInk3,
          letterSpacing: 0.315,
        ),
      ),
    );
  }
}

// ── Bar chart ─────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  const _BarChart({required this.dailyStats, required this.locale});

  final List<DailyStatModel> dailyStats;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final isRtl = locale == 'ar';
    final ordered = isRtl ? dailyStats.reversed.toList() : dailyStats;
    final labels = ordered.map((d) => _dayLabel(d.date, locale)).toList();
    final hiIdx = _highlightIndex(ordered);
    final maxVal =
        ordered.fold(0, (m, d) => d.delivered > m ? d.delivered : m);
    final maxY = maxVal > 0 ? (maxVal * 1.25).ceilToDouble() : 8.0;

    final groups = ordered.asMap().entries.map((e) {
      final i = e.key;
      final d = e.value;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: d.delivered.toDouble(),
            color: i == hiIdx ? mbErr : mbBlue,
            width: 18,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(5),
              topRight: Radius.circular(5),
            ),
          ),
        ],
      );
    }).toList();

    return Semantics(
      label: hiIdx >= 0
          ? '${labels[hiIdx]} · ${ordered[hiIdx].delivered}'
          : '',
      child: SizedBox(
        height: 120,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            barGroups: groups,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: mbLine2, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= labels.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 4,
                      child: Text(
                        labels[i],
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 9,
                          color: mbInk3,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => mbInk.withAlpha(0xDD),
                getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                  '${labels[group.x]} · ${rod.toY.toInt()}',
                  GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ),
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.hankenGrotesk(fontSize: 13, color: mbInk3),
        ),
      ),
    );
  }
}

// ── Failure table ─────────────────────────────────────────────────────────────

class _FailureTable extends StatelessWidget {
  const _FailureTable({required this.reasons});
  final List<FailureReasonModel> reasons;

  @override
  Widget build(BuildContext context) {
    final max = reasons.fold(0, (m, r) => r.count > m ? r.count : m);
    return Column(
      children: reasons.asMap().entries.map((e) {
        final i = e.key;
        final r = e.value;
        return Column(
          children: [
            if (i > 0) const Divider(color: mbLine2, height: 1, thickness: 1),
            _ReasonRow(
              reason: r.reason,
              count: r.count,
              fraction: max > 0 ? r.count / max : 0.0,
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.reason,
    required this.count,
    required this.fraction,
  });

  final String reason;
  final int count;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              reason,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12.5,
                color: mbInk,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: fraction.clamp(0.05, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: mbErr,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$count',
            style: GoogleFonts.archivo(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: mbInk2,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoFailures extends StatelessWidget {
  const _NoFailures({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.hankenGrotesk(fontSize: 13, color: mbInk3),
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.55,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(4, (_) => const _SkeletonBox()),
          ),
          const SizedBox(height: 16),
          const _SkeletonBox(height: 160),
          const SizedBox(height: 16),
          const _SkeletonBox(height: 130),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.height});
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: mbLine2,
        borderRadius: BorderRadius.circular(MbRadius.card),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.strings, required this.onRetry});
  final AppStrings strings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: mbInk3),
          const SizedBox(height: MbSpacing.md),
          Text(
            strings.statsError,
            textAlign: TextAlign.center,
            style: GoogleFonts.hankenGrotesk(fontSize: 14, color: mbInk2),
          ),
          const SizedBox(height: MbSpacing.lg),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: mbBlue),
            child: Text(strings.statsRetry),
          ),
        ],
      ),
    );
  }
}
