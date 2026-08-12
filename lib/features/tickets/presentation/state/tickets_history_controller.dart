import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../sale_points/presentation/state/active_sale_point_controller.dart';
import '../../domain/entities/list_tickets_query.dart';
import '../../domain/entities/ticket_summary.dart';
import '../../domain/repositories/tickets_repository.dart';
import '../../domain/usecases/list_my_tickets.dart';
import '../../domain/usecases/void_my_ticket.dart';

class TicketsHistoryFilters {
  const TicketsHistoryFilters({
    this.from,
    this.to,
    this.gameId,
    this.drawTime,
  });

  final DateTime? from;
  final DateTime? to;
  /// Filtro por juego (null = todos los juegos).
  final String? gameId;
  /// Filtro por hora del sorteo en "HH:MM" (null = todos los sorteos).
  final String? drawTime;

  TicketsHistoryFilters copyWith({
    DateTime? from,
    DateTime? to,
    Object? gameId = _sentinel,
    Object? drawTime = _sentinel,
  }) {
    return TicketsHistoryFilters(
      from: from ?? this.from,
      to: to ?? this.to,
      gameId: identical(gameId, _sentinel) ? this.gameId : gameId as String?,
      drawTime:
          identical(drawTime, _sentinel) ? this.drawTime : drawTime as String?,
    );
  }
}

const Object _sentinel = Object();

class TicketsHistoryFiltersNotifier extends Notifier<TicketsHistoryFilters> {
  @override
  TicketsHistoryFilters build() {
    final now = DateTime.now();
    return TicketsHistoryFilters(
      from: DateTime(now.year, now.month, now.day),
      to: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  void set({DateTime? from, DateTime? to}) {
    state = TicketsHistoryFilters(
      from: from,
      to: to,
      gameId: state.gameId,
      drawTime: state.drawTime,
    );
  }

  void setGame(String? gameId) {
    // Al cambiar de juego, reseteamos drawTime porque las horas de
    // sorteo dependen del juego elegido.
    state = state.copyWith(gameId: gameId, drawTime: null);
  }

  void setDrawTime(String? drawTime) {
    state = state.copyWith(drawTime: drawTime);
  }

  void clear() => state = const TicketsHistoryFilters();
}

final ticketsHistoryFiltersProvider =
    NotifierProvider<TicketsHistoryFiltersNotifier, TicketsHistoryFilters>(
  TicketsHistoryFiltersNotifier.new,
);

class TicketsHistoryController extends AsyncNotifier<List<TicketSummary>> {
  late final _list = getIt<ListMyTickets>();
  late final _void = getIt<VoidMyTicket>();
  late final _repository = getIt<TicketsRepository>();

  @override
  Future<List<TicketSummary>> build() async {
    ref.listen(ticketsHistoryFiltersProvider, (previous, next) {
      if (previous != next) refresh();
    });
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<Either<Failure, TicketSummary>> voidTicket({
    required String id,
    required String reason,
  }) async {
    final result = await _void(VoidMyTicketParams(id: id, reason: reason));
    result.match(
      (_) {},
      _replace,
    );
    return result;
  }

  Future<Either<Failure, TicketSummary>> payTicket(String id) async {
    final result = await _repository.payTicket(id);
    result.match(
      (_) {},
      _replace,
    );
    return result;
  }

  void _replace(TicketSummary updated) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current
        .map<TicketSummary>((t) => t.id == updated.id ? updated : t)
        .toList());
  }

  Future<List<TicketSummary>> _fetch() async {
    final salePoint = ref.read(activeSalePointProvider).selected;
    if (salePoint == null) return const [];
    final filters = ref.read(ticketsHistoryFiltersProvider);

    final result = await _list(ListTicketsQuery(
      salePointId: salePoint.id,
      from: filters.from,
      to: filters.to,
      gameId: filters.gameId,
      drawTime: filters.drawTime,
      // Alineado con `ListWinningTickets` (backend usa `limit: 1000`) —
      // sin esto, en días con > 200 boletos la lista se truncaba y el
      // `_TotalsBar` mostraba un `won` menor al que aparece en la
      // pantalla de "Boletos ganadores" (misma data, pantallas distintas).
      // Backend enforce Max(1000), así que 1000 es el techo aceptado.
      limit: 1000,
    ));
    return result.fold(
      (failure) => throw Exception(failure.message),
      (r) => r.items,
    );
  }
}

final ticketsHistoryControllerProvider = AsyncNotifierProvider<
    TicketsHistoryController, List<TicketSummary>>(
  TicketsHistoryController.new,
);
