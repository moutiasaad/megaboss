import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';

import 'core/network/offline_queue.dart';
import 'core/network/providers.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/calls/domain/repositories/call_repository.dart';
import 'features/notifications/domain/repositories/notification_repository.dart';
import 'features/pickup/domain/repositories/pickup_repository.dart';
import 'features/runsheets/domain/repositories/runsheet_repository.dart';
import 'features/shipments/domain/repositories/shipment_repository.dart';
import 'features/stats/domain/repositories/stats_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();

  // Open all Hive boxes in parallel — record .wait preserves each return type.
  final (
    _,
    driverBox,
    runsheetBox,
    shipmentBox,
    pickupBox,
    callBox,
    notifBox,
    statsBox,
    offlineQueue,
  ) = await (
    Hive.openBox<String>(kLocaleBoxName),
    AuthRepository.openBox(),
    RunsheetRepository.openBox(),
    ShipmentRepository.openBox(),
    PickupRepository.openBox(),
    CallRepository.openBox(),
    NotificationRepository.openBox(),
    StatsRepository.openBox(),
    OfflineQueue.open(),
  ).wait;

  runApp(
    ProviderScope(
      overrides: [
        driverBoxProvider.overrideWithValue(driverBox),
        runsheetBoxProvider.overrideWithValue(runsheetBox),
        shipmentBoxProvider.overrideWithValue(shipmentBox),
        pickupBoxProvider.overrideWithValue(pickupBox),
        callBoxProvider.overrideWithValue(callBox),
        notificationBoxProvider.overrideWithValue(notifBox),
        statsBoxProvider.overrideWithValue(statsBox),
        offlineQueueProvider.overrideWithValue(offlineQueue),
      ],
      child: const MegaBossApp(),
    ),
  );
}

class MegaBossApp extends ConsumerWidget {
  const MegaBossApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'MegaBoss',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
