import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_core_kit_plus/flutter_core_kit_plus.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

void main() {
  // ============================================================================
  // NETWORKING TESTS
  // ============================================================================

  group('NetworkException Tests', () {
    test('should create exception with message and status code', () {
      final exception = NetworkException('Network error', statusCode: 404);

      expect(exception.message, 'Network error');
      expect(exception.statusCode, 404);
      expect(exception.errorType, ErrorType.notFound);
    });

    test('should determine error types correctly', () {
      final auth = NetworkException('Unauthorized', statusCode: 401);
      final forbidden = NetworkException('Forbidden', statusCode: 403);
      final notFound = NetworkException('Not found', statusCode: 404);
      final client = NetworkException('Bad request', statusCode: 400);
      final server = NetworkException('Server error', statusCode: 500);

      expect(auth.errorType, ErrorType.unauthorized);
      expect(auth.isAuthError, isTrue);
      expect(forbidden.errorType, ErrorType.forbidden);
      expect(notFound.errorType, ErrorType.notFound);
      expect(client.errorType, ErrorType.clientError);
      expect(server.errorType, ErrorType.serverError);
      expect(server.isServerError, isTrue);
    });

    test('should identify retryable errors', () {
      final timeout = TimeoutException();
      final noInternet = NoInternetException();
      final server = ServerException();
      final auth = AuthException();

      expect(timeout.isRetryable, isTrue);
      expect(noInternet.isRetryable, isTrue);
      expect(server.isRetryable, isTrue);
      expect(auth.isRetryable, isFalse);
    });

    test('typed exceptions should have correct properties', () {
      final noInternet = NoInternetException();
      final timeout = TimeoutException();
      final auth = AuthException();
      final forbidden = ForbiddenException();
      final notFound = NotFoundException();
      final server = ServerException('Server down', 503);

      expect(noInternet.isNetworkError, isTrue);
      expect(timeout.errorType, ErrorType.timeout);
      expect(auth.statusCode, 401);
      expect(forbidden.statusCode, 403);
      expect(notFound.statusCode, 404);
      expect(server.statusCode, 503);
    });

    test('should convert DioException to NetworkException', () {
      final dioTimeout = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );

      final networkEx = dioTimeout.toNetworkException();
      expect(networkEx, isA<TimeoutException>());
      expect(networkEx.isRetryable, isTrue);
    });
  });

  // ============================================================================
  // AUTH TOKEN MANAGER TESTS
  // ============================================================================

  group('AuthTokenManager Tests', () {
    late AuthTokenManager tokenManager;

    setUp(() {
      tokenManager = AuthTokenManager(useSecureStorage: false);
    });

    test('should save and retrieve access token', () async {
      await tokenManager.saveAccessToken('test_access_token');
      final token = await tokenManager.getAccessToken();

      expect(token, 'test_access_token');
    });

    test('should save and retrieve refresh token', () async {
      await tokenManager.saveRefreshToken('test_refresh_token');
      final token = await tokenManager.getRefreshToken();

      expect(token, 'test_refresh_token');
    });

    test('should save multiple tokens at once', () async {
      await tokenManager.saveTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final accessToken = await tokenManager.getAccessToken();
      final refreshToken = await tokenManager.getRefreshToken();
      final expiry = await tokenManager.getTokenExpiry();

      expect(accessToken, 'access');
      expect(refreshToken, 'refresh');
      expect(expiry, isNotNull);
    });

    test('should detect expired tokens', () async {
      await tokenManager.saveTokens(
        accessToken: 'expired',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      final isExpired = await tokenManager.isAccessTokenExpired();
      final hasValid = await tokenManager.hasValidAccessToken();

      expect(isExpired, isTrue);
      expect(hasValid, isFalse);
    });

    test('should detect valid tokens', () async {
      await tokenManager.saveTokens(
        accessToken: 'valid',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final isExpired = await tokenManager.isAccessTokenExpired();
      final hasValid = await tokenManager.hasValidAccessToken();

      expect(isExpired, isFalse);
      expect(hasValid, isTrue);
    });

    test('should clear all tokens', () async {
      await tokenManager.saveTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
      );

      await tokenManager.clearTokens();

      final accessToken = await tokenManager.getAccessToken();
      final refreshToken = await tokenManager.getRefreshToken();

      expect(accessToken, isNull);
      expect(refreshToken, isNull);
    });
  });

  // ============================================================================
  // ERROR MAPPER TESTS
  // ============================================================================

  group('ErrorMapper Tests', () {
    test('should map typed exceptions to friendly messages', () {
      final noInternet = NoInternetException();
      final timeout = TimeoutException();
      final auth = AuthException();
      final forbidden = ForbiddenException();
      final notFound = NotFoundException();
      final server = ServerException();

      expect(ErrorMapper.mapError(noInternet), contains('internet'));
      expect(ErrorMapper.mapError(timeout), contains('timeout'));
      expect(ErrorMapper.mapError(auth), contains('Authentication'));
      expect(ErrorMapper.mapError(forbidden), contains('permission'));
      expect(ErrorMapper.mapError(notFound), contains('not found'));
      expect(ErrorMapper.mapError(server), contains('server error'));
    });

    test('should map status codes to friendly messages', () {
      final error400 = NetworkException('Bad request', statusCode: 400);
      final error404 = NetworkException('Not found', statusCode: 404);
      final error500 = NetworkException('Server error', statusCode: 500);
      final error503 = NetworkException('Unavailable', statusCode: 503);

      expect(ErrorMapper.mapError(error400), contains('Bad request'));
      expect(ErrorMapper.mapError(error404), contains('not found'));
      expect(ErrorMapper.mapError(error500), contains('server error'));
      expect(ErrorMapper.mapError(error503), contains('unavailable'));
    });

    test('should support custom error mappings', () {
      ErrorMapper.addMapping(TimeoutException, 'Custom timeout message');
      final timeout = TimeoutException();

      expect(ErrorMapper.mapError(timeout), 'Custom timeout message');

      ErrorMapper.clearCustomMappings();
    });

    test('should support custom status code mappings', () {
      ErrorMapper.addStatusCodeMapping(418, 'I\'m a teapot');
      final error = NetworkException('Teapot', statusCode: 418);

      expect(ErrorMapper.mapError(error), 'I\'m a teapot');

      ErrorMapper.clearCustomMappings();
    });

    test('should handle unknown errors gracefully', () {
      final message = ErrorMapper.mapError(Exception('Unknown'));

      expect(message, contains('unexpected error'));
    });
  });

  // ============================================================================
  // DEBOUNCER TESTS (Enhanced)
  // ============================================================================

  group('Debouncer Tests', () {
    test('should debounce rapid calls', () async {
      final debouncer = Debouncer(duration: const Duration(milliseconds: 100));
      int callCount = 0;

      debouncer.run(() => callCount++);
      debouncer.run(() => callCount++);
      debouncer.run(() => callCount++);

      expect(callCount, 0);
      await Future.delayed(const Duration(milliseconds: 150));
      expect(callCount, 1);

      debouncer.dispose();
    });

    test('cancel should stop pending execution', () async {
      final debouncer = Debouncer(duration: const Duration(milliseconds: 100));
      int callCount = 0;

      debouncer.run(() => callCount++);
      expect(debouncer.isActive, isTrue);

      debouncer.cancel();
      expect(debouncer.isActive, isFalse);

      await Future.delayed(const Duration(milliseconds: 150));
      expect(callCount, 0);

      debouncer.dispose();
    });

    test('isActive should reflect debouncer state', () async {
      final debouncer = Debouncer(duration: const Duration(milliseconds: 100));

      expect(debouncer.isActive, isFalse);

      debouncer.run(() {});
      expect(debouncer.isActive, isTrue);

      await Future.delayed(const Duration(milliseconds: 150));
      expect(debouncer.isActive, isFalse);

      debouncer.dispose();
    });

    test('dispose should cancel timer and clear state', () async {
      final debouncer = Debouncer(duration: const Duration(milliseconds: 100));
      int callCount = 0;

      debouncer.run(() => callCount++);
      expect(debouncer.isActive, isTrue);

      debouncer.dispose();
      expect(debouncer.isActive, isFalse);

      await Future.delayed(const Duration(milliseconds: 150));
      expect(callCount, 0);
    });
  });

  // ============================================================================
  // ASYNC VALUE TESTS
  // ============================================================================

  group('AsyncValue Tests', () {
    test('should create loading state', () {
      const asyncValue = AsyncValue<int>.loading();

      expect(asyncValue.isLoading, isTrue);
      expect(asyncValue.hasData, isFalse);
      expect(asyncValue.hasError, isFalse);
      expect(asyncValue.state, AsyncValueState.loading);
    });

    test('should create success state', () {
      const asyncValue = AsyncValue<int>.success(42);

      expect(asyncValue.isLoading, isFalse);
      expect(asyncValue.hasData, isTrue);
      expect(asyncValue.hasError, isFalse);
      expect(asyncValue.data, 42);
      expect(asyncValue.state, AsyncValueState.success);
    });

    test('should create error state', () {
      final error = Exception('Test error');
      final asyncValue = AsyncValue<int>.error(error);

      expect(asyncValue.isLoading, isFalse);
      expect(asyncValue.hasData, isFalse);
      expect(asyncValue.hasError, isTrue);
      expect(asyncValue.error, error);
      expect(asyncValue.state, AsyncValueState.error);
    });

    test('guard should catch successful futures', () async {
      final asyncValue = await AsyncValue.guard(() async => 42);

      expect(asyncValue, isA<AsyncSuccess<int>>());
      expect(asyncValue.data, 42);
    });

    test('guard should catch failing futures', () async {
      final asyncValue = await AsyncValue.guard<int>(() async {
        throw Exception('Test error');
      });

      expect(asyncValue, isA<AsyncError<int>>());
      expect(asyncValue.error.toString(), contains('Test error'));
    });

    test('when should handle all states correctly', () {
      const loading = AsyncValue<int>.loading();
      const success = AsyncValue<int>.success(42);
      final error = AsyncValue<int>.error(Exception('Error'));

      expect(
        loading.when(
          loading: () => 'loading',
          error: (e, s) => 'error',
          success: (data) => 'success: $data',
        ),
        'loading',
      );

      expect(
        success.when(
          loading: () => 'loading',
          error: (e, s) => 'error',
          success: (data) => 'success: $data',
        ),
        'success: 42',
      );

      expect(
        error.when(
          loading: () => 'loading',
          error: (e, s) => 'error',
          success: (data) => 'success: $data',
        ),
        'error',
      );
    });

    test('copyWith should update state', () {
      const loading = AsyncValue<int>.loading();
      final updated = loading.copyWith(
        data: 42,
        state: AsyncValueState.success,
      );

      expect(updated.data, 42);
      expect(updated.state, AsyncValueState.success);
    });

    test('should support equality comparison', () {
      const value1 = AsyncValue<int>.success(42);
      const value2 = AsyncValue<int>.success(42);
      const value3 = AsyncValue<int>.success(43);

      expect(value1, equals(value2));
      expect(value1, isNot(equals(value3)));
    });
  });

  // ============================================================================
  // PAGED RESPONSE TESTS
  // ============================================================================

  group('PagedResponse Tests', () {
    test('should create paged response from JSON', () {
      final json = {
        'data': [
          {'id': 1, 'name': 'Item 1'},
          {'id': 2, 'name': 'Item 2'},
        ],
        'meta': {'current_page': 1, 'last_page': 5, 'total': 50},
      };

      final response = PagedResponse.fromJson(json, (item) => item);

      expect(response.items.length, 2);
      expect(response.currentPage, 1);
      expect(response.totalPages, 5);
      expect(response.totalItems, 50);
      expect(response.hasNext, isTrue);
    });

    test('hasNext should return false on last page', () {
      final response = PagedResponse<String>(
        items: ['a', 'b'],
        currentPage: 5,
        totalPages: 5,
        totalItems: 50,
      );

      expect(response.hasNext, isFalse);
    });

    test('hasNext should return true when more pages exist', () {
      final response = PagedResponse<String>(
        items: ['a', 'b'],
        currentPage: 2,
        totalPages: 5,
        totalItems: 50,
      );

      expect(response.hasNext, isTrue);
    });
  });

  // ============================================================================
  // UI WIDGET TESTS
  // ============================================================================

  group('AsyncValueWidget Tests', () {
    testWidgets('should show loading indicator for loading state', (
      tester,
    ) async {
      const asyncValue = AsyncValue<int>.loading();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncValueWidget<int>(
              value: asyncValue,
              data: (data) => Text('Data: $data'),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show data for success state', (tester) async {
      const asyncValue = AsyncValue<int>.success(42);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncValueWidget<int>(
              value: asyncValue,
              data: (data) => Text('Data: $data'),
            ),
          ),
        ),
      );

      expect(find.text('Data: 42'), findsOneWidget);
    });

    testWidgets('should show retry button and call onRetry', (tester) async {
      final asyncValue = AsyncValue<int>.error(Exception('Test error'));
      bool retryClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncValueWidget<int>(
              value: asyncValue,
              data: (data) => Text('Data: $data'),
              onRetry: () => retryClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retryClicked, isTrue);
    });
  });

  group('AsyncValueBuilder Tests', () {
    testWidgets('should provide full control over UI', (tester) async {
      const asyncValue = AsyncValue<int>.success(42);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncValueBuilder<int>(
              value: asyncValue,
              builder: (context, value) {
                return value.when(
                  loading: () => const Text('Loading...'),
                  error: (e, s) => const Text('Error'),
                  success: (data) => Text('Custom: $data'),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Custom: 42'), findsOneWidget);
    });

    testWidgets('should handle all states in builder', (tester) async {
      const loading = AsyncValue<int>.loading();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncValueBuilder<int>(
              value: loading,
              builder: (context, value) {
                return value.when(
                  loading: () => const Text('Custom Loading'),
                  error: (e, s) => const Text('Custom Error'),
                  success: (data) => Text('Data: $data'),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Custom Loading'), findsOneWidget);
    });
  });

  group('AsyncValueSliverWidget Tests', () {
    testWidgets('should render sliver for success state', (tester) async {
      const asyncValue = AsyncValue<String>.success('Test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                AsyncValueSliverWidget<String>(
                  value: asyncValue,
                  data: (data) => Text(data),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Test'), findsOneWidget);
      expect(find.byType(SliverToBoxAdapter), findsOneWidget);
    });

    testWidgets('should show loading in sliver', (tester) async {
      const asyncValue = AsyncValue<String>.loading();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                AsyncValueSliverWidget<String>(
                  value: asyncValue,
                  data: (data) => Text(data),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(SliverFillRemaining), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
