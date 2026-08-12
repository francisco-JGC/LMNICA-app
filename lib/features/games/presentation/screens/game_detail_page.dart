import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/current_user.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/time_format.dart';
import '../../../game_prizes/domain/entities/effective_game_prize.dart';
import '../../../game_prizes/presentation/state/effective_game_prizes_provider.dart';
import '../../../printer/domain/entities/ticket_payload.dart';
import '../../../printer/presentation/state/printer_controller.dart';
import '../../../sale_limits/presentation/state/sale_limit_availability_provider.dart';
import '../../../sale_limits/presentation/widgets/sale_limits_banner.dart';
import '../../../sale_points/presentation/state/active_sale_point_controller.dart';
import '../../../sales/presentation/state/cart_controller.dart';
import '../../../sales/presentation/state/cart_state.dart';
import '../../../sales/presentation/state/combo_cart_controller.dart';
import '../../../sales/presentation/state/combo_cart_state.dart';
import '../../../sales/presentation/state/date_cart_controller.dart';
import '../../../sales/presentation/state/date_cart_state.dart';
import '../../../sales/presentation/state/form_reset_provider.dart';
import '../../../sales/presentation/state/gana3_cart_controller.dart';
import '../../../sales/presentation/state/gana3_cart_state.dart';
import '../../../sales/presentation/widgets/bet_tile.dart';
import '../../../sales/presentation/widgets/combo_bet_tile.dart';
import '../../../sales/presentation/widgets/combo_line_form.dart';
import '../../../sales/presentation/widgets/combo_random_form.dart';
import '../../../sales/presentation/widgets/date_bet_tile.dart';
import '../../../sales/presentation/widgets/date_line_form.dart';
import '../../../sales/presentation/widgets/gana3_bet_tile.dart';
import '../../../sales/presentation/widgets/gana3_line_form.dart';
import '../../../sales/presentation/widgets/gana3_random_form.dart';
import '../../../sales/presentation/widgets/line_form.dart';
import '../../../sales/presentation/widgets/quick_bet_form.dart';
import '../../../sales/presentation/widgets/quick_combo_bet_form.dart';
import '../../../sales/presentation/widgets/quick_date_bet_form.dart';
import '../../../sales/presentation/widgets/quick_gana3_bet_form.dart';
import '../../../sales/presentation/widgets/random_form.dart';
import '../../../schedules/presentation/state/available_draws_provider.dart';
import '../../../schedules/presentation/state/game_lock_controller.dart';
import '../../../schedules/presentation/widgets/game_lock_gate.dart';
import '../../../settings/domain/entities/billing_method.dart';
import '../../../settings/presentation/state/settings_controller.dart';
import '../../../tickets/domain/entities/create_ticket_request.dart';
import '../../../tickets/domain/entities/ticket_receipt.dart';
import '../../../tickets/domain/usecases/create_ticket.dart';
import '../../../whatsapp_billing/presentation/services/ticket_image_share_service.dart';
import '../../domain/entities/game.dart';
import '../../domain/entities/game_type.dart';
import '../state/games_controller.dart';

/// True mientras un `_persistAndPrint` está en curso — desde el momento en
/// que el botón se toca hasta que termina (o falla). Cubre la ventana entre
/// el click y `printerState.isPrinting` prendiéndose adentro de
/// `printer_controller.printTicket()`, durante la cual el usuario podría
/// pulsar el botón dos veces y crear tickets duplicados en el backend.
class TicketSubmittingController extends Notifier<bool> {
  @override
  bool build() => false;

  void setValue(bool value) => state = value;
}

final ticketSubmittingProvider =
    NotifierProvider<TicketSubmittingController, bool>(
  TicketSubmittingController.new,
);

/// Guard duro sincrónico contra reentradas de `_persistAndPrint`. Vive
/// paralelo al Notifier porque el rebuild del widget que deshabilita el
/// botón es asíncrono — un doble tap muy rápido puede colar la segunda
/// llamada antes de que el UI vea el estado nuevo. Este bool no depende
/// del ciclo de Flutter/Riverpod, solo del event loop de Dart, así que
/// dos taps back-to-back en el mismo micro-turno también quedan cubiertos.
bool _submissionInFlight = false;

/// UUID v4 generator compartido — barato de instanciar pero reutilizamos
/// para no crear un `Random` nuevo por venta.
const _uuid = Uuid();

class GameDetailPage extends ConsumerWidget {
  const GameDetailPage({required this.gameId, this.game, super.key});

  final String gameId;
  final Game? game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = game;
    if (resolved == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Juego')),
        body: _NotFound(gameId: gameId),
      );
    }
    final child = switch (resolved.type) {
      GameType.date => _DateGameView(game: resolved),
      GameType.threeDigit => _Gana3GameView(game: resolved),
      GameType.fourDigit => _ComboGameView(game: resolved),
      GameType.multiSorteo => _MultiSorteoGameView(game: resolved),
      GameType.regular => _RegularGameView(game: resolved),
    };
    return GameLockGate(gameId: resolved.id, child: child);
  }
}

class _RegularGameView extends ConsumerWidget {
  const _RegularGameView({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider(game.id));
    final controller = ref.read(cartControllerProvider(game.id).notifier);
    final printerState = ref.watch(printerControllerProvider);
    final submitting = ref.watch(ticketSubmittingProvider);
    final formResetKey = ref.watch(formResetProvider(game.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(game.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Registrar línea',
            onPressed: () => _openLineForm(context, controller),
          ),
          IconButton(
            icon: const Icon(Icons.casino_outlined),
            tooltip: 'Registrar aleatorio',
            onPressed: () => _openRandomForm(context, controller),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Escanear boleto',
            onPressed: () => context.push('/juegos/${game.id}/escanear', extra: game),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Limpiar carrito',
            onPressed: cart.isEmpty
                ? null
                : () => _confirmClear(context, controller.clear),
          ),
        ],
      ),
      body: Column(
        children: [
          SaleLimitsBannerAuto(gameId: game.id),
          QuickBetForm(
            key: ValueKey('quick-bet-form-$formResetKey'),
            onSubmit: controller.addSingle,
          ),
          Expanded(
            child: cart.isEmpty
                ? const _EmptyView()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: cart.bets.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => BetTile(
                      bet: cart.bets[i],
                      onRemove: () => controller.removeAt(i),
                    ),
                  ),
          ),
          if (cart.isNotEmpty)
            _TotalBar(
              total: cart.total,
              numberCount: cart.count,
              isPrinting: printerState.isPrinting || submitting,
              onPrint: () => _printRegular(context, ref, game, cart),
            ),
        ],
      ),
    );
  }

  Future<void> _openLineForm(
    BuildContext context,
    CartController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => LineForm(
        onSubmit: (r) {
          controller.addRange(
            start: r.start,
            end: r.end,
            amount: r.amount,
          );
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Future<void> _openRandomForm(
    BuildContext context,
    CartController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => RandomForm(
        onSubmit: (r) {
          controller.addRandom(count: r.count, amount: r.amount);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

class _DateGameView extends ConsumerWidget {
  const _DateGameView({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(dateCartControllerProvider(game.id));
    final controller =
        ref.read(dateCartControllerProvider(game.id).notifier);
    final printerState = ref.watch(printerControllerProvider);
    final submitting = ref.watch(ticketSubmittingProvider);
    final formResetKey = ref.watch(formResetProvider(game.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(game.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Registrar línea',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (ctx) => DateLineForm(
                onSubmit: (r) {
                  controller.addRange(
                    dayStart: r.dayStart,
                    dayEnd: r.dayEnd,
                    month: r.month,
                    amount: r.amount,
                  );
                  Navigator.of(ctx).pop();
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Escanear boleto',
            onPressed: () => context.push('/juegos/${game.id}/escanear', extra: game),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Limpiar carrito',
            onPressed: cart.isEmpty
                ? null
                : () => _confirmClear(context, controller.clear),
          ),
        ],
      ),
      body: Column(
        children: [
          SaleLimitsBannerAuto(gameId: game.id),
          QuickDateBetForm(
            key: ValueKey('quick-date-bet-form-$formResetKey'),
            onSubmit: controller.addSingle,
          ),
          Expanded(
            child: cart.isEmpty
                ? const _EmptyView(
                    icon: Icons.calendar_month_outlined,
                    label: 'Aún no hay fechas registradas',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: cart.bets.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => DateBetTile(
                      bet: cart.bets[i],
                      onRemove: () => controller.removeAt(i),
                    ),
                  ),
          ),
          if (cart.isNotEmpty)
            _TotalBar(
              total: cart.total,
              numberCount: cart.count,
              isPrinting: printerState.isPrinting || submitting,
              onPrint: () => _printDates(context, ref, game, cart),
            ),
        ],
      ),
    );
  }
}

class _MultiSorteoGameView extends ConsumerStatefulWidget {
  const _MultiSorteoGameView({required this.game});

  final Game game;

  @override
  ConsumerState<_MultiSorteoGameView> createState() =>
      _MultiSorteoGameViewState();
}

class _MultiSorteoGameViewState
    extends ConsumerState<_MultiSorteoGameView> {
  Game? _selectedSubGame;
  final Set<DateTime> _selectedDrawAts = <DateTime>{};
  bool _isBatchPrinting = false;

  @override
  Widget build(BuildContext context) {
    final gamesAsync = ref.watch(gamesControllerProvider);
    final printerState = ref.watch(printerControllerProvider);
    final submitting = ref.watch(ticketSubmittingProvider);

    final subGames = (gamesAsync.value ?? const <Game>[])
        .where((g) => g.type != GameType.multiSorteo && g.id != widget.game.id)
        .toList();

    if (_selectedSubGame == null && subGames.isNotEmpty) {
      _selectedSubGame = subGames.first;
    } else if (_selectedSubGame != null &&
        !subGames.any((g) => g.id == _selectedSubGame!.id)) {
      _selectedSubGame = subGames.isNotEmpty ? subGames.first : null;
      _selectedDrawAts.clear();
    }

    final sub = _selectedSubGame;
    final cartSummary = sub == null ? null : _readCartSummary(sub);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.game.name, style: const TextStyle(fontSize: 18)),
            if (sub != null)
              Text(sub.name, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          if (sub != null)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Limpiar carrito',
              onPressed: cartSummary != null && !cartSummary.isEmpty
                  ? () => _confirmClear(context, () => _clearCart(sub))
                  : null,
            ),
        ],
      ),
      body: Column(
        children: [
          _SubGameChips(
            subGames: subGames,
            selectedId: sub?.id,
            onSelected: (g) => setState(() {
              _selectedSubGame = g;
              _selectedDrawAts.clear();
            }),
          ),
          if (sub != null) ...[
            SaleLimitsBannerAuto(gameId: sub.id),
            _cartBodyFor(sub),
            _AvailableDrawsSelector(
              gameId: sub.id,
              selected: _selectedDrawAts,
              onToggle: (d) => setState(() {
                if (_selectedDrawAts.contains(d)) {
                  _selectedDrawAts.remove(d);
                } else {
                  _selectedDrawAts.add(d);
                }
              }),
            ),
            if (cartSummary != null &&
                !cartSummary.isEmpty &&
                _selectedDrawAts.isNotEmpty)
              _MultiTotalBar(
                total: cartSummary.total * _selectedDrawAts.length,
                ticketCount: _selectedDrawAts.length,
                isPrinting: _isBatchPrinting ||
                    printerState.isPrinting ||
                    submitting,
                onPrint: () => _printMultiSorteoDraws(sub),
              ),
          ],
        ],
      ),
    );
  }

  Widget _cartBodyFor(Game sub) {
    final formResetKey = ref.watch(formResetProvider(sub.id));
    switch (sub.type) {
      case GameType.regular:
        final cart = ref.watch(cartControllerProvider(sub.id));
        final controller = ref.read(cartControllerProvider(sub.id).notifier);
        return Expanded(
          child: _scrollableCart(
            form: QuickBetForm(
              key: ValueKey('quick-bet-form-$formResetKey'),
              onSubmit: controller.addSingle,
            ),
            isEmpty: cart.isEmpty,
            itemCount: cart.bets.length,
            itemBuilder: (i) => BetTile(
              bet: cart.bets[i],
              onRemove: () => controller.removeAt(i),
            ),
          ),
        );
      case GameType.date:
        final cart = ref.watch(dateCartControllerProvider(sub.id));
        final controller =
            ref.read(dateCartControllerProvider(sub.id).notifier);
        return Expanded(
          child: _scrollableCart(
            form: QuickDateBetForm(
              key: ValueKey('quick-date-bet-form-$formResetKey'),
              onSubmit: controller.addSingle,
            ),
            isEmpty: cart.isEmpty,
            emptyIcon: Icons.calendar_month_outlined,
            emptyLabel: 'Aún no hay fechas registradas',
            itemCount: cart.bets.length,
            itemBuilder: (i) => DateBetTile(
              bet: cart.bets[i],
              onRemove: () => controller.removeAt(i),
            ),
          ),
        );
      case GameType.threeDigit:
        final cart = ref.watch(gana3CartControllerProvider(sub.id));
        final controller =
            ref.read(gana3CartControllerProvider(sub.id).notifier);
        return Expanded(
          child: _scrollableCart(
            form: QuickGana3BetForm(
              key: ValueKey('quick-gana3-bet-form-$formResetKey'),
              onSubmit: controller.addSingle,
            ),
            isEmpty: cart.isEmpty,
            itemCount: cart.bets.length,
            itemBuilder: (i) => Gana3BetTile(
              bet: cart.bets[i],
              onRemove: () => controller.removeAt(i),
            ),
          ),
        );
      case GameType.fourDigit:
        final cart = ref.watch(comboCartControllerProvider(sub.id));
        final controller =
            ref.read(comboCartControllerProvider(sub.id).notifier);
        return Expanded(
          child: _scrollableCart(
            form: QuickComboBetForm(
              key: ValueKey('quick-combo-bet-form-$formResetKey'),
              onSubmit: controller.addSingle,
            ),
            isEmpty: cart.isEmpty,
            itemCount: cart.bets.length,
            itemBuilder: (i) => ComboBetTile(
              bet: cart.bets[i],
              onRemove: () => controller.removeAt(i),
            ),
          ),
        );
      case GameType.multiSorteo:
        return const SizedBox.shrink();
    }
  }

  Widget _scrollableCart({
    required Widget form,
    required bool isEmpty,
    required int itemCount,
    required Widget Function(int index) itemBuilder,
    IconData emptyIcon = Icons.list_alt_outlined,
    String emptyLabel = 'Aún no hay números registrados',
  }) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: form),
        if (isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyView(icon: emptyIcon, label: emptyLabel),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            sliver: SliverList.separated(
              itemCount: itemCount,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => itemBuilder(i),
            ),
          ),
      ],
    );
  }

  ({int total, int count, bool isEmpty}) _readCartSummary(Game sub) {
    switch (sub.type) {
      case GameType.regular:
        final c = ref.watch(cartControllerProvider(sub.id));
        return (total: c.total, count: c.count, isEmpty: c.isEmpty);
      case GameType.date:
        final c = ref.watch(dateCartControllerProvider(sub.id));
        return (total: c.total, count: c.count, isEmpty: c.isEmpty);
      case GameType.threeDigit:
        final c = ref.watch(gana3CartControllerProvider(sub.id));
        return (total: c.total, count: c.count, isEmpty: c.isEmpty);
      case GameType.fourDigit:
        final c = ref.watch(comboCartControllerProvider(sub.id));
        return (total: c.total, count: c.count, isEmpty: c.isEmpty);
      case GameType.multiSorteo:
        return (total: 0, count: 0, isEmpty: true);
    }
  }

  void _clearCart(Game sub) {
    switch (sub.type) {
      case GameType.regular:
        ref.read(cartControllerProvider(sub.id).notifier).clear();
      case GameType.date:
        ref.read(dateCartControllerProvider(sub.id).notifier).clear();
      case GameType.threeDigit:
        ref.read(gana3CartControllerProvider(sub.id).notifier).clear();
      case GameType.fourDigit:
        ref.read(comboCartControllerProvider(sub.id).notifier).clear();
      case GameType.multiSorteo:
        return;
    }
  }

  Future<void> _printMultiSorteoDraws(Game sub) async {
    if (_isBatchPrinting) return;
    setState(() => _isBatchPrinting = true);
    try {
      final draws = _selectedDrawAts.toList()..sort();
      final messenger = ScaffoldMessenger.of(context);
      var okCount = 0;
      for (final drawAt in draws) {
        final ok = await _printOneForDraw(sub, drawAt);
        if (!ok) {
          messenger.showSnackBar(SnackBar(
            content: Text(
              'Se generaron $okCount de ${draws.length} tickets. '
              'Revisa el error del último intento.',
            ),
          ));
          return;
        }
        okCount++;
      }
      if (!mounted) return;
      _clearCart(sub);
      // Fuerza a los forms del subgame a recrearse desde cero — sino el
      // TextField "Cliente" mantiene el nombre para la siguiente venta.
      ref.read(formResetProvider(sub.id).notifier).bump();
      _selectedDrawAts.clear();
      ref.invalidate(availableDrawsProvider(sub.id));
      messenger.showSnackBar(SnackBar(
        content: Text('$okCount ticket(s) impreso(s) correctamente'),
      ));
    } finally {
      if (mounted) setState(() => _isBatchPrinting = false);
    }
  }

  Future<bool> _printOneForDraw(Game sub, DateTime drawAt) async {
    switch (sub.type) {
      case GameType.regular:
        final cart = ref.read(cartControllerProvider(sub.id));
        return _persistAndPrintForSub(
          sub: sub,
          client: cart.client,
          drawAt: drawAt,
          lines: cart.bets
              .map((b) => (
                    label: b.numberLabel,
                    amount: b.amount,
                    prize: b.prize,
                    subGameId: null as String?,
                    subGameName: null as String?,
                  ))
              .toList(),
          buildPayload: (receipt) => TicketPayload(
            id: receipt.id,
            gameId: sub.id,
            gameSlug: sub.slug,
            gameName: sub.name,
            lines: cart.bets
                .map((b) => TicketLine(
                      number: b.numberLabel,
                      amount: b.amount,
                      prize: b.prize,
                    ))
                .toList(),
            folio: receipt.folio,
            date: DateTime.now(),
            drawAt: receipt.drawAt,
            seller: ref.read(currentUserProvider)?.name,
            client: cart.client,
          ),
        );
      case GameType.date:
        final cart = ref.read(dateCartControllerProvider(sub.id));
        return _persistAndPrintForSub(
          sub: sub,
          client: cart.client,
          drawAt: drawAt,
          lines: cart.bets
              .map((b) => (
                    label: b.label,
                    amount: b.amount,
                    prize: b.prize,
                    subGameId: null as String?,
                    subGameName: null as String?,
                  ))
              .toList(),
          buildPayload: (receipt) => TicketPayload(
            id: receipt.id,
            gameId: sub.id,
            gameSlug: sub.slug,
            gameName: sub.name,
            lines: cart.bets
                .map((b) => TicketLine(
                      number: b.label,
                      amount: b.amount,
                      prize: b.prize,
                    ))
                .toList(),
            folio: receipt.folio,
            date: DateTime.now(),
            drawAt: receipt.drawAt,
            seller: ref.read(currentUserProvider)?.name,
            client: cart.client,
          ),
        );
      case GameType.threeDigit:
        final cart = ref.read(gana3CartControllerProvider(sub.id));
        return _persistAndPrintForSub(
          sub: sub,
          client: cart.client,
          drawAt: drawAt,
          lines: cart.bets
              .map((b) => (
                    label: b.isExact ? b.numberLabel : '${b.numberLabel} (F)',
                    amount: b.amount,
                    prize: b.prize,
                    subGameId: null as String?,
                    subGameName: null as String?,
                  ))
              .toList(),
          buildPayload: (receipt) => TicketPayload(
            id: receipt.id,
            gameId: sub.id,
            gameSlug: sub.slug,
            gameName: sub.name,
            lines: cart.bets
                .map((b) => TicketLine(
                      number: b.isExact
                          ? b.numberLabel
                          : '${b.numberLabel} (F)',
                      amount: b.amount,
                      prize: b.prize,
                    ))
                .toList(),
            folio: receipt.folio,
            date: DateTime.now(),
            drawAt: receipt.drawAt,
            seller: ref.read(currentUserProvider)?.name,
            client: cart.client,
          ),
        );
      case GameType.fourDigit:
        final cart = ref.read(comboCartControllerProvider(sub.id));
        return _persistAndPrintForSub(
          sub: sub,
          client: cart.client,
          drawAt: drawAt,
          lines: cart.bets
              .map((b) => (
                    label: b.numberLabel,
                    amount: b.amount,
                    prize: b.prize,
                    subGameId: null as String?,
                    subGameName: null as String?,
                  ))
              .toList(),
          buildPayload: (receipt) => TicketPayload(
            id: receipt.id,
            gameId: sub.id,
            gameSlug: sub.slug,
            gameName: sub.name,
            lines: cart.bets
                .map((b) => TicketLine(
                      number: b.numberLabel,
                      amount: b.amount,
                      prize: b.prize,
                    ))
                .toList(),
            folio: receipt.folio,
            date: DateTime.now(),
            drawAt: receipt.drawAt,
            seller: ref.read(currentUserProvider)?.name,
            client: cart.client,
          ),
        );
      case GameType.multiSorteo:
        return false;
    }
  }

  Future<bool> _persistAndPrintForSub({
    required Game sub,
    required String? client,
    required DateTime drawAt,
    required List<_RequestLine> lines,
    required TicketPayload Function(TicketReceipt) buildPayload,
  }) async {
    var ok = false;
    await _persistAndPrint(
      context,
      ref,
      game: sub,
      client: client,
      lines: lines,
      buildPayload: buildPayload,
      drawAt: drawAt,
      skipLockCheck: true,
      onSuccess: () => ok = true,
    );
    return ok;
  }
}

class _SubGameChips extends StatelessWidget {
  const _SubGameChips({
    required this.subGames,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Game> subGames;
  final String? selectedId;
  final ValueChanged<Game> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: subGames.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final g = subGames[i];
            return ChoiceChip(
              label: Text(g.name),
              selected: selectedId == g.id,
              onSelected: (_) => onSelected(g),
            );
          },
        ),
      ),
    );
  }
}

class _AvailableDrawsSelector extends ConsumerWidget {
  const _AvailableDrawsSelector({
    required this.gameId,
    required this.selected,
    required this.onToggle,
  });

  final String gameId;
  final Set<DateTime> selected;
  final ValueChanged<DateTime> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draws = ref.watch(availableDrawsProvider(gameId));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sorteos disponibles',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          draws.when(
            loading: () =>
                const SizedBox(height: 32, child: LinearProgressIndicator()),
            error: (e, _) => Text(
              'No se pudieron cargar los sorteos.',
              style: TextStyle(color: Colors.red.shade700),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Text(
                  'No hay sorteos disponibles hoy.',
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 110),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: items
                        .map((d) => FilterChip(
                              label: Text(formatTime12h(d.drawAt)),
                              selected: selected.contains(d.drawAt),
                              onSelected: (_) => onToggle(d.drawAt),
                            ))
                        .toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MultiTotalBar extends ConsumerWidget {
  const _MultiTotalBar({
    required this.total,
    required this.ticketCount,
    required this.isPrinting,
    required this.onPrint,
  });

  final int total;
  final int ticketCount;
  final bool isPrinting;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final method = ref.watch(settingsControllerProvider).value ??
        BillingMethod.bluetoothPrinter;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kCurrencyFormat.format(total),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$ticketCount ticket${ticketCount == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              icon: isPrinting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(_iconFor(method)),
              label: Text('${method.actionLabel} $ticketCount'),
              onPressed: isPrinting ? null : onPrint,
            ),
          ],
        ),
      ),
    );
  }
}

/// Icono para el botón según el método de facturación activo. Se comparte
/// entre `_TotalBar` y `_MultiTotalBar`.
IconData _iconFor(BillingMethod method) => switch (method) {
      BillingMethod.bluetoothPrinter => Icons.print,
      BillingMethod.whatsapp => Icons.share,
    };


class _ComboGameView extends ConsumerWidget {
  const _ComboGameView({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(comboCartControllerProvider(game.id));
    final controller =
        ref.read(comboCartControllerProvider(game.id).notifier);
    final printerState = ref.watch(printerControllerProvider);
    final submitting = ref.watch(ticketSubmittingProvider);
    final formResetKey = ref.watch(formResetProvider(game.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(game.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Registrar línea',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (ctx) => ComboLineForm(
                onSubmit: (r) {
                  controller.addRange(
                    start: r.start,
                    end: r.end,
                    amount: r.amount,
                  );
                  Navigator.of(ctx).pop();
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.casino_outlined),
            tooltip: 'Registrar aleatorio',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (ctx) => ComboRandomForm(
                onSubmit: (r) {
                  controller.addRandom(count: r.count, amount: r.amount);
                  Navigator.of(ctx).pop();
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Escanear boleto',
            onPressed: () => context.push('/juegos/${game.id}/escanear', extra: game),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Limpiar carrito',
            onPressed: cart.isEmpty
                ? null
                : () => _confirmClear(context, controller.clear),
          ),
        ],
      ),
      body: Column(
        children: [
          SaleLimitsBannerAuto(gameId: game.id),
          QuickComboBetForm(
            key: ValueKey('quick-combo-bet-form-$formResetKey'),
            onSubmit: controller.addSingle,
          ),
          Expanded(
            child: cart.isEmpty
                ? const _EmptyView(
                    icon: Icons.tag,
                    label: 'Aún no hay números registrados',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: cart.bets.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => ComboBetTile(
                      bet: cart.bets[i],
                      onRemove: () => controller.removeAt(i),
                    ),
                  ),
          ),
          if (cart.isNotEmpty)
            _TotalBar(
              total: cart.total,
              numberCount: cart.count,
              isPrinting: printerState.isPrinting || submitting,
              onPrint: () => _printCombo(context, ref, game, cart),
            ),
        ],
      ),
    );
  }
}

class _Gana3GameView extends ConsumerWidget {
  const _Gana3GameView({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(gana3CartControllerProvider(game.id));
    final controller =
        ref.read(gana3CartControllerProvider(game.id).notifier);
    final printerState = ref.watch(printerControllerProvider);
    final submitting = ref.watch(ticketSubmittingProvider);
    final formResetKey = ref.watch(formResetProvider(game.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(game.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Registrar línea',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (ctx) => Gana3LineForm(
                onSubmit: (r) {
                  controller.addRange(
                    start: r.start,
                    end: r.end,
                    amount: r.amount,
                    isExact: r.isExact,
                  );
                  Navigator.of(ctx).pop();
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.casino_outlined),
            tooltip: 'Registrar aleatorio',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (ctx) => Gana3RandomForm(
                onSubmit: (r) {
                  controller.addRandom(
                    count: r.count,
                    amount: r.amount,
                    isExact: r.isExact,
                  );
                  Navigator.of(ctx).pop();
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Escanear boleto',
            onPressed: () => context.push('/juegos/${game.id}/escanear', extra: game),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Limpiar carrito',
            onPressed: cart.isEmpty
                ? null
                : () => _confirmClear(context, controller.clear),
          ),
        ],
      ),
      body: Column(
        children: [
          SaleLimitsBannerAuto(gameId: game.id),
          QuickGana3BetForm(
            key: ValueKey('quick-gana3-bet-form-$formResetKey'),
            onSubmit: controller.addSingle,
          ),
          Expanded(
            child: cart.isEmpty
                ? const _EmptyView(
                    icon: Icons.tag,
                    label: 'Aún no hay números registrados',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: cart.bets.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => Gana3BetTile(
                      bet: cart.bets[i],
                      onRemove: () => controller.removeAt(i),
                    ),
                  ),
          ),
          if (cart.isNotEmpty)
            _TotalBar(
              total: cart.total,
              numberCount: cart.count,
              isPrinting: printerState.isPrinting || submitting,
              onPrint: () => _printGana3(context, ref, game, cart),
            ),
        ],
      ),
    );
  }
}

Future<void> _confirmClear(
  BuildContext context,
  VoidCallback onConfirm,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Limpiar carrito'),
      content: const Text('¿Descartar todos los números registrados?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Limpiar'),
        ),
      ],
    ),
  );
  if (confirmed ?? false) onConfirm();
}

Future<void> _printRegular(
  BuildContext context,
  WidgetRef ref,
  Game game,
  CartState cart,
) async {
  final lines = cart.bets
      .map((b) => (
            label: b.numberLabel,
            amount: b.amount,
            prize: b.prize,
            subGameId: null as String?,
            subGameName: null as String?,
          ))
      .toList();

  await _persistAndPrint(
    context,
    ref,
    game: game,
    client: cart.client,
    lines: lines,
    buildPayload: (receipt) => TicketPayload(
      id: receipt.id,
      gameId: game.id,
      gameSlug: game.slug,
      gameName: game.name,
      lines: cart.bets
          .map((b) => TicketLine(
                number: b.numberLabel,
                amount: b.amount,
                prize: b.prize,
              ))
          .toList(),
      folio: receipt.folio,
      date: DateTime.now(),
      drawAt: receipt.drawAt,
      seller: ref.read(currentUserProvider)?.name,
      client: cart.client,
    ),
    onSuccess: () {
      ref.read(cartControllerProvider(game.id).notifier).clear();
      // Fuerza a los forms a recrearse desde cero → limpia el
      // `TextEditingController` local del campo "Cliente" que sino
      // conserva el nombre para la siguiente venta.
      ref.read(formResetProvider(game.id).notifier).bump();
    },
  );
}

Future<void> _printCombo(
  BuildContext context,
  WidgetRef ref,
  Game game,
  ComboCartState cart,
) async {
  final lines = cart.bets
      .map((b) => (
            label: b.numberLabel,
            amount: b.amount,
            prize: b.prize,
            subGameId: null as String?,
            subGameName: null as String?,
          ))
      .toList();

  await _persistAndPrint(
    context,
    ref,
    game: game,
    client: cart.client,
    lines: lines,
    buildPayload: (receipt) => TicketPayload(
      id: receipt.id,
      gameId: game.id,
      gameSlug: game.slug,
      gameName: game.name,
      lines: cart.bets
          .map((b) => TicketLine(
                number: b.numberLabel,
                amount: b.amount,
                prize: b.prize,
              ))
          .toList(),
      folio: receipt.folio,
      date: DateTime.now(),
      drawAt: receipt.drawAt,
      seller: ref.read(currentUserProvider)?.name,
      client: cart.client,
    ),
    onSuccess: () {
      ref.read(comboCartControllerProvider(game.id).notifier).clear();
      ref.read(formResetProvider(game.id).notifier).bump();
    },
  );
}

Future<void> _printGana3(
  BuildContext context,
  WidgetRef ref,
  Game game,
  Gana3CartState cart,
) async {
  final lines = cart.bets
      .map((b) => (
            label: b.isExact ? b.numberLabel : '${b.numberLabel} (F)',
            amount: b.amount,
            prize: b.prize,
            subGameId: null as String?,
            subGameName: null as String?,
          ))
      .toList();

  await _persistAndPrint(
    context,
    ref,
    game: game,
    client: cart.client,
    lines: lines,
    buildPayload: (receipt) => TicketPayload(
      id: receipt.id,
      gameId: game.id,
      gameSlug: game.slug,
      gameName: game.name,
      lines: cart.bets
          .map((b) => TicketLine(
                number: b.isExact ? b.numberLabel : '${b.numberLabel} (F)',
                amount: b.amount,
                prize: b.prize,
              ))
          .toList(),
      folio: receipt.folio,
      date: DateTime.now(),
      drawAt: receipt.drawAt,
      seller: ref.read(currentUserProvider)?.name,
      client: cart.client,
    ),
    onSuccess: () {
      ref.read(gana3CartControllerProvider(game.id).notifier).clear();
      ref.read(formResetProvider(game.id).notifier).bump();
    },
  );
}

Future<void> _printDates(
  BuildContext context,
  WidgetRef ref,
  Game game,
  DateCartState cart,
) async {
  final lines = cart.bets
      .map((b) => (
            label: b.label,
            amount: b.amount,
            prize: b.prize,
            subGameId: null as String?,
            subGameName: null as String?,
          ))
      .toList();

  await _persistAndPrint(
    context,
    ref,
    game: game,
    client: cart.client,
    lines: lines,
    buildPayload: (receipt) => TicketPayload(
      id: receipt.id,
      gameId: game.id,
      gameSlug: game.slug,
      gameName: game.name,
      lines: cart.bets
          .map((b) => TicketLine(
                number: b.label,
                amount: b.amount,
                prize: b.prize,
              ))
          .toList(),
      folio: receipt.folio,
      date: DateTime.now(),
      drawAt: receipt.drawAt,
      seller: ref.read(currentUserProvider)?.name,
      client: cart.client,
    ),
    onSuccess: () {
      ref.read(dateCartControllerProvider(game.id).notifier).clear();
      ref.read(formResetProvider(game.id).notifier).bump();
    },
  );
}

typedef _RequestLine = ({
  String label,
  int amount,
  int prize,
  String? subGameId,
  String? subGameName,
});

Future<void> _persistAndPrint(
  BuildContext context,
  WidgetRef ref, {
  required Game game,
  required String? client,
  required List<_RequestLine> lines,
  required TicketPayload Function(TicketReceipt) buildPayload,
  required VoidCallback onSuccess,
  DateTime? drawAt,
  bool skipLockCheck = false,
}) async {
  // Guard duro primero: bool sincrónico a nivel de módulo. Atrapa el
  // reentry aunque el rebuild del provider aún no haya llegado al widget.
  if (_submissionInFlight) return;
  _submissionInFlight = true;
  // Y el provider además, para que el botón cambie visualmente a disabled.
  ref.read(ticketSubmittingProvider.notifier).setValue(true);
  try {
    await _persistAndPrintInner(
      context,
      ref,
      game: game,
      client: client,
      lines: lines,
      buildPayload: buildPayload,
      onSuccess: onSuccess,
      drawAt: drawAt,
      skipLockCheck: skipLockCheck,
    );
  } finally {
    _submissionInFlight = false;
    ref.read(ticketSubmittingProvider.notifier).setValue(false);
  }
}

Future<void> _persistAndPrintInner(
  BuildContext context,
  WidgetRef ref, {
  required Game game,
  required String? client,
  required List<_RequestLine> lines,
  required TicketPayload Function(TicketReceipt) buildPayload,
  required VoidCallback onSuccess,
  DateTime? drawAt,
  bool skipLockCheck = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final printer = ref.read(printerControllerProvider);
  final salePoint = ref.read(activeSalePointProvider).selected;
  final lock = ref.read(gameLockControllerProvider(game.id));
  final billingMethod =
      ref.read(settingsControllerProvider).value ?? BillingMethod.bluetoothPrinter;

  if (!skipLockCheck && lock.isLocked) {
    messenger.showSnackBar(const SnackBar(
      content: Text('Sorteo en curso. No se pueden ingresar boletos ahora.'),
    ));
    return;
  }
  if (salePoint == null) {
    messenger.showSnackBar(const SnackBar(
      content: Text('No hay puesto de venta activo.'),
    ));
    return;
  }
  // El check de impresora conectada solo aplica cuando el método activo la
  // requiere. Para whatsapp no hace falta impresora — se genera imagen.
  if (billingMethod == BillingMethod.bluetoothPrinter && !printer.isConnected) {
    messenger.showSnackBar(const SnackBar(
      content: Text(
        'No hay impresora conectada. Ve a Configuración → Impresora.',
      ),
    ));
    return;
  }

  // Rescale line prizes if this sucursal has per-game overrides. We look
  // up the effective multipliers, then for each line detect whether the
  // caller used the "main" or "secondary" default and swap it for the
  // override. Custom prizes matching neither default pass through unchanged.
  final prizesAsync =
      await ref.read(effectiveGamePrizesProvider(salePoint.id).future);
  final prizeByGameId = <String, EffectiveGamePrize>{
    for (final p in prizesAsync) p.gameId: p,
  };

  final requestLines = lines.map((l) {
    // A ticket line's game_id is the parent game unless it's a sub-game
    // line (multi-sorteo). Use whichever applies for the multiplier lookup.
    final gameIdForLookup = l.subGameId ?? game.id;
    final override = prizeByGameId[gameIdForLookup];
    final prize = _rescalePrize(l.amount, l.prize, override);
    final pairEasyPrize = _resolvePairEasyPrize(l, override);
    return CreateTicketLine(
      label: l.label,
      amount: l.amount,
      prize: prize,
      pairEasyPrize: pairEasyPrize,
      subGameId: l.subGameId,
      subGameName: l.subGameName,
    );
  }).toList();

  // UUID de idempotencia — se genera UNA sola vez por intento de venta y
  // se manda al backend. Si la respuesta se pierde (timeout, red mala) y
  // el vendedor toca "Enviar" de nuevo, o si el `AuthInterceptor` reintenta
  // tras un refresh de token, el segundo POST llega con el mismo id y el
  // backend devuelve el ticket existente en lugar de duplicarlo.
  final clientRequestId = _uuid.v4();

  final request = CreateTicketRequest(
    gameId: game.id,
    salePointId: salePoint.id,
    client: client,
    drawAt: drawAt,
    lines: requestLines,
    clientRequestId: clientRequestId,
  );

  final result = await getIt<CreateTicket>().call(request);
  final receipt = result.fold<TicketReceipt?>(
    (failure) {
      messenger.showSnackBar(SnackBar(
        content: Text('No se pudo registrar el ticket: ${failure.message}'),
      ));
      return null;
    },
    (r) => r,
  );
  if (receipt == null) return;

  // Fresh sale — invalidate availability so the banner reflects the new
  // usage on next fetch. Family-level invalidation covers every (game,
  // sucursal, drawAt) combo cached, which is safest across pickers.
  ref.invalidate(saleLimitAvailabilityProvider);

  final payload = buildPayload(receipt);

  // Bifurcación por método de facturación. El ticket YA quedó persistido en
  // el backend arriba — acá solo cambia cómo se lo entregamos al cliente.
  // Si la entrega falla (impresora perdida, share cancelado), el ticket
  // sigue existiendo y se puede reintentar desde el historial.
  switch (billingMethod) {
    case BillingMethod.bluetoothPrinter:
      await ref.read(printerControllerProvider.notifier).printTicket(payload);
      final after = ref.read(printerControllerProvider);
      if (after.errorMessage != null) {
        messenger.showSnackBar(SnackBar(
          content: Text('Ticket #${receipt.folio} registrado, pero falló la '
              'impresión: ${after.errorMessage}'),
        ));
        return;
      }
    case BillingMethod.whatsapp:
      if (!context.mounted) return;
      final shared = await const TicketImageShareService()
          .share(context: context, payload: payload);
      if (!context.mounted) return;
      if (!shared) {
        messenger.showSnackBar(SnackBar(
          content: Text('Ticket #${receipt.folio} registrado, pero falló la '
              'generación de la imagen para compartir.'),
        ));
        return;
      }
  }

  onSuccess();
  final drawTime = formatTime12h(receipt.drawAt);
  messenger.showSnackBar(SnackBar(
    content: Text('Ticket #${receipt.folio} — Sorteo $drawTime'),
  ));
}


class _EmptyView extends StatelessWidget {
  const _EmptyView({
    this.icon = Icons.grid_view_outlined,
    this.label = 'Aún no hay números registrados',
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalBar extends ConsumerWidget {
  const _TotalBar({
    required this.total,
    required this.numberCount,
    required this.isPrinting,
    required this.onPrint,
  });

  final int total;
  final int numberCount;
  final bool isPrinting;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final method = ref.watch(settingsControllerProvider).value ??
        BillingMethod.bluetoothPrinter;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kCurrencyFormat.format(total),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$numberCount número${numberCount == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              icon: isPrinting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(_iconFor(method)),
              label: Text(method.actionLabel),
              onPressed: isPrinting ? null : onPrint,
            ),
          ],
        ),
      ),
    );
  }
}

/// Detect whether the client-computed [existingPrize] used the game's
/// `main` or `secondary` default and, if so, swap for the per-sucursal
/// override. Prizes that don't match either default are returned as-is
/// (some game types compute prize via non-linear rules we can't rescale).
int _rescalePrize(int amount, int existingPrize, EffectiveGamePrize? o) {
  if (o == null || amount <= 0) return existingPrize;
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

/// Snapshot del premio "par" (fácil sobre número ganador con dígitos
/// repetidos). Solo se llena si:
///   1. El juego evaluado es Juega 3 (por slug — es una regla de negocio
///      específica, no de tipo THREE_DIGIT; Gana 3 y Tresmonazo comparten
///      tipo pero no la regla).
///   2. La línea es fácil (sufijo `(F)` en el label, misma convención que
///      el backend en `TicketEvaluator`).
///   3. La sucursal tiene `pairEasyMultiplier` efectivo no-null para ese
///      juego.
/// Devuelve null si algún check falla; el backend cae al `prize` estándar.
int? _resolvePairEasyPrize(_RequestLine l, EffectiveGamePrize? o) {
  if (o == null) return null;
  if (o.gameSlug != 'juega3') return null;
  final pair = o.pairEasyMultiplier;
  if (pair == null) return null;
  final isFacil = RegExp(r'\(F\)', caseSensitive: false).hasMatch(l.label);
  if (!isFacil) return null;
  return l.amount * pair;
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.black38),
          const SizedBox(height: 12),
          Text('Juego "$gameId" no encontrado'),
        ],
      ),
    );
  }
}
