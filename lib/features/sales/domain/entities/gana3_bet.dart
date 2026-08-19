import 'package:equatable/equatable.dart';

import '../../../../core/utils/prize.dart';

class Gana3Bet extends Equatable {
  const Gana3Bet({
    required this.number,
    required this.amount,
    required this.isExact,
  });

  final int number;
  final int amount;
  final bool isExact;

  String get numberLabel => number.toString().padLeft(3, '0');
  String get modeLabel => isExact ? 'Exacto' : 'Fácil';

  /// Label del número tiene dígitos repetidos (ej. 121, 010, 252). Solo
  /// aplica al modo fácil, donde toda permutación ganadora hereda la
  /// pareja del label. En fácil "sin pareja" (ej. 123) el ganador nunca
  /// tiene pareja, así que el multiplicador estándar aplica.
  bool get hasPair => !isExact && gana3LabelHasPair(numberLabel);

  int get prize {
    if (isExact) return amount * kGana3ExactMultiplier;
    // Fácil con pareja en el label → siempre paga el multiplicador par,
    // porque todas las permutaciones ganadoras posibles son pareja.
    if (hasPair) return amount * kGana3PairEasyMultiplier;
    return amount * kGana3EasyMultiplier;
  }

  @override
  List<Object?> get props => [number, amount, isExact];
}
