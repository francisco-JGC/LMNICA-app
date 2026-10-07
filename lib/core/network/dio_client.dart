import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

import 'auth_interceptor.dart';
import 'network_constants.dart';
import 'token_store.dart';

class DioClient {
  DioClient({
    required TokenStore tokenStore,
    required Future<void> Function(String accessToken, String refreshToken)
        onRefreshed,
    required void Function() onSessionExpired,
    Logger? logger,
  }) : _logger = logger ?? Logger() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl(),
        connectTimeout: kNetworkConnectTimeout,
        receiveTimeout: kNetworkReceiveTimeout,
        sendTimeout: kNetworkSendTimeout,
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
