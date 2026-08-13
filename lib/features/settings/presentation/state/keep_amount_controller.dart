import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection.dart';

/// Preferencia local: cuando el vendedor agrega un número al cart desde el
/// quick-form, ¿mantenemos el monto en el campo (`true`) o lo limpiamos
/// como se hacía antes (`false`)?
///
/// Aislado del `SettingsController` (que maneja `BillingMethod` con lógica
/// async y errores) — este vive con lectura/escritura sincrónica sobre
/// `SharedPreferences` para no arrastrar la complejidad y mantener a
/// prueba de errores el flujo de venta.
class KeepAmountController extends Notifier<bool> {
  static const _kKey = 'settings.keep_amount_between_bets';

  SharedPreferences get _prefs => getIt<SharedPreferences>();

  @override
  bool build() => _prefs.getBool(_kKey) ?? false;

  Future<void> setValue(bool value) async {
    if (state == value) return;
    // Actualizamos el state ANTES de persistir para respuesta inmediata en
    // la UI; si el `setBool` fallara (raro en SharedPreferences), el
    // próximo build vuelve a leer disco y se autocorrige.
    state = value;
    await _prefs.setBool(_kKey, value);
  }
}

final keepAmountProvider =
    NotifierProvider<KeepAmountController, bool>(KeepAmountController.new);
