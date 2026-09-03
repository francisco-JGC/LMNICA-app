import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/ticket_payload.dart';
import '../repositories/printer_repository.dart';

class PrintTicket {
  const PrintTicket({required this.repository});

  final PrinterRepository repository;

  Future<Either<Failure, Unit>> call(String address, TicketPayload payload) {
    return repository.printTicket(address, payload);
  }
}
