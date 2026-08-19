import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../sale_points/presentation/state/active_sale_point_controller.dart';
import '../../domain/entities/effective_game_prize.dart';
import '../../domain/repositories/game_prizes_repository.dart';

/// Effective multipliers for every game at the given sucursal. Sellers
/// consult this at ticket-create time so the `prize` sent to the server
/// reflects the override — if the operator configured Diaria at 75x for
/// Puesto Principal, tickets sold there use 75x, not the game default 80x.
final effectiveGamePrizesProvider = FutureProvider.autoDispose
    .family<List<EffectiveGamePrize>, String>((ref, salePointId) async {
  final repo = getIt<GamePrizesRepository>();
  final result = await repo.listBySalePoint(salePointId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (data) => data,
  );
});

/// Effective multipliers for a single game at the currently active sucursal.
/// Devuelve null si no hay sucursal seleccionada o la lista aún carga —
/// los tiles caen al `bet.prize` con constantes hardcoded en ese caso.
final effectiveGamePrizeForGameProvider = Provider.autoDispose
    .family<EffectiveGamePrize?, String>((ref, gameId) {
  final salePoint = ref.watch(activeSalePointProvider).selected;
  if (salePoint == null) return null;
  final async = ref.watch(effectiveGamePrizesProvider(salePoint.id));
  return async.maybeWhen(
    data: (list) {
      for (final p in list) {
        if (p.gameId == gameId) return p;
      }
      return null;
    },
    orElse: () => null,
  );
});
