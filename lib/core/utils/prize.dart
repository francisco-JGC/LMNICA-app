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
