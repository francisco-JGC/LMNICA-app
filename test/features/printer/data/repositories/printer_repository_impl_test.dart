import 'package:flutter_test/flutter_test.dart';
import 'package:loteria_client_app/core/errors/failures.dart';
import 'package:loteria_client_app/features/printer/data/datasources/printer_bluetooth_datasource.dart';
import 'package:loteria_client_app/features/printer/data/datasources/printer_local_datasource.dart';
import 'package:loteria_client_app/features/printer/data/models/printer_device_model.dart';
import 'package:loteria_client_app/features/printer/data/repositories/printer_repository_impl.dart';
import 'package:loteria_client_app/features/printer/domain/entities/ticket_payload.dart';
import 'package:mocktail/mocktail.dart';

class _MockBluetooth extends Mock implements PrinterBluetoothDatasource {}

class _MockLocal extends Mock implements PrinterLocalDatasource {}

class _FakePayload extends Fake implements TicketPayload {}

class _FakeDeviceModel extends Fake implements PrinterDeviceModel {}

void main() {
  late _MockBluetooth bluetooth;
  late _MockLocal local;
  late PrinterRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(_FakePayload());
    registerFallbackValue(_FakeDeviceModel());
  });

  setUp(() {
    bluetooth = _MockBluetooth();
    local = _MockLocal();
    repository = PrinterRepositoryImpl(datasource: bluetooth, local: local);
  });

  test('getPairedDevices returns Right with devices', () async {
    const devices = [
      PrinterDeviceModel(name: 'Xprinter', address: '00:11:22:33:44:55'),
    ];
    when(() => bluetooth.getPairedDevices()).thenAnswer((_) async => devices);

    final result = await repository.getPairedDevices();

    expect(result.isRight(), isTrue);
    result.match(
      (_) => fail('expected Right'),
      (list) => expect(list, devices),
    );
  });

  test('getPairedDevices returns UnexpectedFailure when datasource throws',
      () async {
    when(() => bluetooth.getPairedDevices()).thenThrow(Exception('boom'));

    final result = await repository.getPairedDevices();

    expect(result.isLeft(), isTrue);
    result.match(
      (f) => expect(f, isA<UnexpectedFailure>()),
      (_) => fail('expected Left'),
    );
  });

  test('connect returns Right(unit) on success', () async {
    when(() => bluetooth.connect(any())).thenAnswer((_) async {});

    final result = await repository.connect('00:11:22');

    expect(result.isRight(), isTrue);
    verify(() => bluetooth.connect('00:11:22')).called(1);
  });

  test('connect returns UnexpectedFailure when datasource throws', () async {
    when(() => bluetooth.connect(any())).thenThrow(Exception('fail'));

    final result = await repository.connect('00:11:22');

    expect(result.isLeft(), isTrue);
  });

  test('printTest returns Right(unit) on success', () async {
    when(() => bluetooth.printTest(any())).thenAnswer((_) async {});

    final result = await repository.printTest('AA:BB:CC:DD:EE:FF');

    expect(result.isRight(), isTrue);
    verify(() => bluetooth.printTest('AA:BB:CC:DD:EE:FF')).called(1);
  });

  test('printTicket delegates to datasource and returns Right(unit)',
      () async {
    when(() => bluetooth.printTicket(any(), any())).thenAnswer((_) async {});
    const address = 'AA:BB:CC:DD:EE:FF';
    final payload = TicketPayload(
      id: 'test-id',
      gameId: 'diaria',
      gameSlug: 'diaria',
      gameName: 'Diaria',
      lines: const [
        TicketLine(number: '12', amount: 100, prize: 8000),
        TicketLine(number: '34', amount: 100, prize: 8000),
      ],
      folio: 'ABC-001',
      date: DateTime(2026, 7, 10, 15, 30),
    );

    final result = await repository.printTicket(address, payload);

    expect(result.isRight(), isTrue);
    verify(() => bluetooth.printTicket(address, payload)).called(1);
  });

  test('getLastConnected returns Right(null) when nothing stored', () async {
    when(() => local.getLastConnected()).thenAnswer((_) async => null);

    final result = await repository.getLastConnected();

    result.match(
      (_) => fail('expected Right'),
      (device) => expect(device, isNull),
    );
  });

  test('saveLastConnected persists via local datasource', () async {
    when(() => local.saveLastConnected(any())).thenAnswer((_) async {});
    const device = PrinterDeviceModel(name: 'Xprinter', address: '00:11:22');

    final result = await repository.saveLastConnected(device);

    expect(result.isRight(), isTrue);
    verify(() => local.saveLastConnected(any())).called(1);
  });

  test('clearLastConnected calls local.clearLastConnected', () async {
    when(() => local.clearLastConnected()).thenAnswer((_) async {});

    final result = await repository.clearLastConnected();

    expect(result.isRight(), isTrue);
    verify(() => local.clearLastConnected()).called(1);
  });
}
