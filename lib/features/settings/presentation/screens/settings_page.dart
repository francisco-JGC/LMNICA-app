import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/billing_method.dart';
import '../state/settings_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (method) => RadioGroup<BillingMethod>(
          groupValue: method,
          onChanged: (value) {
            if (value != null) {
              ref
                  .read(settingsControllerProvider.notifier)
                  .changeBillingMethod(value);
            }
          },
          child: ListView(
            children: [
              const _SectionHeader(title: 'Método de facturación'),
              for (final m in BillingMethod.values)
                RadioListTile<BillingMethod>(
                  title: Text(m.displayName),
                  subtitle: Text(m.description),
                  value: m,
                ),
              const Divider(),
              const _SectionHeader(title: 'Impresora'),
              ListTile(
                leading: const Icon(Icons.bluetooth),
                title: const Text('Conexión Bluetooth'),
                subtitle: const Text('Escanear y conectar impresora'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/configuracion/impresora'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
