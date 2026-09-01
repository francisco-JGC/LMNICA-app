import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_page.dart';
import '../../features/auth/presentation/screens/splash_page.dart';
import '../../features/auth/presentation/state/auth_controller.dart';
import '../../features/auth/presentation/state/auth_state.dart';
import '../../features/draw_totals/presentation/screens/draw_totals_page.dart';
import '../../features/dream_guide/presentation/screens/dream_guide_page.dart';
import '../../features/games/domain/entities/game.dart';
import '../../features/games/presentation/screens/game_detail_page.dart';
import '../../features/games/presentation/screens/games_page.dart';
import '../../features/lucky/presentation/screens/cross_lucky_page.dart';
import '../../features/lucky/presentation/screens/pyramid_lucky_page.dart';
import '../../features/movements/presentation/screens/movements_page.dart';
import '../../features/printer/presentation/screens/printer_setup_page.dart';
import '../../features/results/presentation/screens/latest_results_page.dart';
import '../../features/results/presentation/screens/verify_ticket_page.dart';
import '../../features/results/presentation/screens/winners_page.dart';
import '../../features/sale_points/presentation/screens/select_sale_point_page.dart';
import '../../features/sale_points/presentation/state/active_sale_point_controller.dart';
import '../../features/sale_points/presentation/state/active_sale_point_state.dart';
import '../../features/sales/presentation/screens/scan_ticket_page.dart';
import '../../features/settings/presentation/screens/settings_page.dart';
import '../../features/tickets/presentation/screens/ticket_detail_page.dart';
import '../../features/tickets/presentation/screens/tickets_history_page.dart';
import 'app_shell.dart';

const _selectPointRoute = '/seleccionar-puesto';

class _AppRouterListenable extends ChangeNotifier {
  _AppRouterListenable(Ref ref) {
    _authSub = ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) {
        if (previous?.status != next.status) {
          if (next.isAuthenticated) {
            Future.microtask(() =>
                ref.read(activeSalePointProvider.notifier).loadForCurrentUser());
          } else if (next.isUnauthenticated) {
            Future.microtask(
                () => ref.read(activeSalePointProvider.notifier).clear());
          }
          notifyListeners();
        }
      },
    );
    _salePointSub = ref.listen<ActiveSalePointState>(
      activeSalePointProvider,
      (previous, next) {
        if (previous?.status != next.status) notifyListeners();
      },
    );
  }

  late final ProviderSubscription<AuthState> _authSub;
  late final ProviderSubscription<ActiveSalePointState> _salePointSub;

  @override
  void dispose() {
    _authSub.close();
    _salePointSub.close();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final listenable = _AppRouterListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final salePoint = ref.read(activeSalePointProvider);
      final location = state.matchedLocation;

      if (auth.isLoading) {
        return location == '/splash' ? null : '/splash';
      }
      if (auth.isUnauthenticated) {
        return location == '/login' ? null : '/login';
      }

      final needsSalePoint = salePoint.status == ActiveSalePointStatus.idle ||
          salePoint.status == ActiveSalePointStatus.loading ||
          salePoint.status == ActiveSalePointStatus.needsSelection ||
          salePoint.status == ActiveSalePointStatus.empty ||
          salePoint.status == ActiveSalePointStatus.error;

      if (needsSalePoint) {
        return location == _selectPointRoute ? null : _selectPointRoute;
      }

      if (location == '/splash' ||
          location == '/login' ||
          location == _selectPointRoute) {
        return '/juegos';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: _selectPointRoute,
        builder: (context, state) => const SelectSalePointPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/juegos',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GamesPage(),
            ),
          ),
          GoRoute(
            path: '/reportes/facturas',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TicketsHistoryPage(),
            ),
          ),
          GoRoute(
            path: '/reportes/totales-sorteos',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DrawTotalsPage(),
            ),
          ),
          GoRoute(
            path: '/reportes/boletos-ganadores',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WinnersPage(),
            ),
          ),
          GoRoute(
            path: '/reportes/ultimos-resultados',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LatestResultsPage(),
            ),
          ),
          GoRoute(
            path: '/reportes/movimientos',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MovementsPage(),
            ),
          ),
          GoRoute(
            path: '/herramientas/guia-suenos',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DreamGuidePage(),
            ),
          ),
          GoRoute(
            path: '/herramientas/cruz-suerte',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CrossLuckyPage(),
            ),
          ),
          GoRoute(
            path: '/herramientas/piramide-suerte',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PyramidLuckyPage(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/reportes/boletos-ganadores/verificar',
        builder: (context, state) => const VerifyTicketPage(),
      ),
      GoRoute(
        path: '/reportes/facturas/:id',
        builder: (context, state) =>
            TicketDetailPage(ticketId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/juegos/:gameId',
        builder: (context, state) {
          final extra = state.extra;
          final Game? game;
          final List<({String label, int amount})> initialLines;
          if (extra is GameDetailArgs) {
            game = extra.game;
            initialLines = extra.initialLines;
          } else {
            game = extra as Game?;
            initialLines = const [];
          }
          return GameDetailPage(
            gameId: state.pathParameters['gameId']!,
            game: game,
            initialLines: initialLines,
          );
        },
        routes: [
          GoRoute(
            path: 'escanear',
            builder: (context, state) => ScanTicketPage(
              game: state.extra as Game,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/configuracion',
        builder: (context, state) => const SettingsPage(),
        routes: [
          GoRoute(
            path: 'impresora',
            builder: (context, state) => const PrinterSetupPage(),
          ),
        ],
      ),
    ],
  );
});
