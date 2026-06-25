import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/app_strings.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/mb_app_header.dart';
import '../../../../core/widgets/mb_card.dart';
import '../../../../core/widgets/mb_chip.dart';
import '../../../../core/widgets/mb_offline_banner.dart';
import '../../../../core/widgets/mb_state_view.dart';
import '../../../../core/widgets/mb_stat_pill.dart';
import '../../../../core/widgets/mb_tri_progress.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../data/models/dashboard_data.dart';
import '../controllers/dashboard_controller.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _silentRefresh();
  }

  void _silentRefresh() => ref.read(dashboardProvider.notifier).refresh();

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    _silentRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final s = AppStrings.of(locale.languageCode);
    final dashAsync = ref.watch(dashboardProvider);
    final pendingOps = ref.watch(pendingOpsCountProvider).valueOrNull ?? 0;
    // Warm the motifs cache on Home so the return / refuse sheets open with a
    // fully populated dropdown on the first try.
    ref.watch(motifsProvider);
    // Bell badge — backed by GET /driver/notifications/unread-count, with a
    // cached fallback so the badge survives offline / API errors.
    final unread = ref.watch(unreadNotifCountProvider).valueOrNull ?? 0;

    return Column(
      children: [
        // ── Fixed blue header ────────────────────────────────────────────────
        dashAsync.when(
          data: (data) => MbAppHeader(
            driverName: data.driver.name,
            isAvailable: data.driver.isAvailable,
            pendingSyncOps: pendingOps,
            unreadNotifications: unread,
            strings: s,
            onBell: () async {
              await context.push('/dashboard/notifications');
              if (!mounted) return;
              // Returning from the inbox — refresh the badge count.
              ref.invalidate(unreadNotifCountProvider);
            },
            onSyncTap: () => context.push('/settings'),
          ),
          loading: () => MbAppHeader(
            driverName: '...',
            isAvailable: true,
            pendingSyncOps: 0,
            unreadNotifications: unread,
            strings: s,
          ),
          error: (_, __) => MbAppHeader(
            driverName: '—',
            isAvailable: false,
            pendingSyncOps: 0,
            unreadNotifications: unread,
            strings: s,
          ),
        ),

        // ── Scrollable body ──────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              if (dashAsync.valueOrNull?.isOffline ?? false) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.dashOfflineToast)),
                );
              }
              await ref.read(dashboardProvider.notifier).refresh();
            },
            color: mbRed,
            child: dashAsync.when(
              data: (data) => _DashboardBody(
                data: data,
                strings: s,
                scrollController: _scrollController,
                locale: locale.languageCode,
              ),
              loading: () => ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 80),
                children: const [MbLoadingView()],
              ),
              error: (err, __) => ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 80),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  MbErrorView(
                    strings: s,
                    onRetry: _silentRefresh,
                    detail: '$err',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Dashboard body ─────────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.data,
    required this.strings,
    required this.scrollController,
    required this.locale,
  });

  final DashboardData data;
  final AppStrings strings;
  final ScrollController scrollController;
  final String locale;

  @override
  Widget build(BuildContext context) {
    // Show the active runsheet/pickup only when it has colis AND there are
    // still some to action. Once everything has been delivered/returned (or
    // collected/refused) the driver just needs to close it — no point taking
    // Home screen real estate.
    final showRunsheet = data.activeRunsheet != null &&
        data.activeRunsheet!.total > 0 &&
        data.activeRunsheet!.remaining > 0;
    final showPickup = data.activePickup != null &&
        data.activePickup!.totalShipments > 0 &&
        data.activePickup!.pendingCount > 0;
    final hasContent = showRunsheet || showPickup;

    // Stagger delay: 60 ms per card visible on screen.
    int d = 0;
    int nextDelay() {
      final v = d;
      d += 60;
      return v;
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 80),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // Offline banner
        if (data.isOffline) ...[
          const SizedBox(height: 13),
          MbOfflineBanner(strings: strings, pendingCount: data.pendingSyncOps),
        ],

        // ── Active runsheet ──────────────────────────────────────────────
        if (showRunsheet) ...[
          const SizedBox(height: 13),
          SectionLabel(strings.dashSectionRunsheet),
          _AnimatedCard(
            delay: nextDelay(),
            child: _RunsheetCard(
              summary: data.activeRunsheet!,
              strings: strings,
            ),
          ),
        ],

        // ── Active pickup ────────────────────────────────────────────────
        if (showPickup) ...[
          const SizedBox(height: 13),
          SectionLabel(strings.dashSectionPickup),
          _AnimatedCard(
            delay: nextDelay(),
            child: _PickupCard(summary: data.activePickup!, strings: strings),
          ),
        ],

        // ── Today stats ──────────────────────────────────────────────────
        const SizedBox(height: 13),
        SectionLabel(strings.dashSectionToday),
        _AnimatedCard(
          delay: nextDelay(),
          child: _TodayCard(stats: data.today, strings: strings, locale: locale),
        ),

        // Empty state (no runsheet + no pickup)
        if (!hasContent) ...[
          const SizedBox(height: 13),
          MbEmptyView(
            strings: strings,
            onRefresh: () => context
                .findAncestorStateOfType<_DashboardScreenState>()
                ?._silentRefresh(),
          ),
        ],
      ],
    );
  }
}

// ── Runsheet card ──────────────────────────────────────────────────────────────

class _RunsheetCard extends StatelessWidget {
  const _RunsheetCard({required this.summary, required this.strings});
  final RunsheetSummary summary;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    // Active runsheet → blue accent + blue chip. Switches to red only when the
    // runsheet has been open for 24h+ (overdue), mirroring the list screen.
    final accent = summary.isOverdue ? mbRed : mbBlue;
    return Semantics(
      label: '${strings.dashSectionRunsheet} RS-${summary.id}, '
          '${summary.label}, '
          '${summary.delivered} ${strings.dashDelivered}, '
          '${summary.failed} ${strings.dashFailed}, '
          '${summary.remaining} ${strings.dashRemaining}',
      child: MbCard(
        accentColor: accent,
        onTap: () => context.go('/runsheets/${summary.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: chip · title · colis count
            Row(
              children: [
                summary.isOverdue
                    ? MbChip.red(label: 'RS-${summary.id}')
                    : MbChip.blue(label: 'RS-${summary.id}'),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    summary.label,
                    style: GoogleFonts.archivo(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: mbInk,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  strings.dashColis(summary.total),
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: mbInk2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),

            // Stats grid: Livrés / Échecs / Restants
            Row(
              children: [
                MbStatPill(
                  value: '${summary.delivered}',
                  label: strings.dashDelivered,
                  valueColor: mbOk,
                ),
                const SizedBox(width: 8),
                MbStatPill(
                  value: '${summary.failed}',
                  label: strings.dashFailed,
                  valueColor: mbErr,
                ),
                const SizedBox(width: 8),
                MbStatPill(
                  value: '${summary.remaining}',
                  label: strings.dashRemaining,
                  valueColor: mbBlue,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tri-color progress bar
            MbTriProgress(
              delivered: summary.delivered,
              failed: summary.failed,
              total: summary.total,
            ),
            const SizedBox(height: 12),

            // CTA button
            OutlinedButton(
              onPressed: () => context.go('/runsheets/${summary.id}'),
              style: _kGhostButtonStyle,
              child: Text(strings.dashViewRunsheet),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pickup card ────────────────────────────────────────────────────────────────

class _PickupCard extends StatelessWidget {
  const _PickupCard({required this.summary, required this.strings});
  final PickupSummary summary;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return MbCard(
      onTap: () => context.go('/pickups'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              MbChip.blue(label: summary.manifestNumber),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  summary.senderName,
                  style: GoogleFonts.archivo(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: mbInk,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Sub-line: "{collected}/{total} collectés · {zone}"
          Text(
            [
              strings.pkdCollected(summary.collectedCount, summary.totalShipments),
              if (summary.zone != null) summary.zone!,
            ].join(' · '),
            style: GoogleFonts.hankenGrotesk(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: mbInk2,
            ),
          ),
          const SizedBox(height: 11),

          // CTA button
          OutlinedButton(
            onPressed: () => context.go('/pickups'),
            style: _kGhostButtonStyle,
            child: Text(strings.dashViewManifest),
          ),
        ],
      ),
    );
  }
}

// ── Today stats card ───────────────────────────────────────────────────────────

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.stats,
    required this.strings,
    required this.locale,
  });

  final DayStats stats;
  final AppStrings strings;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern(locale);
    return MbCard(
      child: Row(
        children: [
          MbStatPill(
            value: fmt.format(stats.deliveries),
            label: strings.dashDeliveries,
            onTap: () => context.push('/stats'),
          ),
          const SizedBox(width: 8),
          MbStatPill(
            value: fmt.format(stats.calls),
            label: strings.dashCalls,
          ),
          const SizedBox(width: 8),
          MbStatPill(
            value: fmt.format(stats.codCollected.round()),
            label: strings.dashCod,
            valueColor: mbBlue,
          ),
        ],
      ),
    );
  }
}

// ── Shared ghost button style ──────────────────────────────────────────────────

final _kGhostButtonStyle = OutlinedButton.styleFrom(
  side: const BorderSide(color: mbBlue, width: 1.5),
  foregroundColor: mbBlue,
  textStyle: GoogleFonts.archivo(fontSize: 14, fontWeight: FontWeight.w700),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(MbRadius.button),
  ),
  minimumSize: const Size(double.infinity, kMbMinTouchTarget),
);

// ── Card entrance animation ────────────────────────────────────────────────────

class _AnimatedCard extends StatefulWidget {
  const _AnimatedCard({required this.child, required this.delay});
  final Widget child;
  final int delay; // ms

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
