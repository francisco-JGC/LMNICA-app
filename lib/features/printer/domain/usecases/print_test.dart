import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/printer_repository.dart';

class PrintTest {
  const PrintTest({required this.repository});

  final PrinterRepository repository;

  Future<Either<Failure, Unit>> call(String address) {
    return repository.printTest(address);
  }
}
