import 'dart:async';
import 'dart:convert';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../../core/utils/currency.dart';
import '../../../../core/utils/printer_text.dart';
import '../../domain/entities/ticket_payload.dart';
import '../models/printer_device_model.dart';

abstract interface class PrinterBluetoothDatasource {
  Future<bool> isBluetoothEnabled();
  Future<List<PrinterDeviceModel>> getPairedDevices();
  Future<void> connect(String address);
  Future<void> disconnect();
  Future<bool> isConnected();
  Future<void> printTest(String address);
  Future<void> printTicket(String address, TicketPayload payload, {bool isSmartPos = false});
}

class PrinterBluetoothDatasourceImpl implements PrinterBluetoothDatasource {
  const PrinterBluetoothDatasourceImpl();

  @override
  Future<bool> isBluetoothEnabled() {
    return PrintBluetoothThermal.bluetoothEnabled;
  }

  @override
  Future<List<PrinterDeviceModel>> getPairedDevices() async {
    final devices = await PrintBluetoothThermal.pairedBluetooths;
    return devices
        .map((d) => PrinterDeviceModel(name: d.name, address: d.macAdress))
        .toList();
  }

  // Timeouts para los llamados nativos del plugin. Sin esto, `connect()` a
  // una impresora apagada puede quedar colgado indefinidamente en algunos
  // devices Android, y el `_isReconnecting` guard del controller impide
  // que el timer intente de nuevo. Con timeout, forzamos el fallo rápido
  // y liberamos el ciclo de reconexión.
  static const _kConnectTimeout = Duration(seconds: 10);
  static const _kDisconnectTimeout = Duration(seconds: 3);
  static const _kWriteTimeout = Duration(seconds: 15);

  @override
  Future<void> connect(String address) async {
    // Force disconnect first — the plugin can hold a stale handle that
    // makes a fresh connect() return false immediately.
    try {
      await PrintBluetoothThermal.disconnect.timeout(_kDisconnectTimeout);
    } catch (_) {
      // Ignore: no active connection or disconnect hung. Continuamos igual.
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final bool ok;
    try {
      ok = await PrintBluetoothThermal.connect(macPrinterAddress: address)
          .timeout(_kConnectTimeout);
    } on TimeoutException {
      throw Exception(
        'La conexión a la impresora tardó demasiado (¿apagada o fuera de rango?)',
      );
    }
    if (!ok) {
      throw Exception('No fue posible conectar a la impresora');
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect.timeout(_kDisconnectTimeout);
    } on TimeoutException {
      // Silent: el plugin colgó. Nada más que podamos hacer.
    }
  }

  @override
  Future<bool> isConnected() {
    return PrintBluetoothThermal.connectionStatus;
  }

  @override
  Future<void> printTest(String address) async {
    await connect(address);
    try {
      final bytes = await _buildTestBytes();
      await _write(bytes);
    } finally {
      try { await disconnect(); } catch (_) {}
    }
  }

  @override
  Future<void> printTicket(String address, TicketPayload payload, {bool isSmartPos = false}) async {
    await connect(address);
    try {
      final bytes = await _buildTicketBytes(payload, isSmartPos: isSmartPos);
      await _write(bytes);
    } finally {
      try { await disconnect(); } catch (_) {}
    }
  }

  Future<void> _write(List<int> bytes) async {
    final ok = await PrintBluetoothThermal.writeBytes(bytes)
        .timeout(_kWriteTimeout, onTimeout: () => false);
    if (!ok) {
      throw Exception('No fue posible enviar los datos a la impresora');
    }
    // `writeBytes` retorna cuando los bytes llegan al buffer BT, no cuando
    // la impresora termina de procesarlos. Esperamos proporcional al tamaño:
    // ~40 bytes/ms es conservador para 58mm a 80 mm/s; mínimo 1.5 s,
    // máximo 12 s para tickets muy grandes.
    final waitMs = (bytes.length / 40).ceil().clamp(1500, 12000);
    await Future<void>.delayed(Duration(milliseconds: waitMs));
  }

  List<int> _safeQrCode(Generator g, String text, {int moduleSize = 6}) {
    final data = utf8.encode(text);
    final storeLen = data.length + 3;
    final pL = storeLen & 0xFF;
    final pH = (storeLen >> 8) & 0xFF;

    return [
      ...g.setStyles(const PosStyles(align: PosAlign.center)),
      0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00,
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, moduleSize,
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x30,
      0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30,
      ...data,
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30,
      ...g.setStyles(const PosStyles(align: PosAlign.left)),
    ];
  }

  Future<List<int>> _buildTestBytes() async {
    final profile = await CapabilityProfile.load();
    final g = Generator(PaperSize.mm58, profile);
    return [
      ...g.text(
        'LOTERIA',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ),
      ),
      ...g.hr(),
      ...g.text(
        'Prueba de impresion',
        styles: const PosStyles(align: PosAlign.center),
      ),
      ...g.hr(),
      ...g.text('Si puedes leer esto,'),
      ...g.text('la impresora esta lista.'),
      ...g.feed(2),
      ...g.cut(),
    ];
  }

  Future<List<int>> _buildTicketBytes(TicketPayload p, {bool isSmartPos = false}) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(PaperSize.mm58, profile);
    final dateOnly = DateFormat('dd/MM/yyyy');
    // `.toLocal()` es obligatorio: los DateTime que vienen del backend
    // (reimpresiones, reenvíos) llegan en UTC. Sin convertir a hora local
    // el ticket físico salía con la hora adelantada 6h (offset UTC-6 de
    // Managua). En una venta nueva `DateTime.now()` ya es local, así que
    // `.toLocal()` es un no-op y es seguro llamarlo siempre.
    String formatDateTime(DateTime d) {
      final local = d.toLocal();
      final t = DateFormat('h:mm a', 'en_US').format(local).toLowerCase();
      return '${dateOnly.format(local)} $t';
    }
    final money = kAmountFormat;
    // Premio sin símbolo de moneda para que quepa en la columna estrecha.
    final prize = NumberFormat('#0', 'en_US');

    // Sanitizamos campos alimentados por el usuario (nombre del vendedor,
    // sucursal, cliente, footer) porque el codec ESC/POS rechaza codepoints
    // fuera del codepage (emojis, símbolos raros) con `ArgumentError:
    // Contains invalid characters`, y toda la impresión falla. Ver
    // `printer_text.dart` para el detalle.
    final salePoint = sanitizeForPrinter(p.salePoint);
    final seller = sanitizeForPrinter(p.seller);
    final client = sanitizeForPrinter(p.client);
    final gameName = sanitizeForPrinter(p.gameName);
    final footer = sanitizeForPrinter(p.footer);

    // Banner para reimpresiones/reenvíos — el cliente sabe que el papel
    // no es una venta nueva.
    final copyBanner = switch (p.copyKind) {
      TicketCopyKind.reprint => 'RECIBO DE COPIA',
      TicketCopyKind.resend => 'BOLETO REENVIADO',
      TicketCopyKind.original => null,
    };

    // --- Formato de columnas ---
    // Papel mm58 = 32 columnas en size1, 16 columnas en size2.
    // Dividimos en tres secciones de igual ancho físico:
    //   Física 0-11  → size1: 12 chars  |  size2: 6 chars
    //   Física 12-21 → size1: 10 chars  |  size2: 5 chars
    //   Física 22-31 → size1: 10 chars  |  size2: 5 chars
    //
    // Usamos g.text() con strings preformateados en lugar de g.row() para
    // evitar el problema de SmartPOS: g.row() emite ESC ! (cambio de modo)
    // dentro de la línea por cada columna; muchos SmartPOS lo procesan como
    // comando de "línea siguiente" en vez de inline, desalineando las
    // columnas y mezclando los números.
    String rowSize1(String left, String mid, String right) =>
        _colFit(left, 12, left: true) +
        _colCenter(mid, 10) +
        _colFit(right, 10, left: false);

    String rowSize2(String left, String mid, String right) =>
        _colFit(left, 6, left: true) +
        _colCenter(mid, 5) +
        _colFit(right, 5, left: false);

    // shiftLeft: número + monto anchos → todo izquierda para evitar solapamiento
    String rowSize2Left(String left, String mid, String right) =>
        _colFit(left, 6, left: true) +
        _colFit(mid, 5, left: true) +
        _colFit(right, 5, left: true);

    return [
      ...g.clearStyle(),
      ...g.setStyles(const PosStyles(align: PosAlign.center)),
      if (copyBanner != null)
        ...g.text(copyBanner, styles: const PosStyles(bold: true, align: PosAlign.center)),
      ...g.text('Folio: ${p.folio}', styles: const PosStyles(bold: true, align: PosAlign.center)),
      ...g.text('Fecha: ${formatDateTime(p.date)}', styles: const PosStyles(bold: true, align: PosAlign.center)),
      ...g.text('Juego: $gameName', styles: const PosStyles(bold: true, align: PosAlign.center)),
      if (p.drawAt != null)
        ...g.text(
          'Sorteo: ${DateFormat('h:mm a', 'en_US').format(p.drawAt!.toLocal()).toLowerCase()}',
          styles: const PosStyles(bold: true, align: PosAlign.center),
        ),
      ...g.text('Cliente: $client', styles: const PosStyles(bold: true, align: PosAlign.center)),
      if (salePoint.isNotEmpty)
        ...g.text('Puesto: $salePoint', styles: const PosStyles(bold: true, align: PosAlign.center)),
      if (seller.isNotEmpty)
        ...g.text('Vendedor: $seller', styles: const PosStyles(bold: true, align: PosAlign.center)),
      ..._dashedLine(g),
      ...g.text(
        rowSize1('Apuesta', 'Monto', p.isFourDigit ? 'Tipo' : 'Premio'),
        styles: const PosStyles(bold: true, align: PosAlign.left),
      ),
      ..._dashedLine(g),
      for (var i = 0; i < p.lines.length; i++) ...[
        if (p.lines[i].subGameName != null &&
            (i == 0 ||
                p.lines[i - 1].subGameName != p.lines[i].subGameName)) ...[
          if (i > 0) ...g.feed(1),
          ...g.text(
            '  -- ${sanitizeForPrinter(p.lines[i].subGameName).toUpperCase()} --',
            styles: const PosStyles(bold: true),
          ),
        ],
        // Juegos de fecha: etiquetas largas ("01 Ene") → size1 siempre.
        // Juegos de número: size2 (BT normal) o size1 (SmartPOS que ignora
        // el comando de ancho doble ESC/POS).
        ...(() {
          if (p.isDate || isSmartPos) {
            return g.text(
              rowSize1(
                p.lines[i].number,
                money.format(p.lines[i].amount),
                p.isFourDigit ? 'E' : prize.format(p.lines[i].prize),
              ),
              styles: const PosStyles(bold: true, align: PosAlign.left),
            );
          }
          // shiftLeft: monto > 2 dígitos (>=100) Y premio > 4 dígitos (>=10000)
          // → todo izquierda para que no se superponga en los 5 chars del size2.
          final shiftLeft = !p.isFourDigit
              && p.lines[i].amount > 99
              && p.lines[i].prize > 9999;
          final prizeText = p.isFourDigit ? 'E' : prize.format(p.lines[i].prize);
          return g.text(
            shiftLeft
                ? rowSize2Left(p.lines[i].number, money.format(p.lines[i].amount), prizeText)
                : rowSize2(p.lines[i].number, money.format(p.lines[i].amount), prizeText),
            styles: const PosStyles(bold: true, width: PosTextSize.size2, align: PosAlign.left),
          );
        })(),
      ],
      ..._dashedLine(g),
      ...g.text(
        'TOTAL: ${kCurrencyFormat.format(p.total)}',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
      ...g.emptyLines(1),
      ...g.text(
        'Valido para 1 sorteo',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
      ...g.text(
        'Por favor revise su boleto',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
      ...g.text(
        'Premio valido por 7 dias',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
      ...g.emptyLines(1),
      ..._safeQrCode(g, p.toQrData(), moduleSize: 4),
      if (footer.isNotEmpty)
        ...g.text(
          '  $footer  ',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      ...g.emptyLines(1),
      // GS V 0: full cut without the extra 5-line feed that g.cut() adds.
      0x1D, 0x56, 0x00,
    ];
  }

  /// Línea de 32 guiones para delimitar visualmente la tabla de jugadas.
  List<int> _dashedLine(Generator g) {
    const dashed = '--------------------------------';
    return g.text(dashed, styles: const PosStyles(align: PosAlign.center));
  }

  /// Ajusta [s] a exactamente [width] chars: trunca si es más largo,
  /// rellena con espacios si es más corto. [left] = true → alineación
  /// izquierda; false → alineación derecha.
  static String _colFit(String s, int width, {required bool left}) {
    if (s.length >= width) return s.substring(0, width);
    return left ? s.padRight(width) : s.padLeft(width);
  }

  /// Centra [s] dentro de [width] chars, rellena con espacios.
  static String _colCenter(String s, int width) {
    if (s.length >= width) return s.substring(0, width);
    final pad = width - s.length;
    final lPad = pad ~/ 2;
    return '${' ' * lPad}$s${' ' * (pad - lPad)}';
  }
}
