import '../../domain/entities/sale_limit_availability.dart';

class SaleLimitAvailabilityModel extends SaleLimitAvailability {
  const SaleLimitAvailabilityModel({
    required super.limit,
    required super.maxPerTicket,
    required super.usage,
  });

  factory SaleLimitAvailabilityModel.fromJson(Map<String, dynamic> json) {
    final rawUsage = json['usage'] as Map<String, dynamic>? ?? const {};
    final usage = <String, int>{};
    for (final entry in rawUsage.entries) {
      final value = entry.value;
      if (value is num) usage[entry.key] = value.toInt();
    }
    final limitRaw = json['limit'];
    final mptRaw = json['maxPerTicket'];
    return SaleLimitAvailabilityModel(
      limit: limitRaw is num ? limitRaw.toInt() : null,
      maxPerTicket: mptRaw is num ? mptRaw.toInt() : null,
      usage: usage,
    );
  }
}
