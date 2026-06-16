import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'locale_provider.dart'; // re-uses the same Hive box

const _kThemeModeKey = 'theme_mode';
const _kPushEnabledKey = 'push_enabled';

// ── Theme mode ─────────────────────────────────────────────────────────────────

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final box = Hive.box<String>(kLocaleBoxName);
    final saved = box.get(_kThemeModeKey);
    return switch (saved) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final value = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    };
    await Hive.box<String>(kLocaleBoxName).put(_kThemeModeKey, value);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// ── Push notifications enabled ─────────────────────────────────────────────────

class PushEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = Hive.box<String>(kLocaleBoxName);
    final saved = box.get(_kPushEnabledKey);
    return saved != 'false'; // default ON
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await Hive.box<String>(kLocaleBoxName).put(_kPushEnabledKey, enabled ? 'true' : 'false');
  }
}

final pushEnabledProvider = NotifierProvider<PushEnabledNotifier, bool>(
  PushEnabledNotifier.new,
);
