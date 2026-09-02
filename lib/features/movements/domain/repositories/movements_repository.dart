import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/business_time.dart';

typedef SellerBalance = ({int cobros, int credits, int prizePayments});

class SellerBalanceQuery {
  const SellerBalanceQuery({this.salePointId, this.from, this.to});

  final String? salePointId;
  final DateTime? from;
  final DateTime? to;

  Map<String, dynamic> toQueryParameters() => {
        if (salePointId != null) 'salePointIds': salePointId,
        if (from != null) 'from': BusinessTime.toBusinessIso(from!),
        if (to != null) 'to': BusinessTime.toBusinessIso(to!),
      };
}

abstract interface class MovementsRepository {
  Future<Either<Failure, SellerBalance>> sellerBalance(
    SellerBalanceQuery query,
  );
}
