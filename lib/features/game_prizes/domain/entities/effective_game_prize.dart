import 'package:equatable/equatable.dart';

/// Effective payout multipliers for one game at one sucursal. Every
/// `*Multiplier` field is ALREADY MERGED — override wins, otherwise the
/// game's default is used. `hasOverride` is a display hint (the mobile
/// shows a banner so the seller knows their sucursal has custom multipliers).
///
/// `pairEasy*` only applies to THREE_DIGIT games with the "premio par" rule
/// enabled. When null, a fácil win pays the standard `easyMultiplier`
/// regardless of the winning number.
class EffectiveGamePrize extends Equatable {
  const EffectiveGamePrize({
    required this.gameId,
    required this.gameSlug,
    required this.gameName,
    required this.exactDefault,
    required this.easyDefault,
    required this.pairEasyDefault,
    required this.exactMultiplier,
    required this.easyMultiplier,
    required this.pairEasyMultiplier,
    required this.hasOverride,
  });

  final String gameId;

  /// Slug del juego (`juega3`, `gana3`, `tresmonazo`, ...). Se usa para
  /// gatear reglas específicas de un juego — hoy la única es el "premio
  /// par" de Juega 3.
  final String gameSlug;

  final String gameName;
  final int? exactDefault;
  final int? easyDefault;
  final int? pairEasyDefault;
  final int? exactMultiplier;
  final int? easyMultiplier;
  final int? pairEasyMultiplier;
  final bool hasOverride;

  @override
  List<Object?> get props => [
        gameId,
        gameSlug,
        gameName,
        exactDefault,
        easyDefault,
        pairEasyDefault,
        exactMultiplier,
        easyMultiplier,
        pairEasyMultiplier,
        hasOverride,
      ];
}
