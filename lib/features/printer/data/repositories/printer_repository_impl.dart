import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/printer_device.dart';
import '../../domain/entities/ticket_payload.dart';
import '../../domain/repositories/printer_repository.dart';
import '../datasources/printer_bluetooth_datasource.dart';
import '../datasources/printer_local_datasource.dart';
import '../models/printer_device_model.dart';

class PrinterRepositoryImpl implements PrinterRepository {
  const PrinterRepositoryImpl({
    required this.datasource,
    required this.local,
  });

  final PrinterBluetoothDatasource datasource;
  final PrinterLocalDatasource local;

  @override
  Future<Either<Failure, bool>> isBluetoothEnabled() async {
    try {
      final enabled = await datasource.isBluetoothEnabled();
      return Right(enabled);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PrinterDevice>>> getPairedDevices() async {
    try {
      final devices = await datasource.getPairedDevices();
      return Right(devices);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> connect(String address) async {
    try {
      await datasource.connect(address);
      return const Right(unit);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> disconnect() async {
    try {
      await datasource.disconnect();
      return const Right(unit);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isConnected() async {
    try {
      final connected = await datasource.isConnected();
      return Right(connected);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> printTest(String address) async {
    try {
      await datasource.printTest(address);
      return const Right(unit);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> printTicket(String address, TicketPayload payload) async {
    try {
      await datasource.printTicket(address, payload);
      return const Right(unit);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PrinterDevice?>> getLastConnected() async {
    try {
      final device = await local.getLastConnected();
      return Right(device);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveLastConnected(PrinterDevice device) async {
    try {
      await local.saveLastConnected(
        PrinterDeviceModel(name: device.name, address: device.address),
      );
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> clearLastConnected() async {
    try {
      await local.clearLastConnected();
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
