import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'network_exception.dart';
import 'cache_manager.dart';
import 'retry_interceptor.dart';

class RestClient {
  late final Dio _dio;
  final String baseUrl;
  final bool enableLogging;
  final Map<String, CancelToken> _pendingRequests = {};

  RestClient({
    required this.baseUrl,
    List<Interceptor>? interceptors,
    this.enableLogging = kDebugMode,
    Duration timeout = const Duration(seconds: 20),
    bool enableCache = false,
    CacheOptions? cacheOptions,
    bool enableRetry = true,
    int maxRetries = 3,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );

    // Add cache interceptor first (if enabled)
    if (enableCache) {
      final cacheInterceptor = cacheOptions != null
          ? DioCacheInterceptor(options: cacheOptions)
          : CacheManager.instance.cacheInterceptor;

      if (cacheInterceptor != null) {
        _dio.interceptors.add(cacheInterceptor);
      }
    }

    // Add logging interceptor
    if (enableLogging) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }

    // Add retry interceptor (if enabled)
    if (enableRetry) {
      _dio.interceptors.add(RetryInterceptor(maxRetries: maxRetries));
    }

    // Add custom interceptors
    if (interceptors != null) {
      _dio.interceptors.addAll(interceptors);
    }
  }

  /// Get the underlying Dio instance for advanced use cases
  Dio get dio => _dio;

  /// --- HTTP METHODS ---

  Future<T> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return _request(
      () => _dio.get(
        endpoint,
        queryParameters: queryParams,
        cancelToken: cancelToken ?? _getCancelToken(endpoint),
        options: options,
      ),
      endpoint: endpoint,
    );
  }

  Future<T> post<T>(
    String endpoint, {
    dynamic data,
    CancelToken? cancelToken,
    Options? options,
    void Function(int, int)? onSendProgress,
  }) {
    return _request(
      () => _dio.post(
        endpoint,
        data: data,
        cancelToken: cancelToken,
        options: options,
        onSendProgress: onSendProgress,
      ),
      endpoint: endpoint,
    );
  }

  Future<T> put<T>(
    String endpoint, {
    dynamic data,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return _request(
      () => _dio.put(
        endpoint,
        data: data,
        cancelToken: cancelToken,
        options: options,
      ),
      endpoint: endpoint,
    );
  }

  Future<T> delete<T>(
    String endpoint, {
    dynamic data,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return _request(
      () => _dio.delete(
        endpoint,
        data: data,
        cancelToken: cancelToken,
        options: options,
      ),
      endpoint: endpoint,
    );
  }

  Future<T> patch<T>(
    String endpoint, {
    dynamic data,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return _request(
      () => _dio.patch(
        endpoint,
        data: data,
        cancelToken: cancelToken,
        options: options,
      ),
      endpoint: endpoint,
    );
  }

  /// Upload file with multipart/form-data
  Future<T> upload<T>(
    String endpoint, {
    required FormData formData,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    Options? options,
  }) {
    return _request(
      () => _dio.post(
        endpoint,
        data: formData,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        options: options,
      ),
      endpoint: endpoint,
    );
  }

  /// Download file
  Future<void> download(
    String endpoint,
    String savePath, {
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
    Options? options,
  }) async {
    if (!await hasNetwork()) {
      throw NoInternetException();
    }

    try {
      await _dio.download(
        endpoint,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        options: options,
      );
    } on DioException catch (e) {
      throw e.toNetworkException();
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  /// --- INTERNAL HANDLER ---

  Future<T> _request<T>(
    Future<Response> Function() requestFunc, {
    String? endpoint,
  }) async {
    if (!await hasNetwork()) {
      throw NoInternetException();
    }

    try {
      final response = await requestFunc();

      // Remove from pending requests
      if (endpoint != null) {
        _pendingRequests.remove(endpoint);
      }

      return response.data as T;
    } on DioException catch (e) {
      // Remove from pending requests
      if (endpoint != null) {
        _pendingRequests.remove(endpoint);
      }

      // Convert to NetworkException using extension
      throw e.toNetworkException();
    } catch (e) {
      // Remove from pending requests
      if (endpoint != null) {
        _pendingRequests.remove(endpoint);
      }

      throw NetworkException(e.toString());
    }
  }

  /// Get or create cancel token for request deduplication
  CancelToken _getCancelToken(String endpoint) {
    // Cancel existing request with same endpoint
    if (_pendingRequests.containsKey(endpoint)) {
      _pendingRequests[endpoint]?.cancel(
        'Request cancelled: duplicate request',
      );
    }

    // Create new cancel token
    final cancelToken = CancelToken();
    _pendingRequests[endpoint] = cancelToken;
    return cancelToken;
  }

  /// Cancel a specific request
  void cancelRequest(String endpoint) {
    _pendingRequests[endpoint]?.cancel('Request cancelled by user');
    _pendingRequests.remove(endpoint);
  }

  /// Cancel all pending requests
  void cancelAllRequests() {
    for (final token in _pendingRequests.values) {
      token.cancel('All requests cancelled');
    }
    _pendingRequests.clear();
  }

  Future<bool> hasNetwork() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}

// Helper to avoid importing Foundation in non-flutter files if needed,
// though kDebugMode is standard in Flutter.
const bool kDebugMode = true;
