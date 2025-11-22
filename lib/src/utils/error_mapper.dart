// Add import for NetworkException
import '../networking/network_exception.dart';

/// Error message mapper for user-friendly error messages
class ErrorMapper {
  static final Map<Type, String> _defaultMessages = {
    NoInternetException: 'No internet connection. Please check your network.',
    TimeoutException: 'Request timeout. Please try again.',
    AuthException: 'Authentication failed. Please log in again.',
    ForbiddenException: 'You don\'t have permission to access this resource.',
    NotFoundException: 'The requested resource was not found.',
    ServerException: 'Server error. Please try again later.',
  };

  static final Map<int, String> _statusCodeMessages = {
    400: 'Bad request. Please check your input.',
    401: 'Authentication required. Please log in.',
    403: 'Access forbidden. You don\'t have permission.',
    404: 'Resource not found.',
    408: 'Request timeout. Please try again.',
    429: 'Too many requests. Please wait and try again.',
    500: 'Internal server error. Please try again later.',
    502: 'Bad gateway. Please try again later.',
    503: 'Service unavailable. Please try again later.',
    504: 'Gateway timeout. Please try again later.',
  };

  /// Map an error to a user-friendly message
  static String mapError(dynamic error) {
    // Check if it's a NetworkException
    if (error is NetworkException) {
      // Check status code first
      if (error.statusCode != null &&
          _statusCodeMessages.containsKey(error.statusCode)) {
        return _statusCodeMessages[error.statusCode]!;
      }

      // Check specific exception type
      final type = error.runtimeType;
      if (_defaultMessages.containsKey(type)) {
        return _defaultMessages[type]!;
      }

      // Return the error message as is
      return error.message;
    }

    // Fallback for unknown errors
    return 'An unexpected error occurred. Please try again.';
  }

  /// Add a custom error message mapping
  static void addMapping(Type errorType, String message) {
    _defaultMessages[errorType] = message;
  }

  /// Add a custom status code message mapping
  static void addStatusCodeMapping(int statusCode, String message) {
    _statusCodeMessages[statusCode] = message;
  }

  /// Clear all custom mappings
  static void clearCustomMappings() {
    _defaultMessages.clear();
    _statusCodeMessages.clear();
  }
}
