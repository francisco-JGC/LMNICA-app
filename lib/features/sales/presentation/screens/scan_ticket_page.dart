import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/di/injection.dart';
import '../../../games/domain/entities/game.dart';
import '../../../games/domain/entities/game_type.dart';
import '../../../tickets/domain/entities/ticket_detail.dart';
import '../../../tickets/domain/repositories/tickets_repository.dart';
import '../../domain/entities/bet.dart';
import '../../domain/entities/date_bet.dart';
import '../state/cart_controller.dart';
import '../state/combo_cart_controller.dart';
import '../state/date_cart_controller.dart';
import '../state/gana3_cart_controller.dart';

class ScanTicketPage extends ConsumerStatefulWidget {
  const ScanTicketPage({required this.game, super.key});

  final Game game;

  @override
  ConsumerState<ScanTicketPage> createState() => _ScanTicketPageState();
}

class _ScanTicketPageState extends ConsumerState<ScanTicketPage>
    with WidgetsBindingObserver {
  // Acotamos formatos y detectionSpeed para reducir el trabajo del plugin
  // nativo — menos frames en vuelo = menos ventana para el race que produce
  // el NPE `Attempt to invoke virtual method on null` reportado en release.
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // El scanner debe pausarse cuando la app pierde foco (llamada entrante,
    // notificación que interrumpe, usuario cambia de app). Si dejamos la
    // cámara viva mientras Android le quita recursos, el plugin nativo
    // termina operando sobre un scanner interno null → NPE. Suscribirnos
    // al ciclo de vida es la principal medida preventiva del race.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Reanudar el scanner al volver a foreground. Envuelto en try/catch
        // porque `start()` puede tirar si la cámara todavía está liberándose.
        _safeStart();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _safeStop();
    }
  }

  Future<void> _safeStart() async {
    try {
      await _controller.start();
    } catch (_) {
      // No propagamos: si el start falla el usuario verá el frame estático
      // y puede reintentar navegando adentro/afuera. Mejor que un crash.
    }
  }

  Future<void> _safeStop() async {
    try {
      await _controller.stop();
    } catch (_) {
      // Stop puede fallar si el controller ya está detenido — no importa.
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    // `!mounted` guard descarta callbacks tardíos que llegan después de que
    // el usuario ya salió de la página — sin esto el plugin puede seguir
    // entregando frames mientras el state se está destruyendo.
    if (_busy || !mounted) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;

    final id = _parseTicketId(raw);
    if (id == null) {
      setState(() => _error = 'QR no reconocido');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final either = await getIt<TicketsRepository>().findById(id);
    if (!mounted) return;

    await either.match(
      (failure) {
        setState(() {
          _busy = false;
          _error = 'No se encontró el boleto: ${failure.message}';
        });
      },
      (detail) async {
        if (detail.summary.gameId != widget.game.id) {
          setState(() {
            _busy = false;
            _error = 'Este boleto es de otro juego';
          });
          return;
        }
        if (widget.game.type == GameType.multiSorteo) {
          setState(() {
            _busy = false;
            _error = 'Los boletos de Multi Sorteo no se pueden re-escanear';
          });
          return;
        }
        final count = _loadIntoCart(detail);
        // Detener explícitamente el scanner ANTES del pop drena los frames
        // en vuelo y evita que el plugin nativo intente entregar un frame
        // sobre estado ya disposable (fuente del NPE en release).
        await _safeStop();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count números cargados')),
        );
        Navigator.of(context).pop();
      },
    );
  }

  /// Accepts either a dashed UUID or a 32-char hex string and returns the
  /// canonical lowercase UUID. Returns null if the input isn't recognizable.
  String? _parseTicketId(String raw) {
    final v = raw.trim();
    final dashed = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (dashed.hasMatch(v)) return v.toLowerCase();
    final compact = RegExp(r'^[0-9a-fA-F]{32}$');
    if (compact.hasMatch(v)) {
      final s = v.toLowerCase();
      return '${s.substring(0, 8)}-${s.substring(8, 12)}-'
          '${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
    }
    return null;
  }

  int _loadIntoCart(TicketDetail detail) {
    final client = detail.summary.client;
    // ANTES de cargar los números escaneados, limpiamos el cart. Si no
    // limpiamos, el `_merge` interno del cart SUMA los montos cuando
    // encuentra el mismo número → doble contabilización. También evita
    // que queden números viejos que no son del boleto escaneado
    // (síntoma "aparecieron números que no compré").
    _clearCurrentCart();
    switch (widget.game.type) {
      case GameType.regular:
        return _loadRegular(detail, client);
      case GameType.threeDigit:
        return _loadGana3(detail, client);
      case GameType.fourDigit:
        return _loadCombo(detail, client);
      case GameType.date:
        return _loadDates(detail, client);
      case GameType.multiSorteo:
        return 0;
    }
  }

  void _clearCurrentCart() {
    switch (widget.game.type) {
      case GameType.regular:
        ref.read(cartControllerProvider(widget.game.id).notifier).clear();
      case GameType.threeDigit:
        ref
            .read(gana3CartControllerProvider(widget.game.id).notifier)
            .clear();
      case GameType.fourDigit:
        ref
            .read(comboCartControllerProvider(widget.game.id).notifier)
            .clear();
      case GameType.date:
        ref
            .read(dateCartControllerProvider(widget.game.id).notifier)
            .clear();
      case GameType.multiSorteo:
        // No aplica — este tipo no acepta rescanning (ver `_onDetect`).
        break;
    }
  }

  int _loadRegular(TicketDetail detail, String? client) {
    final bets = <Bet>[];
    for (final line in detail.lines) {
      final n = int.tryParse(line.label);
      if (n == null || n < 0 || n > 99) continue;
      bets.add(Bet(number: n, amount: line.amount));
    }
    ref
        .read(cartControllerProvider(widget.game.id).notifier)
        .addBets(bets, client: client);
    return bets.length;
  }

  int _loadGana3(TicketDetail detail, String? client) {
    final notifier =
        ref.read(gana3CartControllerProvider(widget.game.id).notifier);
    int count = 0;
    for (final line in detail.lines) {
      final isFalso = line.label.contains('(F)');
      final numStr = line.label.replaceAll('(F)', '').trim();
      final n = int.tryParse(numStr);
      if (n == null || n < 0 || n > 999) continue;
      notifier.addSingle(
        number: n,
        amount: line.amount,
        isExact: !isFalso,
        client: client,
      );
      count++;
    }
    return count;
  }

  int _loadCombo(TicketDetail detail, String? client) {
    final notifier =
        ref.read(comboCartControllerProvider(widget.game.id).notifier);
    int count = 0;
    for (final line in detail.lines) {
      final n = int.tryParse(line.label);
      if (n == null || n < 0 || n > 9999) continue;
      notifier.addSingle(number: n, amount: line.amount, client: client);
      count++;
    }
    return count;
  }

  int _loadDates(TicketDetail detail, String? client) {
    final notifier =
        ref.read(dateCartControllerProvider(widget.game.id).notifier);
    int count = 0;
    for (final line in detail.lines) {
      final parts = line.label.split('-');
      if (parts.length != 2) continue;
      final day = int.tryParse(parts[0]);
      final monthIndex = kMonthAbbreviations.indexOf(parts[1]);
      if (day == null || day < 1 || day > 31 || monthIndex < 0) continue;
      notifier.addSingle(
        day: day,
        month: monthIndex + 1,
        amount: line.amount,
        client: client,
      );
      count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear boleto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Linterna',
            onPressed: _controller.toggleTorch,
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined),
            tooltip: 'Cambiar cámara',
            onPressed: _controller.switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          const _ScannerOverlay(),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _ErrorCard(
                message: _error!,
                onDismiss: () => setState(() => _error = null),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 3),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.red.shade800)),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
