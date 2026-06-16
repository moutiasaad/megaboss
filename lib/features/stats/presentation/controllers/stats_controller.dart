import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/stats_model.dart';
import '../../../../core/network/providers.dart';

// Stats period parameter (period + optional date range for custom).
class StatsParams {
  const StatsParams({
    this.period = StatsPeriod.today,
    this.from,
    this.to,
  });

  final String period;
  final String? from; // ISO date — required when period=custom
  final String? to;

  @override
  bool operator ==(Object other) =>
      other is StatsParams &&
      other.period == period &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(period, from, to);
}

class StatsController
    extends AutoDisposeFamilyAsyncNotifier<StatsModel, StatsParams> {
  @override
  Future<StatsModel> build(StatsParams params) async {
    final repo = ref.watch(statsRepositoryProvider);

    // Return cached data immediately while refreshing.
    final cached = repo.cached(params.period);
    if (cached != null) {
      Future.microtask(() async {
        try {
          final fresh = await repo.get(
            period: params.period,
            from: params.from,
            to: params.to,
          );
          state = AsyncData(fresh);
        } catch (_) {}
      });
      return cached;
    }

    return repo.get(
      period: params.period,
      from: params.from,
      to: params.to,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(statsRepositoryProvider).get(
            period: arg.period,
            from: arg.from,
            to: arg.to,
          ),
    );
  }
}

final statsProvider = AsyncNotifierProvider.autoDispose
    .family<StatsController, StatsModel, StatsParams>(
  StatsController.new,
);

// Quick accessor for today's stats — used on the Dashboard card.
final todayStatsProvider = Provider.autoDispose<AsyncValue<StatsModel>>((ref) {
  return ref.watch(statsProvider(const StatsParams(period: StatsPeriod.today)));
});
