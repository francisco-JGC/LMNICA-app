import '../../domain/entities/effective_game_prize.dart';

class EffectiveGamePrizeModel extends EffectiveGamePrize {
  const EffectiveGamePrizeModel({
    required super.gameId,
    required super.gameSlug,
    required super.gameName,
    required super.exactDefault,
    required super.easyDefault,
    required super.pairEasyDefault,
    required super.exactMultiplier,
    required super.easyMultiplier,
    required super.pairEasyMultiplier,
    required super.hasOverride,
  });

  factory EffectiveGamePrizeModel.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) => v is num ? v.toInt() : null;
    return EffectiveGamePrizeModel(
      gameId: json['gameId'] as String,
      // Backwards compat: old backend responses may not include gameSlug.
      // Empty string flags "no slug info" — pair rule checks require the
      // exact slug so an unknown value blocks the rule (safe default).
      gameSlug: (json['gameSlug'] as String?) ?? '',
      gameName: json['gameName'] as String,
      exactDefault: asInt(json['exactDefault']),
      easyDefault: asInt(json['easyDefault']),
      pairEasyDefault: asInt(json['pairEasyDefault']),
      exactMultiplier: asInt(json['exactMultiplier']),
      easyMultiplier: asInt(json['easyMultiplier']),
      pairEasyMultiplier: asInt(json['pairEasyMultiplier']),
      hasOverride: json['hasOverride'] as bool? ?? false,
    );
  }
}
