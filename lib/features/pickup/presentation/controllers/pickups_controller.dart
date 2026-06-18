import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/pickup_model.dart';
import '../../../../core/network/providers.dart';

// ── Display status derived from API data ───────────────────────────────────────

enum ManifestStatus { inProgress, upcoming, done }

extension PickupDisplayStatus on PickupModel {
  ManifestStatus get displayStatus {
    // Stats-first: most reliable
    if (totalShipments > 0 && collectedCount >= totalShipments) {
      return ManifestStatus.done;
    }
    final s = status.toLowerCase();
    if (s == 'completed' || s == 'closed' || s == 'done' || s == 'collected') {
      return ManifestStatus.done;
    }
    if (collectedCount > 0) return ManifestStatus.inProgress;
    if (s == 'in_progress' || s == 'started' || s == 'validated' ||
        s == 'active' || s == 'ongoing') {
      return ManifestStatus.inProgress;
    }
    return ManifestStatus.upcoming;
  }

  // null = hide the bar (upcoming)
  double? get progressFraction {
    if (displayStatus == ManifestStatus.upcoming) return null;
    if (totalShipments == 0) return null;
    return (collectedCount / totalShipments).clamp(0.0, 1.0);
  }

  String get location => senderAddress ?? '';
}

// ── State ─────────────────────────────────────────────────────────────────────

class PickupsState {
  const PickupsState({
    required this.filter,
    required this.allItems,
    this.offline = false,
  });

  final String filter; // '' = Tous
  final List<PickupModel> allItems;
  final bool offline;

  List<PickupModel> get filtered => filter.isEmpty
      ? allItems
      : allItems.where((p) => p.senderName == filter).toList();

  List<String> get senders {
    final seen = <String>{};
    return allItems.map((p) => p.senderName).where(seen.add).toList();
  }

  PickupsState copyWith({
    String? filter,
    List<PickupModel>? allItems,
    bool? offline,
  }) =>
      PickupsState(
        filter: filter ?? this.filter,
        allItems: allItems ?? this.allItems,
        offline: offline ?? this.offline,
      );
}

// ── Controller ────────────────────────────────────────────────────────────────

class PickupsController extends AsyncNotifier<PickupsState> {
  @override
  Future<PickupsState> build() async {
    final repo = ref.read(pickupRepositoryProvider);
    final cached = repo.cachedActive;
    if (cached.isNotEmpty) {
      Future.microtask(_backgroundRefresh);
      return PickupsState(filter: '', allItems: _sorted(cached), offline: false);
    }
    final items = await repo.getActive();
    return PickupsState(filter: '', allItems: _sorted(items));
  }

  Future<void> _backgroundRefresh() async {
    try {
      final items = await ref.read(pickupRepositoryProvider).getActive();
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(current.copyWith(
          allItems: _sorted(items),
          offline: false,
        ));
      }
    } catch (_) {
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(current.copyWith(offline: true));
      }
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final items = await ref.read(pickupRepositoryProvider).getActive();
      return PickupsState(filter: '', allItems: _sorted(items));
    });
  }

  void setFilter(String sender) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(filter: sender));
  }

  List<PickupModel> _sorted(List<PickupModel> items) {
    const order = {
      ManifestStatus.inProgress: 0,
      ManifestStatus.upcoming: 1,
      ManifestStatus.done: 2,
    };
    return [...items]..sort(
        (a, b) => (order[a.displayStatus] ?? 1).compareTo(order[b.displayStatus] ?? 1),
      );
  }
}

final pickupsProvider =
    AsyncNotifierProvider<PickupsController, PickupsState>(PickupsController.new);
