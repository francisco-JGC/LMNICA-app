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
            // Header
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
            // Rows
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
            // Restante
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
