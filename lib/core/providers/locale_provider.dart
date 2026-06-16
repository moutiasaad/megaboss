import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const kLocaleBoxName = 'mb_locale';
const _kLocaleKey = 'locale';

// Locale state — persisted in Hive, restored on cold start.
// Controls both the MaterialApp locale (RTL) and AppStrings lookup.
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    // Hive box opened in main() before runApp().
    final box = Hive.box<String>(kLocaleBoxName);
    final saved = box.get(_kLocaleKey);
    return Locale(saved ?? 'fr');
  }

  Future<void> setLocale(String languageCode) async {
    state = Locale(languageCode);
    await Hive.box<String>(kLocaleBoxName).put(_kLocaleKey, languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

// Supported locales for the whole app.
const kSupportedLocales = [Locale('fr'), Locale('ar'), Locale('en')];
