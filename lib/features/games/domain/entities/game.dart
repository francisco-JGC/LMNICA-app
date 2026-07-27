import 'package:equatable/equatable.dart';

import 'game_type.dart';

class Game extends Equatable {
  const Game({
    required this.id,
    required this.slug,
    required this.name,
    required this.type,
    this.exactMultiplier,
    this.easyMultiplier,
    this.pairEasyMultiplier,
    this.imagePath,
    this.orderIndex = 0,
    this.isActive = true,
  });

  final String id;
  final String slug;
  final String name;
  final GameType type;
  final int? exactMultiplier;
  final int? easyMultiplier;

  /// Multiplicador para el "premio par" — se paga al ganar por fácil cuando
  /// el número ganador tiene dígitos repetidos. Solo THREE_DIGIT lo usa, y
  /// aun ahí es opcional (null = regla apagada para ese juego).
  final int? pairEasyMultiplier;

  final String? imagePath;
  final int orderIndex;
  final bool isActive;

  @override
  List<Object?> get props => [
        id,
        slug,
        name,
        type,
        exactMultiplier,
        easyMultiplier,
        pairEasyMultiplier,
        imagePath,
        orderIndex,
        isActive,
      ];
}
