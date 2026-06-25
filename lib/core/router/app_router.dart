import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/calls/presentation/screens/calls_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/pickup/presentation/screens/pickup_detail_screen.dart';
import '../../features/pickup/presentation/screens/pickups_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/runsheets/presentation/screens/runsheet_detail_screen.dart';
import '../../features/runsheets/presentation/screens/runsheets_screen.dart';
import '../../features/scan/presentation/screens/pickup_scan_screen.dart';
import '../../features/scan/presentation/screens/scan_delivery_screen.dart';
import '../../features/shipments/presentation/screens/shipment_detail_screen.dart';
import '../../features/stats/presentation/screens/stats_screen.dart';
import '../i18n/app_strings.dart';
import '../providers/locale_provider.dart';
import '../theme/colors.dart';
import '../widgets/mb_tab_bar.dart';

// ── Router provider ────────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => SplashScreen(
          onNavigate: (destination) {
            if (destination == 'dashboard') {
              context.go('/dashboard');
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          onSuccess: () => context.go('/dashboard'),
        ),
      ),

      // ── Shell with tab bar (5 branches) ─────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) {
          return _MainShell(shell: shell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, __) => const DashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'calls',
                    builder: (_, __) => const CallsScreen(),
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (_, __) => const NotificationsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/runsheets',
                builder: (_, __) => const RunsheetsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (_, __) => const _RunsheetNewStub(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) {
                      final id = int.tryParse(
                            state.pathParameters['id'] ?? '',
                          ) ??
                          0;
                      return RunsheetDetailScreen(id: id);
                    },
                    routes: [
                      GoRoute(
                        path: 'map',
                        builder: (_, state) {
                          final id = int.tryParse(
                                state.pathParameters['id'] ?? '',
                              ) ??
                              0;
                          return _MapStub(id: id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pickups',
                builder: (_, __) => const PickupsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) {
                      final id = int.tryParse(
                            state.pathParameters['id'] ?? '',
                          ) ??
                          0;
                      return PickupDetailScreen(id: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (_, __) => const StatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, __) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Full-screen routes (no tab bar) ──────────────────────────────────
      GoRoute(
        path: '/scan/delivery',
        builder: (_, state) {
          final runsheetId =
              int.tryParse(state.uri.queryParameters['runsheetId'] ?? '');
          final shipmentId =
              int.tryParse(state.uri.queryParameters['shipmentId'] ?? '');
          return ScanDeliveryScreen(
            runsheetId: runsheetId,
            shipmentId: shipmentId,
          );
        },
      ),
      GoRoute(
        path: '/scan/pickup',
        builder: (_, state) {
          final manifestId =
              int.tryParse(state.uri.queryParameters['manifest'] ?? '') ?? 0;
          return PickupScanScreen(manifestId: manifestId);
        },
      ),
      GoRoute(
        path: '/shipments/:id',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return ShipmentDetailScreen(id: id);
        },
      ),
    ],
  );
});

// ── Main shell (persistent scaffold with tab bar + FAB) ───────────────────────

class _MainShell extends ConsumerWidget {
  const _MainShell({required this.shell});
  final StatefulNavigationShell shell;

  void _onTabTap(BuildContext context, int index) {
    shell.goBranch(
      index,
      initialLocation: index == shell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final locale = widgetRef.watch(localeProvider);
    final s = AppStrings.of(locale.languageCode);

    return Scaffold(
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? mbDarkBg
              : mbSurface2,
      body: shell,
      bottomNavigationBar: MbTabBar(
        currentIndex: shell.currentIndex,
        onTap: (i) => _onTabTap(context, i),
        items: [
          MbTab(icon: MbTabIcon.home,       label: s.tabHome),
          MbTab(icon: MbTabIcon.runsheets,  label: s.tabRunsheets),
          MbTab(icon: MbTabIcon.pickup,     label: s.tabPickup),
          MbTab(icon: MbTabIcon.stats,      label: s.tabStats),
          MbTab(icon: MbTabIcon.profile,    label: s.tabProfile),
        ],
      ),
    );
  }
}

// ── Placeholder stubs for future screens ──────────────────────────────────────

class _RunsheetNewStub extends StatelessWidget {
  const _RunsheetNewStub();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un runsheet')),
      body: const Center(child: Text('Création runsheet — à venir')),
    );
  }
}

class _MapStub extends StatelessWidget {
  const _MapStub({required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Carte · Runsheet #$id')),
      body: const Center(child: Text('Carte — à venir')),
    );
  }
}

