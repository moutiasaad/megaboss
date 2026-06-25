import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/app_strings.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/mb_card.dart';
import '../../../../core/widgets/mb_chip.dart';
import '../../../../core/widgets/mb_segmented.dart';
import '../../data/models/pickup_model.dart';
import '../controllers/pickups_controller.dart';

// ── Pickups screen ─────────────────────────────────────────────────────────────

class PickupsScreen extends ConsumerStatefulWidget {
  const PickupsScreen({super.key});

  @override
  ConsumerState<PickupsScreen> createState() => _PickupsScreenState();
}

class _PickupsScreenState extends ConsumerState<PickupsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final s = AppStrings.of(locale.languageCode);
    final pickupsAsync = ref.watch(pickupsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingOps = ref.watch(pendingOpsCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: isDark ? mbDarkBg : mbSurface2,
      body: Column(
        children: [
          // (A) App bar
          _PickupsAppBar(title: s.pickupTitle),

          // (B) Segmented + optional offline banner + list
          pickupsAsync.when(
            loading: () => _buildLoading(s, isDark),
            error: (_, __) => _buildError(s, ref),
            data: (state) => _buildData(context, s, state, isDark, pendingOps),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(AppStrings s, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          _SegmentedBar(
            senders: const [],
            filter: '',
            allLabel: s.pickupFilterAll,
            isDark: isDark,
            onChanged: (_) {},
          ),
          Expanded(child: _PickupSkeleton(isDark: isDark)),
        ],
      ),
    );
  }

  Widget _buildError(AppStrings s, WidgetRef ref) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(MbSpacing.xl2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: mbErr),
              const SizedBox(height: MbSpacing.md),
              Text(
                s.pickupError,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: mbErr,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MbSpacing.lg),
              FilledButton(
                onPressed: () => ref.read(pickupsProvider.notifier).refresh(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildData(
    BuildContext context,
    AppStrings s,
    PickupsState state,
    bool isDark,
    int pendingOps,
  ) {
    final senders = state.senders;
    final filtered = state.filtered;

    return Expanded(
      child: Column(
        children: [
          // Segmented control
          _SegmentedBar(
            senders: senders,
            filter: state.filter,
            allLabel: s.pickupFilterAll,
            isDark: isDark,
            onChanged: (v) => ref.read(pickupsProvider.notifier).setFilter(v),
          ),

          // Offline banner
          if (state.offline)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: _OfflineBanner(isDark: isDark, label: s.dashOfflineCache),
            ),

          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(pickupsProvider.notifier).refresh(),
              color: mbBlue,
              child: filtered.isEmpty
                  ? _buildEmpty(s, state.filter)
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: ListView.builder(
                        key: ValueKey(state.filter),
                        controller: _scrollCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _ManifestCard(
                          key: ValueKey(filtered[i].id),
                          pickup: filtered[i],
                          strings: s,
                          reduceMotion: _reduceMotion,
                          animDelay: Duration(milliseconds: _reduceMotion ? 0 : i * 40),
                          onTap: () async {
                            await context.push('/pickups/${filtered[i].id}');
                            ref.invalidate(pickupsProvider);
                          },
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppStrings s, String filter) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: 400,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(MbSpacing.xl2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_shipping_outlined,
                    size: 56, color: Theme.of(context).brightness == Brightness.dark ? mbDarkInk3 : mbInk3),
                const SizedBox(height: MbSpacing.md),
                Text(
                  s.pickupEmptyTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: MbSpacing.xs),
                Text(
                  s.pickupEmptyBody(filter),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).brightness == Brightness.dark ? mbDarkInk2 : mbInk2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── App bar ────────────────────────────────────────────────────────────────────

class _PickupsAppBar extends StatelessWidget {
  const _PickupsAppBar({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: mbBlue,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.archivo(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Filter action button
                Semantics(
                  button: true,
                  label: 'Filtrer',
                  child: GestureDetector(
                    onTap: () {}, // reserved for advanced filter sheet
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(0x24),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.filter_list_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Segmented bar ──────────────────────────────────────────────────────────────

class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({
    required this.senders,
    required this.filter,
    required this.allLabel,
    required this.isDark,
    required this.onChanged,
  });

  final List<String> senders;
  final String filter;
  final String allLabel;
  final bool isDark;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Total tabs = "Tous" + all unique senders
    final allItems = [
      MbSegmentedItem<String>(value: '', label: allLabel),
      ...senders.map((s) => MbSegmentedItem<String>(value: s, label: _shortName(s))),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      // Scrollable when > 4 tabs to avoid cramping
      child: allItems.length > 4
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _ScrollableSegmented(
                items: allItems,
                selected: filter,
                isDark: isDark,
                onChanged: onChanged,
              ),
            )
          : MbSegmented<String>(
              items: allItems,
              selected: filter,
              onChanged: onChanged,
            ),
    );
  }

  // Abbreviate long sender names to first word
  String _shortName(String name) {
    final words = name.trim().split(' ');
    return words.first;
  }
}

// Scrollable variant — items have a fixed width instead of Expanded
class _ScrollableSegmented extends StatelessWidget {
  const _ScrollableSegmented({
    required this.items,
    required this.selected,
    required this.isDark,
    required this.onChanged,
  });

  final List<MbSegmentedItem<String>> items;
  final String selected;
  final bool isDark;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? mbDarkSurface2 : mbSurface3,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          final isActive = item.value == selected;
          return GestureDetector(
            onTap: () => onChanged(item.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              constraints: const BoxConstraints(minWidth: 64),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isActive
                    ? (isDark ? mbDarkSurface : mbSurface)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isActive
                    ? const [BoxShadow(color: Color(0x1F142850), blurRadius: 3, offset: Offset(0, 1))]
                    : null,
              ),
              child: Text(
                item.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? (isDark ? Colors.white : mbBlue)
                      : (isDark ? mbDarkInk2 : mbInk2),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Offline banner ─────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.isDark, required this.label});
  final bool isDark;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MbSpacing.md, vertical: MbSpacing.xs),
      decoration: BoxDecoration(
        color: mbWarnBg,
        borderRadius: BorderRadius.circular(MbRadius.chip),
        border: Border.all(color: mbWarn.withAlpha(0x66), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: mbWarn, size: 15),
          const SizedBox(width: MbSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: mbWarn,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Manifest card ──────────────────────────────────────────────────────────────

class _ManifestCard extends StatefulWidget {
  const _ManifestCard({
    super.key,
    required this.pickup,
    required this.strings,
    required this.reduceMotion,
    required this.animDelay,
    required this.onTap,
  });

  final PickupModel pickup;
  final AppStrings strings;
  final bool reduceMotion;
  final Duration animDelay;
  final VoidCallback onTap;

  @override
  State<_ManifestCard> createState() => _ManifestCardState();
}

class _ManifestCardState extends State<_ManifestCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<double>(begin: 10, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    if (widget.reduceMotion) {
      _ctrl.value = 1.0;
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

  @override
  Widget build(BuildContext context) {
    final pickup = widget.pickup;
    final s = widget.strings;
    final status = pickup.displayStatus;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final subtitle = status == ManifestStatus.done
        ? s.pickupSubDone(pickup.totalShipments, pickup.collectedCount)
        : s.pickupSubToCollect(pickup.totalShipments, pickup.location);

    final semanticLabel =
        'Manifest ${pickup.manifestNumber}, ${pickup.senderName}, '
        '${pickup.totalShipments} colis, ${pickup.location}, '
        '${_statusLabel(status, s)}, '
        '${pickup.collectedCount} sur ${pickup.totalShipments} collectés';

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: Offset(0, _slide.value),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Semantics(
          label: semanticLabel,
          button: true,
          child: MbCard(
            accentColor: status == ManifestStatus.inProgress ? mbBlue : null,
            onTap: widget.onTap,
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: chip + sender name + status badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Manifest number chip
                    status == ManifestStatus.inProgress
                        ? MbChip.blue(label: pickup.manifestNumber)
                        : _NeutralChip(label: pickup.manifestNumber, isDark: isDark),
                    const SizedBox(width: 9),
                    // Sender name
                    Expanded(
                      child: Text(
                        pickup.senderName,
                        style: GoogleFonts.archivo(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? mbDarkInk : mbInk,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 9),
                    // Status badge
                    _StatusBadge(status: status, s: s),
                  ],
                ),
                const SizedBox(height: 7),
                // Sub-line
                Text(
                  subtitle,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? mbDarkInk2 : mbInk2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Progress bar (hidden for upcoming)
                if (pickup.progressFraction != null) ...[
                  const SizedBox(height: 10),
                  _ProgressBar(fraction: pickup.progressFraction!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(ManifestStatus status, AppStrings s) => switch (status) {
        ManifestStatus.inProgress => s.pickupStatusInProgress,
        ManifestStatus.upcoming => s.pickupStatusUpcoming,
        ManifestStatus.done => s.pickupStatusDone,
      };
}

// ── Neutral (grey) chip ────────────────────────────────────────────────────────

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
          color: (isDark ? mbDarkLine : mbLine).withAlpha(0xAA),
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

// ── Status badge ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.s});
  final ManifestStatus status;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color dot;
    final Color bg;
    final Color fg;
    final String label;

    switch (status) {
      case ManifestStatus.done:
        dot = mbOk;
        bg = isDark ? const Color(0xFF052E14) : mbOkBg;
        fg = mbOk;
        label = s.pickupStatusDone;
      case ManifestStatus.inProgress:
      case ManifestStatus.upcoming:
        dot = mbBlue;
        bg = isDark ? const Color(0xFF001E45) : mbPendBg;
        fg = isDark ? const Color(0xFF5B9BD5) : mbBlue;
        label = status == ManifestStatus.inProgress
            ? s.pickupStatusInProgress
            : s.pickupStatusUpcoming;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MbRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress bar ───────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark ? mbDarkLine : mbSurface3;
    final disableAnim = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction),
      duration: disableAnim ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (_, value, __) => LayoutBuilder(
        builder: (_, constraints) {
          final total = constraints.maxWidth;
          final filled = (total * value).clamp(0.0, total);
          return ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 7,
              child: Row(
                children: [
                  if (filled > 0) Container(width: filled, color: mbOk),
                  Expanded(child: Container(color: trackColor)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Skeleton ───────────────────────────────────────────────────────────────────

class _PickupSkeleton extends StatefulWidget {
  const _PickupSkeleton({required this.isDark});
  final bool isDark;

  @override
  State<_PickupSkeleton> createState() => _PickupSkeletonState();
}

class _PickupSkeletonState extends State<_PickupSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MbCard(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SkBox(w: 60, h: 20, isDark: widget.isDark),
                      const SizedBox(width: 9),
                      Expanded(child: _SkBox(w: double.infinity, h: 16, isDark: widget.isDark)),
                      const SizedBox(width: 9),
                      _SkBox(w: 70, h: 20, isDark: widget.isDark),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SkBox(w: 180, h: 13, isDark: widget.isDark),
                  const SizedBox(height: 10),
                  _SkBox(w: double.infinity, h: 7, isDark: widget.isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkBox extends StatelessWidget {
  const _SkBox({required this.w, required this.h, required this.isDark});
  final double w;
  final double h;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w == double.infinity ? null : w,
      height: h,
      decoration: BoxDecoration(
        color: isDark ? mbDarkLine : mbSurface3,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
