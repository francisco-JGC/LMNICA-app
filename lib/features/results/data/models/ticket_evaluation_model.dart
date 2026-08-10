import '../../domain/entities/ticket_evaluation.dart';
import 'winning_ticket_model.dart';

class TicketEvaluationModel extends TicketEvaluation {
  const TicketEvaluationModel({
    required super.ticketId,
    required super.folio,
    required super.gameId,
    required super.drawAt,
    required super.status,
    required super.isWinner,
    required super.hasPendingDraw,
    required super.totalPrize,
    required super.lines,
  });

  factory TicketEvaluationModel.fromJson(Map<String, dynamic> json) {
    final rawLines = (json['lines'] as List<dynamic>? ?? const [])
        .map((raw) => raw as Map<String, dynamic>)
        .map(WinningTicketLineModel.fromJson)
        .toList();
    return TicketEvaluationModel(
      ticketId: json['ticketId'] as String,
      folio: json['folio'] as String,
      gameId: json['gameId'] as String,
      drawAt: DateTime.parse(json['drawAt'] as String),
      status: json['status'] as String,
      isWinner: json['isWinner'] as bool,
      hasPendingDraw: json['hasPendingDraw'] as bool,
      totalPrize: (json['totalPrize'] as num).toInt(),
      lines: rawLines,
    );
  }
}
