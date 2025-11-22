import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'network_exception.dart';

class RestClient {
  late final Dio _dio;
  final String baseUrl;
  final bool enableLogging;

  RestClient({
    required this.baseUrl,
    List<Interceptor>? interceptors,
    this.enableLogging = kDebugMode, // Default to true only in debug mode
    Duration timeout = const Duration(seconds: 20),
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );

    if (enableLogging) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }

    if (interceptors != null) {
      _dio.interceptors.addAll(interceptors);
    }
  }

  /// --- HTTP METHODS ---

  Future<T> get<T>(String endpoint, {Map<String, dynamic>? queryParams}) {
    return _request(() => _dio.get(endpoint, queryParameters: queryParams));
  }

  Future<T> post<T>(String endpoint, {dynamic data}) {
    return _request(() => _dio.post(endpoint, data: data));
  }

  Future<T> put<T>(String endpoint, {dynamic data}) {
    return _request(() => _dio.put(endpoint, data: data));
  }

  Future<T> delete<T>(String endpoint, {dynamic data}) {
    return _request(() => _dio.delete(endpoint, data: data));
  }

  Future<T> patch<T>(String endpoint, {dynamic data}) {
    return _request(() => _dio.patch(endpoint, data: data));
  }

  /// --- INTERNAL HANDLER ---

  Future<T> _request<T>(Future<Response> Function() requestFunc) async {
    if (!await hasNetwork()) {
      throw NetworkException('No internet connection');
    }

    try {
      final response = await requestFunc();
      return response.data as T;
    } on DioException catch (e) {
      final message = e.response?.statusMessage ?? e.message ?? 'Unknown Error';
      throw NetworkException(message, statusCode: e.response?.statusCode);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  Future<bool> hasNetwork() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}

// Helper to avoid importing Foundation in non-flutter files if needed,
// though kDebugMode is standard in Flutter.
const bool kDebugMode = true;
