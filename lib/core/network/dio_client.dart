import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

import 'auth_interceptor.dart';
import 'token_store.dart';

class DioClient {
  DioClient({
    required TokenStore tokenStore,
    required Future<void> Function(String newAccessToken) onRefreshed,
    required void Function() onSessionExpired,
    Logger? logger,
  }) : _logger = logger ?? Logger() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl(),
        // Timeouts pensados para operar con datos móviles flakeados y
        // hosting con cold-start (Railway/Render suspenden la instancia
        // por inactividad; despertar puede tomar 15-25s la primera
        // request de la mañana). Antes eran 15s de connect y 20s de
        // receive/send — se veía como TimeoutException para el vendedor
        // aunque la operación fuera legítima.
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      AuthInterceptor(
        tokenStore: tokenStore,
        onRefreshed: onRefreshed,
        onSessionExpired: onSessionExpired,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _logger.d('→ ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.d('← ${response.statusCode} ${response.requestOptions.uri}');
          handler.next(response);
        },
        onError: (err, handler) {
          _logger.e(
            '✗ ${err.requestOptions.method} ${err.requestOptions.uri}',
            error: err,
          );
          handler.next(err);
        },
      ),
    );
  }

  late final Dio _dio;
  final Logger _logger;

  Dio get instance => _dio;

  static String _baseUrl() {
    try {
      return dotenv.maybeGet('API_BASE_URL') ?? '';
    } catch (_) {
      return '';
    }
  }
}
