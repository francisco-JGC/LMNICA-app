import 'package:equatable/equatable.dart';

class MovementsSummary extends Equatable {
  const MovementsSummary({
    required this.billed,
    required this.wonPrize,
    required this.salary,
    required this.cobros,
    required this.credits,
    required this.prizePayments,
  });

  final int billed;
  final int wonPrize;
  final int salary;
  /// Dinero recibido del vendedor (cobros registrados como movimiento).
  final int cobros;
  /// Créditos devueltos al vendedor.
  final int credits;
  /// Movimientos marcados como pago de premio.
  final int prizePayments;

  /// Pendiente = vendido − premios ganados − salario − cobrado + créditos
  int get remaining => billed - wonPrize - salary - cobros + credits;

  static const empty = MovementsSummary(
    billed: 0,
    wonPrize: 0,
    salary: 0,
    cobros: 0,
    credits: 0,
    prizePayments: 0,
  );

  @override
  List<Object?> get props =>
      [billed, wonPrize, salary, cobros, credits, prizePayments];
}
