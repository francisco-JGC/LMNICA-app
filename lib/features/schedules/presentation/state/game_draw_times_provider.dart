import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/draw_schedule.dart';
import '../../domain/repositories/schedules_repository.dart';

/// Todas las horas de sorteo de un juego dado en "HH:MM" (24h Managua),
/// deduplicadas y ordenadas. A diferencia de `availableDrawsProvider`, este
/// no filtra por lock window — se usa para filtros de reporte/historial
/// donde importa TODAS las horas existentes, no solo las vendibles ahora.
final gameDrawTimesProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, gameId) async {
  final repo = getIt<SchedulesRepository>();
  final result = await repo.listByGame(gameId);
  final schedules = result.fold<List<DrawSchedule>>(
    (_) => const [],
    (items) => items.where((s) => s.isActive).toList(),
  );
  if (schedules.isEmpty) return const [];

  final times = <String>{};
  for (final s in schedules) {
    times.add(s.drawTime);
  }
  final sorted = times.toList()..sort();
  return sorted;
});
