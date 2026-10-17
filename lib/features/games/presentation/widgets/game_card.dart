import 'package:flutter/material.dart';

import '../../domain/entities/game.dart';

class GameCard extends StatelessWidget {
  const GameCard({required this.game, required this.onTap, super.key});

  final Game game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Content(game: game),
              if (!game.isActive) const _InactiveOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

class _InactiveOverlay extends StatelessWidget {
  const _InactiveOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'No disponible',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    if (game.imagePath == null) {
      return _Fallback(game: game);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          game.imagePath!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _Fallback(game: game),
        ),
        const _Vignette(),
      ],
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 0.85,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.35),
              Colors.black.withValues(alpha: 0.80),
            ],
            stops: const [0.40, 0.75, 1.0],
          ),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.game});

  final Game game;

  static const _palette = <String, List<Color>>{
    'diaria': [Color(0xFF3A1F2B), Color(0xFF1A0D14)],
    'juega3': [Color(0xFF3D2A0F), Color(0xFF17100A)],
    'fechas': [Color(0xFF2E1C10), Color(0xFF160C08)],
    'combo': [Color(0xFF2A1A28), Color(0xFF120A11)],
    'terminacion2': [Color(0xFF102030), Color(0xFF060C14)],
    'tica': [Color(0xFF3A1414), Color(0xFF1A0808)],
    'tresmonazo': [Color(0xFF33230A), Color(0xFF160E06)],
    'hondurena': [Color(0xFF1B2A1E), Color(0xFF0A130D)],
    'gana3': [Color(0xFF34260C), Color(0xFF15100A)],
    'primera': [Color(0xFF102A3A), Color(0xFF071620)],
    'salvadorena': [Color(0xFF2A2010), Color(0xFF141008)],
    'rifas': [Color(0xFF291632), Color(0xFF130A18)],
    'juga4': [Color(0xFF0A1830), Color(0xFF050C18)],
    'multisorteo': [Color(0xFF1F1F1F), Color(0xFF0A0A0A)],
  };

  @override
  Widget build(BuildContext context) {
    final colors =
        _palette[game.id] ?? const [Color(0xFF222222), Color(0xFF0D0D0D)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            game.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
