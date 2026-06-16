import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/app_strings.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/mb_fab.dart';
import '../../../../core/widgets/mb_offline_banner.dart';
import '../../../../core/widgets/mb_tri_progress.dart';
import '../../../shipments/data/models/shipment_model.dart';
import '../../data/models/runsheet_model.dart';
import '../controllers/runsheet_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Header-specific light-blue colour (#CFE0F1) — only in the blue header.
const _kHeaderSub = Color(0xFFCFE0F1);

class RunsheetDetailScreen extends ConsumerWidget {
  const RunsheetDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final s = AppStrings.of(locale.languageCode);
    final detailAsync = ref.watch(runsheetDetailProvider(id));
    final pendingOps = ref.watch(pendingOpsCountProvider).valueOrNull ?? 0;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Fixed header ───────────────────────────────────────────────
            detailAsync.when(
              loading: () => _HeaderSkeleton(id: id, s: s),
              error: (_, __) => _HeaderMinimal(id: id, s: s),
              data: (rs) => _SummaryHeader(
                runsheet: rs,
                s: s,
                onClose: () => _confirmClose(context, ref, rs, s),
              ),
            ),

            // ── Offline banner ─────────────────────────────────────────────
            if (detailAsync.valueOrNull != null)
              _OfflineBannerSlot(ref: ref, s: s, pendingOps: pendingOps),

            // ── Section label ──────────────────────────────────────────────
            detailAsync.whenOrNull(
              data: (rs) => _SectionLabel(
                label: s.rsdColis(rs.totalShipments),
                suffix: '${rs.deliveredCount} ${s.shipStatusDelivered.toLowerCase()}',
              ),
            ) ??
                const SizedBox(height: MbSpacing.md),

            // ── Shipments list (white card container) ─────────────────────
            Flexible(
              fit: FlexFit.loose,
              child: Builder(
                builder: (ctx) {
                  final isDark = Theme.of(ctx).brightness == Brightness.dark;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? mbDarkSurface : mbSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? mbDarkLine : mbLine,
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: detailAsync.when(
                          loading: () => _ShipmentSkeleton(),
                          error: (e, _) => _ErrorBody(
                            s: s,
                            onRetry: () => ref.invalidate(runsheetDetailProvider(id)),
                          ),
                          data: (rs) {
                            if (rs.shipments.isEmpty) return _EmptyBody(s: s);
                            final sorted = _sortShipments(rs.shipments);
                            return RefreshIndicator(
                              color: mbBlue,
                              onRefresh: () => ref
                                  .read(runsheetDetailProvider(id).notifier)
                                  .refresh(),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(0, 4, 0, 64),
                                itemCount: sorted.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: isDark ? mbDarkLine2 : mbLine2,
                                ),
                                itemBuilder: (ctx2, i) => _ShipmentRow(
                                  key: ValueKey(sorted[i].id),
                                  shipment: sorted[i],
                                  s: s,
                                  index: i,
                                  onTap: () =>
                                      context.push('/shipments/${sorted[i].id}'),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        // ── FAB Scanner (113×44, radius 16) ───────────────────────────────
        PositionedDirectional(
          end: 16,
          bottom: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x8CEE0101),
                  blurRadius: 24,
                  spreadRadius: -8,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: SizedBox(
              width: 113,
              height: 44,
              child: Material(
                color: mbRed,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/scan/delivery?runsheetId=$id');
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(18, 18),
                        painter: const MbScanIconPainter(color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.dashScan,
                        style: GoogleFonts.archivo(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Close flow ─────────────────────────────────────────────────────────────

  Future<void> _confirmClose(
    BuildContext context,
    WidgetRef ref,
    RunsheetModel rs,
    AppStrings s,
  ) async {
    if (rs.status == RunsheetStatus.closed) return;

    if (rs.pendingCount > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(s.rsdCloseConfirmTitle),
          content: Text(s.rsdCloseConfirmBody(rs.pendingCount)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(s.rsdCloseConfirmCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(s.rsdCloseConfirmForce),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    try {
      await ref.read(runsheetDetailProvider(id).notifier).close();
      // Refresh the list so it reflects the new status.
      ref.invalidate(runsheetsPageProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.rsdClosedToast)),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: mbErr,
          ),
        );
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static List<ShipmentModel> _sortShipments(List<ShipmentModel> list) {
    int rank(String st) => switch (st) {
          ShipmentStatus.delivered => 2,
          ShipmentStatus.returned || ShipmentStatus.failed => 3,
          _ => 1,
        };
    return [...list]..sort((a, b) => rank(a.status).compareTo(rank(b.status)));
  }
}

// ── Offline banner slot ────────────────────────────────────────────────────────

class _OfflineBannerSlot extends StatelessWidget {
  const _OfflineBannerSlot({
    required this.ref,
    required this.s,
    required this.pendingOps,
  });
  final WidgetRef ref;
  final AppStrings s;
  final int pendingOps;

  @override
  Widget build(BuildContext context) {
    // Show banner only when we're truly offline (connectivity check is handled
    // upstream; here we just show the stored pending count if >0 or offline flag).
    if (pendingOps == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: MbOfflineBanner(strings: s, pendingCount: pendingOps),
    );
  }
}

// ── Summary header ────────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.runsheet,
    required this.s,
    required this.onClose,
  });

  final RunsheetModel runsheet;
  final AppStrings s;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final rs = runsheet;
    final title = rs.name.isNotEmpty && rs.name != rs.label ? rs.name : rs.label;
    final statusLabel = _statusLabel(rs.status, s);
    final isClosed = rs.status == RunsheetStatus.closed;

    return Container(
      color: mbBlue,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Nav row: back + title + code/status ───────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    label: 'Retour',
                    button: true,
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: GoogleFonts.archivo(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${rs.label} · $statusLabel',
                          style: GoogleFonts.splineSansMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _kHeaderSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 13),

              // ── Summary tiles: delivered / COD ─────────────────────────────
              Semantics(
                label:
                    '${rs.deliveredCount} sur ${rs.totalShipments} livrés, COD ${_fmtCod(rs.codTotal)}',
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryTile(
                        value: '${rs.deliveredCount}/${rs.totalShipments}',
                        label: s.dashDelivered,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryTile(
                        value: _fmtCod(rs.codTotal),
                        label: s.rsdCodTotal,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Tri-color progress ─────────────────────────────────────────
              MbTriProgress(
                delivered: rs.deliveredCount,
                failed: rs.failedCount,
                total: rs.totalShipments,
                semanticLabel:
                    '${rs.deliveredCount} livrés, ${rs.failedCount} échecs, ${rs.pendingCount} restants',
              ),

              const SizedBox(height: 11),

              // ── Action button (full-width close) ───────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _HeaderBtn.light(
                      label: s.rsdClose,
                      onTap: isClosed ? null : onClose,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(String status, AppStrings s) => switch (status) {
        RunsheetStatus.inProgress => s.rsStatusInProgress,
        RunsheetStatus.closed => s.rsStatusClosed,
        RunsheetStatus.cancelled => s.rsStatusCancelled,
        _ => s.rsStatusUpcoming,
      };

  static String _fmtCod(double v) {
    if (v <= 0) return '0 DH';
    final n = v.toInt();
    final str = n.toString();
    final buf = StringBuffer();
    final len = str.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) buf.write(' '); // narrow no-break space
      buf.write(str[i]);
    }
    buf.write(' DH');
    return buf.toString();
  }
}

// ── Summary tile (delivered / COD) ────────────────────────────────────────────

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(0x1F), // ~12 %
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.archivo(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: _kHeaderSub),
          ),
        ],
      ),
    );
  }
}

// ── Header action button ───────────────────────────────────────────────────────

class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn({required this.label, required this.onTap})
      : light = false;
  const _HeaderBtn.light({required this.label, required this.onTap})
      : light = true;

  final String label;
  final VoidCallback? onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: light
          ? (disabled ? Colors.white.withAlpha(0x99) : Colors.white)
          : Colors.white.withAlpha(0x29), // ~16 %
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 36,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!light) ...[
                const Icon(Icons.map_outlined, color: Colors.white, size: 14),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: light
                      ? (disabled ? mbBlue.withAlpha(0x88) : mbBlue)
                      : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.suffix});
  final String label;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? mbDarkInk3 : mbInk3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 9),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.archivo(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.06 * 10.5,
              color: color,
            ),
          ),
          if (suffix != null) ...[
            const Spacer(),
            Text(
              suffix!,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shipment row ───────────────────────────────────────────────────────────────

class _ShipmentRow extends StatelessWidget {
  const _ShipmentRow({
    super.key,
    required this.shipment,
    required this.s,
    required this.index,
    required this.onTap,
  });

  final ShipmentModel shipment;
  final AppStrings s;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sh = shipment;

    final dotColor = _dotColor(sh.status);
    final statusLabel = _statusLabel(sh.status, s);
    final addrShort = sh.city.isNotEmpty ? sh.city : sh.address;
    final trackShort = _shortTracking(sh.trackingNumber);

    final codText =
        sh.hasCod ? _fmtCodShort(sh.codAmount!) : '—';

    return Semantics(
      label:
          '${sh.recipientName}, $addrShort, $trackShort, $statusLabel'
          '${sh.hasCod ? ', COD $codText' : ''}',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
          child: Row(
            children: [
              // Status dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),

              const SizedBox(width: 11),

              // Recipient + address
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sh.recipientName,
                      style: GoogleFonts.archivo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? mbDarkInk : mbInk,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: '$addrShort · ',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? mbDarkInk3 : mbInk3,
                          ),
                        ),
                        TextSpan(
                          text: trackShort,
                          style: GoogleFonts.splineSansMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark ? mbDarkInk3 : mbInk3,
                          ),
                        ),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // COD amount
              Text(
                codText,
                style: GoogleFonts.archivo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: sh.hasCod
                      ? (isDark ? const Color(0xFF5B9BD5) : mbBlue)
                      : (isDark ? mbDarkInk3 : mbInk3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _dotColor(String status) => switch (status) {
        ShipmentStatus.delivered => mbOk,
        ShipmentStatus.failed || ShipmentStatus.returned => mbErr,
        _ => mbPend,
      };

  static String _statusLabel(String status, AppStrings s) => switch (status) {
        ShipmentStatus.delivered => s.shipStatusDelivered,
        ShipmentStatus.failed => s.shipStatusFailed,
        ShipmentStatus.returned => s.shipStatusReturned,
        _ => s.shipStatusPending,
      };

  static String _shortTracking(String t) {
    if (t.length <= 6) return t;
    return '…${t.substring(t.length - 6)}';
  }

  static String _fmtCodShort(double v) {
    final n = v.toInt();
    if (n < 1000) return '$n';
    final str = n.toString();
    final buf = StringBuffer();
    final len = str.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) buf.write(' ');
      buf.write(str[i]);
    }
    return buf.toString();
  }
}

// ── Header skeleton (loading state) ──────────────────────────────────────────

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton({required this.id, required this.s});
  final int id;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: mbBlue,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nav row
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Runsheet #$id',
                        style: GoogleFonts.archivo(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _SkeletonBar(width: 100, height: 12, opacity: 0.3),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(child: _SkeletonBar(height: 56, opacity: 0.2)),
                  const SizedBox(width: 8),
                  Expanded(child: _SkeletonBar(height: 56, opacity: 0.2)),
                ],
              ),
              const SizedBox(height: 10),
              _SkeletonBar(height: 9, opacity: 0.2),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(child: _SkeletonBar(height: 36, opacity: 0.2)),
                  const SizedBox(width: 8),
                  Expanded(child: _SkeletonBar(height: 36, opacity: 0.2)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({this.width, required this.height, required this.opacity});
  final double? width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

// ── Minimal header for error state ────────────────────────────────────────────

class _HeaderMinimal extends StatelessWidget {
  const _HeaderMinimal({required this.id, required this.s});
  final int id;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: mbBlue,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Runsheet #$id',
                style: GoogleFonts.archivo(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shipment list skeleton ─────────────────────────────────────────────────────

class _ShipmentSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sh = isDark ? mbDarkSurface : mbSurface3;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      itemCount: 6,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: isDark ? mbDarkLine2 : mbLine2,
      ),
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: sh, shape: BoxShape.circle),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 13, width: 120,
                      decoration: BoxDecoration(color: sh, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 4),
                  Container(height: 10, width: 90,
                      decoration: BoxDecoration(color: sh, borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
            Container(width: 36, height: 13,
                decoration: BoxDecoration(color: sh, borderRadius: BorderRadius.circular(4))),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.s});
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48,
                color: isDark ? mbDarkInk3 : mbInk3),
            const SizedBox(height: 12),
            Text(s.rsdEmpty,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? mbDarkInk2 : mbInk2,
                ),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.s, required this.onRetry});
  final AppStrings s;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: mbErr),
            const SizedBox(height: 12),
            Text(s.rsdError,
                style: const TextStyle(fontSize: 14, color: mbErr),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(s.dashRetry)),
          ],
        ),
      ),
    );
  }
}
