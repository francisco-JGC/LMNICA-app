import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/feature_flag.dart';
import '../../domain/repositories/feature_flags_repository.dart';
import '../datasources/feature_flags_remote_datasource.dart';

class FeatureFlagsRepositoryImpl implements FeatureFlagsRepository {
  const FeatureFlagsRepositoryImpl({required this.remote});

  final FeatureFlagsRemoteDatasource remote;

  @override
  Future<Either<Failure, List<FeatureFlag>>> list() async {
    try {
      final items = await remote.list();
      return Right(items);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
