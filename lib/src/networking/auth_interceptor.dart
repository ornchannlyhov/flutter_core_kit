import 'dart:async';
import 'package:dio/dio.dart';
import 'auth_token_manager.dart';

/// Configuration for AuthInterceptor
class AuthConfig {
  /// Callback to retrieve the current access token
  final Future<String?> Function() getAccessToken;

  /// Callback to retrieve the current refresh token
  final Future<String?> Function()? getRefreshToken;

  /// Callback to refresh the token when it expires
  /// Should return the new access token
  final Future<String?> Function(String? refreshToken)? onTokenRefresh;

  /// Callback when token refresh fails (e.g., logout user)
  final Future<void> Function()? onRefreshFailed;

  /// Header name for the authorization token
  final String headerName;

  /// Token prefix (e.g., "Bearer")
  final String tokenPrefix;

  const AuthConfig({
    required this.getAccessToken,
    this.getRefreshToken,
    this.onTokenRefresh,
    this.onRefreshFailed,
    this.headerName = 'Authorization',
    this.tokenPrefix = 'Bearer',
  });
}

/// Interceptor that automatically injects auth tokens and handles refresh
class AuthInterceptor extends QueuedInterceptor {
  final AuthConfig config;
  final AuthTokenManager? tokenManager;
  bool _isRefreshing = false;
  final List<_RequestQueueItem> _requestQueue = [];

  AuthInterceptor({required this.config, this.tokenManager});

  /// Convenience constructor using AuthTokenManager
  factory AuthInterceptor.withTokenManager({
    required AuthTokenManager tokenManager,
    required Future<String?> Function(String? refreshToken) onTokenRefresh,
    Future<void> Function()? onRefreshFailed,
  }) {
    return AuthInterceptor(
      config: AuthConfig(
        getAccessToken: () => tokenManager.getAccessToken(),
        getRefreshToken: () => tokenManager.getRefreshToken(),
        onTokenRefresh: onTokenRefresh,
        onRefreshFailed: onRefreshFailed,
      ),
      tokenManager: tokenManager,
    );
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Get access token
    final token = await config.getAccessToken();

    if (token != null && token.isNotEmpty) {
      // Inject token into headers
      options.headers[config.headerName] = '${config.tokenPrefix} $token'
          .trim();
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Check if error is 401 Unauthorized
    if (err.response?.statusCode == 401 && config.onTokenRefresh != null) {
      // If already refreshing, queue the request
      if (_isRefreshing) {
        _addToQueue(err, handler);
        return;
      }

      _isRefreshing = true;

      try {
        // Get refresh token
        final refreshToken = await config.getRefreshToken?.call();

        // Refresh the token
        final newAccessToken = await config.onTokenRefresh!(refreshToken);

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          // Save new token
          await tokenManager?.saveAccessToken(newAccessToken);

          // Retry the original request with new token
          err.requestOptions.headers[config.headerName] =
              '${config.tokenPrefix} $newAccessToken'.trim();

          final response = await _retry(err.requestOptions);

          // Process queued requests
          _processQueue(newAccessToken);

          _isRefreshing = false;
          return handler.resolve(response);
        } else {
          // Token refresh failed
          await config.onRefreshFailed?.call();
          _clearQueue(err);
          _isRefreshing = false;
          return handler.next(err);
        }
      } catch (e) {
        // Token refresh error
        await config.onRefreshFailed?.call();
        _clearQueue(err);
        _isRefreshing = false;
        return handler.next(err);
      }
    }

    handler.next(err);
  }

  /// Add request to queue while token is being refreshed
  void _addToQueue(DioException err, ErrorInterceptorHandler handler) {
    _requestQueue.add(
      _RequestQueueItem(requestOptions: err.requestOptions, handler: handler),
    );
  }

  /// Process all queued requests with new token
  void _processQueue(String newToken) {
    for (final item in _requestQueue) {
      item.requestOptions.headers[config.headerName] =
          '${config.tokenPrefix} $newToken'.trim();

      _retry(item.requestOptions)
          .then((response) {
            item.handler.resolve(response);
          })
          .catchError((e) {
            if (e is DioException) {
              item.handler.next(e);
            } else {
              item.handler.next(
                DioException(requestOptions: item.requestOptions, error: e),
              );
            }
          });
    }
    _requestQueue.clear();
  }

  /// Clear queue with error
  void _clearQueue(DioException error) {
    for (final item in _requestQueue) {
      item.handler.next(error);
    }
    _requestQueue.clear();
  }

  /// Retry a request
  Future<Response> _retry(RequestOptions requestOptions) {
    return Dio().fetch(requestOptions);
  }
}

/// Internal class to queue requests during token refresh
class _RequestQueueItem {
  final RequestOptions requestOptions;
  final ErrorInterceptorHandler handler;

  _RequestQueueItem({required this.requestOptions, required this.handler});
}
