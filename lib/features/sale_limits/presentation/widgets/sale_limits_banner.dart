import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../sale_points/presentation/state/active_sale_point_controller.dart';
import '../../../schedules/presentation/state/available_draws_provider.dart';
import '../state/sale_limit_availability_provider.dart';

/// Convenience wrapper — resolves the active sucursal and the next upcoming
/// draw automatically, then renders [SaleLimitsBanner]. Use this from any
/// game screen with just the gameId.
class SaleLimitsBannerAuto extends ConsumerWidget {
  const SaleLimitsBannerAuto({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salePoint = ref.watch(activeSalePointProvider).selected;
    if (salePoint == null) return const SizedBox.shrink();
    final drawsAsync = ref.watch(availableDrawsProvider(gameId));
    final next = drawsAsync.value?.isNotEmpty == true
        ? drawsAsync.value!.first
        : null;
    if (next == null) return const SizedBox.shrink();
    return SaleLimitsBanner(
      gameId: gameId,
      salePointId: salePoint.id,
      drawAt: next.drawAt,
    );
  }
}

/// Compact banner that surfaces per-number sale limits for the current
/// (game, sucursal, drawAt). Sellers see immediately which numbers are
/// blocked or close to full, WITHOUT having to try and fail.
///
/// Renders nothing when no limit is configured or when there's no usage
/// yet — the intent is to only show up when there's something relevant to
/// communicate. Tapping expands to a detail list.
class SaleLimitsBanner extends ConsumerStatefulWidget {
  const SaleLimitsBanner({
    super.key,
    required this.gameId,
    required this.salePointId,
    required this.drawAt,
  });

  final String gameId;
  final String salePointId;
  final DateTime drawAt;

  @override
  ConsumerState<SaleLimitsBanner> createState() => _SaleLimitsBannerState();
}

class _SaleLimitsBannerState extends ConsumerState<SaleLimitsBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final key = SaleLimitAvailabilityKey(
      gameId: widget.gameId,
      salePointId: widget.salePointId,
      drawAt: widget.drawAt,
    );
    final async = ref.watch(saleLimitAvailabilityProvider(key));

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (availability) {
        if (!availability.hasLimit) return const SizedBox.shrink();
        final limit = availability.limit!;
        // Sorted for stable display; blocked first, then closest-to-full.
        final entries = availability.usage.entries
            .where((e) => e.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        // Nothing sold yet → skip the banner to avoid noise.
        if (entries.isEmpty) return const SizedBox.shrink();

        final blocked = entries.where((e) => e.value >= limit).length;
        final tone = blocked > 0 ? _Tone.warning : _Tone.info;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Material(
            color: tone.background,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(tone.icon, size: 18, color: tone.foreground),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            blocked > 0
                                ? '$blocked número(s) bloqueado(s) — límite C\$$limit por sorteo'
                                : availability.maxPerTicket != null
                                    ? 'Límite: C\$$limit por sorteo · C\$${availability.maxPerTicket} por boleto'
                                    : 'Límite activo: C\$$limit por número por sorteo',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: tone.foreground,
                            ),
                          ),
                        ),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: tone.foreground,
                        ),
                      ],
                    ),
                    if (_expanded) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: entries.take(24).map((e) {
                          final sold = e.value;
                          final remaining = limit - sold;
                          final isBlocked = remaining <= 0;
                          return _ChipBadge(
                            label: e.key,
                            remaining: remaining < 0 ? 0 : remaining,
                            blocked: isBlocked,
                          );
                        }).toList(),
                      ),
                      if (entries.length > 24)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '+${entries.length - 24} números más con ventas.',
                            style: TextStyle(
                              fontSize: 11,
                              color: tone.foreground.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChipBadge extends StatelessWidget {
  const _ChipBadge({
    required this.label,
    required this.remaining,
    required this.blocked,
  });

  final String label;
  final int remaining;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final bg = blocked ? Colors.red.shade100 : Colors.amber.shade100;
    final fg = blocked ? Colors.red.shade900 : Colors.amber.shade900;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            blocked ? 'BLOQ' : 'C\$$remaining',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

enum _Tone {
  info,
  warning,
}

extension _ToneStyle on _Tone {
  Color get background {
    switch (this) {
      case _Tone.info:
        return AppTheme.primary.withValues(alpha: 0.08);
      case _Tone.warning:
        return Colors.red.shade50;
    }
  }

  Color get foreground {
    switch (this) {
      case _Tone.info:
        return AppTheme.primary;
      case _Tone.warning:
        return Colors.red.shade900;
    }
  }

  IconData get icon {
    switch (this) {
      case _Tone.info:
        return Icons.info_outline;
      case _Tone.warning:
        return Icons.warning_amber_rounded;
    }
  }
}
