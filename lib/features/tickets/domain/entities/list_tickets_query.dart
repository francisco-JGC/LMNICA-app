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
    this.page = 1,
    this.limit = 50,
  });

  final String? salePointId;
  final String? gameId;
  /// "HH:MM" wall clock Managua para filtrar por sorteo específico.
  final String? drawTime;
  final TicketStatus? status;
  final DateTime? from;
  final DateTime? to;
  final int page;
  final int limit;

  Map<String, dynamic> toQueryParameters() => {
        if (salePointId != null) 'salePointId': salePointId,
        if (gameId != null) 'gameId': gameId,
        if (drawTime != null) 'drawTime': drawTime,
        if (status != null) 'status': status == TicketStatus.voided ? 'voided' : 'valid',
        if (from != null) 'from': BusinessTime.toBusinessIso(from!),
        if (to != null) 'to': BusinessTime.toBusinessIso(to!),
        'page': page,
        'limit': limit,
      };

  @override
  List<Object?> get props =>
      [salePointId, gameId, drawTime, status, from, to, page, limit];
}

class ListTicketsResult extends Equatable {
  const ListTicketsResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  final List<TicketSummary> items;
  final int page;
  final int limit;
  final int total;

  @override
  List<Object?> get props => [items, page, limit, total];
}
