import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/i18n/app_strings.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/mb_fab.dart';
import '../../../../core/widgets/mb_offline_banner.dart';
import '../../../../core/widgets/mb_segmented.dart';
import '../../../../core/widgets/mb_tri_progress.dart';
import '../../../shipments/data/models/shipment_model.dart';
import '../../data/models/runsheet_model.dart';
import '../controllers/runsheet_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
const _kHeaderSub = Color(0xFFCFE0F1);
const _kDonePreview = 5;

enum _ShipFilter { all, pending, delivered, failed }

// ── Screen ────────────────────────────────────────────────────────────────────

class RunsheetDetailScreen extends ConsumerStatefulWidget {
  const RunsheetDetailScreen({super.key, required this.id});
  final int id;

  @override
  ConsumerState<RunsheetDetailScreen> createState() =>
      _RunsheetDetailScreenState();
}

class _RunsheetDetailScreenState
    extends ConsumerState<RunsheetDetailScreen> {
  _ShipFilter _filter = _ShipFilter.all;
  bool _showAllDone = false;

  // ── Partition helpers ──────────────────────────────────────────────────────

  static bool _isPending(String status) =>
      status != ShipmentStatus.delivered &&
      status != ShipmentStatus.failed &&
      status != ShipmentStatus.returned;

  static List<ShipmentModel> _pendingOf(RunsheetModel rs) =>
      ([...rs.shipments.where((s) => _isPending(s.status))]
        ..sort((a, b) => a.id.compareTo(b.id)));

  static List<ShipmentModel> _allDoneOf(RunsheetModel rs) =>
      ([...rs.shipments.where((s) => !_isPending(s.status))]
        ..sort((a, b) => b.id.compareTo(a.id)));

  List<ShipmentModel> _filteredDoneOf(RunsheetModel rs) {
    final all = _allDoneOf(rs);
    return switch (_filter) {
      _ShipFilter.delivered =>
        all.where((s) => s.status == ShipmentStatus.delivered).toList(),
      _ShipFilter.failed =>
        all.where((s) => s.status != ShipmentStatus.delivered).toList(),
      _ => all,
    };
  }

  static double _codSumOf(List<ShipmentModel> items) =>
      items.fold(0.0, (sum, s) => sum + (s.codAmount ?? 0));

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final s = AppStrings.of(locale.languageCode);
    final detailAsync = ref.watch(runsheetDetailProvider(widget.id));
    final pendingOps = ref.watch(pendingOpsCountProvider).valueOrNull ?? 0;
    final isOffline = ref.watch(isOfflineProvider).valueOrNull ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tab counts (from loaded data or zeros while loading)
    final rs = detailAsync.valueOrNull;
    final allPending = rs != null ? _pendingOf(rs) : <ShipmentModel>[];
    final allDone = rs != null ? _allDoneOf(rs) : <ShipmentModel>[];
    final allDelivered =
        allDone.where((s) => s.status == ShipmentStatus.delivered).length;
    final allFailed =
        allDone.where((s) => s.status != ShipmentStatus.delivered).length;
    final total =
        rs?.totalShipments ?? (allPending.length + allDone.length);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Fixed header (UNCHANGED) ───────────────────────────────────
            detailAsync.when(
              loading: () => _HeaderSkeleton(id: widget.id, s: s),
              error: (_, __) => _HeaderMinimal(id: widget.id, s: s),
              data: (rs) => _SummaryHeader(
                runsheet: rs,
                s: s,
                onClose: () => _confirmClose(context, rs, s),
              ),
            ),

            // ── Offline banner ─────────────────────────────────────────────
            if (detailAsync.valueOrNull != null)
              _OfflineBannerSlot(ref: ref, s: s, pendingOps: pendingOps, isOffline: isOffline),

            // ── List section ───────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: mbBlue,
                onRefresh: () => ref
                    .read(runsheetDetailProvider(widget.id).notifier)
                    .refresh(),
                child: CustomScrollView(
                  slivers: [
                    // (A) Sticky segmented filter
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _FilterDelegate(
                        isDark: isDark,
                        height: 52,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                          child: MbSegmented<_ShipFilter>(
                            items: [
                              MbSegmentedItem(
                                  value: _ShipFilter.all,
                                  label: s.rsdFilterAll(total)),
                              MbSegmentedItem(
                                  value: _ShipFilter.pending,
                                  label: s.rsdFilterPending(allPending.length)),
                              MbSegmentedItem(
                                  value: _ShipFilter.delivered,
                                  label: s.rsdFilterDelivered(allDelivered)),
                              MbSegmentedItem(
                                  value: _ShipFilter.failed,
                                  label: s.rsdFilterFailed(allFailed)),
                            ],
                            selected: _filter,
                            onChanged: (f) => setState(() {
                              _filter = f;
                              _showAllDone = false;
                            }),
                          ),
                        ),
                      ),
                    ),

                    // Loading skeleton (no cached data yet)
                    if (rs == null && detailAsync.isLoading)
                      SliverToBoxAdapter(
                        child: _ListSkeleton(isDark: isDark),
                      )

                    // Error state
                    else if (rs == null && detailAsync.hasError)
                      SliverFillRemaining(
                        child: _ErrorBody(
                          s: s,
                          onRetry: () => ref
                              .invalidate(runsheetDetailProvider(widget.id)),
                        ),
                      )

                    // Content
                    else if (rs != null) ..._buildContent(
                        context, rs, s, isDark, allPending, allDone),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ),
          ],
        ),

      ],
    );
  }

  // ── Content slivers ────────────────────────────────────────────────────────

  List<Widget> _buildContent(
    BuildContext context,
    RunsheetModel rs,
    AppStrings s,
    bool isDark,
    List<ShipmentModel> allPending,
    List<ShipmentModel> allDone,
  ) {
    if (rs.shipments.isEmpty) {
      return [SliverFillRemaining(child: _EmptyBody(s: s))];
    }

    final showPending =
        _filter == _ShipFilter.all || _filter == _ShipFilter.pending;
    final showDone = _filter != _ShipFilter.pending;
    final pendingItems = showPending ? allPending : <ShipmentModel>[];
    final filteredDone = showDone ? _filteredDoneOf(rs) : <ShipmentModel>[];
    final codSum = _codSumOf(allPending);

    // Visible done items (collapse to _kDonePreview when filter==all)
    final visibleDone = (_showAllDone || _filter != _ShipFilter.all)
        ? filteredDone
        : filteredDone.take(_kDonePreview).toList();
    final canExpand = !_showAllDone &&
        _filter == _ShipFilter.all &&
        filteredDone.length > _kDonePreview;

    return [
      // ── (B) Pending group header ─────────────────────────────────────────
      if (showPending)
        SliverToBoxAdapter(
          child: _GroupHeader(
            label: s.rsdGroupTodo,
            count: allPending.length,
            countColor: mbBlue,
            trailing: allPending.isNotEmpty
                ? s.rsdGroupSumToCollect('${_fmtCod(codSum)} TND')
                : null,
            trailingColor: mbBlue,
            isDark: isDark,
            topPadding: 6,
          ),
        ),

      // ── (C) Pending cards or empty ───────────────────────────────────────
      if (showPending)
        if (pendingItems.isEmpty)
          SliverToBoxAdapter(
            child: _EmptyFilterView(
              label: s.rsdEmptyPending,
              isDark: isDark,
            ),
          )
        else
          SliverList.builder(
            itemCount: pendingItems.length,
            itemBuilder: (ctx, i) => _MbStopCard(
              key: ValueKey(pendingItems[i].id),
              shipment: pendingItems[i],
              seq: i + 1,
              isNext: i == 0,
              s: s,
              isDark: isDark,
              onCall: pendingItems[i].recipientPhone != null
                  ? () => _launchCall(pendingItems[i].recipientPhone!)
                  : null,
              onNavigate: () =>
                  _launchMaps(_buildAddress(pendingItems[i])),
              onDeliver: () => context
                  .push('/scan/delivery?shipmentId=${pendingItems[i].id}&runsheetId=${widget.id}'),
              onTap: () =>
                  context.push('/shipments/${pendingItems[i].id}'),
            ),
          ),

      // ── (D) Done group header ────────────────────────────────────────────
      if (showDone)
        SliverToBoxAdapter(
          child: _GroupHeader(
            label: s.rsdGroupDone,
            count: allDone.length,
            countColor: mbOk,
            trailing: canExpand ? s.rsdShowAll : null,
            trailingColor: mbBlue,
            onTrailingTap: canExpand
                ? () => setState(() => _showAllDone = true)
                : null,
            isDark: isDark,
            topPadding: showPending ? 16 : 6,
          ),
        ),

      // ── (E) Done card or empty ───────────────────────────────────────────
      if (showDone)
        if (filteredDone.isEmpty)
          SliverToBoxAdapter(
            child: _EmptyFilterView(label: s.rsdEmptyFiltered, isDark: isDark),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: _DoneCard(
                items: visibleDone,
                s: s,
                isDark: isDark,
                onTap: (id) => context.push('/shipments/$id'),
              ),
            ),
          ),
    ];
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _launchCall(String phone) async {
    var p = phone.replaceAll(RegExp(r'[\s\-()+]'), '');
    if (p.startsWith('216') && p.length > 8) p = p.substring(3);
    final uri = Uri(scheme: 'tel', path: p);
    if (await canLaunchUrl(uri)) unawaited(launchUrl(uri));
  }

  static Future<void> _launchMaps(String address) async {
    if (address.isEmpty) return;
    final encoded = Uri.encodeComponent(address);
    final geo = Uri.parse('geo:0,0?q=$encoded');
    if (await canLaunchUrl(geo)) {
      unawaited(launchUrl(geo, mode: LaunchMode.externalApplication));
    } else {
      final web = Uri.parse('https://maps.google.com/?q=$encoded');
      if (await canLaunchUrl(web)) {
        unawaited(launchUrl(web, mode: LaunchMode.externalApplication));
      }
    }
  }

  // ── Close flow ─────────────────────────────────────────────────────────────

  Future<void> _confirmClose(
    BuildContext context,
    RunsheetModel rs,
    AppStrings s,
  ) async {
    if (rs.status == RunsheetStatus.closed) return;

    if (rs.pendingCount > 0) {
      final proceed = await showModalBottomSheet<bool>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CloseConfirmSheet(
          pendingCount: rs.pendingCount,
          s: s,
        ),
      );
      if (proceed != true) return;
    }

    try {
      await ref.read(runsheetDetailProvider(widget.id).notifier).close();
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
          SnackBar(content: Text('$e'), backgroundColor: mbErr),
        );
      }
    }
  }

  // ── Static helpers ─────────────────────────────────────────────────────────

  static String _buildAddress(ShipmentModel sh) => [
        sh.address,
        sh.city,
        if (sh.governorate != null) sh.governorate!,
      ].where((s) => s.isNotEmpty).join(', ');

  static String _fmtCod(double v) {
    if (v <= 0) return '0';
    final n = v.toInt();
    final str = n.toString();
    final buf = StringBuffer();
    final len = str.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) buf.write(' ');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  static String _fmtCodShort(double v) {
    final n = v.toInt();
    if (n < 1000) return '$n';
    final str = n.toString();
    final buf = StringBuffer();
    final len = str.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) buf.write(' ');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  static DateTime? _terminalEventTime(ShipmentModel sh) {
    for (final e in sh.timeline.reversed) {
      if (e.status == ShipmentStatus.delivered ||
          e.status == ShipmentStatus.failed ||
          e.status == ShipmentStatus.returned) {
        return e.timestamp;
      }
    }
    return null;
  }

  static String? _failReason(ShipmentModel sh) {
    for (final e in sh.timeline.reversed) {
      if ((e.status == ShipmentStatus.failed ||
              e.status == ShipmentStatus.returned) &&
          e.comment != null &&
          e.comment!.isNotEmpty) {
        return e.comment;
      }
    }
    return sh.notes?.isNotEmpty == true ? sh.notes : null;
  }

  static String _fmtTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Sticky filter header delegate ─────────────────────────────────────────────

class _FilterDelegate extends SliverPersistentHeaderDelegate {
  const _FilterDelegate({
    required this.child,
    required this.height,
    required this.isDark,
  });
  final Widget child;
  final double height;
  final bool isDark;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: isDark ? mbDarkBg : mbSurface2,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_FilterDelegate old) =>
      old.child != child || old.height != height || old.isDark != isDark;
}

// ── (B / D) Group header ─────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.count,
    required this.countColor,
    required this.isDark,
    this.trailing,
    this.trailingColor,
    this.onTrailingTap,
    this.topPadding = 6,
  });

  final String label;
  final int count;
  final Color countColor;
  final bool isDark;
  final String? trailing;
  final Color? trailingColor;
  final VoidCallback? onTrailingTap;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark ? mbDarkInk3 : mbInk3;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, topPadding, 14, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.archivo(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.04 * 11.5,
              color: labelColor,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: countColor.withAlpha(0x22),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.archivo(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: countColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: isDark ? mbDarkLine2 : mbLine2,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(
                trailing!,
                style: GoogleFonts.archivo(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: trailingColor ?? labelColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── (C) Pending stop card ─────────────────────────────────────────────────────

class _MbStopCard extends StatelessWidget {
  const _MbStopCard({
    super.key,
    required this.shipment,
    required this.seq,
    required this.isNext,
    required this.s,
    required this.isDark,
    required this.onCall,
    required this.onNavigate,
    required this.onDeliver,
    required this.onTap,
  });

  final ShipmentModel shipment;
  final int seq;
  final bool isNext;
  final AppStrings s;
  final bool isDark;
  final VoidCallback? onCall;
  final VoidCallback onNavigate;
  final VoidCallback onDeliver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sh = shipment;
    final address = _RunsheetDetailScreenState._buildAddress(sh);
    final tracking =
        sh.trackingNumber.isNotEmpty ? sh.trackingNumber : sh.barcode;
    final hasAddress = address.isNotEmpty;

    return Semantics(
      button: true,
      label: '${s.rsdNextStop} $seq, ${sh.recipientName}, $address, '
          '${s.rsdTrackingLabel} $tracking'
          '${sh.hasCod ? ', COD ${sh.codAmount?.toInt()} TND' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 11),
          decoration: BoxDecoration(
            color: isDark ? mbDarkSurface : mbSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isNext ? mbBlue : (isDark ? mbDarkLine : mbLine),
              width: isNext ? 1.5 : 1,
            ),
            boxShadow: [
              if (isNext)
                BoxShadow(
                  color: mbBlue.withAlpha(0x22),
                  blurRadius: 18,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                )
              else
                const BoxShadow(
                  color: Color(0x0D142850),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "Prochain arrêt" tag
              if (isNext)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
                        decoration: BoxDecoration(
                          color: mbBlue,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.near_me_rounded,
                                size: 11, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              s.rsdNextStop.toUpperCase(),
                              style: GoogleFonts.archivo(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.04 * 9.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Main content
              Padding(
                padding: EdgeInsets.fromLTRB(14, isNext ? 10 : 15, 14, 15),
                child: Column(
                  children: [
                    // Top row: seq badge + info + COD
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sequence badge
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: mbBlue,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$seq',
                            style: GoogleFonts.archivo(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Name
                              Text(
                                sh.recipientName,
                                style: GoogleFonts.archivo(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.01 * 15.5,
                                  color: isDark ? mbDarkInk : mbInk,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // 2. Full address
                              if (address.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  address,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: isDark ? mbDarkInk3 : mbInk3,
                                  ),
                                ),
                              ],
                              // 3. Tracking row
                              if (tracking.isNotEmpty) ...[
                                const SizedBox(height: 7),
                                _TrackingRow(
                                  tracking: tracking,
                                  s: s,
                                  isDark: isDark,
                                ),
                              ],
                              // 4. ETA / distance
                              if (sh.etaMin != null ||
                                  sh.distanceKm != null) ...[
                                const SizedBox(height: 5),
                                _EtaRow(
                                  etaMin: sh.etaMin,
                                  distanceKm: sh.distanceKm,
                                  isDark: isDark,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // COD column
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (sh.hasCod) ...[
                              Text(
                                _RunsheetDetailScreenState._fmtCodShort(
                                    sh.codAmount!),
                                style: GoogleFonts.archivo(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? const Color(0xFF5B9BD5)
                                      : mbBlue,
                                ),
                              ),
                              Text(
                                'TND',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? mbDarkInk3 : mbInk3,
                                ),
                              ),
                            ] else
                              Text(
                                '—',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? mbDarkInk3 : mbInk3,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 13),

                    // Action buttons
                    Row(
                      children: [
                        _IconActionBtn(
                          icon: Icons.phone_rounded,
                          isDark: isDark,
                          enabled: onCall != null,
                          onTap: onCall ?? () {},
                        ),
                        const SizedBox(width: 8),
                        _IconActionBtn(
                          icon: Icons.near_me_rounded,
                          isDark: isDark,
                          enabled: hasAddress,
                          onTap: onNavigate,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: FilledButton.icon(
                              onPressed: onDeliver,
                              style: FilledButton.styleFrom(
                                backgroundColor: mbRed,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                              ),
                              icon: CustomPaint(
                                size: const Size(14, 14),
                                painter: const MbScanIconPainter(
                                    color: Colors.white),
                              ),
                              label: Text(
                                s.rsdDeliver,
                                style: GoogleFonts.archivo(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

// ── Tracking row (barcode icon + label + mono number) ─────────────────────────

class _TrackingRow extends StatelessWidget {
  const _TrackingRow(
      {required this.tracking, required this.s, required this.isDark});
  final String tracking;
  final AppStrings s;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.qr_code_rounded,
            size: 13, color: isDark ? mbDarkInk3 : mbInk3),
        const SizedBox(width: 5),
        Text(
          '${s.rsdTrackingLabel}  ',
          style: TextStyle(
            fontFamily: 'HankenGrotesk',
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.04 * 9,
            color: isDark ? mbDarkInk3 : mbInk3,
          ),
        ),
        Flexible(
          child: Text(
            tracking,
            style: GoogleFonts.splineSansMono(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? mbDarkInk : mbInk,
            ),
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
      ],
    );
  }
}

// ── ETA / distance row ────────────────────────────────────────────────────────

class _EtaRow extends StatelessWidget {
  const _EtaRow({this.etaMin, this.distanceKm, required this.isDark});
  final int? etaMin;
  final double? distanceKm;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? const Color(0xFF5B9BD5) : mbBlue;
    return Row(
      children: [
        if (etaMin != null) ...[
          Icon(Icons.schedule_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$etaMin min',
            style: GoogleFonts.archivo(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
        if (etaMin != null && distanceKm != null) ...[
          const SizedBox(width: 6),
          Text('·',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? mbDarkInk3 : mbInk3)),
          const SizedBox(width: 6),
        ],
        if (distanceKm != null) ...[
          Icon(Icons.location_on_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            _fmtKm(distanceKm!),
            style: GoogleFonts.archivo(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ],
    );
  }

  static String _fmtKm(double km) {
    if (km >= 10) return '${km.toInt()} km';
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }
}

// ── Icon action button (Call / Navigate) ─────────────────────────────────────

class _IconActionBtn extends StatelessWidget {
  const _IconActionBtn({
    required this.icon,
    required this.isDark,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool isDark;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? mbBlue : (isDark ? mbDarkInk3 : mbInk3);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 46,
          height: 42,
          decoration: BoxDecoration(
            color: isDark ? mbDarkSurface2 : mbSurface3,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ── (E) Done card container ───────────────────────────────────────────────────

class _DoneCard extends StatelessWidget {
  const _DoneCard({
    required this.items,
    required this.s,
    required this.isDark,
    required this.onTap,
  });
  final List<ShipmentModel> items;
  final AppStrings s;
  final bool isDark;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? mbDarkSurface : mbSurface,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? mbDarkLine : mbLine, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A142850),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? mbDarkLine2 : mbLine2,
                ),
              _MbDoneRow(
                shipment: items[i],
                s: s,
                isDark: isDark,
                onTap: () => onTap(items[i].id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── (E) Done row ─────────────────────────────────────────────────────────────

class _MbDoneRow extends StatelessWidget {
  const _MbDoneRow({
    required this.shipment,
    required this.s,
    required this.isDark,
    required this.onTap,
  });
  final ShipmentModel shipment;
  final AppStrings s;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sh = shipment;
    final isDelivered = sh.status == ShipmentStatus.delivered;
    final address = _RunsheetDetailScreenState._buildAddress(sh);
    final tracking =
        sh.trackingNumber.isNotEmpty ? sh.trackingNumber : sh.barcode;
    final time = _RunsheetDetailScreenState._fmtTime(
        _RunsheetDetailScreenState._terminalEventTime(sh));
    final failReason = isDelivered
        ? null
        : _RunsheetDetailScreenState._failReason(sh);
    final metaStr = isDelivered
        ? s.rsdDeliveredAt(time)
        : s.rsdFailedAt(failReason ?? '', time);

    final ink = isDark ? mbDarkInk : mbInk;
    final ink3 = isDark ? mbDarkInk3 : mbInk3;

    return Semantics(
      button: true,
      label: '${sh.recipientName}, $address, $tracking, $metaStr',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status icon
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isDelivered ? mbOkBg : mbErrBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isDelivered ? Icons.check_rounded : Icons.close_rounded,
                  size: 14,
                  color: isDelivered ? mbOk : mbErr,
                ),
              ),
              const SizedBox(width: 11),

              // Info column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      sh.recipientName,
                      style: GoogleFonts.archivo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Address
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        address,
                        style: TextStyle(fontSize: 12, color: ink3),
                      ),
                    ],
                    // Tracking (no label)
                    if (tracking.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.qr_code_rounded,
                              size: 11, color: ink3),
                          const SizedBox(width: 4),
                          Text(
                            tracking,
                            style: GoogleFonts.splineSansMono(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: ink,
                            ),
                            softWrap: false,
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ),
                    ],
                    // Status + time
                    const SizedBox(height: 2),
                    Text(
                      metaStr,
                      style: GoogleFonts.splineSansMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: ink3,
                      ),
                    ),
                  ],
                ),
              ),

              // COD (dimmed — already processed)
              const SizedBox(width: 8),
              if (sh.hasCod)
                Text(
                  '${_RunsheetDetailScreenState._fmtCodShort(sh.codAmount!)} TND',
                  style: GoogleFonts.archivo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? mbDarkInk2 : mbInk2,
                  ),
                )
              else
                Text('—',
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark ? mbDarkInk3 : mbInk3)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty filter state ────────────────────────────────────────────────────────

class _EmptyFilterView extends StatelessWidget {
  const _EmptyFilterView({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? mbDarkInk3 : mbInk3,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ── List loading skeleton ─────────────────────────────────────────────────────

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final sh = isDark ? mbDarkSurface2 : mbSurface3;
    return Column(
      children: List.generate(
        4,
        (i) => Container(
          margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isDark ? mbDarkSurface : mbSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: isDark ? mbDarkLine : mbLine, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                          color: sh,
                          borderRadius: BorderRadius.circular(11))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            height: 14,
                            width: 140,
                            decoration: BoxDecoration(
                                color: sh,
                                borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 6),
                        Container(
                            height: 11,
                            decoration: BoxDecoration(
                                color: sh,
                                borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 4),
                        Container(
                            height: 11,
                            width: 100,
                            decoration: BoxDecoration(
                                color: sh,
                                borderRadius: BorderRadius.circular(4))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                      height: 34,
                      width: 44,
                      decoration: BoxDecoration(
                          color: sh,
                          borderRadius: BorderRadius.circular(6))),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Container(
                      width: 46,
                      height: 42,
                      decoration: BoxDecoration(
                          color: sh,
                          borderRadius: BorderRadius.circular(12))),
                  const SizedBox(width: 8),
                  Container(
                      width: 46,
                      height: 42,
                      decoration: BoxDecoration(
                          color: sh,
                          borderRadius: BorderRadius.circular(12))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                            color: sh,
                            borderRadius: BorderRadius.circular(12))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Offline banner slot ────────────────────────────────────────────────────────

class _OfflineBannerSlot extends StatelessWidget {
  const _OfflineBannerSlot({
    required this.ref,
    required this.s,
    required this.pendingOps,
    required this.isOffline,
  });
  final WidgetRef ref;
  final AppStrings s;
  final int pendingOps;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    if (!isOffline || pendingOps == 0) return const SizedBox.shrink();
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
    final title =
        rs.name.isNotEmpty && rs.name != rs.label ? rs.name : rs.label;
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
              MbTriProgress(
                delivered: rs.deliveredCount,
                failed: rs.failedCount,
                total: rs.totalShipments,
                semanticLabel:
                    '${rs.deliveredCount} livrés, ${rs.failedCount} échecs, ${rs.pendingCount} restants',
              ),
              const SizedBox(height: 11),
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

  static String _statusLabel(String status, AppStrings s) =>
      switch (status) {
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
      if (i > 0 && (len - i) % 3 == 0) buf.write(' ');
      buf.write(str[i]);
    }
    buf.write(' DH');
    return buf.toString();
  }
}

// ── Summary tile ──────────────────────────────────────────────────────────────

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(0x1F),
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
          Text(label,
              style: const TextStyle(fontSize: 10, color: _kHeaderSub)),
        ],
      ),
    );
  }
}

// ── Header action button ───────────────────────────────────────────────────────

class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn({required this.label, required this.onTap}) : light = false;
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
          : Colors.white.withAlpha(0x29),
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

// ── Header skeleton ────────────────────────────────────────────────────────────

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
              Row(
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
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
              _SkeletonBar(height: 36, opacity: 0.2),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar(
      {this.width, required this.height, required this.opacity});
  final double? width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(6),
        ),
      );
}

// ── Minimal header (error state) ──────────────────────────────────────────────

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
            Icon(Icons.inventory_2_outlined,
                size: 48, color: isDark ? mbDarkInk3 : mbInk3),
            const SizedBox(height: 12),
            Text(
              s.rsdEmpty,
              style: TextStyle(
                  fontSize: 14, color: isDark ? mbDarkInk2 : mbInk2),
              textAlign: TextAlign.center,
            ),
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

// ── Close-confirm bottom sheet ────────────────────────────────────────────────

class _CloseConfirmSheet extends StatelessWidget {
  const _CloseConfirmSheet({required this.pendingCount, required this.s});
  final int pendingCount;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    final surfaceColor = isDark ? mbDarkSurface : Colors.white;
    final inkColor = isDark ? mbDarkInk : mbInk;
    final ink2Color = isDark ? mbDarkInk2 : mbInk2;
    final lineColor = isDark ? mbDarkLine : mbLine;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Grab handle
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: lineColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + safeBottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row: title + pending badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        s.rsdCloseConfirmTitle,
                        style: GoogleFonts.archivo(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: inkColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: mbWarnBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hourglass_empty_rounded,
                              size: 13, color: mbWarn),
                          const SizedBox(width: 4),
                          Text(
                            '$pendingCount',
                            style: GoogleFonts.archivo(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: mbWarn,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Body
                Text(
                  s.rsdCloseConfirmBody(pendingCount),
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13.5,
                    height: 1.5,
                    color: ink2Color,
                  ),
                ),
                const SizedBox(height: 22),
                // Confirm button
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: mbRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(Icons.lock_outline_rounded,
                        size: 17, color: Colors.white),
                    label: Text(
                      s.rsdCloseConfirmForce,
                      style: GoogleFonts.archivo(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                // Cancel button
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: inkColor,
                      side: BorderSide(color: lineColor, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: Text(
                      s.rsdCloseConfirmCancel,
                      style: GoogleFonts.archivo(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: inkColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
