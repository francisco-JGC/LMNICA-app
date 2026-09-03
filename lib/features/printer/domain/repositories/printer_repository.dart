import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/printer_device.dart';
import '../entities/ticket_payload.dart';

abstract interface class PrinterRepository {
  Future<Either<Failure, bool>> isBluetoothEnabled();
  Future<Either<Failure, List<PrinterDevice>>> getPairedDevices();
  Future<Either<Failure, Unit>> connect(String address);
  Future<Either<Failure, Unit>> disconnect();
  Future<Either<Failure, bool>> isConnected();
  Future<Either<Failure, Unit>> printTest(String address);
  Future<Either<Failure, Unit>> printTicket(String address, TicketPayload payload);

  Future<Either<Failure, PrinterDevice?>> getLastConnected();
  Future<Either<Failure, Unit>> saveLastConnected(PrinterDevice device);
  Future<Either<Failure, Unit>> clearLastConnected();
}
