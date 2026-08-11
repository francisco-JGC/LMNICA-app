import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/create_ticket_request.dart';
import '../entities/list_tickets_query.dart';
import '../entities/ticket_detail.dart';
import '../entities/ticket_receipt.dart';
import '../entities/ticket_summary.dart';
import '../entities/tickets_by_draw.dart';
import '../entities/tickets_summary.dart';

abstract interface class TicketsRepository {
  Future<Either<Failure, TicketReceipt>> create(CreateTicketRequest request);
  Future<Either<Failure, ListTicketsResult>> list(ListTicketsQuery query);
  Future<Either<Failure, TicketDetail>> findById(String id);
  /// Lookup específico para escaneo de QR — sin restricción de dueño.
  Future<Either<Failure, TicketDetail>> findByIdForScan(String id);
  Future<Either<Failure, TicketSummary>> voidTicket({
    required String id,
    required String reason,
  });
  Future<Either<Failure, TicketSummary>> payTicket(String id);
  Future<Either<Failure, TicketsSummary>> summary(TicketsSummaryQuery query);
  Future<Either<Failure, List<TicketsByDrawItem>>> byDraw(
    TicketsByDrawQuery query,
  );
}
