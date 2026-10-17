import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/game_type.dart';
import '../models/game_model.dart';

abstract interface class GamesLocalDatasource {
  Future<List<GameModel>> readCached();
  Future<void> writeCache(List<GameModel> games);
  Future<List<GameModel>> readFallback();
}

class GamesLocalDatasourceImpl implements GamesLocalDatasource {
  const GamesLocalDatasourceImpl({required this.prefs});

  final SharedPreferences prefs;

  static const _cacheKey = 'games.cache_v1';
  static const _basePath = 'assets/images/games';

  @override
  Future<List<GameModel>> readCached() async {
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => GameModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      await prefs.remove(_cacheKey);
      return const [];
    }
  }

  @override
  Future<void> writeCache(List<GameModel> games) async {
    final encoded =
        jsonEncode(games.map((game) => game.toJson()).toList());
    await prefs.setString(_cacheKey, encoded);
  }

  @override
  Future<List<GameModel>> readFallback() async {
    return const [
      GameModel(
        id: 'diaria',
        slug: 'diaria',
        name: 'Diaria',
        type: GameType.regular,
        exactMultiplier: 80,
        imagePath: '$_basePath/diaria.jpeg',
        orderIndex: 1,
      ),
      GameModel(
        id: 'juega3',
        slug: 'juega3',
        name: 'Juega 3',
        type: GameType.threeDigit,
        exactMultiplier: 600,
        easyMultiplier: 100,
        imagePath: '$_basePath/juega3.jpeg',
        orderIndex: 2,
      ),
      GameModel(
        id: 'fechas',
        slug: 'fechas',
        name: 'Fechas',
        type: GameType.date,
        exactMultiplier: 200,
        imagePath: '$_basePath/fechas.jpeg',
        orderIndex: 3,
      ),
      GameModel(
        id: 'combo',
        slug: 'combo',
        name: 'Combo',
        type: GameType.fourDigit,
        exactMultiplier: 4000,
        imagePath: '$_basePath/combo.jpeg',
        orderIndex: 4,
      ),
      GameModel(
        id: 'terminacion2',
        slug: 'terminacion2',
        name: 'Terminación 2',
        type: GameType.regular,
        exactMultiplier: 80,
        imagePath: '$_basePath/terminacion2.jpeg',
        orderIndex: 5,
      ),
      GameModel(
        id: 'tica',
        slug: 'tica',
        name: 'Tica',
        type: GameType.regular,
        exactMultiplier: 80,
        imagePath: '$_basePath/tica.jpeg',
        orderIndex: 6,
      ),
      GameModel(
        id: 'tresmonazo',
        slug: 'tresmonazo',
        name: 'Tresmonazo',
        type: GameType.threeDigit,
        exactMultiplier: 600,
        easyMultiplier: 100,
        imagePath: '$_basePath/tresmonazo.jpeg',
        orderIndex: 7,
      ),
      GameModel(
        id: 'hondurena',
        slug: 'hondurena',
        name: 'Hondureña',
        type: GameType.regular,
        exactMultiplier: 80,
        imagePath: '$_basePath/hondurena.jpeg',
        orderIndex: 8,
      ),
      GameModel(
        id: 'gana3',
        slug: 'gana3',
        name: 'Gana 3',
        type: GameType.threeDigit,
        exactMultiplier: 600,
        easyMultiplier: 100,
        imagePath: '$_basePath/gana3.jpeg',
        orderIndex: 9,
      ),
      GameModel(
        id: 'primera',
        slug: 'primera',
        name: 'Primera',
        type: GameType.regular,
        exactMultiplier: 80,
        imagePath: '$_basePath/primera.jpeg',
        orderIndex: 10,
      ),
      GameModel(
        id: 'salvadorena',
        slug: 'salvadorena',
        name: 'Salvadoreña',
        type: GameType.regular,
        exactMultiplier: 80,
        imagePath: '$_basePath/salvadorena.jpeg',
        orderIndex: 11,
      ),
      GameModel(
        id: 'rifas',
        slug: 'rifas',
        name: 'Rifas',
        type: GameType.regular,
        exactMultiplier: 80,
        imagePath: '$_basePath/rifas.jpeg',
        orderIndex: 12,
      ),
      GameModel(
        id: 'juga4',
        slug: 'juga4',
        name: 'Juga 4',
        type: GameType.fourDigit,
        exactMultiplier: 6000,
        imagePath: '$_basePath/juga4.webp',
        orderIndex: 13,
      ),
      GameModel(
        id: 'multisorteo',
        slug: 'multisorteo',
        name: 'Multi Sorteo',
        type: GameType.multiSorteo,
        imagePath: '$_basePath/multisorteo.jpeg',
        orderIndex: 14,
      ),
    ];
  }
}
