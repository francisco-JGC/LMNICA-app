import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/di/injection.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/feature_flags/presentation/state/feature_flags_controller.dart';
import 'features/printer/presentation/state/printer_controller.dart';
import 'features/schedules/presentation/state/available_draws_provider.dart';
import 'features/schedules/presentation/state/game_draw_times_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env').catchError((_) {});
  await initializeDateFormatting('es', null);
  await configureDependencies();

  runApp(const ProviderScope(child: LoteriaClientApp()));
}

class LoteriaClientApp extends ConsumerStatefulWidget {
  const LoteriaClientApp({super.key});

  @override
  ConsumerState<LoteriaClientApp> createState() => _LoteriaClientAppState();
}

class _LoteriaClientAppState extends ConsumerState<LoteriaClientApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Cubre el caso "app cerrada → BT off → BT on → abre app": el usuario
    // arranca la app y esperamos que la impresora se reconecte sola a la
    // última conocida.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(printerControllerProvider.notifier).autoReconnect();
      // Fetch feature flags al arrancar. Sin bloquear el UI: si falla, el
      // controller mantiene su estado default (vacío = flags desconocidos).
      ref.read(featureFlagsControllerProvider.notifier).refresh();
    });
    // Y con el observer cubrimos "app backgroundeada → BT off → BT on →
    // seller vuelve a la app": el resume dispara un autoReconnect adicional
    // y refresca los feature flags por si el admin cambió algo mientras
    // el vendedor tenía la app en segundo plano.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(printerControllerProvider.notifier).autoReconnect();
      ref.read(featureFlagsControllerProvider.notifier).refresh();
      // Los horarios/sorteos disponibles se cachean en `FutureProvider.
      // autoDispose.family` — mientras haya observers no expiran. Si el
      // admin cambia horarios mientras el vendedor tenía la app en
      // background, al volver seguía viendo la lista vieja. Invalidamos
      // ambas familias completas para forzar refresh en la próxima
      // observación; los autoDispose limpian las huérfanas.
      ref.invalidate(availableDrawsProvider);
      ref.invalidate(gameDrawTimesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'LM NICA',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
