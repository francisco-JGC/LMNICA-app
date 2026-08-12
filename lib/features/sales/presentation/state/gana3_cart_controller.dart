import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/gana3_bet.dart';
import 'cart_controller.dart';
import 'gana3_cart_state.dart';

class Gana3CartController extends Notifier<Gana3CartState> {
  Gana3CartController(this.gameId);

  final String gameId;

  @override
  Gana3CartState build() => const Gana3CartState();

  AddBetOutcome addSingle({
    required int number,
    required int amount,
    required bool isExact,
    String? client,
  }) {
    if (number < 0 || number > 999) return AddBetOutcome.invalid;
    if (amount < 1 || amount > 999) return AddBetOutcome.invalid;
    state = Gana3CartState(
      bets: _merge(state.bets, [
        Gana3Bet(number: number, amount: amount, isExact: isExact),
      ]),
      client: _clean(client) ?? state.client,
    );
    return AddBetOutcome.added;
  }

  void addRange({
    required int start,
    required int end,
    required int amount,
    required bool isExact,
  }) {
    if (start < 0 || end > 999 || end < start) return;
    if (amount < 1 || amount > 999) return;
    final incoming = [
      for (var n = start; n <= end; n++)
        Gana3Bet(number: n, amount: amount, isExact: isExact),
    ];
    state = Gana3CartState(
      bets: _merge(state.bets, incoming),
      client: state.client,
    );
  }

  void addRandom({
    required int count,
    required int amount,
    required bool isExact,
  }) {
    if (count < 1 || amount < 1 || amount > 999) return;
    final random = math.Random();
    final numbers = <int>{};
    while (numbers.length < count.clamp(1, 1000)) {
      numbers.add(random.nextInt(1000));
    }
    final incoming = numbers
        .map((n) => Gana3Bet(number: n, amount: amount, isExact: isExact))
        .toList();
    state = Gana3CartState(
      bets: _merge(state.bets, incoming),
      client: state.client,
    );
  }

  List<Gana3Bet> _merge(List<Gana3Bet> existing, List<Gana3Bet> incoming) {
    final result = [...existing];
    for (final b in incoming) {
      final i = result.indexWhere(
        (e) => e.number == b.number && e.isExact == b.isExact,
      );
      if (i >= 0) {
        result[i] = Gana3Bet(
          number: b.number,
          amount: result[i].amount + b.amount,
          isExact: b.isExact,
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
    state = Gana3CartState(bets: state.bets, client: cleaned);
  }

  void removeAt(int index) {
    state = Gana3CartState(
      bets: [...state.bets]..removeAt(index),
      client: state.client,
    );
  }

  void clear() {
    state = const Gana3CartState();
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

final gana3CartControllerProvider = NotifierProvider.family<
    Gana3CartController, Gana3CartState, String>(Gana3CartController.new);
