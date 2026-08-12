import 'package:equatable/equatable.dart';

class CreateTicketLine extends Equatable {
  const CreateTicketLine({
    required this.label,
    required this.amount,
    required this.prize,
    this.pairEasyPrize,
    this.subGameId,
    this.subGameName,
  });

  final String label;
  final int amount;
  final int prize;

  /// Snapshot del premio si esta línea gana por fácil Y el número ganador
  /// tiene dígitos repetidos ("premio par"). Solo se envía en líneas
  /// fácil de Juega 3 cuando la sucursal tiene el multiplicador par
  /// configurado. Null → la regla no aplica; el backend usa `prize`.
  final int? pairEasyPrize;

  final String? subGameId;
  final String? subGameName;

  Map<String, dynamic> toJson() => {
        'label': label,
        'amount': amount,
        'prize': prize,
        if (pairEasyPrize != null) 'pairEasyPrize': pairEasyPrize,
        if (subGameId != null) 'subGameId': subGameId,
        if (subGameName != null) 'subGameName': subGameName,
      };

  @override
  List<Object?> get props =>
      [label, amount, prize, pairEasyPrize, subGameId, subGameName];
}

class CreateTicketRequest extends Equatable {
  const CreateTicketRequest({
    required this.gameId,
    required this.salePointId,
    required this.lines,
    this.client,
    this.drawAt,
    this.clientRequestId,
  });

  final String gameId;
  final String salePointId;
  final List<CreateTicketLine> lines;
  final String? client;
  final DateTime? drawAt;

  /// UUID v4 generado una sola vez por intento de venta. Se manda al backend
  /// para dedupear reintentos: si la respuesta se pierde y el vendedor toca
  /// "Enviar" de nuevo, o si el interceptor de auth reintenta tras un 401,
  /// el segundo POST llega con el MISMO `clientRequestId` y el backend
  /// devuelve el ticket ya creado en lugar de duplicarlo.
  final String? clientRequestId;

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'salePointId': salePointId,
        if (client != null) 'client': client,
        'lines': lines.map((l) => l.toJson()).toList(),
        if (drawAt != null) 'drawAt': drawAt!.toUtc().toIso8601String(),
        if (clientRequestId != null) 'clientRequestId': clientRequestId,
      };

  @override
  List<Object?> get props =>
      [gameId, salePointId, lines, client, drawAt, clientRequestId];
}
