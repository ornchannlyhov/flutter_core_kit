import 'package:dio/dio.dart';

/// Interceptor that automatically retries failed requests with exponential backoff
class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;

  RetryInterceptor({
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.backoffMultiplier = 2.0,
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }

    final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;

    if (retryCount >= maxRetries) {
      return handler.next(err);
    }

    // Calculate delay with exponential backoff
    final delay = initialDelay * (backoffMultiplier * retryCount);
    await Future.delayed(delay);

    // Increment retry count
    err.requestOptions.extra['retryCount'] = retryCount + 1;

    try {
      // Retry the request
      final response = await Dio().fetch(err.requestOptions);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  /// Determine if the request should be retried
  bool _shouldRetry(DioException err) {
    // Don't retry cancelled requests
    if (err.type == DioExceptionType.cancel) {
      return false;
    }

    // Retry on connection errors
    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout) {
      return true;
    }

    // Retry on timeout
    if (err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      return true;
    }

    // Retry on 5xx server errors
    final statusCode = err.response?.statusCode;
    if (statusCode != null && statusCode >= 500) {
      return true;
    }

    // Don't retry 4xx client errors
    return false;
  }
}
