import '../../features/game_prizes/domain/entities/effective_game_prize.dart';

const int kPrizeMultiplier = 80;
const int kDateMultiplier = 200;
const int kComboMultiplier = 4000;
const int kGana3ExactMultiplier = 600;
const int kGana3EasyMultiplier = 100;
/// Multiplicador para Juega3 fácil cuando el label tiene dígitos repetidos
/// (ej. 121, 010, 252). Como toda permutación ganadora de ese multiset
/// necesariamente tiene pareja, el pago siempre es este multiplicador —
/// no depende del sorteo, es determinístico según el label. La sucursal
/// puede sobrescribirlo desde su config (`pairEasyMultiplier`).
const int kGana3PairEasyMultiplier = 200;

int prizeFor(int amount) => amount * kPrizeMultiplier;

/// True si el label numérico de Juega3 (3 dígitos) tiene al menos 2
/// dígitos iguales. `numberLabel` viene ya en formato `NNN` (padded).
bool gana3LabelHasPair(String numberLabel) {
  if (numberLabel.isEmpty) return false;
  return numberLabel.split('').toSet().length < numberLabel.length;
}

/// Re-escala el prize calculado con constantes hardcoded al valor efectivo
/// de la sucursal. Si el multiplicador implícito de la línea (prize/amount)
/// matchea el default del juego (`exactDefault`/`easyDefault`), se cambia
/// por el override configurado.
///
/// Casos especiales:
///  - Fácil-pareja de Juega3 (label con `(F)` y dígitos repetidos): usamos
///    `pairEasyMultiplier` de la sucursal directo — no depende del prize
///    original, porque toda permutación ganadora es pareja.
///  - Sin sucursal (o) → devolvemos el prize crudo.
///  - Prize no divisible por amount → devolvemos tal cual (defensivo).
int rescaleEffectivePrize(
  int amount,
  int existingPrize,
  EffectiveGamePrize? o, {
  String? label,
}) {
  if (o == null || amount <= 0) return existingPrize;

  // Fácil-pareja: chequeo primero — sobrescribe cualquier otra lógica.
  if (label != null) {
    final isFacil = RegExp(r'\(F\)', caseSensitive: false).hasMatch(label);
    if (isFacil) {
      final digits = label
          .replaceAll(RegExp(r'\(F\)', caseSensitive: false), '')
          .trim();
      final hasPair = digits.isNotEmpty &&
          digits.split('').toSet().length < digits.length;
      if (hasPair && o.pairEasyMultiplier != null) {
        return amount * o.pairEasyMultiplier!;
      }
    }
  }

  if (existingPrize % amount != 0) return existingPrize;
  final implicit = existingPrize ~/ amount;

  if (o.exactDefault != null && implicit == o.exactDefault) {
    final target = o.exactMultiplier ?? o.exactDefault!;
    return amount * target;
  }
  if (o.easyDefault != null && implicit == o.easyDefault) {
    final target = o.easyMultiplier ?? o.easyDefault!;
    return amount * target;
  }
  return existingPrize;
}
