import '../../domain/entities/ticket_summary.dart';

class TicketSummaryModel extends TicketSummary {
  const TicketSummaryModel({
    required super.id,
    required super.folio,
    required super.gameId,
    required super.salePointId,
    required super.client,
    required super.status,
    required super.total,
    required super.count,
    required super.drawAt,
    required super.cutoffMinutes,
    required super.drawExecuted,
    required super.createdAt,
    required super.voidedAt,
    required super.voidedReason,
    required super.wonPrize,
  });

  factory TicketSummaryModel.fromJson(Map<String, dynamic> json) {
    return TicketSummaryModel(
      id: json['id'] as String,
      folio: json['folio'] as String,
      gameId: json['gameId'] as String,
      salePointId: json['salePointId'] as String,
      client: json['client'] as String?,
      status: ticketStatusFromString(json['status'] as String),
      total: (json['total'] as num).toInt(),
      count: (json['count'] as num).toInt(),
      drawAt: DateTime.parse(json['drawAt'] as String),
      cutoffMinutes: (json['cutoffMinutes'] as num).toInt(),
      drawExecuted: json['drawExecuted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      voidedAt: json['voidedAt'] == null
          ? null
          : DateTime.parse(json['voidedAt'] as String),
      voidedReason: json['voidedReason'] as String?,
      wonPrize: (json['wonPrize'] as num?)?.toInt() ?? 0,
    );
  }
}
