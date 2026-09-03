import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/printer_device.dart';
import '../../domain/entities/ticket_payload.dart';
import '../../domain/repositories/printer_repository.dart';
import 'printer_state.dart';

enum _PermissionOutcome { granted, denied, permanentlyDenied }

// Modelo connect-to-print: no se mantiene un socket BT persistente.
// Cada llamada a printTicket / printTest abre la conexión, imprime y
// la cierra en el datasource. Esto permite que múltiples dispositivos
// compartan la misma impresora sin conflictos de socket.

class PrinterController extends Notifier<PrinterState> {
  late final _repository = getIt<PrinterRepository>();

  @override
  PrinterState build() {
    // Carga la impresora configurada desde storage local sin bloquear el UI.
    Future.microtask(_loadConfiguredDevice);
    return const PrinterState.initial();
  }

  Future<void> _loadConfiguredDevice() async {
    final lastResult = await _repository.getLastConnected();
    final last = lastResult.getOrElse((_) => null);
    if (last != null) {
      state = state.copyWith(connectedDevice: last);
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(
      status: PrinterStatus.loading,
      clearError: true,
      needsSettings: false,
    );

    final outcome = await _ensurePermissions();
    switch (outcome) {
      case _PermissionOutcome.permanentlyDenied:
        state = state.copyWith(
          status: PrinterStatus.error,
          errorMessage:
              'Los permisos de Bluetooth están bloqueados. Ábrelos desde Ajustes de la app.',
          needsSettings: true,
        );
        return;
      case _PermissionOutcome.denied:
        state = state.copyWith(
          status: PrinterStatus.error,
          errorMessage: 'Se requieren permisos de Bluetooth para continuar.',
        );
        return;
      case _PermissionOutcome.granted:
        break;
    }

    final btResult = await _repository.isBluetoothEnabled();
    final btEnabled = btResult.getOrElse((_) => false);

    if (!btEnabled) {
      state = state.copyWith(
        status: PrinterStatus.ready,
        bluetoothEnabled: false,
        devices: const [],
      );
      return;
    }

    final devicesResult = await _repository.getPairedDevices();
    devicesResult.match(
      (failure) => state = state.copyWith(
        status: PrinterStatus.error,
        bluetoothEnabled: true,
        errorMessage: failure.message,
      ),
      (devices) => state = state.copyWith(
        status: PrinterStatus.ready,
        bluetoothEnabled: true,
        devices: devices,
      ),
    );

    // Restaura la impresora configurada (sin abrir socket BT).
    final lastResult = await _repository.getLastConnected();
    final last = lastResult.getOrElse((_) => null);
    if (last != null) {
      state = state.copyWith(connectedDevice: last);
    }
  }

  /// Configura una impresora como preferida. Solo guarda la dirección en
  /// storage local — no abre ningún socket Bluetooth. La conexión real
  /// ocurre solo al imprimir.
  Future<void> connect(PrinterDevice device) async {
    state = state.copyWith(isConnecting: true, clearError: true);
    await _repository.saveLastConnected(device);
    state = state.copyWith(isConnecting: false, connectedDevice: device);
  }

  /// Olvida la impresora configurada. No hay socket que cerrar.
  Future<void> disconnect() async {
    state = state.copyWith(clearConnectedDevice: true);
  }

  Future<void> forgetPrinter() async {
    await _repository.clearLastConnected();
    state = state.copyWith(clearConnectedDevice: true);
  }

  Future<void> printTest() async {
    final address = state.connectedDevice?.address;
    if (address == null) {
      state = state.copyWith(errorMessage: 'No hay impresora configurada.');
      return;
    }
    state = state.copyWith(isPrinting: true, clearError: true);
    final result = await _repository.printTest(address);
    final failure = result.fold<String?>((f) => f.message, (_) => null);
    state = state.copyWith(isPrinting: false, errorMessage: failure);
  }

  Future<void> printTicket(TicketPayload payload) async {
    final address = state.connectedDevice?.address;
    if (address == null) {
      state = state.copyWith(errorMessage: 'No hay impresora configurada.');
      return;
    }
    state = state.copyWith(isPrinting: true, clearError: true);
    final result = await _repository.printTicket(address, payload);
    final failure = result.fold<String?>((f) => f.message, (_) => null);
    state = state.copyWith(isPrinting: false, errorMessage: failure);
  }

  /// Verifica si hay una impresora configurada. Con el modelo connect-to-print
  /// no hay socket que verificar; si el address existe, el intento de impresión
  /// se realiza y cualquier fallo se reporta en ese momento.
  Future<bool> verifyConnectedOrReconnect() async {
    return state.connectedDevice != null;
  }

  Future<void> openSystemSettings() => openAppSettings();

  Future<_PermissionOutcome> _ensurePermissions() async {
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    final statuses = await permissions.request();

    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      return _PermissionOutcome.permanentlyDenied;
    }

    final btScanOk =
        statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final btConnectOk =
        statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    final locationOk =
        statuses[Permission.locationWhenInUse]?.isGranted ?? false;

    final android12Plus = btScanOk && btConnectOk;
    final legacyAndroid = locationOk;

    if (android12Plus || legacyAndroid) {
      return _PermissionOutcome.granted;
    }
    return _PermissionOutcome.denied;
  }
}

final printerControllerProvider =
    NotifierProvider<PrinterController, PrinterState>(PrinterController.new);
