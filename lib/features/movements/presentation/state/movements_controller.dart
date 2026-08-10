import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../sale_points/presentation/state/active_sale_point_controller.dart';
import '../../../tickets/domain/entities/tickets_summary.dart';
import '../../../tickets/domain/repositories/tickets_repository.dart';
import '../../domain/entities/movements_summary.dart';

class MovementsFilters extends Equatable {
  const MovementsFilters({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  @override
  List<Object?> get props => [from, to];
}

class MovementsFiltersNotifier extends Notifier<MovementsFilters> {
  @override
  MovementsFilters build() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return MovementsFilters(from: today, to: endOfDay);
  }

  void setRange(DateTime from, DateTime to) {
    state = MovementsFilters(from: from, to: to);
  }
}

final movementsFiltersProvider = NotifierProvider<
    MovementsFiltersNotifier, MovementsFilters>(
  MovementsFiltersNotifier.new,
);

class MovementsController extends AsyncNotifier<MovementsSummary> {
  late final _tickets = getIt<TicketsRepository>();

  @override
  Future<MovementsSummary> build() async {
    ref.listen(movementsFiltersProvider, (previous, next) {
      if (previous != next) refresh();
    });
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<MovementsSummary> _fetch() async {
    final salePoint = ref.read(activeSalePointProvider).selected;
    if (salePoint == null) return MovementsSummary.empty;
    final filters = ref.read(movementsFiltersProvider);

    // Single aggregate call — the server sums `total` and `paid_prize` in
    // one query, so a busy puesto no longer bumps into pagination limits.
    final result = await _tickets.summary(TicketsSummaryQuery(
      salePointId: salePoint.id,
      from: filters.from,
      to: filters.to,
    ));
    return result.fold(
      (failure) => throw Exception(failure.message),
      (s) => MovementsSummary(
        billed: s.billed,
        // For now: collected == billed (no separate credit tracking yet).
        collected: s.billed,
        wonPrize: s.wonPrize,
        // Expenses will come from a future module; leave as 0.
        expenses: 0,
        // Server-computed commission. Falls back to 0 when the seller has
        // no `paymentPercentage` configured yet.
        salary: s.salary ?? 0,
      ),
    );
  }
}

final movementsControllerProvider = AsyncNotifierProvider<
    MovementsController, MovementsSummary>(MovementsController.new);
