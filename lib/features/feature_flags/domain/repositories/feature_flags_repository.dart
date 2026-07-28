import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/feature_flag.dart';

abstract interface class FeatureFlagsRepository {
  Future<Either<Failure, List<FeatureFlag>>> list();
}
