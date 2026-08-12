import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/bet.dart';
import 'cart_state.dart';

enum AddBetOutcome { added, invalid }

class CartController extends Notifier<CartState> {
  CartController(this.gameId);

  final String gameId;

  @override
  CartState build() => const CartState();

  AddBetOutcome addSingle({
    required int number,
    required int amount,
    String? client,
  }) {
    if (number < 0 || number > 99 || amount < 1 || amount > 999) {
      return AddBetOutcome.invalid;
    }
    state = CartState(
      bets: _merge(state.bets, [Bet(number: number, amount: amount)]),
      client: _clean(client) ?? state.client,
    );
    return AddBetOutcome.added;
  }

  void addRange({
    required int start,
    required int end,
    required int amount,
  }) {
    final incoming = [
      for (var n = start; n <= end; n++) Bet(number: n, amount: amount),
    ];
    state = CartState(
      bets: _merge(state.bets, incoming),
      client: state.client,
    );
  }

  void addRandom({required int count, required int amount}) {
    final random = Random();
    final numbers = <int>{};
    final target = count.clamp(1, 100);
    while (numbers.length < target) {
      numbers.add(random.nextInt(100));
    }
    final incoming =
        numbers.map((n) => Bet(number: n, amount: amount)).toList();
    state = CartState(
      bets: _merge(state.bets, incoming),
      client: state.client,
    );
  }

  void addBets(List<Bet> bets, {String? client}) {
    if (bets.isEmpty) return;
    state = CartState(
      bets: _merge(state.bets, bets),
      client: _clean(client) ?? state.client,
    );
  }

  List<Bet> _merge(List<Bet> existing, List<Bet> incoming) {
    final result = [...existing];
    for (final b in incoming) {
      final i = result.indexWhere((e) => e.number == b.number);
      if (i >= 0) {
        result[i] = Bet(
          number: b.number,
          amount: result[i].amount + b.amount,
        );
      } else {
        result.add(b);
      }
    }
    return result;
  }

  /// Sincroniza el nombre del cliente desde el TextField del quick-form.
  /// Se llama en cada keystroke (via listener) para que `state.client` esté
  /// siempre alineado con lo que el vendedor ve en pantalla. Sin esto, si
  /// el vendedor escribía el nombre DESPUÉS de haber agregado el último
  /// número al cart y luego apretaba "Imprimir", el nombre no salía en el
  /// boleto — `state.client` había quedado null porque en cada `addSingle`
  /// previo el campo estaba vacío.
  void setClient(String? value) {
    final cleaned = _clean(value);
    if (cleaned == state.client) return;
    state = CartState(bets: state.bets, client: cleaned);
  }

  void removeAt(int index) {
    state = CartState(
      bets: [...state.bets]..removeAt(index),
      client: state.client,
    );
  }

  void clear() {
    state = const CartState();
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

final cartControllerProvider =
    NotifierProvider.family<CartController, CartState, String>(
  CartController.new,
);
