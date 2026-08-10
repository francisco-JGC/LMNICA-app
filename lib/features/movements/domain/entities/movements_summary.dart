import 'package:equatable/equatable.dart';

class MovementsSummary extends Equatable {
  const MovementsSummary({
    required this.billed,
    required this.collected,
    required this.wonPrize,
    required this.expenses,
    required this.salary,
  });

  final int billed;
  final int collected;
  /// Total ganado por clientes en el rango (evaluado contra draws).
  /// Antes se llamaba `paidPrize` — el concepto de "pagado" fue eliminado.
  final int wonPrize;
  final int expenses;
  final int salary;

  int get remaining => collected - wonPrize - expenses - salary;

  MovementsSummary copyWith({
    int? billed,
    int? collected,
    int? wonPrize,
    int? expenses,
    int? salary,
  }) {
    return MovementsSummary(
      billed: billed ?? this.billed,
      collected: collected ?? this.collected,
      wonPrize: wonPrize ?? this.wonPrize,
      expenses: expenses ?? this.expenses,
      salary: salary ?? this.salary,
    );
  }

  static const empty =
      MovementsSummary(billed: 0, collected: 0, wonPrize: 0, expenses: 0, salary: 0);

  @override
  List<Object?> get props => [billed, collected, wonPrize, expenses, salary];
}
