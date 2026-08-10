import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../sale_points/presentation/state/active_sale_point_controller.dart';
import '../../domain/entities/winning_ticket.dart';
import '../../domain/repositories/results_repository.dart';

class WinnersFilters {
  const WinnersFilters({this.from, this.to});

  final DateTime? from;
  final DateTime? to;
}

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
    state = WinnersFilters(from: from, to: to);
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
