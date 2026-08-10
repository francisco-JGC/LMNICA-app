import 'package:equatable/equatable.dart';

import 'winning_ticket.dart';

class TicketEvaluation extends Equatable {
  const TicketEvaluation({
    required this.ticketId,
    required this.folio,
    required this.gameId,
    required this.drawAt,
    required this.status,
    required this.isWinner,
    required this.hasPendingDraw,
    required this.totalPrize,
    required this.lines,
  });

  final String ticketId;
  final String folio;
  final String gameId;
  final DateTime drawAt;
  final String status;
  final bool isWinner;
  final bool hasPendingDraw;
  final int totalPrize;
  final List<WinningTicketLine> lines;

  bool get isVoided => status == 'voided';

  @override
  List<Object?> get props => [
        ticketId,
        folio,
        gameId,
        drawAt,
        status,
        isWinner,
        hasPendingDraw,
        totalPrize,
        lines,
      ];
}
