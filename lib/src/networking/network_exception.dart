import 'package:dio/dio.dart';

/// Enhanced NetworkException with typed error handling
class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final ErrorType errorType;
  final dynamic originalError;

  NetworkException(
    this.message, {
    this.statusCode,
    ErrorType? errorType,
    this.originalError,
  }) : errorType = errorType ?? _determineErrorType(statusCode);

  /// Determine if this error is retryable
  bool get isRetryable {
    return errorType == ErrorType.network ||
        errorType == ErrorType.timeout ||
        errorType == ErrorType.serverError;
  }

  /// Determine if this is a network connectivity issue
  bool get isNetworkError => errorType == ErrorType.network;

  /// Determine if this is an authentication error
  bool get isAuthError => errorType == ErrorType.unauthorized;

  /// Determine if this is a client error (4xx)
  bool get isClientError =>
      errorType == ErrorType.clientError ||
      errorType == ErrorType.unauthorized ||
      errorType == ErrorType.forbidden;

  /// Determine if this is a server error (5xx)
  bool get isServerError => errorType == ErrorType.serverError;

  static ErrorType _determineErrorType(int? statusCode) {
    if (statusCode == null) return ErrorType.unknown;

    if (statusCode == 401) return ErrorType.unauthorized;
    if (statusCode == 403) return ErrorType.forbidden;
    if (statusCode == 404) return ErrorType.notFound;
    if (statusCode >= 400 && statusCode < 500) return ErrorType.clientError;
    if (statusCode >= 500) return ErrorType.serverError;

    return ErrorType.unknown;
  }

  @override
  String toString() {
    final buffer = StringBuffer('NetworkException: $message');
    if (statusCode != null) {
      buffer.write(' (Status: $statusCode)');
    }
    buffer.write(' [Type: ${errorType.name}]');
    return buffer.toString();
  }
}

/// Specific error for no internet connection
class NoInternetException extends NetworkException {
  NoInternetException()
    : super('No internet connection', errorType: ErrorType.network);
}

/// Specific error for timeout
class TimeoutException extends NetworkException {
  TimeoutException([super.message = 'Request timeout'])
    : super(errorType: ErrorType.timeout);
}

/// Specific error for authentication failures
class AuthException extends NetworkException {
  AuthException([super.message = 'Authentication failed'])
    : super(statusCode: 401, errorType: ErrorType.unauthorized);
}

/// Specific error for authorization failures
class ForbiddenException extends NetworkException {
  ForbiddenException([super.message = 'Access forbidden'])
    : super(statusCode: 403, errorType: ErrorType.forbidden);
}

/// Specific error for not found
class NotFoundException extends NetworkException {
  NotFoundException([super.message = 'Resource not found'])
    : super(statusCode: 404, errorType: ErrorType.notFound);
}

/// Specific error for server errors (5xx)
class ServerException extends NetworkException {
  ServerException([super.message = 'Server error', int? statusCode])
    : super(statusCode: statusCode ?? 500, errorType: ErrorType.serverError);
}

/// Error type enumeration
enum ErrorType {
  /// Network connectivity issues
  network,

  /// Request timeout
  timeout,

  /// 401 Unauthorized
  unauthorized,

  /// 403 Forbidden
  forbidden,

  /// 404 Not Found
  notFound,

  /// Other 4xx client errors
  clientError,

  /// 5xx server errors
  serverError,

  /// Unknown error
  unknown,
}

/// Extension to convert DioException to NetworkException
extension DioExceptionExtension on DioException {
  NetworkException toNetworkException() {
    switch (type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException(message ?? 'Request timeout');

      case DioExceptionType.connectionError:
        return NoInternetException();

      case DioExceptionType.badResponse:
        final statusCode = response?.statusCode;
        final message = response?.statusMessage ?? 'Bad response';

        if (statusCode == 401) {
          return AuthException(message);
        } else if (statusCode == 403) {
          return ForbiddenException(message);
        } else if (statusCode == 404) {
          return NotFoundException(message);
        } else if (statusCode != null && statusCode >= 500) {
          return ServerException(message, statusCode);
        }

        return NetworkException(
          message,
          statusCode: statusCode,
          originalError: this,
        );

      case DioExceptionType.cancel:
        return NetworkException('Request cancelled', originalError: this);

      case DioExceptionType.badCertificate:
        return NetworkException('SSL certificate error', originalError: this);

      case DioExceptionType.unknown:
        return NetworkException(
          message ?? 'Unknown error',
          originalError: this,
        );
    }
  }
}
