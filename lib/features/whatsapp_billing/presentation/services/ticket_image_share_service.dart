import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../printer/domain/entities/ticket_payload.dart';
import '../widgets/ticket_receipt_widget.dart';

/// Renderiza el `TicketReceiptWidget` off-screen, lo captura a PNG y lo
/// comparte por el share sheet nativo. El usuario elige WhatsApp (o
/// cualquier otra app de mensajería) desde ahí.
///
/// Estrategia off-screen: montamos el widget en un `OverlayEntry` con
/// `Visibility(visible: false, maintainState: true, ...)` para que layout
/// y paint ocurran sin que el usuario lo vea, esperamos un frame para que
/// el `RepaintBoundary` tenga la imagen lista, y capturamos.
///
/// Falla silenciosa (retorna `false`) solo si algo del pipeline nativo
/// revienta. El caller decide el snackbar.
class TicketImageShareService {
  const TicketImageShareService();

  Future<bool> share({
    required BuildContext context,
    required TicketPayload payload,
  }) async {
    try {
      final bytes = await _capture(context, payload);
      if (bytes == null) return false;

      final tempDir = await getTemporaryDirectory();
      final safeFolio = payload.folio.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '');
      final file = File('${tempDir.path}/ticket-$safeFolio.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        // Caption mínimo: solo el folio para que el receptor tenga
        // referencia si le llegan varios tickets. Toda la info del ticket
        // está en la imagen — no duplicamos acá.
        text: 'Ticket #${payload.folio}',
        subject: 'Ticket #${payload.folio}',
      );
      return true;
    } catch (e) {
      // El caller ya loggea o muestra snackbar según necesite. Acá tragamos
      // para no propagar y romper el flujo del `_persistAndPrint`.
      if (kDebugMode) {
        debugPrint('TicketImageShareService failed: $e');
      }
      return false;
    }
  }

  /// Monta el widget en un `OverlayEntry`, espera a que renderice, y
  /// captura los bytes del RepaintBoundary.
  Future<Uint8List?> _capture(
    BuildContext context,
    TicketPayload payload,
  ) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final boundaryKey = GlobalKey();

    final completer = Completer<Uint8List?>();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        // `Positioned` fuera del área visible + `Offstage` como respaldo.
        // El RepaintBoundary DEBE recibir un layout normal, así que le
        // damos un Offstage con maintainState:true para que renderice.
        return Positioned(
          left: -10000,
          top: -10000,
          child: Material(
            type: MaterialType.transparency,
            child: RepaintBoundary(
              key: boundaryKey,
              child: TicketReceiptWidget(payload: payload),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);

    // Esperamos a que Flutter complete al menos un frame de paint.
    // Un solo `endOfFrame` a veces alcanza a pintar el QR con QrImageView
    // por dentro; ante la duda esperamos dos frames.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await WidgetsBinding.instance.endOfFrame;

    try {
      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        completer.complete(null);
      } else {
        // 3.0 pixelRatio → imagen de ~1800px de ancho para el widget de
        // 600px. Suficiente para que el QR sobreviva la compresión de
        // WhatsApp y siga siendo escaneable.
        final image = await renderObject.toImage(pixelRatio: 3.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        completer.complete(byteData?.buffer.asUint8List());
      }
    } catch (e) {
      completer.complete(null);
    } finally {
      entry.remove();
    }

    return completer.future;
  }
}
