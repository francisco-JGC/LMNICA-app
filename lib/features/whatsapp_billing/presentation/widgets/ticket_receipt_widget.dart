import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/utils/currency.dart';
import '../../../printer/domain/entities/ticket_payload.dart';

/// Replica visual del ticket térmico impreso por
/// `printer_bluetooth_datasource._buildTicketBytes`. La regla es: **misma
/// información y en el mismo orden** — sin agregados ni logos. Si algo
/// cambia en el ticket físico, este widget también debe cambiar.
///
/// Se envuelve en `RepaintBoundary` desde el llamador; acá solo definimos
/// la vista pura.
class TicketReceiptWidget extends StatelessWidget {
  const TicketReceiptWidget({
    required this.payload,
    super.key,
  });

  final TicketPayload payload;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InfoBlock(payload: payload),
            const SizedBox(height: 12),
            const _SolidDivider(),
            const SizedBox(height: 8),
            _LinesTable(lines: payload.lines),
            const SizedBox(height: 8),
            const _SolidDivider(),
            const SizedBox(height: 8),
            _TotalRow(total: payload.total),
            const SizedBox(height: 8),
            const _SolidDivider(),
            const SizedBox(height: 12),
            const _CenteredNote(
              text: 'Boleto valido para 1 sorteo',
              bold: true,
            ),
            const _CenteredNote(text: 'Por favor revisar su compra'),
            const _CenteredNote(text: 'No se aceptan devoluciones'),
            const SizedBox(height: 16),
            _QrBlock(data: payload.toQrData()),
            if (payload.footer != null && payload.footer!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _CenteredNote(text: payload.footer!, bold: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.payload});
  final TicketPayload payload;

  @override
  Widget build(BuildContext context) {
    // La fecha del ticket y el sorteo se muestran en la hora LOCAL del
    // dispositivo (mismo criterio que el ticket físico, que llama
    // `.toLocal()` antes de formatear). Sin esto los DateTime UTC del
    // backend salían con offset UTC — un ticket a las 3pm Managua se veía
    // como sorteo de 9pm porque UTC-6 nunca se aplicaba.
    final saleDateFmt = DateFormat('dd/MM/yyyy');
    final timeFmt = DateFormat('h:mm a', 'en_US');
    final shortDateFmt = DateFormat('dd/MM');
    final saleLocal = payload.date.toLocal();
    final saleFormatted =
        '${saleDateFmt.format(saleLocal)} ${timeFmt.format(saleLocal).toLowerCase()}';

    String? drawFormatted;
    if (payload.drawAt != null) {
      final drawLocal = payload.drawAt!.toLocal();
      final now = DateTime.now();
      final sameDay = drawLocal.year == now.year &&
          drawLocal.month == now.month &&
          drawLocal.day == now.day;
      final drawTime = timeFmt.format(drawLocal).toLowerCase();
      drawFormatted =
          sameDay ? drawTime : '${shortDateFmt.format(drawLocal)} $drawTime';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoLine(text: 'Folio: ${payload.folio}'),
        _InfoLine(text: 'Fecha: $saleFormatted'),
        _InfoLine(
          text: drawFormatted != null
              ? 'Sorteo: ${payload.gameName} - $drawFormatted'
              : 'Sorteo: ${payload.gameName}',
        ),
        if (payload.seller != null && payload.seller!.isNotEmpty)
          _InfoLine(text: 'Vendedor: ${payload.seller!}'),
        if (payload.client != null && payload.client!.isNotEmpty)
          _InfoLine(text: 'Cliente: ${payload.client!}'),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _LinesTable extends StatelessWidget {
  const _LinesTable({required this.lines});
  final List<TicketLine> lines;

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Colors.black,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Expanded(flex: 4, child: Text('No.', style: headerStyle)),
            Expanded(
              flex: 3,
              child: Text(
                'Monto',
                textAlign: TextAlign.right,
                style: headerStyle,
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                'Premio',
                textAlign: TextAlign.right,
                style: headerStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < lines.length; i++) ...[
          if (lines[i].subGameName != null &&
              (i == 0 ||
                  lines[i - 1].subGameName != lines[i].subGameName)) ...[
            if (i > 0) const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '-- ${lines[i].subGameName!.toUpperCase()} --',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ],
          _LineRow(line: lines[i]),
        ],
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});
  final TicketLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              line.number,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              kAmountFormat.format(line.amount),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              kAmountFormat.format(line.prize),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          flex: 5,
          child: Text(
            'TOTAL',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            kAmountFormat.format(total),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _CenteredNote extends StatelessWidget {
  const _CenteredNote({required this.text, this.bold = false});
  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: Colors.black,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _QrBlock extends StatelessWidget {
  const _QrBlock({required this.data});
  final String data;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: 200,
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _SolidDivider extends StatelessWidget {
  const _SolidDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: Colors.black,
    );
  }
}
