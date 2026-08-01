import 'dart:convert';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../../core/utils/currency.dart';
import '../../domain/entities/ticket_payload.dart';
import '../models/printer_device_model.dart';

abstract interface class PrinterBluetoothDatasource {
  Future<bool> isBluetoothEnabled();
  Future<List<PrinterDeviceModel>> getPairedDevices();
  Future<void> connect(String address);
  Future<void> disconnect();
  Future<bool> isConnected();
  Future<void> printTest();
  Future<void> printTicket(TicketPayload payload);
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

  @override
  Future<void> connect(String address) async {
    // Force disconnect first — the plugin can hold a stale handle that
    // makes a fresh connect() return false immediately.
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {
      // Ignore: no active connection.
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final ok =
        await PrintBluetoothThermal.connect(macPrinterAddress: address);
    if (!ok) {
      throw Exception('No fue posible conectar a la impresora');
    }
  }

  @override
  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
  }

  @override
  Future<bool> isConnected() {
    return PrintBluetoothThermal.connectionStatus;
  }

  @override
  Future<void> printTest() async {
    final bytes = await _buildTestBytes();
    await _write(bytes);
  }

  @override
  Future<void> printTicket(TicketPayload payload) async {
    final bytes = await _buildTicketBytes(payload);
    await _write(bytes);
  }

  Future<void> _write(List<int> bytes) async {
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) {
      throw Exception('No fue posible enviar los datos a la impresora');
    }
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

  Future<List<int>> _buildTicketBytes(TicketPayload p) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(PaperSize.mm58, profile);
    final dateOnly = DateFormat('dd/MM/yyyy');
    final shortDate = DateFormat('dd/MM');
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
    String formatDrawHint(DateTime d) {
      final local = d.toLocal();
      final t = DateFormat('h:mm a', 'en_US').format(local).toLowerCase();
      final now = DateTime.now();
      final sameDay = local.year == now.year &&
          local.month == now.month &&
          local.day == now.day;
      return sameDay ? t : '${shortDate.format(local)} $t';
    }
    final money = kAmountFormat;

    const infoStyle = PosStyles(bold: true, align: PosAlign.left);
    const infoRight = PosStyles(bold: true, align: PosAlign.right);
    const numberStyle = PosStyles(
      bold: true,
      height: PosTextSize.size2,
      align: PosAlign.left,
    );
    const numberRight = PosStyles(
      bold: true,
      height: PosTextSize.size2,
      align: PosAlign.right,
    );
    PosColumn gutter() => PosColumn(text: '', width: 1);

    return [
      ...g.reset(),
      ...g.setStyles(const PosStyles(align: PosAlign.left)),
      ...g.text('  Folio: ${p.folio}', styles: infoStyle),
      ...g.text('  Fecha: ${formatDateTime(p.date)}', styles: infoStyle),
      ...g.text(
        '  Sorteo: ${p.gameName}'
        '${p.drawAt != null ? ' - ${formatDrawHint(p.drawAt!)}' : ''}',
        styles: infoStyle,
      ),
      if (p.seller != null)
        ...g.text('  Vendedor: ${p.seller}', styles: infoStyle),
      if (p.client != null)
        ...g.text('  Cliente: ${p.client}', styles: infoStyle),
      ...g.hr(),
      ...g.row([
        gutter(),
        PosColumn(text: 'No.', width: 3, styles: infoStyle),
        PosColumn(text: 'Monto', width: 3, styles: infoRight),
        PosColumn(text: 'Premio', width: 4, styles: infoRight),
        gutter(),
      ]),
      for (var i = 0; i < p.lines.length; i++) ...[
        if (p.lines[i].subGameName != null &&
            (i == 0 ||
                p.lines[i - 1].subGameName != p.lines[i].subGameName)) ...[
          if (i > 0) ...g.feed(1),
          ...g.text(
            '  -- ${p.lines[i].subGameName!.toUpperCase()} --',
            styles: const PosStyles(bold: true),
          ),
        ],
        ...g.row([
          gutter(),
          PosColumn(text: p.lines[i].number, width: 3, styles: numberStyle),
          PosColumn(
            text: money.format(p.lines[i].amount),
            width: 3,
            styles: numberRight,
          ),
          PosColumn(
            text: money.format(p.lines[i].prize),
            width: 4,
            styles: numberRight,
          ),
          gutter(),
        ]),
      ],
      ...g.hr(),
      ...g.row([
        gutter(),
        PosColumn(text: 'TOTAL', width: 5, styles: infoStyle),
        PosColumn(
          text: money.format(p.total),
          width: 5,
          styles: infoRight,
        ),
        gutter(),
      ]),
      ...g.hr(),
      ...g.text(
        'Boleto valido para 1 sorteo',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
      ...g.text(
        'Por favor revisar su compra',
        styles: const PosStyles(align: PosAlign.center),
      ),
      ...g.text(
        'No se aceptan devoluciones',
        styles: const PosStyles(align: PosAlign.center),
      ),
      ..._safeQrCode(g, p.toQrData(), moduleSize: 4),
      if (p.footer != null)
        ...g.text(
          '  ${p.footer}  ',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      ...g.emptyLines(2),
      // GS V 0: full cut without the extra 5-line feed that g.cut() adds.
      0x1D, 0x56, 0x00,
    ];
  }

}
