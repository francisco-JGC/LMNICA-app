import 'package:equatable/equatable.dart';

enum TicketCopyKind { original, reprint, resend }

class TicketLine extends Equatable {
  const TicketLine({
    required this.number,
    required this.amount,
    required this.prize,
    this.subGameName,
  });

  final String number;
  final int amount;
  final int prize;
  final String? subGameName;

  List<dynamic> toQrEntry() => [number, amount];

  @override
  List<Object?> get props => [number, amount, prize, subGameName];
}

class TicketPayload extends Equatable {
  const TicketPayload({
    required this.id,
    required this.gameId,
    required this.gameSlug,
    required this.gameName,
    required this.lines,
    required this.folio,
    required this.date,
    this.drawAt,
    this.seller,
    this.client,
    this.footer,
    this.salePoint,
    this.copyKind = TicketCopyKind.original,
    this.isDate = false,
    this.isFourDigit = false,
  });

  final String id;
  final String gameId;
  final String gameSlug;
  final String gameName;
  final List<TicketLine> lines;
  final String folio;
  final DateTime date;
  final DateTime? drawAt;
  final String? seller;
  final String? client;
  final String? footer;
  final String? salePoint;
  final TicketCopyKind copyKind;
  // Juego de tipo fecha (Quiniela de Fechas): las líneas muestran fechas,
  // no números de 2 dígitos, por lo que el layout ESC/POS usa columnas
  // size1 para que quepan.
  final bool isDate;
  // Juego de 4 dígitos (Loto 4): los números son más largos y el monto
  // puede ser mayor, por lo que el layout ESC/POS aplica `shiftLeft`
  // cuando monto > 99 y premio > 9999.
  final bool isFourDigit;

  int get total => lines.fold(0, (sum, l) => sum + l.amount);
  int get totalPrize => lines.fold(0, (sum, l) => sum + l.prize);
  int get count => lines.length;

  bool get isCopy => copyKind != TicketCopyKind.original;

  // Uses uppercase hex without dashes so the ESC/POS QR encoder picks
  // alphanumeric mode (5.5 bits/char) instead of byte mode (8 bits/char).
  // The scanner reconstructs the UUID on the way back.
  String toQrData() => id.replaceAll('-', '').toUpperCase();

  @override
  List<Object?> get props => [
        id,
        gameId,
        gameSlug,
        gameName,
        lines,
        folio,
        date,
        drawAt,
        seller,
        client,
        footer,
        salePoint,
        copyKind,
        isDate,
        isFourDigit,
      ];
}
