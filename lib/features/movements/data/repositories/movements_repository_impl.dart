import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/movements_repository.dart';
import '../datasources/movements_remote_datasource.dart';

class MovementsRepositoryImpl implements MovementsRepository {
  const MovementsRepositoryImpl({required this.remote});

  final MovementsRemoteDatasource remote;

  @override
  Future<Either<Failure, SellerBalance>> sellerBalance(
    SellerBalanceQuery query,
  ) {
    return _guard(() => remote.sellerBalance(query));
  }

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Right(await call());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
