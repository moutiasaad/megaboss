import 'package:audioplayers/audioplayers.dart';

/// Short audible beeps played alongside haptic feedback during barcode scans.
///
/// Success: short crisp high beep (~90 ms @ 2300 Hz).
/// Error:   double low-pulse beep (~260 ms @ 350 Hz).
class ScanBeepService {
  ScanBeepService._();
  static final ScanBeepService instance = ScanBeepService._();

  final AudioPlayer _success = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _error = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  static const _successAsset = 'sounds/scan_success.wav';
  static const _errorAsset = 'sounds/scan_error.wav';

  Future<void> playSuccess() async {
    await _success.stop();
    await _success.play(AssetSource(_successAsset), volume: 1.0);
  }

  Future<void> playError() async {
    await _error.stop();
    await _error.play(AssetSource(_errorAsset), volume: 1.0);
  }

  Future<void> dispose() async {
    await _success.dispose();
    await _error.dispose();
  }
}
