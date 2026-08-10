import '../../domain/entities/tickets_summary.dart';

class TicketsSummaryModel extends TicketsSummary {
  const TicketsSummaryModel({
    required super.ticketCount,
    required super.voidedCount,
    required super.billed,
    required super.wonPrize,
    super.salary,
    super.paymentPercentage,
  });

  factory TicketsSummaryModel.fromJson(Map<String, dynamic> json) {
    return TicketsSummaryModel(
      ticketCount: (json['ticketCount'] as num).toInt(),
      voidedCount: (json['voidedCount'] as num).toInt(),
      billed: (json['billed'] as num).toInt(),
      wonPrize: (json['wonPrize'] as num).toInt(),
      salary: (json['salary'] as num?)?.toInt(),
      paymentPercentage: (json['paymentPercentage'] as num?)?.toInt(),
    );
  }
}
