import 'package:equatable/equatable.dart';

import '../../../../core/utils/business_time.dart';
import 'ticket_summary.dart';

class ListTicketsQuery extends Equatable {
  const ListTicketsQuery({
    this.salePointId,
    this.gameId,
    this.drawTime,
    this.status,
    this.from,
    this.to,
  });

  final String? salePointId;
  final String? gameId;
  /// "HH:MM" wall clock Managua para filtrar por sorteo específico.
  final String? drawTime;
  final TicketStatus? status;
  final DateTime? from;
  final DateTime? to;

  Map<String, dynamic> toQueryParameters() => {
        if (salePointId != null) 'salePointId': salePointId,
        if (gameId != null) 'gameId': gameId,
        if (drawTime != null) 'drawTime': drawTime,
        if (status != null)
          'status': status == TicketStatus.voided ? 'voided' : 'valid',
        if (from != null) 'from': BusinessTime.toBusinessIso(from!),
        if (to != null) 'to': BusinessTime.toBusinessIso(to!),
      };

  @override
  List<Object?> get props => [salePointId, gameId, drawTime, status, from, to];
}

class ListTicketsResult extends Equatable {
  const ListTicketsResult({
    required this.items,
    required this.total,
    required this.totalBilled,
    required this.totalWonPrize,
  });

  final List<TicketSummary> items;
  final int total;

  /// Total facturado sobre TODO el rango filtrado. El endpoint no pagina,
  /// así que este número refleja exactamente lo mismo que `items`, pero
  /// el widget de totales lo usa directamente sin re-sumar client-side.
  final int totalBilled;

  /// Ídem `totalBilled` pero para wonPrize (premios ganados, evaluados
  /// contra draw_results). Reconcilia con `/tickets/winners`.
  final int totalWonPrize;

  @override
  List<Object?> get props => [items, total, totalBilled, totalWonPrize];
}
