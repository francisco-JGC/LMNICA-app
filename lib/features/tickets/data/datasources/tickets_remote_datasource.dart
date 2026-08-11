import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/create_ticket_request.dart';
import '../../domain/entities/list_tickets_query.dart';
import '../../domain/entities/tickets_by_draw.dart';
import '../../domain/entities/tickets_summary.dart';
import '../models/ticket_detail_model.dart';
import '../models/ticket_receipt_model.dart';
import '../models/ticket_summary_model.dart';
import '../models/tickets_by_draw_model.dart';
import '../models/tickets_summary_model.dart';

abstract interface class TicketsRemoteDatasource {
  Future<TicketReceiptModel> create(CreateTicketRequest request);
  Future<({List<TicketSummaryModel> items, int page, int limit, int total})>
      list(ListTicketsQuery query);
  Future<TicketDetailModel> findById(String id);
  /// Lookup para el flujo de escaneo — sin restricción de dueño, permite
  /// a un vendedor escanear boletos que no son suyos (p. ej. de un
  /// compañero de sucursal o de días pasados).
  Future<TicketDetailModel> findByIdForScan(String id);
  Future<TicketSummaryModel> voidTicket({
    required String id,
    required String reason,
  });
  Future<TicketSummaryModel> payTicket(String id);
  Future<TicketsSummaryModel> summary(TicketsSummaryQuery query);
  Future<List<TicketsByDrawItemModel>> byDraw(TicketsByDrawQuery query);
}

class TicketsRemoteDatasourceImpl implements TicketsRemoteDatasource {
  const TicketsRemoteDatasourceImpl({required this.client});

  final DioClient client;

  @override
  Future<TicketReceiptModel> create(CreateTicketRequest request) async {
    try {
      final response = await client.instance.post<Map<String, dynamic>>(
        '/tickets',
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) throw ServerException('Empty response from server');
      return TicketReceiptModel.fromJson(data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<({List<TicketSummaryModel> items, int page, int limit, int total})>
      list(ListTicketsQuery query) async {
    try {
      final response = await client.instance.get<Map<String, dynamic>>(
        '/tickets',
        queryParameters: query.toQueryParameters(),
      );
      final data = response.data;
      if (data == null) throw ServerException('Empty response from server');
      final rawItems = (data['items'] as List<dynamic>? ?? const []);
      final items = rawItems
          .map((raw) =>
              TicketSummaryModel.fromJson(raw as Map<String, dynamic>))
          .toList();
      return (
        items: items,
        page: (data['page'] as num).toInt(),
        limit: (data['limit'] as num).toInt(),
        total: (data['total'] as num).toInt(),
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<TicketDetailModel> findById(String id) async {
    try {
      final response =
          await client.instance.get<Map<String, dynamic>>('/tickets/$id');
      final data = response.data;
      if (data == null) throw ServerException('Empty response from server');
      return TicketDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<TicketDetailModel> findByIdForScan(String id) async {
    try {
      final response = await client.instance
          .get<Map<String, dynamic>>('/tickets/$id/scan');
      final data = response.data;
      if (data == null) throw ServerException('Empty response from server');
      return TicketDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<TicketSummaryModel> voidTicket({
    required String id,
    required String reason,
  }) async {
    try {
      final response = await client.instance.post<Map<String, dynamic>>(
        '/tickets/$id/void',
        data: {'reason': reason},
      );
      final data = response.data;
      if (data == null) throw ServerException('Empty response from server');
      return TicketSummaryModel.fromJson(data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<TicketSummaryModel> payTicket(String id) async {
    try {
      final response = await client.instance.post<Map<String, dynamic>>(
        '/tickets/$id/pay',
      );
      final data = response.data;
      if (data == null) throw ServerException('Empty response from server');
      return TicketSummaryModel.fromJson(data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<TicketsSummaryModel> summary(TicketsSummaryQuery query) async {
    try {
      final response = await client.instance.get<Map<String, dynamic>>(
        '/tickets/summary',
        queryParameters: query.toQueryParameters(),
      );
      final data = response.data;
      if (data == null) throw ServerException('Empty response from server');
      return TicketsSummaryModel.fromJson(data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<List<TicketsByDrawItemModel>> byDraw(
    TicketsByDrawQuery query,
  ) async {
    try {
      final response = await client.instance.get<List<dynamic>>(
        '/tickets/by-draw',
        queryParameters: query.toQueryParameters(),
      );
      final data = response.data ?? const [];
      return data
          .map((raw) =>
              TicketsByDrawItemModel.fromJson(raw as Map<String, dynamic>))
          .toList();
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
