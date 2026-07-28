import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/feature_flag.dart';
import '../../domain/repositories/feature_flags_repository.dart';

/// Snapshot in-memory de los feature flags. El controller los fetchea a
/// pedido — típicamente al arrancar la app (`main.dart`) y al volver a
/// foreground. Como el backend es la fuente de verdad para bloqueos
/// operativos, tolerar unos segundos de cache desactualizado es aceptable:
/// si un vendedor intenta operar sobre un flag apagado que su móvil todavía
/// cree prendido, el backend rechaza la venta con un 400 explícito.
class FeatureFlagsController extends Notifier<Map<String, FeatureFlag>> {
  late final _repository = getIt<FeatureFlagsRepository>();

  @override
  Map<String, FeatureFlag> build() {
    return const {};
  }

  Future<void> refresh() async {
    final result = await _repository.list();
    result.match(
      (_) {
        // Silencioso: si falla la carga (offline, backend caído), mantenemos
        // el cache actual. El comportamiento de fallback lo definen los
        // consumidores (ej. `isEnabled('nightly_lock')` devuelve false si
        // no hay data, apagando la regla por seguridad ante datos faltantes).
      },
      (list) {
        state = {for (final f in list) f.key: f};
      },
    );
  }

  /// Retorna `true` cuando la flag está prendida según el último snapshot.
  /// Ante ausencia de la flag (nunca fue seedeada o el fetch nunca terminó)
  /// devuelve `false` — un flag desconocido se comporta como apagado.
  bool isEnabled(String key) => state[key]?.enabled ?? false;
}

final featureFlagsControllerProvider = NotifierProvider<
    FeatureFlagsController, Map<String, FeatureFlag>>(
  FeatureFlagsController.new,
);
