import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/create_ticket_request.dart';
import '../../domain/entities/list_tickets_query.dart';
import '../../domain/entities/ticket_detail.dart';
import '../../domain/entities/ticket_receipt.dart';
import '../../domain/entities/ticket_summary.dart';
import '../../domain/entities/tickets_by_draw.dart';
import '../../domain/entities/tickets_summary.dart';
import '../../domain/repositories/tickets_repository.dart';
import '../datasources/tickets_remote_datasource.dart';

class TicketsRepositoryImpl implements TicketsRepository {
  const TicketsRepositoryImpl({required this.remote});

  final TicketsRemoteDatasource remote;

  @override
  Future<Either<Failure, TicketReceipt>> create(
    CreateTicketRequest request,
  ) {
    return _guard(() => remote.create(request));
  }

  @override
  Future<Either<Failure, ListTicketsResult>> list(
    ListTicketsQuery query,
  ) async {
    return _guard(() async {
      final raw = await remote.list(query);
      return ListTicketsResult(
        items: raw.items,
        page: raw.page,
        limit: raw.limit,
        total: raw.total,
      );
    });
  }

  @override
  Future<Either<Failure, TicketDetail>> findById(String id) {
    return _guard(() => remote.findById(id));
  }

  @override
  Future<Either<Failure, TicketDetail>> findByIdForScan(String id) {
    return _guard(() => remote.findByIdForScan(id));
  }

  @override
  Future<Either<Failure, TicketSummary>> voidTicket({
    required String id,
    required String reason,
  }) {
    return _guard(() => remote.voidTicket(id: id, reason: reason));
  }

  @override
  Future<Either<Failure, TicketSummary>> payTicket(String id) {
    return _guard(() => remote.payTicket(id));
  }

  @override
  Future<Either<Failure, TicketsSummary>> summary(TicketsSummaryQuery query) {
    return _guard(() => remote.summary(query));
  }

  @override
  Future<Either<Failure, List<TicketsByDrawItem>>> byDraw(
    TicketsByDrawQuery query,
  ) {
    return _guard(() async {
      final list = await remote.byDraw(query);
      return list.cast<TicketsByDrawItem>();
    });
  }

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
