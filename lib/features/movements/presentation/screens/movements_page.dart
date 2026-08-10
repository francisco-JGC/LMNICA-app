import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/date_range_field.dart';
import '../../domain/entities/movements_summary.dart';
import '../state/movements_controller.dart';

class MovementsPage extends ConsumerWidget {
  const MovementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(movementsControllerProvider);
    final filters = ref.watch(movementsFiltersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () =>
                ref.read(movementsControllerProvider.notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(movementsControllerProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DateRangeField(
              from: filters.from,
              to: filters.to,
              onChanged: (from, to) => ref
                  .read(movementsFiltersProvider.notifier)
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
                    .read(movementsControllerProvider.notifier)
                    .refresh(),
              ),
              data: (summary) => _DetailCard(summary: summary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.summary});

  final MovementsSummary summary;

  @override
  Widget build(BuildContext context) {
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
                    'Detalle',
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
            _Row(label: 'Facturado', value: summary.billed),
            const _Divider(),
            _Row(label: 'Ganado por clientes', value: summary.wonPrize),
            const _Divider(),
            _Row(label: 'Cobrado', value: summary.collected),
            const _Divider(),
            _Row(label: 'Gastos', value: summary.expenses),
            const _Divider(),
            _Row(label: 'Salario', value: summary.salary),
            const _Divider(),
            _Row(
              label: 'Restante',
              value: summary.remaining,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final int value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: isTotal ? 16 : 15,
      fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
      color: isTotal ? Colors.black87 : Colors.grey.shade800,
    );
    final valueStyle = TextStyle(
      fontSize: isTotal ? 18 : 16,
      fontWeight: FontWeight.w800,
      color: isTotal
          ? (value < 0 ? Colors.red.shade700 : AppTheme.primary)
          : Colors.black87,
    );
    return Container(
      color: isTotal ? AppTheme.accentSoft : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          Text(kCurrencyFormat.format(value), style: valueStyle),
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
