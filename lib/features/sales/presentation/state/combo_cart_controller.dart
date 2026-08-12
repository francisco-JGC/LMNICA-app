import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/combo_bet.dart';
import 'cart_controller.dart';
import 'combo_cart_state.dart';

class ComboCartController extends Notifier<ComboCartState> {
  ComboCartController(this.gameId);

  final String gameId;

  @override
  ComboCartState build() => const ComboCartState();

  AddBetOutcome addSingle({
    required int number,
    required int amount,
    String? client,
  }) {
    if (number < 0 || number > 9999) return AddBetOutcome.invalid;
    if (amount < 1 || amount > 999) return AddBetOutcome.invalid;
    state = ComboCartState(
      bets: _merge(state.bets, [ComboBet(number: number, amount: amount)]),
      client: _clean(client) ?? state.client,
    );
    return AddBetOutcome.added;
  }

  void addRange({
    required int start,
    required int end,
    required int amount,
  }) {
    if (start < 0 || end > 9999 || end < start) return;
    if (amount < 1 || amount > 999) return;
    final incoming = [
      for (var n = start; n <= end; n++) ComboBet(number: n, amount: amount),
    ];
    state = ComboCartState(
      bets: _merge(state.bets, incoming),
      client: state.client,
    );
  }

  void addRandom({required int count, required int amount}) {
    if (count < 1 || amount < 1 || amount > 999) return;
    final random = math.Random();
    final numbers = <int>{};
    while (numbers.length < count.clamp(1, 10000)) {
      numbers.add(random.nextInt(10000));
    }
    final incoming =
        numbers.map((n) => ComboBet(number: n, amount: amount)).toList();
    state = ComboCartState(
      bets: _merge(state.bets, incoming),
      client: state.client,
    );
  }

  List<ComboBet> _merge(List<ComboBet> existing, List<ComboBet> incoming) {
    final result = [...existing];
    for (final b in incoming) {
      final i = result.indexWhere((e) => e.number == b.number);
      if (i >= 0) {
        result[i] = ComboBet(
          number: b.number,
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
    state = ComboCartState(bets: state.bets, client: cleaned);
  }

  void removeAt(int index) {
    state = ComboCartState(
      bets: [...state.bets]..removeAt(index),
      client: state.client,
    );
  }

  void clear() {
    state = const ComboCartState();
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

final comboCartControllerProvider = NotifierProvider.family<
    ComboCartController, ComboCartState, String>(ComboCartController.new);
