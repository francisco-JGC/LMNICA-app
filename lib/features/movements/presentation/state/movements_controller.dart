import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../sale_points/presentation/state/active_sale_point_controller.dart';
import '../../../tickets/domain/entities/tickets_summary.dart';
import '../../../tickets/domain/repositories/tickets_repository.dart';
import '../../domain/entities/movements_summary.dart';
import '../../domain/repositories/movements_repository.dart';

class MovementsFilters extends Equatable {
  const MovementsFilters({
    required this.from,
    required this.to,
    this.historyType,
  });

  final DateTime from;
  final DateTime to;
  /// null = todos los tipos
  final String? historyType;

  @override
  List<Object?> get props => [from, to, historyType];
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
    state = MovementsFilters(from: from, to: to, historyType: state.historyType);
  }

  void setHistoryType(String? type) {
    state = MovementsFilters(from: state.from, to: state.to, historyType: type);
  }
}

final movementsFiltersProvider = NotifierProvider<
    MovementsFiltersNotifier, MovementsFilters>(
  MovementsFiltersNotifier.new,
);

class MovementsController extends AsyncNotifier<MovementsSummary> {
  late final _tickets = getIt<TicketsRepository>();
  late final _movements = getIt<MovementsRepository>();

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

    final ticketsResult = await _tickets.summary(TicketsSummaryQuery(
      salePointId: salePoint.id,
      from: filters.from,
      to: filters.to,
    ));

    final balanceResult = await _movements.sellerBalance(SellerBalanceQuery(
      salePointId: salePoint.id,
      from: filters.from,
      to: filters.to,
    ));

    final ticketsSummary = ticketsResult.fold(
      (failure) => throw Exception(failure.message),
      (s) => s,
    );

    final balance = balanceResult.getOrElse(
      (_) => (cobros: 0, credits: 0, prizePayments: 0),
    );

    return MovementsSummary(
      billed: ticketsSummary.billed,
      wonPrize: ticketsSummary.wonPrize,
      salary: ticketsSummary.salary ?? 0,
      cobros: balance.cobros,
      credits: balance.credits,
      prizePayments: balance.prizePayments,
    );
  }
}

final movementsControllerProvider = AsyncNotifierProvider<
    MovementsController, MovementsSummary>(MovementsController.new);

// ---------------------------------------------------------------------------
// Historial de movimientos
// ---------------------------------------------------------------------------

class MovementsHistoryController
    extends AsyncNotifier<MovementsList> {
  late final _repo = getIt<MovementsRepository>();

  @override
  Future<MovementsList> build() {
    ref.listen(movementsFiltersProvider, (previous, next) {
      if (previous != next) refresh();
    });
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<MovementsList> _fetch() async {
    final salePoint = ref.read(activeSalePointProvider).selected;
    if (salePoint == null) return (items: const <MovementItem>[], total: 0);
    final filters = ref.read(movementsFiltersProvider);

    final result = await _repo.listMovements(ListMovementsQuery(
      salePointId: salePoint.id,
      type: filters.historyType,
      from: filters.from,
      to: filters.to,
    ));

    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  }
}

final movementsHistoryProvider =
    AsyncNotifierProvider<MovementsHistoryController, MovementsList>(
  MovementsHistoryController.new,
);
