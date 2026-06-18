import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/i18n/app_strings.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../runsheets/data/models/runsheet_model.dart';
import '../../../shipments/data/models/shipment_model.dart';

// ── Permission state ──────────────────────────────────────────────────────────

enum _PermState { checking, granted, denied }

// ── Screen ────────────────────────────────────────────────────────────────────

class ScanDeliveryScreen extends ConsumerStatefulWidget {
  const ScanDeliveryScreen({super.key, this.runsheetId, this.shipmentId});

  final int? runsheetId;
  final int? shipmentId;

  @override
  ConsumerState<ScanDeliveryScreen> createState() => _ScanDeliveryScreenState();
}

class _ScanDeliveryScreenState extends ConsumerState<ScanDeliveryScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final MobileScannerController _camera;
  late final AnimationController _lineCtrl;
  late final AnimationController _pillCtrl;
  late final Animation<double> _lineAnim;
  late final Animation<double> _pillScale;
  late final Animation<double> _pillFade;

  _PermState _permState = _PermState.checking;
  ShipmentModel? _detected;
  bool _sheetOpen = false;
  bool _isValidating = false; // true while API barcode lookup is in-flight
  DateTime? _lastDetect;
  bool _torchOn = false;
  bool _reduceMotion = false;

  // Offline state
  bool _isOnline = true;
  bool _offlineQueued = false; // shows orange pill after offline action
  int _pendingCount = 0;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  // Fail-mode state
  bool _blockResume = false;   // prevents _resumeScan during fail sheet
  bool _isSubmitting = false;  // prevents _resumeScan while API call + pop is in-flight
  String? _failTracking;       // non-null when fail reason sheet is open

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _camera = MobileScannerController(
      // normal + global _throttle() mirrors pickup-scan: allows retry of the same
      // barcode after a rejection, which noDuplicates would block.
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );

    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pillCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _lineAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut),
    );

    _pillScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _pillCtrl, curve: Curves.easeOut),
    );

    _pillFade = Tween<double>(begin: 0, end: 1).animate(_pillCtrl);

    _checkPermission();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final conn = ref.read(connectivityProvider);
    final results = await conn.checkConnectivity();
    if (mounted) setState(() => _isOnline = _resultsOnline(results));
    _connSub = conn.onConnectivityChanged.listen((results) {
      if (mounted) setState(() => _isOnline = _resultsOnline(results));
    });
    // Also track pending count from the offline queue
    ref.read(offlineQueueProvider).pendingCountStream.listen((count) {
      if (mounted) setState(() => _pendingCount = count);
    });
    _pendingCount = ref.read(offlineQueueProvider).pendingCount;
  }

  bool _resultsOnline(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);

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
      if (_permState == _PermState.granted && !_sheetOpen) {
        _camera.start();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    _camera.dispose();
    _lineCtrl.dispose();
    _pillCtrl.dispose();
    super.dispose();
  }

  // ── Permission ─────────────────────────────────────────────────────────────

  Future<void> _checkPermission() async {
    var status = await Permission.camera.status;
    if (status.isDenied) {
      status = await Permission.camera.request();
    }
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _permState = _PermState.granted);
      if (!_reduceMotion) _lineCtrl.repeat(reverse: true);
    } else {
      setState(() => _permState = _PermState.denied);
    }
  }

  // ── Detection ──────────────────────────────────────────────────────────────

  bool _throttle() {
    final now = DateTime.now();
    if (_lastDetect != null &&
        now.difference(_lastDetect!).inMilliseconds < 800) {
      return true;
    }
    _lastDetect = now;
    return false;
  }

  void _onDetect(BarcodeCapture cap) {
    if (_sheetOpen || _detected != null || _isValidating) return;
    if (cap.barcodes.isEmpty) return;
    if (_throttle()) return;

    // Collect all non-empty values from the frame (multiple barcodes may be visible).
    final codes = cap.barcodes
        .map((b) => b.rawValue?.trim())
        .where((v) => v != null && v.isNotEmpty)
        .cast<String>()
        .toList();
    if (codes.isEmpty) return;

    // Pick the best candidate: real cache hit > stub (runsheet free-scan) > first code.
    String best = codes.first;
    String? stubCandidate;
    for (final c in codes) {
      final s = _lookupBarcode(c);
      if (s != null && s.id != 0) { best = c; break; }
      if (s != null) stubCandidate ??= c;
    }
    if (best == codes.first && stubCandidate != null) best = stubCandidate;

    unawaited(_validateAndOpenSheet(best));
  }

  // Validates barcode then opens the confirmation sheet.
  Future<void> _validateAndOpenSheet(String barcode) async {
    HapticFeedback.mediumImpact();
    _lineCtrl.stop();
    setState(() => _isValidating = true);
    _pillCtrl.forward(from: 0);

    final ShipmentModel? shipment = _lookupBarcode(barcode);

    if (!mounted) return;

    if (shipment == null) {
      setState(() => _isValidating = false);
      _pillCtrl.reverse();
      if (!_reduceMotion) _lineCtrl.repeat(reverse: true);
      _lastDetect = null; // reset throttle so user can retry immediately
      _camera.start();
      _errorFeedback();
      return;
    }

    setState(() {
      _isValidating = false;
      _detected = shipment;
    });

    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted && _detected != null && !_sheetOpen) {
      unawaited(_openSheet(shipment));
    }
  }

  ShipmentModel? _lookupBarcode(String code) {
    final c = code.trim();

    // ── Case A: specific shipment known (opened from runsheet card or shipment detail)
    if (widget.shipmentId != null) {
      final rsRepo = ref.read(runsheetRepositoryProvider);
      final runsheets = <RunsheetModel>[];
      if (widget.runsheetId != null) {
        final d = rsRepo.cachedDetail(widget.runsheetId!);
        if (d != null) runsheets.add(d);
      }
      final active = rsRepo.cachedActive;
      if (active != null && !runsheets.any((r) => r.id == active.id)) {
        runsheets.add(active);
      }
      for (final rs in rsRepo.cachedAllDetails()) {
        if (!runsheets.any((r) => r.id == rs.id)) runsheets.add(rs);
      }

      ShipmentModel? found;
      for (final rs in runsheets) {
        final s = rs.shipments.where((s) => s.id == widget.shipmentId).firstOrNull;
        if (s != null) { found = s; break; }
      }
      found ??= ref.read(shipmentRepositoryProvider).cached(widget.shipmentId!);

      if (found != null) {
        // Validate exactly like pickup scan's matchesCode: accept if barcode or
        // tracking number matches.  Mismatch → null → caller shows "Colis hors liste".
        final brc = found.barcode.trim();
        final trk = found.trackingNumber.trim();
        if (trk == c || brc == c) return found;
        return null;
      }

      // Shipment not in any cache (like pickup when manifest isn't loaded) — accept any.
      return ShipmentModel(
        id: widget.shipmentId!,
        trackingNumber: c,
        barcode: c,
        status: '',
        recipientName: '',
        address: '',
        city: '',
      );
    }

    // ── Case B: free scan from runsheet (no specific shipment pre-selected)
    if (widget.runsheetId != null) {
      final rsRepo = ref.read(runsheetRepositoryProvider);
      final seen = <int>{};
      final candidates = <RunsheetModel>[];
      void tryAdd(RunsheetModel? rs) {
        if (rs != null && seen.add(rs.id)) candidates.add(rs);
      }
      tryAdd(rsRepo.cachedDetail(widget.runsheetId!));
      tryAdd(rsRepo.cachedActive);

      for (final rs in candidates) {
        final s = rs.shipments
            .where((s) => s.barcode.trim() == c || s.trackingNumber.trim() == c)
            .firstOrNull;
        if (s != null) return s;
      }

      if (candidates.any((r) => r.shipments.isNotEmpty)) return null;

      return ShipmentModel(
        id: 0,
        trackingNumber: c,
        barcode: c,
        status: '',
        recipientName: c,
        address: '',
        city: '',
      );
    }

    return null;
  }

  void _errorFeedback() {
    HapticFeedback.vibrate();
    // Spec: pastille ROUGE « Colis hors tournée » — show briefly as SnackBar
    final locale = ref.read(localeProvider).languageCode;
    final s = AppStrings.of(locale);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.scanOutOfRoute,
          style: GoogleFonts.archivo(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: mbErr,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Bottom sheet ───────────────────────────────────────────────────────────

  Future<void> _openSheet(ShipmentModel shipment) async {
    if (!mounted) return;
    setState(() => _sheetOpen = true);
    _camera.stop();

    final locale = ref.read(localeProvider).languageCode;
    final s = AppStrings.of(locale);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(0x66),
      isDismissible: true,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => _ConfirmationSheet(
        shipment: shipment,
        strings: s,
        isOffline: !_isOnline,
        onDeliver: () {
          Navigator.of(ctx).pop();
          unawaited(_doDeliver(shipment));
        },
        onFail: () {
          Navigator.of(ctx).pop();
          unawaited(_doFail(shipment));
        },
        onBack: () => Navigator.of(ctx).pop(),
      ),
    );

    _resumeScan();
  }

  void _resumeScan() {
    if (!mounted || _blockResume || _isSubmitting) return;
    setState(() {
      _sheetOpen = false;
      _detected = null;
      _offlineQueued = false;
      _failTracking = null;
    });
    _pillCtrl.reverse();
    if (!_reduceMotion) _lineCtrl.repeat(reverse: true);
    _camera.start();
  }

  Future<void> _doDeliver(ShipmentModel shipment) async {
    if (_isOnline) {
      // Online: show COD confirmation sheet (Image #19)
      await _showConfirmDeliverySheet(shipment);
    } else {
      // Offline: queue immediately, show orange pill
      await _queueDeliveryOffline(shipment);
    }
  }

  Future<void> _showConfirmDeliverySheet(ShipmentModel shipment) async {
    if (!mounted) return;
    setState(() => _sheetOpen = true);
    _camera.stop();

    final locale = ref.read(localeProvider).languageCode;
    final s = AppStrings.of(locale);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(0x66),
      isDismissible: true,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => _ConfirmDeliverySheet(
        shipment: shipment,
        strings: s,
        onConfirm: (double codAmount) async {
          Navigator.of(ctx).pop();
          await _submitDelivery(shipment, codAmount: codAmount);
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );

    _resumeScan();
  }

  Future<void> _submitDelivery(
    ShipmentModel shipment, {
    double? codAmount,
  }) async {
    _isSubmitting = true;
    final locale = ref.read(localeProvider).languageCode;
    final s = AppStrings.of(locale);
    final scanRepo = ref.read(scanRepositoryProvider);

    final result = await scanRepo.scanDelivery(
      barcode:
          shipment.barcode.isNotEmpty ? shipment.barcode : shipment.trackingNumber,
      status: ShipmentStatus.delivered,
      codCollected: codAmount != null && codAmount > 0,
      shipmentId: shipment.id != 0 ? shipment.id : null,
    );

    if (!mounted) return;
    if (result == null) _showToast(s.scanToastQueued, mbWarn);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> _queueDeliveryOffline(ShipmentModel shipment) async {
    _isSubmitting = true;
    final locale = ref.read(localeProvider).languageCode;
    final s = AppStrings.of(locale);
    final scanRepo = ref.read(scanRepositoryProvider);

    // Queue offline (returns null — no network)
    await scanRepo.scanDelivery(
      barcode:
          shipment.barcode.isNotEmpty ? shipment.barcode : shipment.trackingNumber,
      status: ShipmentStatus.delivered,
      codCollected: shipment.hasCod,
      shipmentId: shipment.id != 0 ? shipment.id : null,
    );

    if (!mounted) return;

    // Show orange "Enregistré" pill in camera area briefly, then pop
    setState(() {
      _sheetOpen = false;
      _offlineQueued = true;
    });
    _pillCtrl.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) {
      _showToast(s.scanToastQueued, mbWarn);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    }
  }

  Future<void> _doFail(ShipmentModel shipment) async {
    // Block _resumeScan while the fail sheet is open (runs concurrently with _openSheet)
    _blockResume = true;
    if (mounted) setState(() => _failTracking = shipment.trackingNumber);

    final locale = ref.read(localeProvider).languageCode;
    final s = AppStrings.of(locale);

    final result = await showModalBottomSheet<({String reason, String? comment})>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(0x66),
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => _FailReasonSheet(shipment: shipment, strings: s),
    );

    if (!mounted) return;
    setState(() => _failTracking = null);
    _blockResume = false;

    if (result == null) {
      _resumeScan();
      return;
    }

    _isSubmitting = true;
    final scanRepo = ref.read(scanRepositoryProvider);
    final apiResult = await scanRepo.scanDelivery(
      barcode:
          shipment.barcode.isNotEmpty ? shipment.barcode : shipment.trackingNumber,
      status: ShipmentStatus.failed,
      returnType: result.reason,
      comment: result.comment,
      shipmentId: shipment.id != 0 ? shipment.id : null,
    );

    if (!mounted) return;
    if (apiResult == null) _showToast(s.scanToastQueued, mbWarn);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _showToast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
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

  void _toggleTorch() {
    setState(() => _torchOn = !_torchOn);
    _camera.toggleTorch();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).languageCode;
    final s = AppStrings.of(locale);

    return Directionality(
      textDirection: s.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF11151B),
        body: switch (_permState) {
          _PermState.checking => const SizedBox.shrink(),
          _PermState.denied => _PermissionView(strings: s),
          _PermState.granted => _buildCameraStack(s),
        },
      ),
    );
  }

  Widget _buildCameraStack(AppStrings s) {
    final isConfirming = _detected != null || _sheetOpen;

    return Stack(
      fit: StackFit.expand,
      children: [
        // (B) Camera feed
        MobileScanner(
          controller: _camera,
          onDetect: _onDetect,
          fit: BoxFit.cover,
        ),

        // Vignette
        const _VignetteOverlay(),

        // (A) Top bar — morphs between scan mode and confirm mode
        PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TopBar(
                strings: s,
                torchOn: _torchOn,
                isConfirming: isConfirming,
                failTracking: _failTracking,
                pendingCount: _pendingCount,
                onClose: () => Navigator.of(context).pop(),
                onBack: _resumeScan,
                onToggleTorch: _toggleTorch,
              ),
              // Offline banner shown when offline and confirming
              if (!_isOnline && isConfirming)
                _OfflineBanner(
                  strings: s,
                  pendingCount: _pendingCount,
                ),
            ],
          ),
        ),

        // (C)(D) Scan frame + pill (validating blue / green detected / orange queued)
        Center(
          child: _ScanFrame(
            scanlineActive: !isConfirming && !_offlineQueued && !_isValidating,
            lineAnim: _lineAnim,
            detected: _offlineQueued ? null : _detected,
            offlineQueued: _offlineQueued,
            isValidating: _isValidating,
            pillScale: _pillScale,
            pillFade: _pillFade,
            reduceMotion: _reduceMotion,
            strings: s,
          ),
        ),

        // Align hint — only while scanning with nothing detected
        if (!isConfirming && !_offlineQueued)
          PositionedDirectional(
            bottom: 140,
            start: 0,
            end: 0,
            child: Text(
              s.scanAlignHint,
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12,
                color: Colors.white.withAlpha(0xAA),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.strings,
    required this.torchOn,
    required this.isConfirming,
    this.failTracking,
    required this.pendingCount,
    required this.onClose,
    required this.onBack,
    required this.onToggleTorch,
  });

  final AppStrings strings;
  final bool torchOn;
  final bool isConfirming;
  final String? failTracking; // non-null when fail sheet is open
  final int pendingCount;
  final VoidCallback onClose;
  final VoidCallback onBack;
  final VoidCallback onToggleTorch;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withAlpha(0xCC), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left action: ← (confirming) or ✕ (scanning)
              Semantics(
                label: isConfirming ? 'Back' : 'Close',
                button: true,
                child: GestureDetector(
                  onTap: isConfirming ? onBack : onClose,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      isConfirming ? Icons.arrow_back : Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Center title + subtitle — 3 modes
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      failTracking != null
                          ? strings.scanFailTitle
                          : isConfirming
                              ? strings.scanConfirmTitle
                              : strings.scanModeDelivery,
                      style: GoogleFonts.archivo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      failTracking != null
                          ? failTracking!
                          : isConfirming
                              ? strings.scanConfirmSubtitle
                              : strings.scanConfirmRequired,
                      style: GoogleFonts.splineSansMono(
                        fontSize: failTracking != null ? 11 : 10.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9FB4C9),
                      ),
                    ),
                  ],
                ),
              ),
              // Right action: pending badge (confirming/failing) or torch (scanning)
              if ((isConfirming || failTracking != null) && pendingCount > 0)
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: mbBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$pendingCount',
                    style: GoogleFonts.archivo(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                )
              else if (!isConfirming && failTracking == null)
                Semantics(
                  label: 'Toggle torch',
                  button: true,
                  child: GestureDetector(
                    onTap: onToggleTorch,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        torchOn ? Icons.flash_on : Icons.flash_off,
                        color: torchOn ? Colors.yellow : Colors.white,
                        size: 20,
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

// ── Vignette overlay ──────────────────────────────────────────────────────────

class _VignetteOverlay extends StatelessWidget {
  const _VignetteOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              const Color(0xFF222B35).withAlpha(0x28),
              const Color(0xFF141A21).withAlpha(0x99),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Scan frame ────────────────────────────────────────────────────────────────

class _ScanFrame extends StatelessWidget {
  const _ScanFrame({
    required this.scanlineActive,
    required this.lineAnim,
    required this.detected,
    required this.offlineQueued,
    required this.isValidating,
    required this.pillScale,
    required this.pillFade,
    required this.reduceMotion,
    required this.strings,
  });

  final bool scanlineActive;
  final Animation<double> lineAnim;
  final ShipmentModel? detected;
  final bool offlineQueued;
  final bool isValidating;
  final Animation<double> pillScale;
  final Animation<double> pillFade;
  final bool reduceMotion;
  final AppStrings strings;

  static const _size = 198.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // (C) 4 L-shaped corners (dimmed when a pill is showing)
          Opacity(
            opacity: (detected != null || offlineQueued || isValidating) ? 0.4 : 1.0,
            child: CustomPaint(painter: _FramePainter()),
          ),

          // (D) Animated scan line
          if (scanlineActive)
            AnimatedBuilder(
              animation: lineAnim,
              builder: (_, __) {
                final t = reduceMotion ? 0.5 : lineAnim.value;
                final y = t * (_size - 24) + 12;
                return Positioned(
                  left: 12,
                  right: 12,
                  top: y - 1,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: mbRed,
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: [
                        BoxShadow(
                          color: mbRed.withAlpha(0x88),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // Blue validating pill (spinner while API call is in-flight)
          if (isValidating)
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: FadeTransition(
                  opacity: pillFade,
                  child: ScaleTransition(
                    scale: pillScale,
                    child: _ValidatingPill(strings: strings),
                  ),
                ),
              ),
            ),

          // Green detected pill
          if (detected != null)
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: FadeTransition(
                  opacity: pillFade,
                  child: ScaleTransition(
                    scale: pillScale,
                    child: _DetectedPill(
                      tracking: detected!.trackingNumber,
                      strings: strings,
                    ),
                  ),
                ),
              ),
            ),

          // Orange queued pill (replaces green after offline action)
          if (offlineQueued)
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: FadeTransition(
                  opacity: pillFade,
                  child: ScaleTransition(
                    scale: pillScale,
                    child: _QueuedPill(strings: strings),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Frame painter (4 L-corner brackets) ──────────────────────────────────────

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    const arm = 34.0;
    const r = 4.0;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, arm)
        ..lineTo(0, r)
        ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
        ..lineTo(arm, 0),
      p,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(w, arm)
        ..lineTo(w, r)
        ..arcToPoint(Offset(w - r, 0),
            radius: const Radius.circular(r), clockwise: false)
        ..lineTo(w - arm, 0),
      p,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, h - arm)
        ..lineTo(0, h - r)
        ..arcToPoint(Offset(r, h),
            radius: const Radius.circular(r), clockwise: false)
        ..lineTo(arm, h),
      p,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(w, h - arm)
        ..lineTo(w, h - r)
        ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
        ..lineTo(w - arm, h),
      p,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => false;
}

// ── Detected pill ─────────────────────────────────────────────────────────────

class _DetectedPill extends StatelessWidget {
  const _DetectedPill({required this.tracking, required this.strings});

  final String tracking;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: mbOk,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: mbOk.withAlpha(0x66),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, color: Colors.white, size: 17),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tracking,
                style: GoogleFonts.archivo(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                strings.scanDetected,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 11,
                  color: Colors.white.withAlpha(0xCC),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Validating pill (blue spinner) ───────────────────────────────────────────

class _ValidatingPill extends StatelessWidget {
  const _ValidatingPill({required this.strings});
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: mbBlue,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: mbBlue.withAlpha(0x66),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            strings.scanValidating,
            style: GoogleFonts.archivo(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Orange queued pill ────────────────────────────────────────────────────────

class _QueuedPill extends StatelessWidget {
  const _QueuedPill({required this.strings});
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: mbWarn,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: mbWarn.withAlpha(0x66),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sync, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            strings.scanToastQueued,
            style: GoogleFonts.archivo(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Offline banner ────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.strings, required this.pendingCount});
  final AppStrings strings;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: mbWarn,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.flash_on, color: Colors.white, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              strings.scanOfflineBanner,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          if (pendingCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(0x33),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$pendingCount',
                style: GoogleFonts.archivo(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Confirmation sheet ────────────────────────────────────────────────────────

class _ConfirmationSheet extends StatelessWidget {
  const _ConfirmationSheet({
    required this.shipment,
    required this.strings,
    required this.isOffline,
    required this.onDeliver,
    required this.onFail,
    required this.onBack,
  });

  final ShipmentModel shipment;
  final AppStrings strings;
  final bool isOffline;
  final VoidCallback onDeliver;
  final VoidCallback onFail;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final s = strings;
    final known = shipment.id != 0;

    // Build address line without trailing separators
    final addressParts = [
      if (shipment.address.isNotEmpty) shipment.address,
      if (shipment.city.isNotEmpty) shipment.city,
      if ((shipment.governorate ?? '').isNotEmpty) shipment.governorate!,
    ];
    final addressLine = addressParts.join(' · ');

    return Container(
      decoration: const BoxDecoration(
        color: mbSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 32, offset: Offset(0, -6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Grab handle ──────────────────────────────────────────────────────
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: mbLine, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [

                // ── Header row: icon + name/tracking + scan badge ─────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: mbOkBg,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: mbOk, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (known)
                            Text(
                              shipment.recipientName,
                              style: GoogleFonts.archivo(
                                fontSize: 16, fontWeight: FontWeight.w700, color: mbInk,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            Text(
                              s.scanConfirmUnknown,
                              style: GoogleFonts.hankenGrotesk(fontSize: 13, color: mbInk2),
                            ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: mbSurface3,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              shipment.trackingNumber,
                              style: GoogleFonts.splineSansMono(
                                fontSize: 10.5, fontWeight: FontWeight.w600, color: mbInk2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Scan-OK badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: mbOkBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(color: mbOk, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Scan OK',
                            style: GoogleFonts.archivo(
                              fontSize: 11, fontWeight: FontWeight.w700, color: mbOk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Address + phone card ──────────────────────────────────────
                if (known && (addressLine.isNotEmpty || shipment.recipientPhone != null)) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: mbSurface2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (addressLine.isNotEmpty)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(Icons.location_on_outlined, size: 14, color: mbInk3),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  addressLine,
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 13, color: mbInk2, height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (addressLine.isNotEmpty && shipment.recipientPhone != null)
                          const SizedBox(height: 7),
                        if (shipment.recipientPhone != null)
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 14, color: mbInk3),
                              const SizedBox(width: 7),
                              Text(
                                shipment.recipientPhone!,
                                style: GoogleFonts.splineSansMono(
                                  fontSize: 12.5, fontWeight: FontWeight.w500, color: mbInk2,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],

                // ── COD card ──────────────────────────────────────────────────
                if (shipment.hasCod) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: mbPendBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0x33004E95), width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Color(0x22004E95),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.payments_outlined, size: 16, color: mbBlue),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s.scanCodLabel,
                            style: GoogleFonts.archivo(
                              fontSize: 10.5, fontWeight: FontWeight.w700,
                              letterSpacing: 0.4, color: mbBlue,
                            ),
                          ),
                        ),
                        Text(
                          '${shipment.codAmount!.toStringAsFixed(0)} TND',
                          style: GoogleFonts.archivo(
                            fontSize: 22, fontWeight: FontWeight.w800, color: mbBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Offline warning ───────────────────────────────────────────
                if (isOffline) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: mbWarnBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.sync_rounded, color: mbWarn, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.scanOfflineWarning,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12, color: mbWarn, height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Primary: Livré ────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: onDeliver,
                    style: FilledButton.styleFrom(
                      backgroundColor: mbOk,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      s.scanDelivered,
                      style: GoogleFonts.archivo(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 9),

                // ── Secondary: Échec + Retour ─────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: onFail,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: mbErr,
                            side: const BorderSide(color: mbErr, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: Text(
                            s.scanFailed,
                            style: GoogleFonts.archivo(fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 46,
                        child: TextButton.icon(
                          onPressed: onBack,
                          style: TextButton.styleFrom(
                            foregroundColor: mbInk2,
                            backgroundColor: mbSurface3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: Text(
                            s.scanBack,
                            style: GoogleFonts.archivo(fontSize: 13.5, fontWeight: FontWeight.w700),
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
    );
  }
}

// ── Confirm delivery sheet (online · Image #19) ───────────────────────────────

class _ConfirmDeliverySheet extends StatefulWidget {
  const _ConfirmDeliverySheet({
    required this.shipment,
    required this.strings,
    required this.onConfirm,
    required this.onCancel,
  });

  final ShipmentModel shipment;
  final AppStrings strings;
  final void Function(double codAmount) onConfirm;
  final VoidCallback onCancel;

  @override
  State<_ConfirmDeliverySheet> createState() => _ConfirmDeliverySheetState();
}

class _ConfirmDeliverySheetState extends State<_ConfirmDeliverySheet> {
  late final TextEditingController _codCtrl;

  @override
  void initState() {
    super.initState();
    final cod = widget.shipment.codAmount;
    _codCtrl = TextEditingController(
      text: cod != null && cod > 0 ? cod.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _codCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final shipment = widget.shipment;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: mbSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 18 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: mbLine,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header: thumbnail + name/address + "Livré" badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: mbSurface3,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: mbInk3,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shipment.recipientName,
                        style: GoogleFonts.archivo(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: mbInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shipment.governorate != null
                            ? '${shipment.address} · ${shipment.city}, ${shipment.governorate}'
                            : '${shipment.address} · ${shipment.city}',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 11.5,
                          color: mbInk2,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // "● Livré" status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: mbOkBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: mbOk,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        s.scanDelivered,
                        style: GoogleFonts.archivo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: mbOk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Tracking chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: mbSurface3,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                shipment.trackingNumber,
                style: GoogleFonts.splineSansMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: mbInk2,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // COD amount input (only if hasCod)
            if (shipment.hasCod) ...[
              Text(
                s.scanCodCollected,
                style: GoogleFonts.archivo(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.33,
                  color: mbBlue,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _codCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.archivo(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: mbBlue,
                ),
                decoration: InputDecoration(
                  suffixText: 'TND',
                  suffixStyle: GoogleFonts.archivo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: mbBlue,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: mbLine, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: mbBlue, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 4),

            // "✓ Confirmer la livraison" green button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () {
                  final amount =
                      double.tryParse(_codCtrl.text.trim()) ?? 0;
                  widget.onConfirm(amount);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: mbOk,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: Text(
                  s.scanConfirmDelivery,
                  style: GoogleFonts.archivo(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // "Annuler" outlined button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: widget.onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: mbInk,
                  side: const BorderSide(color: mbLine, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  s.scanCancel,
                  style: GoogleFonts.archivo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: mbInk,
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

// ── Fail reason sheet (Image #21) ─────────────────────────────────────────────

class _FailReasonSheet extends StatefulWidget {
  const _FailReasonSheet({
    required this.shipment,
    required this.strings,
  });
  final ShipmentModel shipment;
  final AppStrings strings;

  @override
  State<_FailReasonSheet> createState() => _FailReasonSheetState();
}

class _FailReasonSheetState extends State<_FailReasonSheet> {
  String? _selected;
  late final TextEditingController _commentCtrl;

  @override
  void initState() {
    super.initState();
    _commentCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final shipment = widget.shipment;
    final bottom = MediaQuery.paddingOf(context).bottom;

    // Image #21 reason order: absent, refused, wrong address, unreachable, rescheduled
    final reasons = [
      (s.scanReasonAbsent,      'absent'),
      (s.scanReasonRefused,     'refused'),
      (s.scanReasonWrongAddress,'wrong_address'),
      (s.scanReasonUnreachable, 'unreachable'),
      (s.scanReasonRescheduled, 'rescheduled'),
    ];

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: const BoxDecoration(
          color: mbSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Color(0x28000000),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 18 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: mbLine,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Shipment header: thumbnail + name + "Échec" badge + address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: mbSurface3,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: mbInk3,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          shipment.recipientName,
                          style: GoogleFonts.archivo(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: mbInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${shipment.address} · ${shipment.city}',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 11.5,
                            color: mbInk2,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // "● Échec" red status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: mbErrBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: mbErr,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          s.scanFailed,
                          style: GoogleFonts.archivo(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: mbErr,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // "RAISON DE L'ÉCHEC" section label
              Text(
                s.scanReasonTitle,
                style: GoogleFonts.archivo(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: mbInk3,
                ),
              ),
              const SizedBox(height: 8),

              // Reason tiles — card style with border
              ...reasons.map((r) => _ReasonTile(
                    label: r.$1,
                    value: r.$2,
                    selected: _selected == r.$2,
                    onTap: () => setState(() => _selected = r.$2),
                  )),

              const SizedBox(height: 16),

              // "COMMENTAIRE (OPTIONNEL)" section label
              Text(
                s.scanReasonComment,
                style: GoogleFonts.archivo(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: mbInk3,
                ),
              ),
              const SizedBox(height: 8),

              // Comment field
              TextField(
                controller: _commentCtrl,
                maxLines: 3,
                minLines: 2,
                style: GoogleFonts.hankenGrotesk(
                    fontSize: 13.5, color: mbInk),
                decoration: InputDecoration(
                  hintText: s.scanReasonCommentHint,
                  hintStyle: GoogleFonts.hankenGrotesk(
                      fontSize: 13.5, color: mbInk3),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: mbLine, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: mbBlue, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),

              const SizedBox(height: 16),

              // "✕ Confirmer l'échec" red confirm button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _selected != null
                      ? () {
                          final comment =
                              _commentCtrl.text.trim().isEmpty
                                  ? null
                                  : _commentCtrl.text.trim();
                          Navigator.of(context).pop(
                            (reason: _selected!, comment: comment),
                          );
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: mbRed,
                    disabledBackgroundColor: mbLine2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.close, size: 18,
                      color: Colors.white),
                  label: Text(
                    s.scanConfirmFail,
                    style: GoogleFonts.archivo(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

// ── Reason tile — card style with animated border (Image #21) ─────────────────

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? mbErrBg : mbSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? mbRed : mbLine,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? mbRed : Colors.transparent,
                border: selected
                    ? null
                    : Border.all(color: mbLine, width: 1.5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 14,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color: mbInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Permission view ───────────────────────────────────────────────────────────

class _PermissionView extends StatelessWidget {
  const _PermissionView({required this.strings});
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, color: mbInk3, size: 56),
              const SizedBox(height: 24),
              Text(
                strings.scanPermTitle,
                style: GoogleFonts.archivo(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: openAppSettings,
                style: FilledButton.styleFrom(
                  backgroundColor: mbBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11)),
                ),
                child: Text(
                  strings.scanPermCta,
                  style: GoogleFonts.archivo(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
