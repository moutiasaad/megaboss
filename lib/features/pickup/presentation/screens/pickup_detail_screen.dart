import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/i18n/app_strings.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/mb_fab.dart';
import '../../../../core/widgets/mb_offline_banner.dart';
import '../../data/models/pickup_model.dart';
import '../controllers/pickup_detail_controller.dart';
import '../controllers/pickups_controller.dart';

const _kHeaderSub = Color(0xFFCFE0F1);

// ─────────────────────────────────────────────────────────────────────────────

class PickupDetailScreen extends ConsumerWidget {
  const PickupDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final s = AppStrings.of(locale.languageCode);
    final detailAsync = ref.watch(pickupDetailProvider(id));
    final pendingOps = ref.watch(pendingOpsCountProvider).valueOrNull ?? 0;
    final isOffline = ref.watch(isOfflineProvider).valueOrNull ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pickup = detailAsync.valueOrNull;

    final allCollected = pickup != null &&
        pickup.totalShipments > 0 &&
        pickup.collectedCount >= pickup.totalShipments;

    return Scaffold(
      backgroundColor: isDark ? mbDarkBg : mbSurface2,
      floatingActionButton: MbFab(
        label: s.pkdScanRapide,
        onTap: () => context.push('/scan/pickup?manifest=$id'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // (A) Fixed blue header
          detailAsync.when(
            loading: () => _HeaderSkeleton(id: id),
            error: (_, __) => _HeaderMinimal(id: id),
            data: (p) => _ManifestHeader(pickup: p, s: s),
          ),

          // Offline banner — only when actually offline with unsynced ops
          if (isOffline && pendingOps > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: MbOfflineBanner(strings: s, pendingCount: pendingOps),
            ),

          // "Tous collectés" banner with Clôturer CTA
          if (allCollected)
            _DoneBanner(
              s: s,
              onClose: () =>
                  ref.read(pickupDetailProvider(id).notifier).close(),
            ),

          // (B) Section label "COLIS ATTENDUS · n"
          if (pickup != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 2),
              child: Text(
                s.pkdExpected(pickup.totalShipments),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: isDark ? mbDarkInk3 : mbInk3,
                ),
              ),
            ),

          // (C) Shipment list
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? mbDarkSurface : mbSurface,
                  borderRadius: BorderRadius.circular(MbRadius.card),
                  border: Border.all(
                    color: isDark ? mbDarkLine : mbLine,
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(MbRadius.card - 1),
                  child: RefreshIndicator(
                    color: mbBlue,
                    onRefresh: () =>
                        ref.read(pickupDetailProvider(id).notifier).refresh(),
                    child: detailAsync.when(
                      loading: () => _ShipmentSkeleton(isDark: isDark),
                      error: (_, __) => _ErrorBody(
                        s: s,
                        onRetry: () => ref.invalidate(pickupDetailProvider(id)),
                      ),
                      data: (p) {
                        if (p.shipments.isEmpty) return _EmptyBody(s: s);

                        // pending first, then collected, then refused
                        final sorted = [...p.shipments]
                          ..sort((a, b) {
                            int rank(String st) => switch (st) {
                                  PickupShipmentStatus.pending => 0,
                                  'ready_for_pickup' => 0,
                                  PickupShipmentStatus.collected => 1,
                                  PickupShipmentStatus.refused => 2,
                                  _ => 1,
                                };
                            return rank(a.status).compareTo(rank(b.status));
                          });

                        return ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                          itemCount: sorted.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: 1,
                            indent: 14,
                            endIndent: 14,
                            color: isDark ? mbDarkLine2 : mbLine2,
                          ),
                          itemBuilder: (_, i) => _ExpectedRow(
                            key: ValueKey(sorted[i].id),
                            shipment: sorted[i],
                            s: s,
                            isDark: isDark,
                            onAccept: () => _doAccept(
                                context, ref, sorted[i].id, s),
                            onRefuse: () => _doRefuse(
                                context, ref, sorted[i].id, s),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doAccept(
    BuildContext context,
    WidgetRef ref,
    int shipmentId,
    AppStrings s,
  ) async {
    HapticFeedback.mediumImpact();
    try {
      await ref.read(pickupDetailProvider(id).notifier).accept(shipmentId);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.pkdError)),
        );
      }
    }
  }

  Future<void> _doRefuse(
    BuildContext context,
    WidgetRef ref,
    int shipmentId,
    AppStrings s,
  ) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RefuseSheet(s: s),
    );
    if (reason == null) return;
    HapticFeedback.mediumImpact();
    try {
      await ref
          .read(pickupDetailProvider(id).notifier)
          .refuse(shipmentId, reason: reason);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.pkdError)),
        );
      }
    }
  }
}

// ── (A) Blue manifest header ───────────────────────────────────────────────────

class _ManifestHeader extends StatelessWidget {
  const _ManifestHeader({required this.pickup, required this.s});
  final PickupModel pickup;
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
              // Nav row: back + sender name + manifest code/progress
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Semantics(
                    button: true,
                    label: 'Retour',
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pickup.senderName,
                          style: GoogleFonts.archivo(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${pickup.manifestNumber} · '
                          '${s.pkdProgress(pickup.collectedCount, pickup.totalShipments)}',
                          style: GoogleFonts.splineSansMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _kHeaderSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  _HeaderStatusBadge(pickup: pickup, s: s),
                ],
              ),

              // Address + call button row
              if (pickup.senderAddress != null || pickup.senderPhone != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 14, color: _kHeaderSub),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          pickup.senderAddress ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (pickup.senderPhone != null)
                        Semantics(
                          button: true,
                          label: s.pkdCall,
                          child: GestureDetector(
                            onTap: () => launchUrl(
                                Uri.parse('tel:${pickup.senderPhone}')),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(0x24),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.phone_rounded,
                                    color: Colors.white, size: 17),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStatusBadge extends StatelessWidget {
  const _HeaderStatusBadge({required this.pickup, required this.s});
  final PickupModel pickup;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final status = pickup.displayStatus;
    final label = switch (status) {
      ManifestStatus.done => s.pickupStatusDone,
      ManifestStatus.inProgress => s.pickupStatusInProgress,
      ManifestStatus.upcoming => s.pickupStatusUpcoming,
    };
    final color = status == ManifestStatus.done ? mbOk : Colors.white;

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(0x24),
        borderRadius: BorderRadius.circular(MbRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ── Done banner ────────────────────────────────────────────────────────────────

class _DoneBanner extends StatelessWidget {
  const _DoneBanner({required this.s, required this.onClose});
  final AppStrings s;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF052E14) : mbOkBg,
        borderRadius: BorderRadius.circular(MbRadius.cardSmall),
        border: Border.all(color: mbOk.withAlpha(0x55), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: mbOk, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.pkdAllCollected,
              style: GoogleFonts.archivo(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: mbOk,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onClose,
            style: FilledButton.styleFrom(
              backgroundColor: mbOk,
              minimumSize: const Size(0, 34),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MbRadius.button),
              ),
            ),
            child: Text(
              s.pkdManifestClose,
              style: GoogleFonts.archivo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expected shipment row ──────────────────────────────────────────────────────

class _ExpectedRow extends StatelessWidget {
  const _ExpectedRow({
    super.key,
    required this.shipment,
    required this.s,
    required this.isDark,
    required this.onAccept,
    required this.onRefuse,
  });

  final PickupShipmentModel shipment;
  final AppStrings s;
  final bool isDark;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  @override
  Widget build(BuildContext context) {
    final isPending = shipment.status == PickupShipmentStatus.pending ||
        shipment.status == 'ready_for_pickup';
    final isCollected = shipment.status == PickupShipmentStatus.collected;
    final isRefused = shipment.status == PickupShipmentStatus.refused;

    final Color dotColor;
    final String subLine;
    if (isCollected) {
      dotColor = mbOk;
      final timeStr = shipment.collectedAt != null
          ? DateFormat.Hm().format(shipment.collectedAt!)
          : '--:--';
      subLine = s.pkdCollectedAt(timeStr);
    } else if (isRefused) {
      dotColor = mbRed;
      subLine = shipment.refuseReason != null
          ? s.pkdRefusedReason(_localizeReason(shipment.refuseReason!, s))
          : s.pkdStatusRefused;
    } else {
      dotColor = mbBlue;
      subLine = s.pkdStatusPending;
    }

    return Semantics(
      label: '${shipment.trackingNumber}, $subLine'
          '${isPending ? ", ${s.pkdCollect}, ${s.pkdRefuse}" : ""}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Status dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 11),

            // Middle: tracking ref + sub-line
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '# ${shipment.trackingNumber}',
                    style: GoogleFonts.archivo(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? mbDarkInk : mbInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLine,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? mbDarkInk3 : mbInk3,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),

            // Action buttons — pending only
            if (isPending) ...[
              const SizedBox(width: 8),
              _ActionBtn(
                bg: isDark ? const Color(0xFF052E14) : mbOkBg,
                icon: Icons.check_rounded,
                iconColor: mbOk,
                semanticsLabel: s.pkdCollect,
                onTap: onAccept,
              ),
              const SizedBox(width: 6),
              _ActionBtn(
                bg: isDark ? const Color(0xFF3D0000) : mbErrBg,
                icon: Icons.close_rounded,
                iconColor: mbRed,
                semanticsLabel: s.pkdRefuse,
                onTap: onRefuse,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _localizeReason(String key, AppStrings s) => switch (key) {
        'packaging' => s.pkdRefusePackaging,
        'missing' => s.pkdRefuseMissing,
        'damaged' => s.pkdRefuseDamaged,
        _ => s.pkdRefuseOther,
      };
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.bg,
    required this.icon,
    required this.iconColor,
    required this.semanticsLabel,
    required this.onTap,
  });

  final Color bg;
  final IconData icon;
  final Color iconColor;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 15),
        ),
      ),
    );
  }
}

// ── Refuse reason bottom sheet ─────────────────────────────────────────────────

class _RefuseSheet extends StatelessWidget {
  const _RefuseSheet({required this.s});
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reasons = [
      (s.pkdRefusePackaging, 'packaging'),
      (s.pkdRefuseMissing, 'missing'),
      (s.pkdRefuseDamaged, 'damaged'),
      (s.pkdRefuseOther, 'other'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? mbDarkSurface : mbSurface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(MbRadius.bottomSheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? mbDarkLine : mbLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  s.pkdRefuseReasonTitle,
                  style: GoogleFonts.archivo(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? mbDarkInk : mbInk,
                  ),
                ),
              ),
            ),
            // Reason options
            ...reasons.map(
              (r) => ListTile(
                title: Text(
                  r.$1,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? mbDarkInk : mbInk,
                  ),
                ),
                leading: Icon(Icons.circle_outlined,
                    size: 18,
                    color: isDark ? mbDarkInk3 : mbInk3),
                onTap: () => Navigator.of(context).pop(r.$2),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                dense: true,
              ),
            ),
            // Cancel
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? mbDarkInk2 : mbInk2,
                  side: BorderSide(
                      color: isDark ? mbDarkLine : mbLine, width: 1.2),
                  minimumSize: const Size(double.infinity, kMbMinTouchTarget),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MbRadius.button),
                  ),
                ),
                child: Text(s.setLogoutCancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header loading / error placeholders ───────────────────────────────────────

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton({required this.id});
  final int id;

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
              Row(
                children: [
                  const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkRect(w: 180, h: 16),
                      const SizedBox(height: 5),
                      _SkRect(w: 130, h: 12),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _SkRect(w: double.infinity, h: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderMinimal extends StatelessWidget {
  const _HeaderMinimal({required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: mbBlue,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Manifest #$id',
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

class _SkRect extends StatelessWidget {
  const _SkRect({required this.w, required this.h});
  final double w;
  final double h;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w == double.infinity ? null : w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(0x33),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ── List placeholders ──────────────────────────────────────────────────────────

class _ShipmentSkeleton extends StatelessWidget {
  const _ShipmentSkeleton({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? mbDarkLine : mbSurface3;
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 150,
                    height: 12,
                    decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 100,
                    height: 10,
                    decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.s, required this.onRetry});
  final AppStrings s;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MbSpacing.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: mbErr),
            const SizedBox(height: MbSpacing.md),
            Text(
              s.pkdError,
              style: const TextStyle(
                  color: mbErr, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MbSpacing.lg),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.s});
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MbSpacing.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 48, color: isDark ? mbDarkInk3 : mbInk3),
            const SizedBox(height: MbSpacing.md),
            Text(
              s.pkdEmptyManifest,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? mbDarkInk2 : mbInk2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
