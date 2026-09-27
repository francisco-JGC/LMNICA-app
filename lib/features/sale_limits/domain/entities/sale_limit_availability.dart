import 'package:equatable/equatable.dart';

/// Snapshot of how much room is left per number for a specific draw at a
/// specific sucursal. `limit` is null when no cap is configured (any bet
/// passes). `usage` maps `label -> centavos sold so far` for valid tickets.
class SaleLimitAvailability extends Equatable {
  const SaleLimitAvailability({
    required this.limit,
    required this.maxPerTicket,
    required this.usage,
  });

  final int? limit;

  /// Maximum bet allowed on a single ticket line. null = no cap.
  final int? maxPerTicket;

  final Map<String, int> usage;

  /// Amount still available for [label]. When no limit is set, returns null
  /// (interpreted as "unlimited" by callers). When sold >= limit, returns 0.
  int? availableFor(String label) {
    if (limit == null) return null;
    final sold = usage[label] ?? 0;
    final left = limit! - sold;
    return left < 0 ? 0 : left;
  }

  /// True when [label] is capped and there's zero room left.
  bool isBlocked(String label) {
    if (limit == null) return false;
    return (usage[label] ?? 0) >= limit!;
  }

  /// True when a cap is configured (regardless of whether any specific
  /// number has been sold yet).
  bool get hasLimit => limit != null;

  @override
  List<Object?> get props => [limit, maxPerTicket, usage];
}
