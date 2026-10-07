import 'package:dio/dio.dart';

import 'network_constants.dart';
import 'token_store.dart';

/// Resultado de un intento de refresh, separando los dos mundos que antes
/// se confundían: que el backend **rechace** el refresh token, y que no
/// hayamos **podido preguntarle**.
enum _RefreshOutcome {
  /// Tokens nuevos en mano.
  success,

  /// El backend miró el refresh token y lo rechazó (401/403). Sesión muerta.
  rejected,

  /// Red caída, timeout, 5xx, cold start. El refresh token sigue bueno.
  unavailable,
}

class _RefreshResult {
  const _RefreshResult(this.outcome, {this.accessToken, this.refreshToken});

  const _RefreshResult.rejected() : this(_RefreshOutcome.rejected);
  const _RefreshResult.unavailable() : this(_RefreshOutcome.unavailable);

  final _RefreshOutcome outcome;
  final String? accessToken;
  final String? refreshToken;
}

/// Adjunta el access token a cada request y, ante un 401, intenta una
/// renovación silenciosa antes de dar la sesión por terminada.
///
/// Notas de diseño:
/// - El refresh pega a `/auth/refresh` con un Dio limpio, así no se
///   intercepta a sí mismo (sin recursión).
/// - Varios 401 concurrentes comparten el mismo future, así una ráfaga de
///   requests paralelos gasta exactamente un refresh.
/// - Cada request original se reintenta como mucho una vez (`_retried` en
///   RequestOptions.extra).
/// - **Solo cerramos sesión si el backend rechaza el refresh token.** Un
///   vendedor sin señal, o el contenedor del backend despertando de un
///   cold start, no deben costarle la sesión: se devuelve el error del
///   request y se reintenta en la próxima llamada.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.tokenStore,
    required this.onRefreshed,
    required this.onSessionExpired,
  });

  final TokenStore tokenStore;

  /// Recibe **ambos** tokens después de un refresh exitoso, para que la app
  /// los persista. El backend rota también el refresh token en cada
  /// llamada: quedarse con el viejo hace que la sesión caduque a fecha fija
  /// desde el login en vez de ir extendiéndose con el uso.
  final Future<void> Function(String accessToken, String refreshToken)
      onRefreshed;

  /// Se dispara solo cuando la sesión está realmente terminada — la app
  /// debe desloguear y volver al login.
  final void Function() onSessionExpired;

  Future<_RefreshResult>? _refreshInFlight;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final token = tokenStore.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    final original = err.requestOptions;

    // Nunca refrescar la llamada de refresh en sí.
    if (original.path.endsWith(kAuthRefreshPath)) {
      onSessionExpired();
      return handler.next(err);
    }

    // Ya reintentamos con un token recién emitido y sigue en 401: el
    // problema no es la frescura del token.
    if (original.extra[kAuthRetriedKey] == true) {
      onSessionExpired();
      return handler.next(err);
    }

    final refreshToken = tokenStore.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      onSessionExpired();
      return handler.next(err);
    }

    final result = await _refreshOnce(
      baseUrl: original.baseUrl,
      refreshToken: refreshToken,
    );

    switch (result.outcome) {
      case _RefreshOutcome.rejected:
        onSessionExpired();
        return handler.next(err);
      case _RefreshOutcome.unavailable:
        // No pudimos preguntar. La sesión queda intacta: devolvemos el
        // error del request original y el próximo intento vuelve a probar.
        return handler.next(err);
      case _RefreshOutcome.success:
        break;
    }

    final newAccessToken = result.accessToken!;
    await onRefreshed(newAccessToken, result.refreshToken!);

    try {
      original.headers['Authorization'] = 'Bearer $newAccessToken';
      original.extra[kAuthRetriedKey] = true;
      // Dio limpio para que el reintento no re-entre a este interceptor.
      // `original` ya trae método, path, body, etc.
      final retryDio = Dio(
        BaseOptions(
          connectTimeout: kNetworkConnectTimeout,
          receiveTimeout: kNetworkReceiveTimeout,
          sendTimeout: kNetworkSendTimeout,
        ),
      );
      final retryResponse = await retryDio.fetch<dynamic>(original);
      return handler.resolve(retryResponse);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    } catch (_) {
      return handler.next(err);
    }
  }

  Future<_RefreshResult> _refreshOnce({
    required String baseUrl,
    required String refreshToken,
  }) {
    final pending = _refreshInFlight;
    if (pending != null) return pending;
    final future = _doRefreshWithRetries(
      baseUrl: baseUrl,
      refreshToken: refreshToken,
    ).whenComplete(() {
      _refreshInFlight = null;
    });
    _refreshInFlight = future;
    return future;
  }

  /// Reintenta mientras el fallo sea transitorio. Un rechazo explícito no
  /// se reintenta: la respuesta no va a cambiar.
  Future<_RefreshResult> _doRefreshWithRetries({
    required String baseUrl,
    required String refreshToken,
  }) async {
    for (var attempt = 0; attempt <= kAuthRefreshRetryDelays.length; attempt += 1) {
      final result = await _doRefresh(
        baseUrl: baseUrl,
        refreshToken: refreshToken,
      );
      if (result.outcome != _RefreshOutcome.unavailable) return result;
      if (attempt < kAuthRefreshRetryDelays.length) {
        await Future<void>.delayed(kAuthRefreshRetryDelays[attempt]);
      }
    }
    return const _RefreshResult.unavailable();
  }

  Future<_RefreshResult> _doRefresh({
    required String baseUrl,
    required String refreshToken,
  }) async {
    try {
      final bareDio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: kNetworkConnectTimeout,
          receiveTimeout: kNetworkReceiveTimeout,
          sendTimeout: kNetworkSendTimeout,
        ),
      );
      final response = await bareDio.post<Map<String, dynamic>>(
        kAuthRefreshPath,
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      final data = response.data;
      final access = data?['accessToken'];
      final refresh = data?['refreshToken'];
      if (access is! String || access.isEmpty) {
        // 200 pero sin token utilizable: no es culpa del refresh token.
        return const _RefreshResult.unavailable();
      }
      return _RefreshResult(
        _RefreshOutcome.success,
        accessToken: access,
        // Backend viejo que todavía no rota el refresh token: seguimos con
        // el que ya teníamos.
        refreshToken: refresh is String && refresh.isNotEmpty
            ? refresh
            : refreshToken,
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        return const _RefreshResult.rejected();
      }
      return const _RefreshResult.unavailable();
    } catch (_) {
      return const _RefreshResult.unavailable();
    }
  }
}
