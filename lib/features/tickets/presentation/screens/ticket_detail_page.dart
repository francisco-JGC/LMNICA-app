import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency.dart';
import '../../../../core/utils/time_format.dart';
import '../../../games/domain/entities/game.dart';
import '../../../games/presentation/screens/game_detail_page.dart';
import '../../../games/presentation/state/games_controller.dart';
import '../../domain/entities/ticket_detail.dart';
import '../../domain/entities/ticket_summary.dart';
import '../state/ticket_detail_provider.dart';

class TicketDetailPage extends ConsumerWidget {
  const TicketDetailPage({required this.ticketId, super.key});

  final String ticketId;

  void _showRepeatSheet(
    BuildContext context,
    Game currentGame,
    TicketDetail detail,
    List<Game> allGames,
  ) {
    final compatible = allGames
        .where((g) => g.isActive && g.type == currentGame.type)
        .toList();

    if (compatible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay juegos activos compatibles para repetir'),
        ),
      );
      return;
    }

    final lines = detail.lines
        .map((l) => (label: l.label.trim(), amount: l.amount))
        .toList();

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Repetir en',
                style: Theme.of(sheetCtx).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ...compatible.map(
              (g) => ListTile(
                leading: const Icon(Icons.casino_outlined),
                title: Text(g.name),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  context.push(
                    '/juegos/${g.id}',
                    extra: GameDetailArgs(game: g, initialLines: lines),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ticketDetailProvider(ticketId));
    final games = ref.watch(gamesControllerProvider).value ?? const [];
    final gamesById = {for (final g in games) g.id: g};

    final loadedDetail = async.value;
    final loadedGame =
        loadedDetail != null ? gamesById[loadedDetail.summary.gameId] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del boleto'),
        actions: loadedGame != null && loadedDetail != null
            ? [
                IconButton(
                  icon: const Icon(Icons.replay),
                  tooltip: 'Repetir boleto',
                  onPressed: () =>
                      _showRepeatSheet(context, loadedGame, loadedDetail, games),
                ),
              ]
            : null,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(ticketDetailProvider(ticketId)),
        ),
        data: (detail) => _DetailView(
          detail: detail,
          game: gamesById[detail.summary.gameId],
        ),
      ),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({required this.detail, required this.game});

  final TicketDetail detail;
  final Game? game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ticket = detail.summary;
    final saleFmt = DateFormat('dd/MM/yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  game?.name ?? '—',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _StatusChip(status: ticket.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '#${ticket.folio}',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: 'Venta',
            value: '${saleFmt.format(ticket.createdAt.toLocal())} '
                '· ${formatTime12h(ticket.createdAt)}',
          ),
          _InfoRow(
            label: 'Sorteo',
            value: '${saleFmt.format(ticket.drawAt.toLocal())} '
                '· ${formatTime12h(ticket.drawAt)}',
          ),
          if (ticket.client != null && ticket.client!.isNotEmpty)
            _InfoRow(label: 'Cliente', value: ticket.client!),
          if (ticket.isVoided && ticket.voidedReason != null)
            _InfoRow(label: 'Motivo anulación', value: ticket.voidedReason!),
          const Divider(height: 32),
          Text(
            'Números vendidos (${detail.lines.length})',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ..._buildLines(context, detail.lines),
          const Divider(height: 32),
          Row(
            children: [
              Text('Total', style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                kCurrencyFormat.format(ticket.total),
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLines(BuildContext context, List<TicketLineDetail> lines) {
    final theme = Theme.of(context);
    final rows = <Widget>[];
    String? currentSub;
    for (final line in lines) {
      if (line.subGameName != null && line.subGameName != currentSub) {
        currentSub = line.subGameName;
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            currentSub!,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ));
      }
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                line.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kCurrencyFormat.format(line.amount),
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    'Premio: ${kCurrencyFormat.format(line.prize)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ));
    }
    return rows;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    final isVoided = status == TicketStatus.voided;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:
            isVoided ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVoided ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Text(
        isVoided ? 'Anulado' : 'Válido',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isVoided ? Colors.red.shade700 : Colors.green.shade700,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
