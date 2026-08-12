import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/date_bet.dart';
import 'cart_controller.dart';
import 'date_cart_state.dart';

class DateCartController extends Notifier<DateCartState> {
  DateCartController(this.gameId);

  final String gameId;

  @override
  DateCartState build() => const DateCartState();

  AddBetOutcome addSingle({
    required int day,
    required int month,
    required int amount,
    String? client,
  }) {
    if (day < 1 || day > 31) return AddBetOutcome.invalid;
    if (month < 1 || month > 12) return AddBetOutcome.invalid;
    if (amount < 1 || amount > 999) return AddBetOutcome.invalid;
    state = DateCartState(
      bets: _merge(state.bets, [
        DateBet(day: day, month: month, amount: amount),
      ]),
      client: _clean(client) ?? state.client,
    );
    return AddBetOutcome.added;
  }

  void addRange({
    required int dayStart,
    required int dayEnd,
    required int month,
    required int amount,
  }) {
    if (dayStart < 1 || dayEnd > 31 || dayEnd < dayStart) return;
    if (month < 1 || month > 12) return;
    if (amount < 1 || amount > 999) return;
    final incoming = [
      for (var d = dayStart; d <= dayEnd; d++)
        DateBet(day: d, month: month, amount: amount),
    ];
    state = DateCartState(
      bets: _merge(state.bets, incoming),
      client: state.client,
    );
  }

  List<DateBet> _merge(List<DateBet> existing, List<DateBet> incoming) {
    final result = [...existing];
    for (final b in incoming) {
      final i = result.indexWhere(
        (e) => e.day == b.day && e.month == b.month,
      );
      if (i >= 0) {
        result[i] = DateBet(
          day: b.day,
          month: b.month,
          amount: result[i].amount + b.amount,
        );
      } else {
        result.add(b);
      }
    }
    return result;
  }

  /// Sincroniza el cliente desde el TextField (ver `CartController.setClient`).
  void setClient(String? value) {
    final cleaned = _clean(value);
    if (cleaned == state.client) return;
    state = DateCartState(bets: state.bets, client: cleaned);
  }

  void removeAt(int index) {
    state = DateCartState(
      bets: [...state.bets]..removeAt(index),
      client: state.client,
    );
  }

  void clear() {
    state = const DateCartState();
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

final dateCartControllerProvider = NotifierProvider.family<
    DateCartController, DateCartState, String>(DateCartController.new);
