import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../sale_points/presentation/state/active_sale_point_controller.dart';
import '../../domain/entities/winning_ticket.dart';
import '../../domain/repositories/results_repository.dart';

class WinnersFilters {
  const WinnersFilters({
    this.from,
    this.to,
    this.gameId,
    this.drawTime,
  });

  final DateTime? from;
  final DateTime? to;
  /// Filtro por juego (null = todos).
  final String? gameId;
  /// Filtro por hora de sorteo "HH:MM" (null = todos).
  final String? drawTime;

  WinnersFilters copyWith({
    DateTime? from,
    DateTime? to,
    Object? gameId = _sentinel,
    Object? drawTime = _sentinel,
  }) {
    return WinnersFilters(
      from: from ?? this.from,
      to: to ?? this.to,
      gameId: identical(gameId, _sentinel) ? this.gameId : gameId as String?,
      drawTime:
          identical(drawTime, _sentinel) ? this.drawTime : drawTime as String?,
    );
  }
}

const Object _sentinel = Object();

class WinnersFiltersNotifier extends Notifier<WinnersFilters> {
  @override
  WinnersFilters build() {
    final now = DateTime.now();
    return WinnersFilters(
      from: DateTime(now.year, now.month, now.day),
      to: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  void set({DateTime? from, DateTime? to}) {
    state = WinnersFilters(
      from: from,
      to: to,
      gameId: state.gameId,
      drawTime: state.drawTime,
    );
  }

  void setGame(String? gameId) {
    // Al cambiar de juego reseteamos drawTime porque las horas de
    // sorteo dependen del juego elegido.
    state = state.copyWith(gameId: gameId, drawTime: null);
  }

  void setDrawTime(String? drawTime) {
    state = state.copyWith(drawTime: drawTime);
  }
}

final winnersFiltersProvider =
    NotifierProvider<WinnersFiltersNotifier, WinnersFilters>(
  WinnersFiltersNotifier.new,
);

class WinnersController extends AsyncNotifier<List<WinningTicket>> {
  late final _repository = getIt<ResultsRepository>();

  @override
  Future<List<WinningTicket>> build() async {
    ref.listen(winnersFiltersProvider, (previous, next) {
      if (previous != next) refresh();
    });
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<List<WinningTicket>> _fetch() async {
    final salePoint = ref.read(activeSalePointProvider).selected;
    if (salePoint == null) return const [];
    final filters = ref.read(winnersFiltersProvider);

    final result = await _repository.listWinners(
      ListWinnersQuery(
        salePointId: salePoint.id,
        from: filters.from,
        to: filters.to,
        gameId: filters.gameId,
        drawTime: filters.drawTime,
      ),
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (items) => items,
    );
  }
}

final winnersControllerProvider =
    AsyncNotifierProvider<WinnersController, List<WinningTicket>>(
  WinnersController.new,
);
