import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency.dart';
import '../../../../core/utils/prize.dart';
import '../../../game_prizes/presentation/state/effective_game_prizes_provider.dart';
import '../../domain/entities/bet.dart';

class BetTile extends ConsumerWidget {
  const BetTile({
    required this.bet,
    required this.gameId,
    required this.onRemove,
    super.key,
  });

  final Bet bet;
  final String gameId;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(effectiveGamePrizeForGameProvider(gameId));
    final prize = rescaleEffectivePrize(bet.amount, bet.prize, override);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.tag, size: 20, color: Colors.black),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              bet.numberLabel,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Text(
              kCurrencyFormat.format(bet.amount),
              style: const TextStyle(fontSize: 15, color: Colors.black),
            ),
          ),
          const Icon(Icons.emoji_events_outlined,
              size: 18, color: Colors.black),
          const SizedBox(width: 4),
          Text(
            kCurrencyFormat.format(prize),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.black),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
