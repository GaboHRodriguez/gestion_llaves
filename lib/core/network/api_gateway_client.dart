import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/rbac_models.dart';
import '../config/app_config.dart';

/// Excepción tipada de la capa de red / API Gateway
class ApiGatewayException implements Exception {
  final String message;
  final int? statusCode;
  final String endpoint;

  const ApiGatewayException({
    required this.message,
    required this.endpoint,
    this.statusCode,
  });

  @override
  String toString() =>
      'ApiGatewayException($statusCode) en [$endpoint]: $message';
}

/// Cliente HTTP tipado para consumir la API REST PHP/MySQL local
/// (`http://<IP_LOCAL>/gestion_llaves/api/`).
/// Desacoplado para permitir inyección en repositorios MySQL o sustitución por Firebase.
class ApiGatewayClient {
  String _baseUrl;
  AppUser? _activeUser;
  final http.Client _httpClient;
  final Duration timeout;

  ApiGatewayClient({
    String? baseUrl,
    AppUser? activeUser,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 4),
  })  : _baseUrl = baseUrl ?? AppConfig.defaultApiBaseUrl,
        _activeUser = activeUser,
        _httpClient = httpClient ?? http.Client();

  String get baseUrl => _baseUrl;

  void updateBaseUrl(String newUrl) {
    _baseUrl = newUrl.trim().replaceAll(RegExp(r'/$'), '');
  }

  void updateActiveUser(AppUser user) {
    _activeUser = user;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        if (_activeUser != null) 'X-User-Id': _activeUser!.idUsuario.toString(),
        if (_activeUser != null) 'X-User-Role': _activeUser!.rol.dbValue,
      };

  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$cleanPath')
        .replace(queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = _buildUri(path, query);
    try {
      final response =
          await _httpClient.get(uri, headers: _headers).timeout(timeout);
      return _decodeResponse(response, uri.toString());
    } catch (e) {
      if (e is ApiGatewayException) rethrow;
      throw ApiGatewayException(
        message: 'Error de conexión con servidor XAMPP/MySQL: $e',
        endpoint: uri.toString(),
      );
    }
  }

  Future<List<Map<String, dynamic>>> getJsonList(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = _buildUri(path, query);
    try {
      final response =
          await _httpClient.get(uri, headers: _headers).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiGatewayException(
          message: 'Respuesta HTTP inesperada: ${response.body}',
          statusCode: response.statusCode,
          endpoint: uri.toString(),
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (decoded is Map && decoded['data'] is List) {
        return (decoded['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return const [];
    } catch (e) {
      if (e is ApiGatewayException) rethrow;
      throw ApiGatewayException(
        message: 'No se pudo conectar al endpoint REST: $e',
        endpoint: uri.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = _buildUri(path);
    try {
      final response = await _httpClient
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(timeout);
      return _decodeResponse(response, uri.toString());
    } catch (e) {
      if (e is ApiGatewayException) rethrow;
      throw ApiGatewayException(
        message: 'Fallo al enviar POST a MySQL REST API: $e',
        endpoint: uri.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = _buildUri(path);
    try {
      final response = await _httpClient
          .put(uri, headers: _headers, body: jsonEncode(body))
          .timeout(timeout);
      return _decodeResponse(response, uri.toString());
    } catch (e) {
      if (e is ApiGatewayException) rethrow;
      throw ApiGatewayException(
        message: 'Fallo al enviar PUT a MySQL REST API: $e',
        endpoint: uri.toString(),
      );
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response, String endpoint) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) return {'status': 'ok'};
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    }
    throw ApiGatewayException(
      message: 'Error HTTP ${response.statusCode}: ${response.body}',
      statusCode: response.statusCode,
      endpoint: endpoint,
    );
  }
}
