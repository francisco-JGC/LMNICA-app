import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/sale_limit_availability.dart';

class SaleLimitAvailabilityQuery {
  const SaleLimitAvailabilityQuery({
    required this.gameId,
    required this.salePointId,
    required this.drawAt,
  });

  final String gameId;
  final String salePointId;
  final DateTime drawAt;
}

abstract interface class SaleLimitsRepository {
  Future<Either<Failure, SaleLimitAvailability>> getAvailability(
    SaleLimitAvailabilityQuery query,
  );

  Future<Either<Failure, Map<String, int>>> getMinAmountsByNumber({
    required String gameId,
    required String salePointId,
  });
}
