import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/network/api_exception.dart';

// ── Login form state ───────────────────────────────────────────────────────────

enum LoginStatus { idle, loading, error, cooldown }

enum LoginErrorType { none, credentials, network, server }

class LoginState {
  const LoginState({
    this.status = LoginStatus.idle,
    this.errorType = LoginErrorType.none,
    this.failCount = 0,
    this.cooldownSecondsLeft = 0,
  });

  final LoginStatus status;
  final LoginErrorType errorType;
  final int failCount;
  final int cooldownSecondsLeft;

  bool get isLoading => status == LoginStatus.loading;
  bool get hasError => status == LoginStatus.error;
  bool get isCooldown => cooldownSecondsLeft > 0;

  // Button is interactive when not loading and not in cooldown.
  bool get canSubmit => !isLoading && !isCooldown;

  LoginState copyWith({
    LoginStatus? status,
    LoginErrorType? errorType,
    int? failCount,
    int? cooldownSecondsLeft,
  }) =>
      LoginState(
        status: status ?? this.status,
        errorType: errorType ?? this.errorType,
        failCount: failCount ?? this.failCount,
        cooldownSecondsLeft: cooldownSecondsLeft ?? this.cooldownSecondsLeft,
      );
}

// ── Controller ─────────────────────────────────────────────────────────────────

class LoginController extends Notifier<LoginState> {
  Timer? _cooldownTimer;

  static const _maxAttempts = 5;
  static const _cooldownSeconds = 30;

  @override
  LoginState build() {
    ref.onDispose(() => _cooldownTimer?.cancel());
    return const LoginState();
  }

  // Clear error banner as soon as the user starts editing a field.
  void clearError() {
    if (state.hasError) {
      state = state.copyWith(
        status: LoginStatus.idle,
        errorType: LoginErrorType.none,
      );
    }
  }

  // Main submit action — called from the form's onPressed / onFieldSubmitted.
  // Returns true on success; caller is responsible for navigation.
  Future<bool> submit({
    required String email,
    required String password,
  }) async {
    if (!state.canSubmit) return false;

    state = state.copyWith(status: LoginStatus.loading);

    try {
      debugPrint('[LoginController] calling repository.login email=$email');
      await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
            deviceName: 'MegaBoss-Driver',
          );
      debugPrint('[LoginController] login success');

      ref.read(syncPushServiceProvider).start();
      // Fire-and-forget — never blocks the user. The service is idempotent
      // and self-subscribes to onTokenRefresh.
      unawaited(ref.read(fcmRegistrationServiceProvider).register());
      state = const LoginState();
      return true;
    } on UnauthorizedException catch (e) {
      debugPrint('[LoginController] UnauthorizedException: $e');
      _handleFailure(LoginErrorType.credentials);
    } on NetworkException catch (e) {
      debugPrint('[LoginController] NetworkException: $e');
      _handleFailure(LoginErrorType.network);
    } on ApiException catch (e) {
      debugPrint('[LoginController] ApiException: $e');
      _handleFailure(LoginErrorType.server);
    } catch (e, st) {
      debugPrint('[LoginController] unexpected error: $e\n$st');
      _handleFailure(LoginErrorType.server);
    }
    return false;
  }

  void _handleFailure(LoginErrorType errorType) {
    HapticFeedback.mediumImpact();
    final newFail = state.failCount + 1;

    if (newFail >= _maxAttempts) {
      _startCooldown(newFail, errorType);
    } else {
      state = state.copyWith(
        status: LoginStatus.error,
        errorType: errorType,
        failCount: newFail,
      );
    }
  }

  void _startCooldown(int failCount, LoginErrorType errorType) {
    _cooldownTimer?.cancel();

    state = state.copyWith(
      status: LoginStatus.cooldown,
      errorType: errorType,
      failCount: failCount,
      cooldownSecondsLeft: _cooldownSeconds,
    );

    _cooldownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.cooldownSecondsLeft - 1;
      if (remaining <= 0) {
        timer.cancel();
        // After cooldown: reset fail count so the driver can try again cleanly.
        state = LoginState(
          status: LoginStatus.error,
          errorType: state.errorType,
          failCount: 0,
        );
      } else {
        state = state.copyWith(cooldownSecondsLeft: remaining);
      }
    });
  }
}

final loginControllerProvider =
    NotifierProvider<LoginController, LoginState>(LoginController.new);

// Version string — read once at startup. Used by the login screen footer.
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  } catch (_) {
    return '1.0.0';
  }
});
