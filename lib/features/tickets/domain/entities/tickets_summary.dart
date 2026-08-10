import 'package:equatable/equatable.dart';

import '../../../../core/utils/business_time.dart';

/// Aggregate totals for a set of tickets, returned by `GET /tickets/summary`.
/// Amounts are in the same integer unit the API uses everywhere else.
class TicketsSummary extends Equatable {
  const TicketsSummary({
    required this.ticketCount,
    required this.voidedCount,
    required this.billed,
    required this.wonPrize,
    this.salary,
    this.paymentPercentage,
  });

  static const empty = TicketsSummary(
    ticketCount: 0,
    voidedCount: 0,
    billed: 0,
    wonPrize: 0,
  );

  final int ticketCount;
  final int voidedCount;
  final int billed;
  /// Total ganado por los tickets del rango, evaluado contra los
  /// `draw_results`. Reemplaza el viejo `paidPrize` — el concepto
  /// de "pagado" fue eliminado.
  final int wonPrize;

  /// Seller commission (`billed * paymentPercentage / 100`). Non-null only
  /// when the query was implicitly or explicitly scoped to a seller AND that
  /// seller has a `paymentPercentage` configured.
  final int? salary;

  /// The rate applied by the server to produce `salary`.
  final int? paymentPercentage;

  @override
  List<Object?> get props => [
        ticketCount,
        voidedCount,
        billed,
        wonPrize,
        salary,
        paymentPercentage,
      ];
}

/// Query params for `GET /tickets/summary`. Sellers cannot spy on other
/// sellers: the server forces `sellerId = requesterId` when the caller has
/// role=seller regardless of what's sent here.
class TicketsSummaryQuery extends Equatable {
  const TicketsSummaryQuery({
    this.salePointId,
    this.gameId,
    this.sellerId,
    this.from,
    this.to,
  });

  final String? salePointId;
  final String? gameId;
  final String? sellerId;
  final DateTime? from;
  final DateTime? to;

  Map<String, dynamic> toQueryParameters() => {
        if (salePointId != null) 'salePointId': salePointId,
        if (gameId != null) 'gameId': gameId,
        if (sellerId != null) 'sellerId': sellerId,
        if (from != null) 'from': BusinessTime.toBusinessIso(from!),
        if (to != null) 'to': BusinessTime.toBusinessIso(to!),
      };

  @override
  List<Object?> get props => [salePointId, gameId, sellerId, from, to];
}
