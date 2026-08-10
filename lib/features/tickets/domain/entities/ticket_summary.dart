import 'package:equatable/equatable.dart';

enum TicketStatus { valid, voided }

TicketStatus ticketStatusFromString(String raw) {
  switch (raw) {
    case 'voided':
      return TicketStatus.voided;
    case 'valid':
    default:
      return TicketStatus.valid;
  }
}

class TicketSummary extends Equatable {
  const TicketSummary({
    required this.id,
    required this.folio,
    required this.gameId,
    required this.salePointId,
    required this.client,
    required this.status,
    required this.total,
    required this.count,
    required this.drawAt,
    required this.cutoffMinutes,
    required this.drawExecuted,
    required this.createdAt,
    required this.voidedAt,
    required this.voidedReason,
    required this.wonPrize,
  });

  final String id;
  final String folio;
  final String gameId;
  final String salePointId;
  final String? client;
  final TicketStatus status;
  final int total;
  final int count;
  final DateTime drawAt;
  final int cutoffMinutes;
  final bool drawExecuted;
  final DateTime createdAt;
  final DateTime? voidedAt;
  final String? voidedReason;
  /// Premio ganado por el ticket (evaluado contra el `draw_result`).
  /// 0 si no ganó o si el sorteo aún no se ejecutó. Reemplaza el
  /// viejo `paidPrize` — el concepto de "pagado" fue eliminado.
  final int wonPrize;

  bool get isVoided => status == TicketStatus.voided;
  bool get isWinner => wonPrize > 0;

  bool canBeVoidedAt(DateTime now) {
    if (isVoided) return false;
    if (drawExecuted) return false;
    final minutesUntil = drawAt.difference(now).inSeconds / 60.0;
    return minutesUntil > cutoffMinutes;
  }

  @override
  List<Object?> get props => [
        id,
        folio,
        gameId,
        salePointId,
        client,
        status,
        total,
        count,
        drawAt,
        cutoffMinutes,
        drawExecuted,
        createdAt,
        voidedAt,
        voidedReason,
        wonPrize,
      ];
}
