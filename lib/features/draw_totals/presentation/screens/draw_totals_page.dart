import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/date_range_field.dart';
import '../../../games/domain/entities/game.dart';
import '../../../games/presentation/state/games_controller.dart';
import '../../../tickets/domain/entities/tickets_by_draw.dart';
import '../state/draw_totals_controller.dart';

class DrawTotalsPage extends ConsumerWidget {
  const DrawTotalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(drawTotalsControllerProvider);
    final filters = ref.watch(drawTotalsFiltersProvider);
    final games = ref.watch(gamesControllerProvider).value ?? const [];
    final gamesById = <String, Game>{for (final g in games) g.id: g};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Totales Sorteos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () =>
                ref.read(drawTotalsControllerProvider.notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(drawTotalsControllerProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DateRangeField(
              from: filters.from,
              to: filters.to,
              onChanged: (from, to) => ref
                  .read(drawTotalsFiltersProvider.notifier)
                  .setRange(from, to),
            ),
            const SizedBox(height: 16),
            state.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => _ErrorBox(
                message: err.toString(),
                onRetry: () => ref
                    .read(drawTotalsControllerProvider.notifier)
                    .refresh(),
              ),
              data: (items) => _Content(items: items, gamesById: gamesById),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.items, required this.gamesById});

  final List<TicketsByDrawItem> items;
  final Map<String, Game> gamesById;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 40,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'No hay sorteos con ventas en este rango.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    final groups = _groupByDay(items);
    final headerTotals = _aggregate(items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderStats(totals: headerTotals),
        const SizedBox(height: 20),
        for (final group in groups) ...[
          _DayHeader(label: group.label, count: group.items.length),
          const SizedBox(height: 8),
          for (final item in group.items) ...[
            _DrawCard(
              item: item,
              gameName: gamesById[item.gameId]?.name ?? 'Juego',
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _HeaderStats extends StatelessWidget {
  const _HeaderStats({required this.totals});

  final _Totals totals;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _HeaderStat(
              label: 'Sorteos',
              value: '${totals.drawCount}',
            ),
          ),
          Container(width: 1, height: 34, color: Colors.white24),
          Expanded(
            child: _HeaderStat(
              label: 'Ventas',
              value: kCurrencyFormat.format(totals.billed),
              small: true,
            ),
          ),
          Container(width: 1, height: 34, color: Colors.white24),
          Expanded(
            child: _HeaderStat(
              label: 'Premios',
              value: kCurrencyFormat.format(totals.wonPrize),
              small: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.label,
    required this.value,
    this.small = false,
  });

  final String label;
  final String value;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: small ? 18 : 22,
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.accentSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawCard extends StatelessWidget {
  const _DrawCard({required this.item, required this.gameName});

  final TicketsByDrawItem item;
  final String gameName;

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('h:mm a', 'en_US');
    final drawTime = timeFmt.format(item.drawAt.toLocal()).toLowerCase();
    final hasWinner = item.winningNumber != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasWinner
              ? AppTheme.primary.withValues(alpha: 0.25)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Text(
                  gameName.characters.take(1).toString().toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      gameName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      drawTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              _WinningChip(number: item.winningNumber),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: 'Ventas',
                  value: kCurrencyFormat.format(item.billed),
                  color: Colors.green.shade700,
                ),
              ),
              Container(width: 1, height: 32, color: Colors.grey.shade200),
              Expanded(
                child: _StatCell(
                  label: 'Premios',
                  value: kCurrencyFormat.format(item.wonPrize),
                  color: item.wonPrize > 0
                      ? Colors.red.shade700
                      : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WinningChip extends StatelessWidget {
  const _WinningChip({required this.number});

  final String? number;

  @override
  Widget build(BuildContext context) {
    if (number == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'Sin resultado',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        number!,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.5,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'No se pudo cargar el resumen',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.red.shade900)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Helpers ---------------------------------------------------------------

class _Totals {
  const _Totals({
    required this.drawCount,
    required this.ticketCount,
    required this.billed,
    required this.wonPrize,
  });

  final int drawCount;
  final int ticketCount;
  final int billed;
  final int wonPrize;
}

_Totals _aggregate(List<TicketsByDrawItem> items) {
  var tickets = 0;
  var billed = 0;
  var won = 0;
  for (final i in items) {
    tickets += i.ticketCount;
    billed += i.billed;
    won += i.wonPrize;
  }
  return _Totals(
    drawCount: items.length,
    ticketCount: tickets,
    billed: billed,
    wonPrize: won,
  );
}

class _DayGroup {
  const _DayGroup({required this.label, required this.items});

  final String label;
  final List<TicketsByDrawItem> items;
}

List<_DayGroup> _groupByDay(List<TicketsByDrawItem> items) {
  final map = <String, List<TicketsByDrawItem>>{};
  for (final i in items) {
    final d = i.drawAt.toLocal();
    final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    map.putIfAbsent(key, () => []).add(i);
  }
  final groups = <_DayGroup>[];
  final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
  for (final key in sortedKeys) {
    final list = map[key]!;
    list.sort((a, b) => b.drawAt.compareTo(a.drawAt));
    groups.add(_DayGroup(label: _labelForDay(list.first.drawAt.toLocal()), items: list));
  }
  return groups;
}

String _labelForDay(DateTime iso) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(iso.year, iso.month, iso.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  final fmt = DateFormat("EEEE d 'de' MMMM", 'es');
  final label = fmt.format(iso);
  return label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
}
