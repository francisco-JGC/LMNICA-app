import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/printer_device.dart';
import '../state/printer_controller.dart';
import '../state/printer_state.dart';

class PrinterSetupPage extends ConsumerStatefulWidget {
  const PrinterSetupPage({super.key});

  @override
  ConsumerState<PrinterSetupPage> createState() => _PrinterSetupPageState();
}

class _PrinterSetupPageState extends ConsumerState<PrinterSetupPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(printerControllerProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(printerControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(printerControllerProvider);
    final controller = ref.read(printerControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impresora Bluetooth'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: state.status == PrinterStatus.loading
                ? null
                : controller.refresh,
          ),
        ],
      ),
      body: _Body(state: state, controller: controller),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.controller});

  final PrinterState state;
  final PrinterController controller;

  @override
  Widget build(BuildContext context) {
    if (state.status == PrinterStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        _StatusCard(state: state),
        if (state.errorMessage != null)
          _ErrorBanner(
            message: state.errorMessage!,
            action: state.needsSettings
                ? _BannerAction(
                    label: 'Abrir ajustes',
                    onPressed: controller.openSystemSettings,
                  )
                : null,
          ),
        if (state.bluetoothEnabled) ...[
          const _SectionHeader(title: 'Dispositivos pareados'),
          if (state.devices.isEmpty) const _EmptyDevicesHint(),
          for (final device in state.devices)
            _DeviceTile(
              device: device,
              isConnected: state.connectedDevice == device,
              isConnecting: state.isConnecting,
              onTap: () => controller.connect(device),
            ),
        ],
        if (state.isConnected) ...[
          const SizedBox(height: 16),
          _ActionsBar(state: state, controller: controller),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final PrinterState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = state.isConnected;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              connected
                  ? Icons.bluetooth_connected
                  : state.bluetoothEnabled
                      ? Icons.bluetooth
                      : Icons.bluetooth_disabled,
              size: 40,
              color: connected ? scheme.primary : Colors.black45,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connected
                        ? 'Impresora configurada'
                        : state.bluetoothEnabled
                            ? 'Bluetooth activo'
                            : 'Bluetooth apagado',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    connected
                        ? state.connectedDevice!.name
                        : state.bluetoothEnabled
                            ? 'Selecciona una impresora de la lista'
                            : 'Activa el Bluetooth del dispositivo',
                    style: const TextStyle(color: Colors.black54),
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

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.isConnected,
    required this.isConnecting,
    required this.onTap,
  });

  final PrinterDevice device;
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isConnected ? Icons.check_circle : Icons.print_outlined,
        color: isConnected
            ? Theme.of(context).colorScheme.primary
            : Colors.black45,
      ),
      title: Text(device.name),
      subtitle: Text(device.address),
      trailing: isConnecting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: isConnecting ? null : onTap,
    );
  }
}

class _ActionsBar extends StatelessWidget {
  const _ActionsBar({required this.state, required this.controller});

  final PrinterState state;
  final PrinterController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: state.isPrinting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.receipt_long),
              label: const Text('Imprimir prueba'),
              onPressed: state.isPrinting ? null : controller.printTest,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Olvidar impresora'),
              onPressed: controller.forgetPrinter,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDevicesHint extends StatelessWidget {
  const _EmptyDevicesHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'No hay impresoras pareadas. Ve a Ajustes del sistema → Bluetooth y '
        'empareja tu impresora térmica antes de conectarla aquí.',
        style: TextStyle(color: Colors.black54),
      ),
    );
  }
}

class _BannerAction {
  const _BannerAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.action});

  final String message;
  final _BannerAction? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: action!.onPressed,
              icon: const Icon(Icons.settings),
              label: Text(action!.label),
            ),
          ],
        ],
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
