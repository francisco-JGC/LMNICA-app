import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/draw_result.dart';
import '../../domain/repositories/results_repository.dart';

class LatestResultsFilters extends Equatable {
  const LatestResultsFilters({
    this.gameId,
    this.from,
    this.to,
  });

  final String? gameId;
  final DateTime? from;
  final DateTime? to;

  bool get hasAny => gameId != null || from != null || to != null;

  @override
  List<Object?> get props => [gameId, from, to];
}

class LatestResultsFiltersNotifier extends Notifier<LatestResultsFilters> {
  @override
  LatestResultsFilters build() {
    final now = DateTime.now();
    return LatestResultsFilters(
      from: DateTime(now.year, now.month, now.day),
      to: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  void update({
    String? gameId,
    DateTime? from,
    DateTime? to,
    bool clearGame = false,
  }) {
    state = LatestResultsFilters(
      gameId: clearGame ? null : (gameId ?? state.gameId),
      from: from ?? state.from,
      to: to ?? state.to,
    );
  }

  void clear() => state = const LatestResultsFilters();
}

final latestResultsFiltersProvider = NotifierProvider<
    LatestResultsFiltersNotifier, LatestResultsFilters>(
  LatestResultsFiltersNotifier.new,
);

class LatestResultsController extends AsyncNotifier<List<DrawResult>> {
  late final _repository = getIt<ResultsRepository>();

  @override
  Future<List<DrawResult>> build() async {
    ref.listen(latestResultsFiltersProvider, (previous, next) {
      if (previous != next) refresh();
    });
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<List<DrawResult>> _fetch() async {
    final filters = ref.read(latestResultsFiltersProvider);
    final result = await _repository.listResults(
      ListDrawResultsQuery(
        gameId: filters.gameId,
        from: filters.from,
        to: filters.to,
        limit: 200,
      ),
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (items) => items..sort((a, b) => a.drawAt.compareTo(b.drawAt)),
    );
  }
}

final latestResultsControllerProvider = AsyncNotifierProvider<
    LatestResultsController, List<DrawResult>>(LatestResultsController.new);
