import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/i18n/app_strings.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/colors.dart';
import '../controllers/pickup_scan_controller.dart';

const _kScanBg = Color(0xFF11151B);
const _kSub = Color(0xFF9FB4C9);

enum _PermState { checking, granted, denied }

// ─────────────────────────────────────────────────────────────────────────────

class PickupScanScreen extends ConsumerStatefulWidget {
  const PickupScanScreen({super.key, required this.manifestId});
  final int manifestId;

  @override
  ConsumerState<PickupScanScreen> createState() => _PickupScanScreenState();
}

class _PickupScanScreenState extends ConsumerState<PickupScanScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final MobileScannerController _camera;
  late final AnimationController _lineCtrl;
  late final AnimationController _counterCtrl;
  late final Animation<double> _lineAnim;
  late final Animation<double> _counterScale;

  final Map<String, DateTime> _lastScan = {};
  _PermState _permState = _PermState.checking;
  bool _torchOn = false;
  bool _reduceMotion = false;

  final _listKey = GlobalKey<AnimatedListState>();
  final _sideItems = <String>[];
  int _sideListKey = 0;

  // Reject visuals — shown briefly in the side overlay
  String? _duplicateBarcode;    // already scanned this session
  String? _outOfManifestBarcode; // barcode not in this manifest
  Timer? _dupTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _camera = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );

    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _counterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _lineAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut),
    );

    _counterScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 50),
    ]).animate(_counterCtrl);

    _checkPermission();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused) {
      _camera.stop();
    } else if (lifecycle == AppLifecycleState.resumed) {
      if (_permState == _PermState.granted) _camera.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.dispose();
    _lineCtrl.dispose();
    _counterCtrl.dispose();
    _dupTimer?.cancel();
    super.dispose();
  }

  // ── Permission ─────────────────────────────────────────────────────────────

  Future<void> _checkPermission() async {
    var status = await Permission.camera.status;
    if (status.isDenied) status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _permState = _PermState.granted);
      if (!_reduceMotion) _lineCtrl.repeat(reverse: true);
    } else {
      setState(() => _permState = _PermState.denied);
    }
  }

  // ── Scan throttle (600 ms per barcode) ─────────────────────────────────────

  bool _throttle(String barcode) {
    final now = DateTime.now();
    final last = _lastScan[barcode];
    if (last != null && now.difference(last).inMilliseconds < 600) return true;
    _lastScan[barcode] = now;
    return false;
  }

  void _onDetect(BarcodeCapture cap) {
    if (cap.barcodes.isEmpty) return;

    // Collect all non-empty values — multiple barcodes may be visible in frame.
    final codes = cap.barcodes
        .map((b) => b.rawValue?.trim())
        .where((v) => v != null && v.isNotEmpty)
        .cast<String>()
        .toList();
    if (codes.isEmpty) return;

    // Prefer a code that matches the manifest; fall back to first.
    final manifest = ref.read(pickupRepositoryProvider).cached(widget.manifestId);
    String raw = codes.first;
    if (manifest != null && manifest.shipments.isNotEmpty) {
      for (final c in codes) {
        if (manifest.shipments.any((s) => s.matchesCode(c))) {
          raw = c;
          break;
        }
      }
    }

    if (_throttle(raw)) return;

    final ctrl = ref.read(pickupScanProvider(widget.manifestId).notifier);
    final result = ctrl.add(raw);

    if (result == ScanAddResult.duplicate) {
      HapticFeedback.heavyImpact();
      _dupTimer?.cancel();
      setState(() {
        _duplicateBarcode = raw;
        _outOfManifestBarcode = null;
      });
      _dupTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _duplicateBarcode = null);
      });
      return;
    }

    if (result == ScanAddResult.notInManifest) {
      HapticFeedback.vibrate();
      _dupTimer?.cancel();
      setState(() {
        _outOfManifestBarcode = raw;
        _duplicateBarcode = null;
      });
      _dupTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _outOfManifestBarcode = null);
      });
      return;
    }

    HapticFeedback.lightImpact();
    if (!_reduceMotion) _counterCtrl.forward(from: 0);

    setState(() {
      _sideItems.insert(0, raw);
      _listKey.currentState?.insertItem(
        0,
        duration: const Duration(milliseconds: 200),
      );
      if (_sideItems.length > 5) {
        final overflowIdx = _sideItems.length - 1;
        _sideItems.removeAt(overflowIdx);
        _listKey.currentState?.removeItem(
          overflowIdx,
          (_, __) => const SizedBox.shrink(),
          duration: Duration.zero,
        );
      }
    });
  }

  // ── Quit confirmation ───────────────────────────────────────────────────────

  Future<void> _close() async {
    final scanState = ref.read(pickupScanProvider(widget.manifestId));
    if (scanState.scanned.isEmpty) {
      if (mounted) context.pop();
      return;
    }
    final s = AppStrings.of(ref.read(localeProvider).languageCode);
    final ctrl = ref.read(pickupScanProvider(widget.manifestId).notifier);

    if (scanState.isOffline) {
      // Persist any in-memory barcodes then close — all will auto-send on reconnect
      await ctrl.persistAll();
      if (mounted) {
        _showToast(s.qscanOfflineDeferred);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) context.pop();
      }
      return;
    }

    // Online: only confirm if there are unqueued barcodes that would be lost
    final hasUnqueued = scanState.scanned
        .any((b) => !scanState.persistedOpIds.containsKey(b));
    if (!hasUnqueued) {
      // All scans are already in Hive — safe to close
      if (mounted) context.pop();
      return;
    }

    final quit = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2630),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          s.qscanQuitTitle,
          style: GoogleFonts.archivo(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        content: Text(
          s.qscanQuitBody,
          style: GoogleFonts.hankenGrotesk(fontSize: 14, color: _kSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.qscanQuitStay, style: const TextStyle(color: _kSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.qscanQuitLeave, style: const TextStyle(color: mbErr)),
          ),
        ],
      ),
    );
    if ((quit ?? false) && mounted) context.pop();
  }

  // ── Send batch ──────────────────────────────────────────────────────────────

  Future<void> _sendBatch() async {
    final count = ref.read(pickupScanProvider(widget.manifestId)).count;
    final s = AppStrings.of(ref.read(localeProvider).languageCode);
    try {
      await ref.read(pickupScanProvider(widget.manifestId).notifier).sendBatch();
      if (!mounted) return;
      final newState = ref.read(pickupScanProvider(widget.manifestId));
      _showToast(
        newState.sentOffline ? s.qscanOfflineDeferred : s.qscanSentToast(count),
      );
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) _showToast(s.qscanSendError, isError: true);
    }
  }

  // ── Review sheet ────────────────────────────────────────────────────────────

  void _openReviewSheet() {
    final s = AppStrings.of(ref.read(localeProvider).languageCode);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A2130),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _ReviewSheet(
        manifestId: widget.manifestId,
        s: s,
        onRemoved: () {
          final scanned =
              ref.read(pickupScanProvider(widget.manifestId)).scanned;
          setState(() {
            _sideItems
              ..clear()
              ..addAll(scanned.take(5));
            _sideListKey++;
          });
        },
      ),
    );
  }

  // ── Toast ───────────────────────────────────────────────────────────────────

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        msg,
        style: GoogleFonts.archivo(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      backgroundColor: isError ? mbErr : mbOk,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
    ));
  }


  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final s = AppStrings.of(locale.languageCode);
    final scanState = ref.watch(pickupScanProvider(widget.manifestId));
    final count = scanState.count;
    final sending = scanState.sending;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: _kScanBg,
        body: switch (_permState) {
          _PermState.denied => _PermissionView(s: s),
          _PermState.checking => const SizedBox.shrink(),
          _PermState.granted => Stack(
              children: [
                // (0) Camera
                Positioned.fill(
                  child: MobileScanner(
                    controller: _camera,
                    onDetect: _onDetect,
                  ),
                ),

                // Top gradient
                Positioned(
                  top: 0, left: 0, right: 0,
                  height: 160,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xCC000000), Colors.transparent],
                      ),
                    ),
                  ),
                ),

                // Bottom gradient
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  height: 180,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xCC000000), Colors.transparent],
                      ),
                    ),
                  ),
                ),

                // (A) Top bar
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: _TopBar(
                    s: s,
                    torchOn: _torchOn,
                    onClose: _close,
                    onTorchToggle: () {
                      setState(() => _torchOn = !_torchOn);
                      _camera.toggleTorch();
                    },
                  ),
                ),

                // (B) Counter
                Positioned(
                  top: 100, left: 0, right: 0,
                  child: _Counter(
                    count: count,
                    s: s,
                    scaleAnim: _counterScale,
                  ),
                ),

                // (C) Side list — most recent first
                // Reject chip: slides in from above (duplicate=red, not-in-manifest=orange)
                Positioned(
                  top: 120,
                  right: 12,
                  width: 132,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -1),
                        end: Offset.zero,
                      ).animate(
                          CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: _outOfManifestBarcode != null
                        ? _RejectChip(
                            key: ValueKey('oom_$_outOfManifestBarcode'),
                            barcode: _outOfManifestBarcode!,
                            label: AppStrings.of(
                                ref.read(localeProvider).languageCode)
                                .qscanNotInManifest,
                            color: mbWarn,
                          )
                        : _duplicateBarcode != null
                            ? _RejectChip(
                                key: ValueKey('dup_$_duplicateBarcode'),
                                barcode: _duplicateBarcode!,
                                label: AppStrings.of(
                                    ref.read(localeProvider).languageCode)
                                    .qscanDuplicate,
                                color: mbErr,
                              )
                            : const SizedBox.shrink(key: Key('no-reject')),
                  ),
                ),

                // List slides down smoothly when a reject chip appears
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  top: (_duplicateBarcode != null || _outOfManifestBarcode != null)
                      ? 166.0
                      : 120.0,
                  bottom: 130,
                  right: 12,
                  width: 132,
                  child: ClipRect(
                    child: AnimatedList(
                      key: ValueKey(_sideListKey),
                      initialItemCount: _sideItems.length,
                      padding: EdgeInsets.zero,
                      itemBuilder: (ctx, index, animation) {
                        if (index >= _sideItems.length) {
                          return const SizedBox.shrink();
                        }
                        return _ScannedItem(
                          barcode: _sideItems[index],
                          animation: animation,
                        );
                      },
                    ),
                  ),
                ),

                // (D) Viewfinder
                Center(
                  child: _Viewfinder(
                    scanLineAnim: _lineAnim,
                    reduceMotion: _reduceMotion,
                  ),
                ),

                // Offline chip
                if (scanState.isOffline)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _OfflineChip(s: s),
                      ),
                    ),
                  ),

                // (E+F) Bottom buttons
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // (E) Blue review
                          _FullButton(
                            color: mbBlue,
                            icon: Icons.check_rounded,
                            label: s.qscanReview(count),
                            enabled: count > 0,
                            onTap: count > 0 ? _openReviewSheet : null,
                          ),
                          const SizedBox(height: 9),
                          // (F) Green send / offline queue
                          _FullButton(
                            color: mbOk,
                            icon: scanState.isOffline
                                ? Icons.cloud_upload_outlined
                                : Icons.send_rounded,
                            label: sending
                                ? s.qscanSending
                                : scanState.isOffline
                                    ? s.qscanSaveOffline(count)
                                    : s.qscanSend(count),
                            loading: sending,
                            enabled: count > 0 && !sending,
                            onTap: count > 0 && !sending ? _sendBatch : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
        },
      ),
    );
  }
}

// ─── (A) Top bar ──────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.s,
    required this.torchOn,
    required this.onClose,
    required this.onTorchToggle,
  });

  final AppStrings s;
  final bool torchOn;
  final VoidCallback onClose;
  final VoidCallback onTorchToggle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ✕ close
            Semantics(
              button: true,
              label: s.qscanQuitLeave,
              child: GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Title + sub
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.qscanTitle,
                    style: GoogleFonts.archivo(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    s.qscanModeSub,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: _kSub,
                    ),
                  ),
                ],
              ),
            ),
            // Torch toggle
            Semantics(
              button: true,
              label: 'Torche',
              child: GestureDetector(
                onTap: onTorchToggle,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Icon(
                      torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: torchOn ? Colors.amber : Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── (B) Counter ──────────────────────────────────────────────────────────────

class _Counter extends StatelessWidget {
  const _Counter({
    required this.count,
    required this.s,
    required this.scaleAnim,
  });

  final int count;
  final AppStrings s;
  final Animation<double> scaleAnim;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: scaleAnim,
          builder: (ctx, child) =>
              Transform.scale(scale: scaleAnim.value, child: child),
          child: Semantics(
            liveRegion: true,
            label: '$count ${s.qscanCounterLabel}',
            child: Text(
              '$count',
              style: GoogleFonts.archivo(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.qscanCounterLabel,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _kSub,
          ),
        ),
      ],
    );
  }
}

// ─── (C) Scanned item ─────────────────────────────────────────────────────────

class _ScannedItem extends StatelessWidget {
  const _ScannedItem({required this.barcode, required this.animation});

  final String barcode;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: FadeTransition(
        opacity: animation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(242), // ~0.95 opacity
            borderRadius: BorderRadius.circular(9),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.check_rounded, color: mbOk, size: 13),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  barcode,
                  style: GoogleFonts.splineSansMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: mbInk,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── (D) Viewfinder ───────────────────────────────────────────────────────────

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({
    required this.scanLineAnim,
    required this.reduceMotion,
  });

  final Animation<double> scanLineAnim;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    const size = 180.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Corner brackets
          Positioned.fill(
            child: CustomPaint(painter: _CornerPainter()),
          ),
          // Scan line
          if (!reduceMotion)
            AnimatedBuilder(
              animation: scanLineAnim,
              builder: (ctx, _) {
                final top = scanLineAnim.value * (size - 2);
                return Positioned(
                  top: top,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: mbRed,
                      boxShadow: [
                        BoxShadow(
                          color: mbRed.withAlpha(153), // 0.6 opacity
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          else
            Positioned(
              top: size / 2 - 1,
              left: 0,
              right: 0,
              child: Container(height: 2, color: mbRed),
            ),
        ],
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const arm = 24.0;
    final w = size.width;
    final h = size.height;

    final path = Path()
      // Top-left
      ..moveTo(0, arm)
      ..lineTo(0, 0)
      ..lineTo(arm, 0)
      // Top-right
      ..moveTo(w - arm, 0)
      ..lineTo(w, 0)
      ..lineTo(w, arm)
      // Bottom-right
      ..moveTo(w, h - arm)
      ..lineTo(w, h)
      ..lineTo(w - arm, h)
      // Bottom-left
      ..moveTo(arm, h)
      ..lineTo(0, h)
      ..lineTo(0, h - arm);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── (E+F) Full-width button ──────────────────────────────────────────────────

class _FullButton extends StatelessWidget {
  const _FullButton({
    required this.color,
    required this.icon,
    required this.label,
    this.loading = false,
    this.enabled = true,
    this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final bool loading;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1.0 : 0.45,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 17),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.archivo(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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

// ─── Review sheet ─────────────────────────────────────────────────────────────

class _ReviewSheet extends ConsumerWidget {
  const _ReviewSheet({
    required this.manifestId,
    required this.s,
    required this.onRemoved,
  });

  final int manifestId;
  final AppStrings s;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanned = ref.watch(pickupScanProvider(manifestId)).scanned;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.3,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Text(
                    s.qscanReviewTitle,
                    style: GoogleFonts.archivo(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: mbBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${scanned.length}',
                      style: GoogleFonts.archivo(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // List
            Expanded(
              child: scanned.isEmpty
                  ? Center(
                      child: Text(
                        s.qscanReviewEmpty,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 14,
                          color: _kSub,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: scanned.length,
                      itemBuilder: (ctx, i) {
                        final barcode = scanned[i];
                        return ListTile(
                          dense: true,
                          leading:
                              const Icon(Icons.check_circle, color: mbOk, size: 18),
                          title: Text(
                            barcode,
                            style: GoogleFonts.splineSansMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white54,
                              size: 18,
                            ),
                            onPressed: () {
                              ref
                                  .read(pickupScanProvider(manifestId).notifier)
                                  .remove(barcode);
                              onRemoved();
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Offline chip ─────────────────────────────────────────────────────────────

class _OfflineChip extends StatelessWidget {
  const _OfflineChip({required this.s});
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE08600).withAlpha(230),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 13),
          const SizedBox(width: 6),
          Text(
            s.qscanOfflineBanner,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reject chip (duplicate = red, not-in-manifest = orange) ─────────────────

class _RejectChip extends StatelessWidget {
  const _RejectChip({
    super.key,
    required this.barcode,
    required this.label,
    required this.color,
  });
  final String barcode;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(230),
        borderRadius: BorderRadius.circular(9),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.archivo(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withAlpha(0xCC),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            barcode,
            style: GoogleFonts.splineSansMono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

// ─── Permission denied view ───────────────────────────────────────────────────

class _PermissionView extends StatelessWidget {
  const _PermissionView({required this.s});
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_rounded, size: 52, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              s.scanPermTitle,
              style: GoogleFonts.archivo(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: openAppSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: mbBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              child: Text(
                s.scanPermCta,
                style: GoogleFonts.archivo(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
