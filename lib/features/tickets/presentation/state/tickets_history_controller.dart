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

/// Estado de la pantalla de Facturas — items paginados + totales agregados
/// del rango completo (server-side). Los totales viajan con el response del
/// endpoint `/tickets` y evitan que la barra de totales quede corta cuando
/// el vendedor tiene más tickets que el `limit` de la página.
class TicketsHistoryData {
  const TicketsHistoryData({
    required this.items,
    required this.totalBilled,
    required this.totalWonPrize,
  });

  final List<TicketSummary> items;
  final int totalBilled;
  final int totalWonPrize;

  static const empty = TicketsHistoryData(
    items: [],
    totalBilled: 0,
    totalWonPrize: 0,
  );
}

class TicketsHistoryController extends AsyncNotifier<TicketsHistoryData> {
  late final _list = getIt<ListMyTickets>();
  late final _void = getIt<VoidMyTicket>();
  late final _repository = getIt<TicketsRepository>();

  @override
  Future<TicketsHistoryData> build() async {
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
    await result.match(
      (_) async {},
      (updated) async {
        // Anular cambia el estado del ticket, por lo tanto los totales del
        // rango (billed excluye anulados, wonPrize excluye anulados) también
        // pueden variar. Recargamos del server para mantener consistencia
        // con la ventana de Boletos Ganadores.
        await refresh();
      },
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
    final items = current.items
        .map<TicketSummary>((t) => t.id == updated.id ? updated : t)
        .toList();
    state = AsyncValue.data(TicketsHistoryData(
      items: items,
      totalBilled: current.totalBilled,
      totalWonPrize: current.totalWonPrize,
    ));
  }

  Future<TicketsHistoryData> _fetch() async {
    final salePoint = ref.read(activeSalePointProvider).selected;
    if (salePoint == null) return TicketsHistoryData.empty;
    final filters = ref.read(ticketsHistoryFiltersProvider);

    // El endpoint no pagina — trae todo el rango filtrado. Los totales
    // vienen calculados server-side sobre el mismo set, así que la barra
    // de totales usa `result.totalBilled` / `result.totalWonPrize`
    // directamente y coincide 1:1 con `/tickets/winners`.
    final result = await _list(ListTicketsQuery(
      salePointId: salePoint.id,
      from: filters.from,
      to: filters.to,
      gameId: filters.gameId,
      drawTime: filters.drawTime,
    ));
    return result.fold(
      (failure) => throw Exception(failure.message),
      (r) => TicketsHistoryData(
        items: r.items,
        totalBilled: r.totalBilled,
        totalWonPrize: r.totalWonPrize,
      ),
    );
  }
}

final ticketsHistoryControllerProvider = AsyncNotifierProvider<
    TicketsHistoryController, TicketsHistoryData>(
  TicketsHistoryController.new,
);
