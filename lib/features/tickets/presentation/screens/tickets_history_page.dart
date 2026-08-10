import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/session/current_user.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/date_range_field.dart';
import '../../../games/domain/entities/game.dart';
import '../../../games/presentation/state/games_controller.dart';
import '../../../printer/domain/entities/ticket_payload.dart' as printer;
import '../../../printer/presentation/state/printer_controller.dart';
import '../../../whatsapp_billing/presentation/services/ticket_image_share_service.dart';
import '../../domain/entities/ticket_detail.dart';
import '../../domain/entities/ticket_summary.dart';
import '../../domain/repositories/tickets_repository.dart';
import '../state/tickets_history_controller.dart';

class TicketsHistoryPage extends ConsumerWidget {
  const TicketsHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ticketsHistoryControllerProvider);
    final games = ref.watch(gamesControllerProvider).value ?? const [];
    final gamesById = {for (final g in games) g.id: g};
    final filters = ref.watch(ticketsHistoryFiltersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis boletos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () =>
                ref.read(ticketsHistoryControllerProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Builder(builder: (context) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final endOfDay = DateTime(
                now.year,
                now.month,
                now.day,
                23,
                59,
                59,
              );
              return DateRangeField(
                from: filters.from ?? today,
                to: filters.to ?? endOfDay,
                onChanged: (from, to) => ref
                    .read(ticketsHistoryFiltersProvider.notifier)
                    .set(from: from, to: to),
              );
            }),
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => _ErrorView(
                message: err.toString(),
                onRetry: () => ref
                    .read(ticketsHistoryControllerProvider.notifier)
                    .refresh(),
              ),
              data: (tickets) => tickets.isEmpty
                  ? const _EmptyView()
                  : RefreshIndicator(
                      onRefresh: () => ref
                          .read(ticketsHistoryControllerProvider.notifier)
                          .refresh(),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: tickets.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _TicketTile(
                          ticket: tickets[i],
                          game: gamesById[tickets[i].gameId],
                        ),
                      ),
                    ),
            ),
          ),
          _TotalsBar(tickets: state.value ?? const []),
        ],
      ),
    );
  }
}

class _TotalsBar extends StatelessWidget {
  const _TotalsBar({required this.tickets});

  final List<TicketSummary> tickets;

  @override
  Widget build(BuildContext context) {
    var billed = 0;
    var paid = 0;
    for (final t in tickets) {
      if (!t.isVoided) billed += t.total;
      if (t.isPaid) paid += t.paidPrize;
    }
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _TotalCell(
                label: 'Facturado',
                value: billed,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TotalCell(
                label: 'Pagado',
                value: paid,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalCell extends StatelessWidget {
  const _TotalCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
        Text(
          kCurrencyFormat.format(value),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TicketTile extends ConsumerWidget {
  const _TicketTile({required this.ticket, required this.game});

  final TicketSummary ticket;
  final Game? game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final saleDateFmt = DateFormat('dd/MM');
    final gameName = game?.name ?? '—';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/reportes/facturas/${ticket.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      gameName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatusChip(ticket: ticket),
                  const SizedBox(width: 4),
                  _TicketMenu(ticket: ticket, game: game),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '#${ticket.folio}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _MetaLine(
                    icon: Icons.shopping_cart_outlined,
                    label:
                        '${saleDateFmt.format(ticket.createdAt.toLocal())} · '
                        '${formatTime12h(ticket.createdAt)}',
                  ),
                  const SizedBox(width: 16),
                  _MetaLine(
                    icon: Icons.event_outlined,
                    label: 'Sorteo ${formatTime12h(ticket.drawAt)}',
                  ),
                ],
              ),
              if (ticket.client != null && ticket.client!.isNotEmpty) ...[
                const SizedBox(height: 4),
                _MetaLine(
                  icon: Icons.person_outline,
                  label: ticket.client!,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${ticket.count} números',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Text(
                    kCurrencyFormat.format(ticket.total),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (ticket.isPaid) ...[
                const SizedBox(height: 4),
                Text(
                  'Pagado: ${kCurrencyFormat.format(ticket.paidPrize)}',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (ticket.isVoided && ticket.voidedReason != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Motivo: ${ticket.voidedReason}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey.shade700),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketMenu extends ConsumerWidget {
  const _TicketMenu({required this.ticket, required this.game});

  final TicketSummary ticket;
  final Game? game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        switch (value) {
          case 'reprint':
            await _reprint(context, ref);
          case 'resend':
            await _resend(context, ref);
          case 'void':
            await _confirmVoid(context, ref, ticket);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'reprint',
          child: ListTile(
            leading: Icon(Icons.print_outlined),
            title: Text('Reimprimir'),
          ),
        ),
        const PopupMenuItem(
          value: 'resend',
          child: ListTile(
            leading: Icon(Icons.share_outlined),
            title: Text('Reenviar por WhatsApp'),
          ),
        ),
        if (!ticket.isVoided)
          const PopupMenuItem(
            value: 'void',
            child: ListTile(
              leading: Icon(Icons.cancel_outlined, color: Colors.red),
              title: Text('Anular', style: TextStyle(color: Colors.red)),
            ),
          ),
      ],
    );
  }

  Future<void> _reprint(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final printer = ref.read(printerControllerProvider);
    if (!printer.isConnected) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
          'No hay impresora conectada. Ve a Configuración → Impresora.',
        ),
      ));
      return;
    }

    final either = await getIt<TicketsRepository>().findById(ticket.id);
    if (!context.mounted) return;
    await either.match(
      (failure) async {
        messenger.showSnackBar(SnackBar(
          content: Text('No se pudo cargar el boleto: ${failure.message}'),
        ));
      },
      (detail) async {
        final payload = _buildPayload(
          detail: detail,
          seller: ref.read(currentUserProvider)?.name,
        );
        await ref.read(printerControllerProvider.notifier).printTicket(payload);
        if (!context.mounted) return;
        final after = ref.read(printerControllerProvider);
        if (after.errorMessage != null) {
          messenger.showSnackBar(SnackBar(
            content: Text('Error al imprimir: ${after.errorMessage}'),
          ));
        } else {
          messenger.showSnackBar(
            const SnackBar(content: Text('Ticket reimpreso')),
          );
        }
      },
    );
  }

  Future<void> _resend(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    final either = await getIt<TicketsRepository>().findById(ticket.id);
    if (!context.mounted) return;
    await either.match(
      (failure) async {
        messenger.showSnackBar(SnackBar(
          content: Text('No se pudo cargar el boleto: ${failure.message}'),
        ));
      },
      (detail) async {
        final payload = _buildPayload(
          detail: detail,
          seller: ref.read(currentUserProvider)?.name,
        );
        if (!context.mounted) return;
        final shared = await const TicketImageShareService()
            .share(context: context, payload: payload);
        if (!context.mounted) return;
        if (!shared) {
          messenger.showSnackBar(const SnackBar(
            content: Text('No se pudo generar la imagen del ticket.'),
          ));
        }
      },
    );
  }

  // Los reprints y reenvíos generan el ticket idéntico al original — sin
  // marca de "reimpresión" ni "reenvío" — para que el cliente lo perciba
  // como el mismo boleto.
  printer.TicketPayload _buildPayload({
    required TicketDetail detail,
    required String? seller,
  }) {
    final summary = detail.summary;
    return printer.TicketPayload(
      id: summary.id,
      gameId: summary.gameId,
      gameSlug: game?.slug ?? '',
      gameName: game?.name ?? '—',
      lines: detail.lines
          .map((l) => printer.TicketLine(
                number: l.label,
                amount: l.amount,
                prize: l.prize,
                subGameName: l.subGameName,
              ))
          .toList(),
      folio: summary.folio,
      date: summary.createdAt,
      drawAt: summary.drawAt,
      seller: seller,
      client: summary.client,
    );
  }
}

Future<void> _confirmVoid(
  BuildContext context,
  WidgetRef ref,
  TicketSummary ticket,
) async {
  final reasonCtrl = TextEditingController();
  final result = await showDialog<String?>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Anular #${ticket.folio}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Escribe el motivo de la anulación:'),
          const SizedBox(height: 8),
          TextField(
            controller: reasonCtrl,
            autofocus: true,
            maxLength: 200,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Ej: error del cliente',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(reasonCtrl.text.trim()),
          child: const Text('Anular'),
        ),
      ],
    ),
  );

  if (result == null || result.isEmpty) return;

  final either = await ref
      .read(ticketsHistoryControllerProvider.notifier)
      .voidTicket(id: ticket.id, reason: result);
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  either.match(
    (failure) => messenger.showSnackBar(
      SnackBar(content: Text('No se pudo anular: ${failure.message}')),
    ),
    (_) => messenger.showSnackBar(
      SnackBar(content: Text('Ticket #${ticket.folio} anulado')),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.ticket});

  final TicketSummary ticket;

  @override
  Widget build(BuildContext context) {
    if (ticket.isVoided) {
      return _Chip(
        text: 'Anulado',
        bg: Colors.red.shade50,
        border: Colors.red.shade200,
        fg: Colors.red.shade700,
      );
    }
    if (ticket.isPaid) {
      return _Chip(
        text: 'Pagado',
        bg: Colors.green.shade100,
        border: Colors.green.shade300,
        fg: Colors.green.shade800,
      );
    }
    return _Chip(
      text: 'Válido',
      bg: Colors.green.shade50,
      border: Colors.green.shade200,
      fg: Colors.green.shade700,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.bg,
    required this.border,
    required this.fg,
  });

  final String text;
  final Color bg;
  final Color border;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Sin boletos en este rango', textAlign: TextAlign.center),
          ],
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
