import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/sale_limit_availability.dart';
import '../../domain/repositories/sale_limits_repository.dart';

/// Cache key: (game, sucursal, drawAt). Kept as a value type so Riverpod
/// dedupes identical requests across widgets and rebuilds only when one of
/// the three changes.
class SaleLimitAvailabilityKey extends Equatable {
  const SaleLimitAvailabilityKey({
    required this.gameId,
    required this.salePointId,
    required this.drawAt,
  });

  final String gameId;
  final String salePointId;
  final DateTime drawAt;

  @override
  List<Object?> get props => [gameId, salePointId, drawAt.toUtc()];
}

/// Current availability snapshot for the given (game, sucursal, drawAt).
/// Refreshes after each ticket create by invalidating externally.
final saleLimitAvailabilityProvider = FutureProvider.autoDispose
    .family<SaleLimitAvailability, SaleLimitAvailabilityKey>(
  (ref, key) async {
    final repo = getIt<SaleLimitsRepository>();
    final result = await repo.getAvailability(
      SaleLimitAvailabilityQuery(
        gameId: key.gameId,
        salePointId: key.salePointId,
        drawAt: key.drawAt,
      ),
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  },
);

class _MinAmountsKey extends Equatable {
  const _MinAmountsKey({required this.gameId, required this.salePointId});
  final String gameId;
  final String salePointId;
  @override
  List<Object?> get props => [gameId, salePointId];
}

/// Minimum bet amounts per number for a (game, sucursal) pair.
/// Returns an empty map when no minimums are configured.
final minAmountsByNumberProvider = FutureProvider.autoDispose
    .family<Map<String, int>, _MinAmountsKey>(
  (ref, key) async {
    final repo = getIt<SaleLimitsRepository>();
    final result = await repo.getMinAmountsByNumber(
      gameId: key.gameId,
      salePointId: key.salePointId,
    );
    return result.fold(
      (_) => const {},
      (data) => data,
    );
  },
);
