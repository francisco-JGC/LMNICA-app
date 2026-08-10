import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/time_format.dart';
import '../../../games/domain/entities/game.dart';
import '../../../games/presentation/state/games_controller.dart';
import '../../domain/entities/ticket_evaluation.dart';
import '../../domain/repositories/results_repository.dart';

final _dashedUuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _compactUuid = RegExp(r'^[0-9a-fA-F]{32}$');

String? _parseTicketId(String raw) {
  final v = raw.trim();
  if (_dashedUuid.hasMatch(v)) return v.toLowerCase();
  if (_compactUuid.hasMatch(v)) {
    final s = v.toLowerCase();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-'
        '${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }
  return null;
}

class VerifyTicketPage extends ConsumerStatefulWidget {
  const VerifyTicketPage({super.key});

  @override
  ConsumerState<VerifyTicketPage> createState() => _VerifyTicketPageState();
}

class _VerifyTicketPageState extends ConsumerState<VerifyTicketPage> {
  final _controller = MobileScannerController();
  bool _busy = false;
  String? _error;
  TicketEvaluation? _evaluation;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _evaluation != null) return;
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
    await _controller.stop();

    final either =
        await getIt<ResultsRepository>().evaluateTicket(id);
    if (!mounted) return;
    either.match(
      (failure) {
        setState(() {
          _busy = false;
          _error = failure.message;
        });
        _controller.start();
      },
      (evaluation) {
        setState(() {
          _busy = false;
          _evaluation = evaluation;
        });
      },
    );
  }

  void _reset() {
    setState(() {
      _evaluation = null;
      _error = null;
    });
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificar boleto'),
        actions: _evaluation == null
            ? [
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
              ]
            : null,
      ),
      body: _evaluation != null
          ? _ResultView(
              evaluation: _evaluation!,
              onScanAnother: _reset,
            )
          : Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
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

class _ResultView extends ConsumerWidget {
  const _ResultView({
    required this.evaluation,
    required this.onScanAnother,
  });

  final TicketEvaluation evaluation;
  final VoidCallback onScanAnother;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(gamesControllerProvider).value ?? const [];
    final Game? game = games
        .where((g) => g.id == evaluation.gameId)
        .fold<Game?>(null, (acc, g) => acc ?? g);
    final theme = Theme.of(context);
    final dateFmt = DateFormat('dd/MM/yyyy');

    final headerColor = _headerColor(evaluation);
    final headerLabel = _headerLabel(evaluation);
    final headerIcon = _headerIcon(evaluation);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: headerColor.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Icon(headerIcon, size: 56, color: headerColor),
                const SizedBox(height: 12),
                Text(
                  headerLabel,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: headerColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (evaluation.isWinner) ...[
                  const SizedBox(height: 8),
                  Text(
                    kCurrencyFormat.format(evaluation.totalPrize),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: headerColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game?.name ?? '—',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#${evaluation.folio}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sorteo: ${dateFmt.format(evaluation.drawAt.toLocal())} '
                    '${formatTime12h(evaluation.drawAt)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (evaluation.status == 'voided') ...[
                    const SizedBox(height: 4),
                    Text(
                      'Este boleto está anulado',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Detalle',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final l in evaluation.lines)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Icon(
                  l.isWinner
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: l.isWinner ? Colors.green : Colors.grey,
                ),
                title: Text([
                  if (l.subGameName != null) '${l.subGameName} — ',
                  l.label,
                ].join()),
                subtitle: Text(
                  l.winningNumber == null
                      ? 'Sin resultado aún'
                      : 'Ganador ${l.winningNumber}',
                ),
                trailing: Text(
                  kCurrencyFormat.format(l.isWinner ? l.wonPrize : l.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: l.isWinner ? Colors.green.shade700 : Colors.black,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Escanear otro boleto'),
            onPressed: onScanAnother,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }

  Color _headerColor(TicketEvaluation e) {
    if (e.status == 'voided') return Colors.red;
    if (e.isWinner) return Colors.green.shade700;
    if (e.hasPendingDraw) return Colors.orange.shade700;
    return Colors.grey.shade700;
  }

  String _headerLabel(TicketEvaluation e) {
    if (e.status == 'voided') return 'Boleto anulado';
    if (e.isWinner) return '¡Boleto ganador!';
    if (e.hasPendingDraw) return 'Sorteo pendiente';
    return 'No ganador';
  }

  IconData _headerIcon(TicketEvaluation e) {
    if (e.status == 'voided') return Icons.cancel;
    if (e.isWinner) return Icons.emoji_events;
    if (e.hasPendingDraw) return Icons.hourglass_top;
    return Icons.info_outline;
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
