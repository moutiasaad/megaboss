import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/call_entry.dart';
import '../../../../core/network/providers.dart';

class CallsHistoryController extends AsyncNotifier<CallsState> {
  @override
  Future<CallsState> build() => _load(CallFilter.all);

  Future<CallsState> _load(CallFilter filter) async {
    final repo = ref.read(callRepositoryProvider);
    final cached = repo.cachedHistory(filter.apiValue);

    if (cached.isNotEmpty) {
      // Return cache immediately; refresh in background.
      Future.microtask(() async {
        try {
          final fresh = await repo.fetchHistory(filter: filter.apiValue);
          if (state case AsyncData(:final value)) {
            if (value.filter == filter) {
              state = AsyncData(value.copyWith(items: fresh, offline: false));
            }
          }
        } catch (_) {}
      });
      return CallsState(filter: filter, items: cached, offline: true);
    }

    final items = await repo.fetchHistory(filter: filter.apiValue);
    return CallsState(filter: filter, items: items);
  }

  Future<void> setFilter(CallFilter filter) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(filter));
  }

  Future<void> refresh() async {
    final current = state.valueOrNull?.filter ?? CallFilter.all;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final items = await ref
          .read(callRepositoryProvider)
          .fetchHistory(filter: current.apiValue);
      return CallsState(filter: current, items: items);
    });
  }
}

final callsHistoryProvider =
    AsyncNotifierProvider<CallsHistoryController, CallsState>(
  CallsHistoryController.new,
);
