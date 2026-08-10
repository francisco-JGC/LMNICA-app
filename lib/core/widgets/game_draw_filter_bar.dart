import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/games/domain/entities/game.dart';
import '../../features/schedules/presentation/state/game_draw_times_provider.dart';

/// Barra de filtros compartida: dropdown de "Juego" + dropdown de
/// "Sorteo" (hora). Se usa en historial de facturas y en ganadores.
///
/// `drawTime` sólo está habilitado cuando hay un juego seleccionado, porque
/// las horas de sorteo dependen del juego. Al cambiar de juego, el caller
/// debe resetear `drawTime` para evitar filtros inconsistentes.
class GameDrawFilterBar extends ConsumerWidget {
  const GameDrawFilterBar({
    super.key,
    required this.games,
    required this.selectedGameId,
    required this.selectedDrawTime,
    required this.onGameChanged,
    required this.onDrawTimeChanged,
  });

  final List<Game> games;
  final String? selectedGameId;
  final String? selectedDrawTime;
  final void Function(String? gameId) onGameChanged;
  final void Function(String? drawTime) onDrawTimeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _GameDropdown(
            games: games,
            selectedGameId: selectedGameId,
            onChanged: onGameChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DrawTimeDropdown(
            gameId: selectedGameId,
            selectedDrawTime: selectedDrawTime,
            onChanged: onDrawTimeChanged,
          ),
        ),
      ],
    );
  }
}

class _GameDropdown extends StatelessWidget {
  const _GameDropdown({
    required this.games,
    required this.selectedGameId,
    required this.onChanged,
  });

  final List<Game> games;
  final String? selectedGameId;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: selectedGameId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Juego',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Todos'),
        ),
        for (final g in games)
          DropdownMenuItem<String?>(
            value: g.id,
            child: Text(g.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _DrawTimeDropdown extends ConsumerWidget {
  const _DrawTimeDropdown({
    required this.gameId,
    required this.selectedDrawTime,
    required this.onChanged,
  });

  final String? gameId;
  final String? selectedDrawTime;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sin juego seleccionado, el filtro de sorteo no tiene sentido
    // (cada juego tiene su propio schedule). Deshabilitado.
    if (gameId == null) {
      return DropdownButtonFormField<String?>(
        initialValue: null,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Sorteo',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
          hintText: 'Elegí un juego',
        ),
        items: const [
          DropdownMenuItem<String?>(value: null, child: Text('Todos')),
        ],
        onChanged: null,
      );
    }

    final times = ref.watch(gameDrawTimesProvider(gameId!));

    return times.when(
      loading: () => DropdownButtonFormField<String?>(
        initialValue: null,
        decoration: const InputDecoration(
          labelText: 'Sorteo',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
          hintText: 'Cargando…',
        ),
        items: const [
          DropdownMenuItem<String?>(value: null, child: Text('…')),
        ],
        onChanged: null,
      ),
      error: (_, _) => DropdownButtonFormField<String?>(
        initialValue: null,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Sorteo',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
          hintText: 'Error',
        ),
        items: const [
          DropdownMenuItem<String?>(value: null, child: Text('Todos')),
        ],
        onChanged: onChanged,
      ),
      data: (list) => DropdownButtonFormField<String?>(
        initialValue: selectedDrawTime,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Sorteo',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
          for (final t in list)
            DropdownMenuItem<String?>(
              value: t,
              child: Text(_formatTime12h(t)),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// Formatea "HH:MM" (24h) a "h:mm am/pm" para display.
String _formatTime12h(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return hhmm;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final suffix = h >= 12 ? 'pm' : 'am';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} $suffix';
}
