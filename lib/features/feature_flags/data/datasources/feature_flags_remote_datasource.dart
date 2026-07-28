import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/feature_flag_model.dart';

abstract interface class FeatureFlagsRemoteDatasource {
  Future<List<FeatureFlagModel>> list();
}

class FeatureFlagsRemoteDatasourceImpl
    implements FeatureFlagsRemoteDatasource {
  const FeatureFlagsRemoteDatasourceImpl({required this.client});

  final DioClient client;

  @override
  Future<List<FeatureFlagModel>> list() async {
    try {
      final response = await client.instance.get<List<dynamic>>(
        '/feature-flags',
      );
      final data = response.data ?? const [];
      return data
          .map((raw) =>
              FeatureFlagModel.fromJson(raw as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final type = e.type;
      if (type == DioExceptionType.connectionTimeout ||
          type == DioExceptionType.connectionError ||
          type == DioExceptionType.receiveTimeout) {
        throw NetworkException(e.message ?? 'Network error');
      }
      throw ServerException(
        e.message ?? 'Server error',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
