import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/time_format.dart';
import '../state/game_lock_controller.dart';

/// Overlay wrapper that blocks the child when the game is inside a draw's
/// lock window (cutoffMinutes before drawAt through 3 min after).
class GameLockGate extends ConsumerWidget {
  const GameLockGate({
    required this.gameId,
    required this.child,
    super.key,
  });

  final String gameId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameLockControllerProvider(gameId));

    return Stack(
      children: [
        child,
        if (state.isLocked) _LockOverlay(state: state),
      ],
    );
  }
}

class _LockOverlay extends StatelessWidget {
  const _LockOverlay({required this.state});

  final GameLockState state;

  @override
  Widget build(BuildContext context) {
    final drawAt = state.currentDrawAt;
    final reopenAt = state.reopenAt;
    final nextDrawAt = state.nextDrawAt;
    final nightly = state.isNightly;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xB2000000),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    nightly ? Icons.nights_stay : Icons.lock_clock,
                    size: 56,
                    color: nightly ? Colors.indigo : Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    nightly ? 'Cierre nocturno' : 'Sorteo en curso',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!nightly && drawAt != null)
                    Text(
                      'Sorteo de las ${formatTime12h(drawAt)}',
                      style: const TextStyle(fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    nightly
                        ? 'Las ventas están cerradas hasta mañana a las 6:00 AM.'
                        : 'No se pueden ingresar boletos durante la ventana de bloqueo.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  if (reopenAt != null)
                    _CountdownText(target: reopenAt, longFormat: nightly),
                  const SizedBox(height: 16),
                  if (nextDrawAt != null)
                    Text(
                      nightly
                          ? 'Próximo sorteo del siguiente día: ${formatTime12h(nextDrawAt)}'
                          : 'Próximo sorteo: ${formatTime12h(nextDrawAt)}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownText extends StatefulWidget {
  const _CountdownText({required this.target, this.longFormat = false});

  final DateTime target;

  /// Cuando true, muestra horas si el tiempo restante > 1h (cierre nocturno).
  /// Cuando false, muestra solo MM:SS (ventana de sorteo, siempre corta).
  final bool longFormat;

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  late Duration _remaining;
  late final Stream<Duration> _stream;

  @override
  void initState() {
    super.initState();
    _remaining = _diff();
    _stream = Stream.periodic(const Duration(seconds: 1), (_) => _diff());
  }

  Duration _diff() {
    final d = widget.target.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  String _format(Duration d) {
    if (widget.longFormat && d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      return '$h h $m min';
    }
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: _stream,
      initialData: _remaining,
      builder: (context, snap) {
        final d = snap.data ?? _remaining;
        return Text(
          'Se rehabilita en ${_format(d)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }
}
