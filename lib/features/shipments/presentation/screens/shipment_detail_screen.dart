import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/i18n/app_strings.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/mb_fab.dart';
import '../../../../core/widgets/mb_offline_banner.dart';
import '../../../calls/data/models/call_log_model.dart';
import '../../data/models/shipment_model.dart';
import '../controllers/shipment_controller.dart';

const _kHeaderSub = Color(0xFFCFE0F1);
const _kCodBorder = Color(0xFFCFE0F1);

// ── Screen ────────────────────────────────────────────────────────────────────

class ShipmentDetailScreen extends ConsumerStatefulWidget {
  const ShipmentDetailScreen({super.key, required this.id});
  final int id;

  @override
  ConsumerState<ShipmentDetailScreen> createState() =>
      _ShipmentDetailScreenState();
}

class _ShipmentDetailScreenState extends ConsumerState<ShipmentDetailScreen>
    with WidgetsBindingObserver {
  // ── Call tracking ──────────────────────────────────────────────────────────
  static const _callChannel = MethodChannel('com.megaboss/calls');

  String? _pendingCallPhone;
  DateTime? _callStartedAt;
  bool _awaitingCallResult = false;
  bool _wentToBackground = false;
  Completer<int>? _durationCompleter; // completes with seconds when call ends

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_awaitingCallResult) return;
    if (state == AppLifecycleState.paused) {
      _wentToBackground = true;
    } else if (state == AppLifecycleState.resumed && _wentToBackground) {
      _awaitingCallResult = false;
      _wentToBackground = false;
      unawaited(_onReturnedFromCall());
    }
  }

  // ── Initiates a call and sets up tracking ──────────────────────────────────

  static String _normalizePhone(String phone) {
    var p = phone.replaceAll(RegExp(r'[\s\-()+]'), '');
    if (p.startsWith('216') && p.length > 8) p = p.substring(3);
    return p;
  }

  Future<void> _makeCall(String phone) async {
    final dialPhone = _normalizePhone(phone);
    _pendingCallPhone = dialPhone;
    _callStartedAt = DateTime.now();
    _awaitingCallResult = true;
    _wentToBackground = false;
    _durationCompleter = null;

    if (Platform.isAndroid) {
      // READ_PHONE_STATE — TelephonyManager fires OFFHOOK/IDLE states.
      // READ_CALL_LOG is requested natively in startCallMonitoring.
      if (!(await Permission.phone.isGranted)) {
        await Permission.phone.request();
      }
      final completer = Completer<int>();
      _durationCompleter = completer;
      _callChannel
          .invokeMethod<Map<Object?, Object?>>('startCallMonitoring')
          .then((data) {
        if (!completer.isCompleted) {
          completer.complete(data?['duration_seconds'] as int? ?? 0);
        }
      }).catchError((_) {
        if (!completer.isCompleted) completer.complete(0);
      });
    }

    final uri = Uri(scheme: 'tel', path: dialPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _awaitingCallResult = false;
      _wentToBackground = false;
    }
  }

  // ── Called when user returns to app after a call ──────────────────────────

  Future<void> _onReturnedFromCall() async {
    // If no OFFHOOK state was ever seen, the user opened the dialer but never
    // actually dialled — discard the session without saving a log entry.
    if (Platform.isAndroid) {
      try {
        final initiated =
            await _callChannel.invokeMethod<bool>('wasCallInitiated');
        if (initiated != true) {
          _durationCompleter = null;
          _pendingCallPhone = null;
          _callStartedAt = null;
          _callChannel
              .invokeMethod<void>('cancelCallMonitoring')
              .catchError((_) {});
          return;
        }
      } catch (_) {}
    }

    int durationSeconds = 0;

    if (Platform.isAndroid && _durationCompleter != null) {
      try {
        durationSeconds = await _durationCompleter!.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () async {
            await _callChannel
                .invokeMethod<void>('cancelCallMonitoring')
                .catchError((_) {});
            return 0;
          },
        );
      } catch (_) {
        durationSeconds = 0;
      }
      _durationCompleter = null;
    }

    if (!mounted) return;

    final locale = ref.read(localeProvider).languageCode;
    final s = AppStrings.of(locale);
    final phone = _pendingCallPhone!;
    final startedAt = _callStartedAt!;
    _pendingCallPhone = null;
    _callStartedAt = null;

    // Auto-determine result: a positive duration means the call was answered.
    final result =
        durationSeconds > 0 ? CallResult.reached : CallResult.noAnswer;

    final log = CallLogModel(
      id: 0,
      rawLogId: '${startedAt.millisecondsSinceEpoch}_$phone',
      phoneNumber: phone,
      durationSeconds: durationSeconds,
      startedAt: startedAt,
      type: CallType.outgoing,
      result: result,
      manual: false,
      shipmentId: widget.id,
      recipientName:
          ref.read(shipmentDetailProvider(widget.id)).valueOrNull?.recipientName,
    );

    // Optimistically add the call to the list so the user sees it immediately.
    ref.read(shipmentCallsProvider(widget.id).notifier).addOptimistic(log);

    _showCallToast(result, durationSeconds, s);

    // Buffer locally so the call survives app restarts, then attempt to sync.
    // We do NOT invalidate the calls list here — _withLocal() already shows
    // the buffered entry. The list syncs to server truth on the next refresh.
    try {
      await ref.read(callRepositoryProvider).bufferCallLog(log);
      await ref.read(callRepositoryProvider).syncPending();
    } catch (_) {}
  }

  void _showCallToast(String result, int durationSec, AppStrings s) {
    final (label, color) = switch (result) {
      CallResult.reached => (s.callJoined, mbOk),
      CallResult.noAnswer => (s.callNoAnswer, mbWarn),
      _ => (s.callUnreachable, mbErr),
    };
    final dur = durationSec > 0
        ? ' · ${durationSec ~/ 60}:${(durationSec % 60).toString().padLeft(2, '0')}'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label$dur',
          style: GoogleFonts.archivo(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final s = AppStrings.of(locale.languageCode);
    final shipmentAsync = ref.watch(shipmentDetailProvider(widget.id));
    final callsAsync = ref.watch(shipmentCallsProvider(widget.id));
    final pendingOps = ref.watch(pendingOpsCountProvider).valueOrNull ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? mbDarkBg : mbSurface2,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── (A) Fixed header ──────────────────────────────────────────────
          shipmentAsync.when(
            loading: () => _HeaderSkeleton(id: widget.id, s: s),
            error: (_, __) => _HeaderMinimal(id: widget.id, s: s),
            data: (ship) => _ShipmentHeader(shipment: ship, s: s),
          ),

          // ── Offline banner ────────────────────────────────────────────────
          if (pendingOps > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: MbOfflineBanner(strings: s, pendingCount: pendingOps),
            ),

          // ── (B–E) Scrollable body ─────────────────────────────────────────
          Expanded(
            child: shipmentAsync.when(
              loading: () => _BodySkeleton(isDark: isDark),
              error: (_, __) => _ErrorBody(
                s: s,
                onRetry: () =>
                    ref.invalidate(shipmentDetailProvider(widget.id)),
              ),
              data: (ship) => RefreshIndicator(
                color: mbBlue,
                onRefresh: () async {
                  try {
                    await ref.read(callRepositoryProvider).syncPending();
                  } catch (_) {}
                  await ref
                      .read(shipmentDetailProvider(widget.id).notifier)
                      .refresh();
                  ref.invalidate(shipmentCallsProvider(widget.id));
                },
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    _RecipientCard(
                      shipment: ship,
                      s: s,
                      isDark: isDark,
                      onCall: _makeCall,
                    ),
                    const SizedBox(height: 12),
                    if (ship.hasCod) ...[
                      _CodAmount(amount: ship.codAmount!, s: s),
                      const SizedBox(height: 12),
                    ],
                    _SectionLabel(label: s.colCallsLabel, isDark: isDark),
                    _CallsSection(
                        callsAsync: callsAsync,
                        s: s,
                        isDark: isDark,
                        onCall: _makeCall),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // ── (F) Fixed action bar ──────────────────────────────────────────
          _ActionBar(
            phone: shipmentAsync.valueOrNull?.recipientPhone,
            enabled: shipmentAsync.hasValue,
            s: s,
            isDark: isDark,
            onCall: _makeCall,
            onScan: () =>
                context.push('/scan/delivery?shipmentId=${widget.id}'),
          ),
        ],
      ),
    );
  }
}

// ── (A) Header ────────────────────────────────────────────────────────────────

class _ShipmentHeader extends StatelessWidget {
  const _ShipmentHeader({required this.shipment, required this.s});
  final ShipmentModel shipment;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final tracking = shipment.trackingNumber.isNotEmpty
        ? shipment.trackingNumber
        : '#${shipment.id}';

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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Semantics(
                    label: 'Retour',
                    button: true,
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.colTitle,
                          style: GoogleFonts.archivo(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tracking,
                          style: GoogleFonts.splineSansMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _kHeaderSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: shipment.status, s: s),
                ],
              ),
              const SizedBox(height: 11),
              Semantics(
                label: 'Code-barres $tracking',
                child: Container(
                  height: 36,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: CustomPaint(
                    painter: _BarcodePainter(data: tracking),
                    size: Size.infinite,
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

// ── Status badge (on blue header) ─────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.s});
  final String status;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final dotColor = _dotColor(status);
    final label = _label(status, s);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(0x29),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  static Color _dotColor(String status) => switch (status) {
        ShipmentStatus.delivered => mbOk,
        ShipmentStatus.failed || ShipmentStatus.returned => mbErr,
        _ => Colors.white,
      };

  static String _label(String status, AppStrings s) => switch (status) {
        ShipmentStatus.delivered => s.shipStatusDelivered,
        ShipmentStatus.failed => s.shipStatusFailed,
        ShipmentStatus.returned => s.shipStatusReturned,
        _ => s.shipStatusPending,
      };
}

// ── Barcode painter ───────────────────────────────────────────────────────────

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter({required this.data});
  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final black = Paint()
      ..color = const Color(0xFF1A1F26)
      ..style = PaintingStyle.fill;

    var seed = data.codeUnits
        .fold(0, (int a, int b) => (a * 31 + b) & 0x7FFFFFFF);
    final unit = math.max(1.0, size.width / 160);
    var x = 0.0;
    bool isBlack = true;

    while (x < size.width) {
      seed = ((seed * 1664525 + 1013904223) & 0x7FFFFFFF);
      final w = (((seed >> 12) & 0x3) + 1) * unit;
      if (isBlack) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), black);
      }
      x += w;
      isBlack = !isBlack;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.data != data;
}

// ── Header skeletons ──────────────────────────────────────────────────────────

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
                    width: 40,
                    height: 40,
                    child: Center(
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.colTitle,
                            style: GoogleFonts.archivo(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        _SkBar(width: 110, height: 12),
                      ],
                    ),
                  ),
                  _SkBar(width: 72, height: 24),
                ],
              ),
              const SizedBox(height: 11),
              _SkBar(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

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
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${s.colTitle} #$id',
                style: GoogleFonts.archivo(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkBar extends StatelessWidget {
  const _SkBar({this.width, required this.height});
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
        ),
      );
}

// ── (B) Recipient card ────────────────────────────────────────────────────────

class _RecipientCard extends StatelessWidget {
  const _RecipientCard({
    required this.shipment,
    required this.s,
    required this.isDark,
    required this.onCall,
  });
  final ShipmentModel shipment;
  final AppStrings s;
  final bool isDark;
  final Future<void> Function(String phone) onCall;

  @override
  Widget build(BuildContext context) {
    final phone = shipment.recipientPhone;
    final addressParts = <String>[];
    if (shipment.address.isNotEmpty) addressParts.add(shipment.address);
    if (shipment.city.isNotEmpty) addressParts.add(shipment.city);
    if (shipment.governorate != null && shipment.governorate!.isNotEmpty) {
      addressParts.add(shipment.governorate!);
    }
    final address = addressParts.join(', ');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? mbDarkSurface : mbSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? mbDarkLine : mbLine, width: 1),
      ),
      child: Column(
        children: [
          _KvRow(
            icon: Icons.person_outline_rounded,
            label: s.colRecipient,
            value: shipment.recipientName,
            isDark: isDark,
          ),
          Divider(
              height: 1,
              thickness: 1,
              color: isDark ? mbDarkLine2 : mbLine2),
          _KvRow(
            icon: Icons.phone_outlined,
            label: s.colPhone,
            value: phone ?? '—',
            isDark: isDark,
            actionIcon:
                phone != null ? Icons.phone_rounded : null,
            onTap: phone != null ? () => onCall(phone) : null,
          ),
          Divider(
              height: 1,
              thickness: 1,
              color: isDark ? mbDarkLine2 : mbLine2),
          _KvRow(
            icon: Icons.location_on_outlined,
            label: s.colAddress,
            value: address.isNotEmpty ? address : '—',
            isDark: isDark,
            multiline: true,
          ),
        ],
      ),
    );
  }

}

class _KvRow extends StatelessWidget {
  const _KvRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.actionIcon,
    this.onTap,
    this.multiline = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final IconData? actionIcon;
  final VoidCallback? onTap;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? mbDarkInk : mbInk;
    final ink3 = isDark ? mbDarkInk3 : mbInk3;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 18, child: Icon(icon, size: 16, color: ink3)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.04 * 10,
                    color: ink3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.archivo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ink,
                    height: 1.4,
                  ),
                  maxLines: multiline ? null : 1,
                  overflow: multiline ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (actionIcon != null) ...[
            const SizedBox(width: 8),
            Icon(actionIcon, size: 14, color: mbBlue),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: content,
        ),
      );
    }
    return content;
  }
}

// ── (C) COD amount ────────────────────────────────────────────────────────────

class _CodAmount extends StatelessWidget {
  const _CodAmount({required this.amount, required this.s});
  final double amount;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${s.colCodLabel} ${_fmt(amount)} dirhams, ${s.colCodSub}',
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: mbPendBg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _kCodBorder, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.colCodLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.03 * 11,
                      color: mbBlue,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.colCodSub,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: mbInk2,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${_fmt(amount)} DH',
              style: GoogleFonts.archivo(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: mbBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) {
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
}

// ── (D) Section label ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 13, 0, 9),
        child: Text(
          label,
          style: GoogleFonts.archivo(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.06 * 10.5,
            color: isDark ? mbDarkInk3 : mbInk3,
          ),
        ),
      );
}

// ── (E) Calls section ─────────────────────────────────────────────────────────

class _CallsSection extends StatelessWidget {
  const _CallsSection(
      {required this.callsAsync, required this.s, required this.isDark, required this.onCall});
  final AsyncValue<List<CallLogModel>> callsAsync;
  final AppStrings s;
  final bool isDark;
  final Future<void> Function(String phone) onCall;

  @override
  Widget build(BuildContext context) {
    return callsAsync.when(
      loading: () => _CallsSkeleton(isDark: isDark),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          s.colNoCalls,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? mbDarkInk3 : mbInk3,
          ),
        ),
      ),
      data: (calls) {
        if (calls.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              s.colNoCalls,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? mbDarkInk3 : mbInk3,
              ),
            ),
          );
        }
        final sorted = [...calls]
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        return Container(
          decoration: BoxDecoration(
            color: isDark ? mbDarkSurface : mbSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isDark ? mbDarkLine : mbLine, width: 1),
          ),
          child: Column(
            children: [
              for (int i = 0; i < sorted.length; i++) ...[
                if (i > 0)
                  Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark ? mbDarkLine2 : mbLine2),
                _CallRow(call: sorted[i], s: s, isDark: isDark, onCall: onCall),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CallRow extends StatelessWidget {
  const _CallRow(
      {required this.call, required this.s, required this.isDark, required this.onCall});
  final CallLogModel call;
  final AppStrings s;
  final bool isDark;
  final Future<void> Function(String phone) onCall;

  @override
  Widget build(BuildContext context) {
    final (iconColor, bgColor, label) = _style(call.result, s);
    final time = _fmtTime(call.startedAt);
    final dur = _fmtDuration(call.durationSeconds);
    final ink = isDark ? mbDarkInk : mbInk;
    final ink3 = isDark ? mbDarkInk3 : mbInk3;

    return Semantics(
      label: '$label, $time, durée $dur',
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.phone_rounded, size: 15, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.archivo(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$time · $dur',
                    style: GoogleFonts.splineSansMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: ink3,
                    ),
                  ),
                ],
              ),
            ),
            if (call.phoneNumber.isNotEmpty)
              Semantics(
                label: 'Rappeler',
                button: true,
                child: GestureDetector(
                  onTap: () => unawaited(onCall(call.phoneNumber)),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border.all(color: mbBlue, width: 1.5),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.phone_outlined,
                        size: 14, color: mbBlue),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static (Color, Color, String) _style(String result, AppStrings s) =>
      switch (result) {
        CallResult.reached => (mbOk, mbOkBg, s.callJoined),
        CallResult.noAnswer => (mbWarn, mbWarnBg, s.callNoAnswer),
        _ => (mbErr, mbErrBg, s.callUnreachable),
      };

  static String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static String _fmtDuration(int secs) {
    if (secs == 0) return '0:00';
    return '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
  }

}

class _CallsSkeleton extends StatelessWidget {
  const _CallsSkeleton({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final sh = isDark ? mbDarkSurface2 : mbSurface3;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? mbDarkSurface : mbSurface,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: isDark ? mbDarkLine : mbLine, width: 1),
      ),
      child: Column(
        children: [
          for (int i = 0; i < 2; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  color: isDark ? mbDarkLine2 : mbLine2),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: sh,
                          borderRadius: BorderRadius.circular(9))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            height: 13,
                            width: 120,
                            decoration: BoxDecoration(
                                color: sh,
                                borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 4),
                        Container(
                            height: 10,
                            width: 80,
                            decoration: BoxDecoration(
                                color: sh,
                                borderRadius: BorderRadius.circular(4))),
                      ],
                    ),
                  ),
                  Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: sh,
                          borderRadius: BorderRadius.circular(9))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Body skeleton ─────────────────────────────────────────────────────────────

class _BodySkeleton extends StatelessWidget {
  const _BodySkeleton({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final sh = isDark ? mbDarkSurface2 : mbSurface3;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? mbDarkSurface : mbSurface,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: isDark ? mbDarkLine : mbLine),
            ),
            child: Column(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        color: isDark ? mbDarkLine2 : mbLine2),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                                color: sh,
                                borderRadius:
                                    BorderRadius.circular(3))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Container(
                                  height: 10,
                                  width: 70,
                                  decoration: BoxDecoration(
                                      color: sh,
                                      borderRadius:
                                          BorderRadius.circular(3))),
                              const SizedBox(height: 5),
                              Container(
                                  height: 13,
                                  decoration: BoxDecoration(
                                      color: sh,
                                      borderRadius:
                                          BorderRadius.circular(3))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: sh,
              borderRadius: BorderRadius.circular(11),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.s, required this.onRetry});
  final AppStrings s;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: mbErr),
              const SizedBox(height: 12),
              Text(s.colError,
                  style: const TextStyle(fontSize: 14, color: mbErr),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: onRetry, child: Text(s.dashRetry)),
            ],
          ),
        ),
      );
}

// ── (F) Action bar ────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.phone,
    required this.enabled,
    required this.s,
    required this.isDark,
    required this.onCall,
    required this.onScan,
  });

  final String? phone;
  final bool enabled;
  final AppStrings s;
  final bool isDark;
  final Future<void> Function(String phone) onCall;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? mbDarkSurface : mbSurface,
        border: Border(
          top: BorderSide(
              color: isDark ? mbDarkLine : mbLine, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(14, 11, 14, 11 + safeBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: _GhostBtn(
              icon: Icons.phone_outlined,
              label: s.colCall,
              enabled: enabled && phone != null,
              onTap: () {
                final p = phone;
                if (p != null) unawaited(onCall(p));
              },
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: enabled
                  ? () {
                      HapticFeedback.lightImpact();
                      onScan();
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: mbRed,
                disabledBackgroundColor: mbErr.withAlpha(0x55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
              icon: CustomPaint(
                size: const Size(16, 16),
                painter:
                    const MbScanIconPainter(color: Colors.white),
              ),
              label: Text(
                s.colScanMark,
                style: GoogleFonts.archivo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _GhostBtn extends StatelessWidget {
  const _GhostBtn({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: mbBlue,
        disabledForegroundColor: mbInk3,
        side: BorderSide(
            color: enabled ? mbBlue : mbLine, width: 1.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11)),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: GoogleFonts.archivo(
            fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

