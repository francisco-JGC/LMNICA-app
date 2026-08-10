import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/printer_device.dart';
import '../../domain/entities/ticket_payload.dart';
import '../../domain/repositories/printer_repository.dart';
import 'printer_state.dart';

enum _PermissionOutcome { granted, denied, permanentlyDenied }

// NOTE: we do NOT poll the printer's connection status via probe writes.
// Cheap SPP thermal printers interpret the probe bytes as raw data and
// slowly feed paper. Print failures surface a broken socket lazily.
// El polling adaptativo de RECONNECT (abajo) es distinto: no toca la
// impresora, solo revisa el flag `bluetoothEnabled` del sistema y reintenta
// conectar si volvió a estar disponible.

/// Cada cuánto reintenta autoReconnect cuando la impresora está
/// desconectada. 4s es agresivo pero necesario: el vendedor típico
/// prende la impresora DESPUÉS de haber abierto la app, y con 8s la
/// espera se sentía eterna. El datasource ya tiene timeouts para que
/// un intento fallido libere el guard rápido (`_isReconnecting`) y el
/// siguiente tick pueda pegarle en cuanto la impresora vuelva.
const _kReconnectPollInterval = Duration(seconds: 4);

class PrinterController extends Notifier<PrinterState> {
  late final _repository = getIt<PrinterRepository>();
  Timer? _reconnectTimer;

  /// Evita que dos autoReconnect corran solapados: el `connect()` de BT
  /// puede tardar 5-15s en fallar y nuestro tick es cada 8s, así que sin
  /// esta guarda podríamos apilar intentos y pisarnos el estado.
  bool _isReconnecting = false;

  @override
  PrinterState build() {
    // Timer siempre corre autoReconnect — dentro decide qué hacer según el
    // estado real del plugin. La diferencia con el diseño anterior es que
    // no confiamos en `state.isConnected` como gate: si el estado dice
    // "conectado" pero el plugin dice que no (típico después de logout,
    // background largo, o BT toggle), autoReconnect detecta el desajuste
    // y reintenta. Antes ese caso quedaba varado hasta que el usuario
    // apretaba imprimir y fallaba.
    _reconnectTimer = Timer.periodic(_kReconnectPollInterval, (_) {
      autoReconnect();
    });
    ref.onDispose(() {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    });
    return const PrinterState.initial();
  }

  Future<void> autoReconnect() async {
    if (_isReconnecting) return;
    _isReconnecting = true;
    try {
      final connectedResult = await _repository.isConnected();
      final pluginConnected = connectedResult.getOrElse((_) => false);
      final stateConnected = state.connectedDevice != null;

      // Caso feliz: ambos coinciden en conectado → nada que hacer.
      if (pluginConnected && stateConnected) return;

      // Plugin conectado pero el state no lo sabe (típico después de
      // rebuild o app resume). Adoptamos el last-connected para que la
      // UI refleje la realidad. Sincronización en dirección segura.
      if (pluginConnected && !stateConnected) {
        final lastResult = await _repository.getLastConnected();
        final last = lastResult.getOrElse((_) => null);
        if (last != null) {
          state = state.copyWith(connectedDevice: last);
        }
        return;
      }

      // Plugin dice desconectado. NO forzamos disconnect en el state
      // basados solo en esto: `connectionStatus` en algunos SPP baratos
      // da false-negatives (dice "no conectado" cuando el socket sigue
      // vivo). Confiar en ese signal y limpiar el state cada 8s haría
      // que vendedores con BT flaky se coman ciclos de reconexión que
      // rompen una impresora que estaba andando bien.
      //
      // La recuperación real cuando el state está stale ocurre en el
      // camino `printTicket` → falla al escribir → `clearConnectedDevice`
      // → `autoReconnect` inmediato. Ese es el disparador confiable.
      //
      // Acá solo intentamos reconectar cuando el state YA sabe que
      // estamos desconectados (state.connectedDevice == null), que es
      // el caso post-arranque de app, post-fallo de impresión, o post-
      // pérdida explícita de conexión.
      if (stateConnected) return;

      final btResult = await _repository.isBluetoothEnabled();
      if (!btResult.getOrElse((_) => false)) return;

      final lastResult = await _repository.getLastConnected();
      final last = lastResult.getOrElse((_) => null);
      if (last == null) return;

      final connectResult = await _repository.connect(last.address);
      connectResult.match(
        (_) {},
        (_) => state = state.copyWith(connectedDevice: last),
      );
    } catch (_) {
      // Silent: auto-reconnect never surfaces errors to the UI.
    } finally {
      _isReconnecting = false;
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
      (devices) {
        state = state.copyWith(
          status: PrinterStatus.ready,
          bluetoothEnabled: true,
          devices: devices,
        );
      },
    );

    if (state.isConnected) return;

    final lastResult = await _repository.getLastConnected();
    final last = lastResult.getOrElse((_) => null);
    if (last == null) return;
    final knownDevice = state.devices.firstWhere(
      (d) => d.address == last.address,
      orElse: () => last,
    );
    await _silentConnect(knownDevice);
  }

  Future<void> connect(PrinterDevice device) async {
    state = state.copyWith(isConnecting: true, clearError: true);
    final result = await _repository.connect(device.address);
    await result.match(
      (failure) async {
        state = state.copyWith(
          isConnecting: false,
          errorMessage: failure.message,
        );
      },
      (_) async {
        await _repository.saveLastConnected(device);
        state = state.copyWith(
          isConnecting: false,
          connectedDevice: device,
        );
      },
    );
  }

  Future<void> disconnect() async {
    final result = await _repository.disconnect();
    result.match(
      (failure) => state = state.copyWith(errorMessage: failure.message),
      (_) => state = state.copyWith(clearConnectedDevice: true),
    );
  }

  Future<void> forgetPrinter() async {
    await _repository.disconnect();
    await _repository.clearLastConnected();
    state = state.copyWith(clearConnectedDevice: true);
  }

  Future<void> printTest() async {
    state = state.copyWith(isPrinting: true, clearError: true);
    final result = await _repository.printTest();
    result.match(
      // Un fallo en imprimir suele significar socket muerto (impresora
      // apagada, sin batería, fuera de rango). Limpiamos `connectedDevice`
      // y disparamos un autoReconnect inmediato — sin esperar el próximo
      // tick del timer (hasta 8s) — para que el vendedor tenga la
      // impresora lista lo antes posible cuando vuelva a intentar.
      (failure) {
        state = state.copyWith(
          isPrinting: false,
          errorMessage: failure.message,
          clearConnectedDevice: true,
        );
        Future.microtask(autoReconnect);
      },
      (_) => state = state.copyWith(isPrinting: false),
    );
  }

  Future<void> printTicket(TicketPayload payload) async {
    state = state.copyWith(isPrinting: true, clearError: true);
    final result = await _repository.printTicket(payload);
    result.match(
      // Ver comentario en printTest — misma lógica.
      (failure) {
        state = state.copyWith(
          isPrinting: false,
          errorMessage: failure.message,
          clearConnectedDevice: true,
        );
        Future.microtask(autoReconnect);
      },
      (_) => state = state.copyWith(isPrinting: false),
    );
  }

  Future<void> openSystemSettings() => openAppSettings();

  Future<void> _silentConnect(PrinterDevice device) async {
    final result = await _repository.connect(device.address);
    result.match(
      (_) {},
      (_) => state = state.copyWith(connectedDevice: device),
    );
  }

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
