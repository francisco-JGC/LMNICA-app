import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/date_range_field.dart';
import '../../domain/entities/movements_summary.dart';
import '../../domain/repositories/movements_repository.dart';
import '../state/movements_controller.dart';

// ---------------------------------------------------------------------------
// Type labels / meta
// ---------------------------------------------------------------------------

const _kAllTypes = '__all__';

const _typeOptions = [
  (_kAllTypes, 'Todos'),
  ('expense', 'Gasto'),
  ('deposit', 'Depósito / Cobro'),
  ('withdrawal', 'Retiro / Crédito'),
  ('adjustment', 'Ajuste'),
];

(IconData, Color, String) _typeMeta(String type, bool isPrizePayment) {
  if (isPrizePayment) {
    return (Icons.card_giftcard, const Color(0xFFF59E0B), 'Premio pagado');
  }
  return switch (type) {
    'expense'    => (Icons.arrow_downward, const Color(0xFFE11D48), 'Gasto'),
    'deposit'    => (Icons.arrow_upward, const Color(0xFF059669), 'Depósito'),
    'withdrawal' => (Icons.account_balance_wallet, const Color(0xFF2563EB), 'Retiro'),
    'opening'    => (Icons.door_front_door_outlined, const Color(0xFF64748B), 'Apertura'),
    'closing'    => (Icons.door_back_door_outlined, const Color(0xFF64748B), 'Cierre'),
    'adjustment' => (Icons.tune, const Color(0xFF64748B), 'Ajuste'),
    _            => (Icons.circle_outlined, const Color(0xFF64748B), type),
  };
}

final _occurredFmt = DateFormat('dd MMM yyyy', 'es');

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class MovementsPage extends ConsumerWidget {
  const MovementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryState = ref.watch(movementsControllerProvider);
    final historyState = ref.watch(movementsHistoryProvider);
    final filters = ref.watch(movementsFiltersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () {
              ref.read(movementsControllerProvider.notifier).refresh();
              ref.read(movementsHistoryProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(movementsControllerProvider.notifier).refresh();
          await ref.read(movementsHistoryProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Filtros compartidos (fecha + tipo para historial)
            DateRangeField(
              from: filters.from,
              to: filters.to,
              onChanged: (from, to) => ref
                  .read(movementsFiltersProvider.notifier)
                  .setRange(from, to),
            ),
            const SizedBox(height: 12),
            // Resumen
            summaryState.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => _ErrorBox(
                message: err.toString(),
                onRetry: () =>
                    ref.read(movementsControllerProvider.notifier).refresh(),
              ),
              data: (summary) => _DetailCard(summary: summary),
            ),
            const SizedBox(height: 24),
            // Historial
            _HistorialSection(
              historyState: historyState,
              selectedType: filters.historyType,
              onTypeChanged: (t) => ref
                  .read(movementsFiltersProvider.notifier)
                  .setHistoryType(t == _kAllTypes ? null : t),
              onRetry: () =>
                  ref.read(movementsHistoryProvider.notifier).refresh(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Historial section
// ---------------------------------------------------------------------------

class _HistorialSection extends StatelessWidget {
  const _HistorialSection({
    required this.historyState,
    required this.selectedType,
    required this.onTypeChanged,
    required this.onRetry,
  });

  final AsyncValue<MovementsList> historyState;
  final String? selectedType;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            const Text(
              'Historial',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            const Spacer(),
            // Filtro de tipo
            _TypeDropdown(
              value: selectedType ?? _kAllTypes,
              onChanged: onTypeChanged,
            ),
          ],
        ),
        const SizedBox(height: 12),
        historyState.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => _ErrorBox(
            message: err.toString(),
            onRetry: onRetry,
          ),
          data: (data) => data.items.isEmpty
              ? _EmptyHistory()
              : _HistoryList(items: data.items, total: data.total),
        ),
      ],
    );
  }
}

class _TypeDropdown extends StatelessWidget {
  const _TypeDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          onChanged: (v) { if (v != null) onChanged(v); },
          items: _typeOptions
              .map((opt) => DropdownMenuItem(
                    value: opt.$1,
                    child: Text(opt.$2),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.items, required this.total});

  final List<MovementItem> items;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, i) => Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.shade100,
              indent: 56,
            ),
            itemBuilder: (_, i) => _MovementTile(item: items[i]),
          ),
        ),
        if (total > items.length)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Mostrando ${items.length} de $total movimientos',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ),
      ],
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.item});

  final MovementItem item;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _typeMeta(item.type, item.isPrizePayment);
    final isPositive = item.type == 'deposit';
    final amountColor =
        isPositive ? const Color(0xFF059669) : const Color(0xFFE11D48);
    final sign = isPositive ? '+' : '-';

    DateTime? date;
    try {
      date = DateTime.parse(item.occurredAt);
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.description != null && item.description!.isNotEmpty)
                  Text(
                    item.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (date != null)
                  Text(
                    _occurredFmt.format(date.toLocal()),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign${kCurrencyFormat.format(item.amount)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.history_toggle_off, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(
            'Sin movimientos en este período',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Resumen card
// ---------------------------------------------------------------------------

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.summary});

  final MovementsSummary summary;

  @override
  Widget build(BuildContext context) {
    final isPositive = summary.remaining >= 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.14),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.accent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.receipt_long_outlined, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Resumen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            _Row(label: 'Facturado', value: summary.billed, tone: _Tone.green),
            const _Divider(),
            _Row(label: 'Premios ganados por clientes', value: summary.wonPrize, tone: _Tone.red),
            const _Divider(),
            _Row(label: 'Salario / Comisión', value: summary.salary, tone: _Tone.neutral),
            if (summary.cobros > 0) ...[
              const _Divider(),
              _Row(label: 'Cobrado', value: summary.cobros, tone: _Tone.green),
            ],
            if (summary.credits > 0) ...[
              const _Divider(),
              _Row(label: 'Créditos', value: summary.credits, tone: _Tone.red),
            ],
            if (summary.prizePayments > 0) ...[
              const _Divider(),
              _Row(label: 'Premios pagados', value: summary.prizePayments, tone: _Tone.neutral),
            ],
            Container(
              color: isPositive
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFFF1F2),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pendiente',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isPositive
                            ? const Color(0xFF065F46)
                            : const Color(0xFF9F1239),
                      ),
                    ),
                  ),
                  Text(
                    kCurrencyFormat.format(summary.remaining),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isPositive
                          ? const Color(0xFF059669)
                          : const Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Tone { green, red, neutral }

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.tone = _Tone.neutral,
  });

  final String label;
  final int value;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final Color valueColor = switch (tone) {
      _Tone.green => const Color(0xFF059669),
      _Tone.red => const Color(0xFFE11D48),
      _Tone.neutral => Colors.black87,
    };
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Text(
            kCurrencyFormat.format(value),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade200,
      indent: 18,
      endIndent: 18,
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
                  'No se pudo cargar',
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
