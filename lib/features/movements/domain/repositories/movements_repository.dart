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

class MovementItem {
  const MovementItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.occurredAt,
    this.description,
    this.isPrizePayment = false,
  });

  final String id;
  final String type;
  final int amount;
  final String occurredAt;
  final String? description;
  final bool isPrizePayment;
}

typedef MovementsList = ({List<MovementItem> items, int total});

class ListMovementsQuery {
  const ListMovementsQuery({
    this.salePointId,
    this.type,
    this.from,
    this.to,
    this.page = 1,
    this.limit = 30,
  });

  final String? salePointId;
  final String? type;
  final DateTime? from;
  final DateTime? to;
  final int page;
  final int limit;

  Map<String, dynamic> toQueryParameters() => {
        if (salePointId != null) 'salePointId': salePointId,
        if (type != null) 'type': type,
        if (from != null) 'from': BusinessTime.toBusinessIso(from!),
        if (to != null) 'to': BusinessTime.toBusinessIso(to!),
        'page': page,
        'limit': limit,
      };
}

abstract interface class MovementsRepository {
  Future<Either<Failure, SellerBalance>> sellerBalance(
    SellerBalanceQuery query,
  );

  Future<Either<Failure, MovementsList>> listMovements(
    ListMovementsQuery query,
  );
}
