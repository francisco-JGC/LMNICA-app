import 'package:equatable/equatable.dart';

import '../../../../core/utils/prize.dart';

const List<String> kMonthAbbreviations = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

class DateBet extends Equatable {
  const DateBet({
    required this.day,
    required this.month,
    required this.amount,
  });

  final int day;
  final int month;
  final int amount;

  int get prize => amount * kDateMultiplier;

  String get dayLabel => day.toString().padLeft(2, '0');
  String get monthLabel => kMonthAbbreviations[month - 1];

  /// API label sent to the backend (lowercase, space separator): "01 ene"
  String get label => '$dayLabel $monthLabel';

  /// Display label for tickets (capitalized month): "01 Ene"
  String get printLabel {
    final m = monthLabel;
    return '$dayLabel ${m[0].toUpperCase()}${m.substring(1)}';
  }

  /// Inversa de [label]: convierte la etiqueta de una línea de boleto de
  /// vuelta a día + mes. Devuelve null si no es una fecha reconocible.
  ///
  /// Es deliberadamente tolerante porque las etiquetas que llegan del
  /// backend no son todas de la misma época ni del mismo origen:
  ///
  ///   - separador espacio ([label]) o guión (formato viejo),
  ///   - mes en minúscula ([label]) o capitalizado ([printLabel]),
  ///   - espacios de más por los costados.
  ///
  /// Parsear solo una de esas variantes hace que el boleto "no se
  /// reconozca" al escanearlo: las líneas que no matchean se descartan en
  /// silencio y el carrito queda vacío. Al vivir acá, junto al formato que
  /// la produce, hay un solo parser para todos los que la consumen.
  static ({int day, int month})? tryParseLabel(String raw) {
    final parts = raw.trim().toLowerCase().split(RegExp(r'[\s\-]+'));
    if (parts.length != 2) return null;
    final day = int.tryParse(parts[0]);
    final monthIndex = kMonthAbbreviations.indexOf(parts[1]);
    if (day == null || day < 1 || day > 31 || monthIndex < 0) return null;
    return (day: day, month: monthIndex + 1);
  }

  @override
  List<Object?> get props => [day, month, amount];
}
