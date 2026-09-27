import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/sale_limit_availability.dart';
import '../../domain/repositories/sale_limits_repository.dart';
import '../datasources/sale_limits_remote_datasource.dart';

class SaleLimitsRepositoryImpl implements SaleLimitsRepository {
  const SaleLimitsRepositoryImpl({required this.remote});

  final SaleLimitsRemoteDatasource remote;

  @override
  Future<Either<Failure, SaleLimitAvailability>> getAvailability(
    SaleLimitAvailabilityQuery query,
  ) async {
    try {
      final result = await remote.getAvailability(query);
      return Right(result);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getMinAmountsByNumber({
    required String gameId,
    required String salePointId,
  }) async {
    try {
      final result = await remote.getMinAmountsByNumber(
        gameId: gameId,
        salePointId: salePointId,
      );
      return Right(result);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
