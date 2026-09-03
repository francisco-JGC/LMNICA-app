import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/business_time.dart';
import '../../../feature_flags/presentation/state/feature_flags_controller.dart';
import '../../domain/entities/draw_schedule.dart';
import '../../domain/repositories/schedules_repository.dart';

const _postDrawGraceMinutes = 3;
const _tickInterval = Duration(seconds: 15);

/// Cierre nocturno: después del último sorteo del día, el juego queda
/// bloqueado hasta esta hora (business time, Managua) del día siguiente.
/// Regla de negocio universal — el mismo horario para todos los juegos.
const _kNightlyReopenHour = 6;

class GameLockState extends Equatable {
  const GameLockState({
    required this.status,
    this.currentDrawAt,
    this.currentCutoffMinutes,
    this.reopenAt,
    this.nextDrawAt,
    this.nextCutoffMinutes,
    this.isNightly = false,
    this.isDayLock = false,
    this.errorMessage,
  });

  const GameLockState.unknown() : this(status: GameLockStatus.unknown);

  final GameLockStatus status;
  final DateTime? currentDrawAt;
  final int? currentCutoffMinutes;
  final DateTime? reopenAt;
  final DateTime? nextDrawAt;
  final int? nextCutoffMinutes;

  /// Cuando el bloqueo actual proviene de la ventana nocturna (después del
  /// último sorteo del día hasta las 06:00 del siguiente), no de una
  /// ventana de sorteo real. El UI muestra un mensaje distinto y no ancla
  /// a un `currentDrawAt`.
  final bool isNightly;

  /// True cuando el juego tiene schedules solo para días específicos y hoy
  /// no es uno de esos días. Las ventas se bloquean hasta el próximo día
  /// con sorteo programado.
  final bool isDayLock;

  final String? errorMessage;

  bool get isLocked => status == GameLockStatus.locked;
  bool get isOpen => status == GameLockStatus.open;

  @override
  List<Object?> get props => [
        status,
        currentDrawAt,
        currentCutoffMinutes,
        reopenAt,
        nextDrawAt,
        nextCutoffMinutes,
        isNightly,
        isDayLock,
        errorMessage,
      ];
}

enum GameLockStatus { unknown, open, locked, noSchedules, error }

class GameLockController extends Notifier<GameLockState> {
  GameLockController(this.gameId);

  final String gameId;

  late final _repository = getIt<SchedulesRepository>();
  List<DrawSchedule>? _schedules;
  Timer? _timer;

  @override
  GameLockState build() {
    ref.onDispose(() => _timer?.cancel());
    // Recompute cuando cambia el feature flag: si el admin apaga
    // `nightly_lock` desde el panel web y el móvil refetchea, tenemos que
    // desbloquear el juego sin esperar al próximo tick de 15s.
    ref.listen(featureFlagsControllerProvider, (_, _) => _recompute());
    Future.microtask(_load);
    return const GameLockState.unknown();
  }

  Future<void> _load() async {
    final result = await _repository.listByGame(gameId);
    result.match(
      (failure) {
        state = GameLockState(
          status: GameLockStatus.error,
          errorMessage: failure.message,
        );
      },
      (items) {
        _schedules = items.where((s) => s.isActive).toList();
        _timer?.cancel();
        _timer = Timer.periodic(_tickInterval, (_) => _recompute());
        _recompute();
      },
    );
  }

  void _recompute() {
    final schedules = _schedules;
    if (schedules == null) return;
    if (schedules.isEmpty) {
      state = const GameLockState(status: GameLockStatus.noSchedules);
      return;
    }

    final now = DateTime.now().toUtc();

    // Si todos los schedules están anclados a días específicos (ninguno es
    // "todos los días") y hoy no es uno de esos días, bloqueamos el juego
    // hasta el próximo sorteo programado — igual que el backend.
    final allDaySpecific = schedules.every((s) => s.dayOfWeek != null);
    final todayWeekday =
        BusinessTime.nowInBusinessTz().weekday % 7; // 0=dom … 6=sáb
    if (allDaySpecific && !schedules.any((s) => s.appliesTo(todayWeekday))) {
      final windows = _buildWindows(schedules, now);
      final next =
          windows.where((w) => !w.isNightly).fold<_Window?>(null, (acc, w) => acc ?? w);
      state = GameLockState(
        status: GameLockStatus.locked,
        isDayLock: true,
        reopenAt: next?.lockStart,
        nextDrawAt: next?.drawAt,
        nextCutoffMinutes: next?.cutoffMinutes,
      );
      return;
    }

    final windows = _buildWindows(schedules, now);

    for (final w in windows) {
      if (now.isBefore(w.lockStart)) {
        state = GameLockState(
          status: GameLockStatus.open,
          nextDrawAt: w.drawAt,
          nextCutoffMinutes: w.cutoffMinutes,
        );
        return;
      }
      if (!now.isAfter(w.lockEnd)) {
        // El "próximo" desde una nocturna es el próximo sorteo REAL del
        // día siguiente. Excluimos ventanas nocturnas al buscar next para
        // no encadenar cierres nocturnos como si fueran sorteos.
        final next = windows
            .where((x) =>
                !x.isNightly && x.drawAt.isAfter(w.drawAt))
            .fold<_Window?>(null, (acc, x) => acc ?? x);
        state = GameLockState(
          status: GameLockStatus.locked,
          // En cierre nocturno no hay sorteo real "actual" — omitimos
          // currentDrawAt/currentCutoffMinutes para que el UI muestre
          // el mensaje adecuado.
          currentDrawAt: w.isNightly ? null : w.drawAt,
          currentCutoffMinutes: w.isNightly ? null : w.cutoffMinutes,
          reopenAt: w.lockEnd,
          nextDrawAt: next?.drawAt,
          nextCutoffMinutes: next?.cutoffMinutes,
          isNightly: w.isNightly,
        );
        return;
      }
    }

    state = const GameLockState(status: GameLockStatus.open);
  }

  List<_Window> _buildWindows(List<DrawSchedule> schedules, DateTime nowUtc) {
    final windows = <_Window>[];
    final biz = BusinessTime.nowInBusinessTz();
    // Anchor day iteration at Managua midnight so DOW math is stable
    // regardless of the device's timezone.
    final bizToday = DateTime.utc(biz.year, biz.month, biz.day);

    // Feature flag: cuando el admin apaga `nightly_lock` desde el panel web
    // (típicamente para pruebas), no inyectamos las ventanas virtuales de
    // cierre nocturno. Default seguro cuando la flag no está en el snapshot
    // (offline al arrancar): mantener el cierre nocturno prendido, así el
    // comportamiento no se relaja por un fetch fallido.
    final flags = ref.read(featureFlagsControllerProvider);
    final nightlyEnabled = flags['nightly_lock']?.enabled ?? true;

    // Track lockEnd más tardío por día (business day) para poder inyectar la
    // ventana nocturna después del último sorteo del día. Clave: yyyymmdd.
    final lastLockEndByDay = <int, DateTime>{};

    for (int offset = 0; offset <= 7; offset++) {
      final day = bizToday.add(Duration(days: offset));
      final weekday = day.weekday % 7;
      final dayKey = day.year * 10000 + day.month * 100 + day.day;
      for (final s in schedules) {
        if (!s.appliesTo(weekday)) continue;
        final t = s.parsedTime;
        final drawAt = BusinessTime.toUtc(
          year: day.year,
          month: day.month,
          day: day.day,
          hour: t.hour,
          minute: t.minute,
        );
        // El backend usa `<` estricto: el minuto exacto del cutoff ya está
        // bloqueado. La UI refleja la misma semántica — lockStart es exactamente
        // drawAt - cutoffMinutes, sin ajuste.
        final effectiveCutoff = s.cutoffMinutes;
        final lockStart =
            drawAt.subtract(Duration(minutes: effectiveCutoff));
        final lockEnd =
            drawAt.add(const Duration(minutes: _postDrawGraceMinutes));
        // Registramos el lockEnd más tardío del día ANTES del filtro de
        // "pasadas" — si el último sorteo del día ya terminó (nowUtc > lockEnd)
        // igual necesitamos la ventana nocturna que arranca ahí.
        final prev = lastLockEndByDay[dayKey];
        if (prev == null || lockEnd.isAfter(prev)) {
          lastLockEndByDay[dayKey] = lockEnd;
        }
        if (lockEnd.isBefore(nowUtc)) continue;
        windows.add(_Window(
          drawAt: drawAt,
          lockStart: lockStart,
          lockEnd: lockEnd,
          cutoffMinutes: s.cutoffMinutes,
        ));
      }
    }

    // Ventanas nocturnas virtuales: desde el final del último sorteo de cada
    // día hasta las 06:00 del día siguiente (business time). No tienen drawAt
    // real — el algoritmo de `_recompute` las trata igual que a cualquier
    // otra: si `now` cae adentro, el juego queda locked con reopenAt = 06:00.
    // Skip cuando la flag `nightly_lock` está apagada.
    if (!nightlyEnabled) {
      windows.sort((a, b) => a.lockStart.compareTo(b.lockStart));
      return windows;
    }
    for (final entry in lastLockEndByDay.entries) {
      final lockStart = entry.value;
      final dayKey = entry.key;
      // Día siguiente (business time). Descomponemos el key para no depender
      // del mismo `day` que ya iteramos arriba.
      final year = dayKey ~/ 10000;
      final month = (dayKey ~/ 100) % 100;
      final day = dayKey % 100;
      final nextDay =
          DateTime.utc(year, month, day).add(const Duration(days: 1));
      final reopenAt = BusinessTime.toUtc(
        year: nextDay.year,
        month: nextDay.month,
        day: nextDay.day,
        hour: _kNightlyReopenHour,
        minute: 0,
      );
      // Si la ventana nocturna ya terminó antes del "ahora", no aporta nada.
      if (!reopenAt.isAfter(nowUtc)) continue;
      // Si otro sorteo del día siguiente cae antes de las 06:00 (poco
      // probable pero posible), el `lockEnd` real sigue siendo 06:00 y esa
      // ventana temprana quedará "adentro" del cierre nocturno — el
      // algoritmo de match resuelve por la primera ventana que contiene now.
      windows.add(_Window(
        drawAt: lockStart, // usamos lockStart como ancla temporal para el sort
        lockStart: lockStart,
        lockEnd: reopenAt,
        cutoffMinutes: 0,
        isNightly: true,
      ));
    }

    windows.sort((a, b) => a.lockStart.compareTo(b.lockStart));
    return windows;
  }
}

class _Window {
  const _Window({
    required this.drawAt,
    required this.lockStart,
    required this.lockEnd,
    required this.cutoffMinutes,
    this.isNightly = false,
  });

  final DateTime drawAt;
  final DateTime lockStart;
  final DateTime lockEnd;
  final int cutoffMinutes;

  /// True para ventanas virtuales de cierre nocturno; el `drawAt` en ese
  /// caso es solo un ancla temporal (== lockStart), no un sorteo real.
  final bool isNightly;
}

final gameLockControllerProvider =
    NotifierProvider.family<GameLockController, GameLockState, String>(
  GameLockController.new,
);
