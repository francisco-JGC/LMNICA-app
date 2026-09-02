import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/repositories/movements_repository.dart';

abstract interface class MovementsRemoteDatasource {
  Future<SellerBalance> sellerBalance(SellerBalanceQuery query);
}

class MovementsRemoteDatasourceImpl implements MovementsRemoteDatasource {
  const MovementsRemoteDatasourceImpl({required this.client});

  final DioClient client;

  @override
  Future<SellerBalance> sellerBalance(SellerBalanceQuery query) async {
    try {
      final response = await client.instance.get<Map<String, dynamic>>(
        '/movements/seller-balance',
        queryParameters: query.toQueryParameters(),
      );
      final data = response.data;
      if (data == null) throw ServerException('Empty response from server');
      final items = (data['items'] as List<dynamic>? ?? const []);
      int cobros = 0;
      int credits = 0;
      int prizePayments = 0;
      for (final raw in items) {
        final item = raw as Map<String, dynamic>;
        cobros += (item['cobros'] as num? ?? 0).toInt();
        credits += (item['credits'] as num? ?? 0).toInt();
        prizePayments += (item['prizePayments'] as num? ?? 0).toInt();
      }
      return (cobros: cobros, credits: credits, prizePayments: prizePayments);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Exception _mapError(DioException e) {
    final type = e.type;
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.connectionError ||
        type == DioExceptionType.receiveTimeout) {
      return NetworkException(e.message ?? 'Network error');
    }
    final body = e.response?.data;
    final message = body is Map<String, dynamic>
        ? (body['message']?.toString() ?? e.message ?? 'Server error')
        : (e.message ?? 'Server error');
    return ServerException(message, statusCode: e.response?.statusCode);
  }
}
