import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Contador que se incrementa cada vez que se finaliza una venta
/// (impresión + WhatsApp share). Los formularios de venta usan este valor
/// como `Key` para forzarse a re-crearse desde cero — sin esto, el
/// `TextEditingController` local del campo "Cliente" mantenía el texto
/// después de imprimir y el nombre se filtraba a la siguiente venta.
///
/// Es un `family` por `gameId` porque cada juego tiene su propio flujo
/// de venta y no queremos que finalizar una venta en un juego resetee
/// los forms de otro.
class FormResetNotifier extends Notifier<int> {
  FormResetNotifier(this.gameId);

  final String gameId;

  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final formResetProvider =
    NotifierProvider.family<FormResetNotifier, int, String>(
  FormResetNotifier.new,
);
