import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_core_kit_plus/flutter_core_kit_plus.dart';
import 'package:flutter/material.dart';

void main() {
  group('NetworkException Tests', () {
    test('should create exception with message and status code', () {
      final exception = NetworkException('Network error', statusCode: 404);

      expect(exception.message, 'Network error');
      expect(exception.statusCode, 404);
    });

    test('should create exception without status code', () {
      final exception = NetworkException('Network error');

      expect(exception.message, 'Network error');
      expect(exception.statusCode, isNull);
    });

    test('should have correct toString', () {
      final exception = NetworkException('Not found', statusCode: 404);

      expect(exception.toString(), 'NetworkException: Not found (Code: 404)');
    });
  });

  group('Result Tests', () {
    test('Success should hold value', () {
      const result = Success<int>(42);

      expect(result, isA<Success<int>>());
      expect(result.value, 42);
    });

    test('Failure should hold exception', () {
      final exception = Exception('Error occurred');
      final result = Failure<int>(exception);

      expect(result, isA<Failure<int>>());
      expect(result.exception, exception);
    });

    test('should work with pattern matching', () {
      const success = Success<String>('Hello');
      final failure = Failure<String>(Exception('Oops'));

      final successResult = switch (success) {
        Success(value: final v) => v,
      };

      final failureResult = switch (failure) {
        Success() => 'success',
        Failure(exception: final e) => e.toString(),
      };

      expect(successResult, 'Hello');
      expect(failureResult, contains('Oops'));
    });
  });

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

      final loadingResult = loading.when(
        loading: () => 'loading',
        error: (e, s) => 'error',
        success: (data) => 'success: $data',
      );

      final successResult = success.when(
        loading: () => 'loading',
        error: (e, s) => 'error',
        success: (data) => 'success: $data',
      );

      final errorResult = error.when(
        loading: () => 'loading',
        error: (e, s) => 'error',
        success: (data) => 'success: $data',
      );

      expect(loadingResult, 'loading');
      expect(successResult, 'success: 42');
      expect(errorResult, 'error');
    });

    test('maybeWhen should use orElse when callback not provided', () {
      const loading = AsyncValue<int>.loading();

      final result = loading.maybeWhen(
        success: (data) => 'success: $data',
        orElse: () => 'default',
      );

      expect(result, 'default');
    });

    test('maybeWhen should use specific callback when provided', () {
      const success = AsyncValue<int>.success(42);

      final result = success.maybeWhen(
        success: (data) => 'success: $data',
        orElse: () => 'default',
      );

      expect(result, 'success: 42');
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

  group('Debouncer Tests', () {
    test('should debounce rapid calls', () async {
      final debouncer = Debouncer(duration: const Duration(milliseconds: 100));
      int callCount = 0;

      // Rapid calls
      debouncer.run(() => callCount++);
      debouncer.run(() => callCount++);
      debouncer.run(() => callCount++);

      // Should not have executed yet
      expect(callCount, 0);

      // Wait for debounce duration
      await Future.delayed(const Duration(milliseconds: 150));

      // Should have executed only once
      expect(callCount, 1);

      debouncer.dispose();
    });

    test('should execute latest action only', () async {
      final debouncer = Debouncer(duration: const Duration(milliseconds: 100));
      String result = '';

      debouncer.run(() => result = 'first');
      await Future.delayed(const Duration(milliseconds: 50));
      debouncer.run(() => result = 'second');
      await Future.delayed(const Duration(milliseconds: 50));
      debouncer.run(() => result = 'third');

      await Future.delayed(const Duration(milliseconds: 150));

      expect(result, 'third');
      debouncer.dispose();
    });

    test('dispose should cancel timer', () async {
      final debouncer = Debouncer(duration: const Duration(milliseconds: 100));
      int callCount = 0;

      debouncer.run(() => callCount++);
      debouncer.dispose();

      await Future.delayed(const Duration(milliseconds: 150));

      expect(callCount, 0);
    });
  });

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

    test('should handle missing meta fields with defaults', () {
      final json = {
        'data': [
          {'id': 1},
        ],
      };

      final response = PagedResponse.fromJson(json, (item) => item);

      expect(response.currentPage, 1);
      expect(response.totalPages, 1);
      expect(response.totalItems, 0);
      expect(response.hasNext, isFalse);
    });
  });

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
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('should show error for error state', (tester) async {
      final asyncValue = AsyncValue<int>.error(Exception('Test error'));

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

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains('Test error'),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
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

    testWidgets('should use custom loading widget', (tester) async {
      const asyncValue = AsyncValue<int>.loading();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncValueWidget<int>(
              value: asyncValue,
              data: (data) => Text('Data: $data'),
              loading: () => const Text('Custom Loading'),
            ),
          ),
        ),
      );

      expect(find.text('Custom Loading'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('should use custom error widget', (tester) async {
      final asyncValue = AsyncValue<int>.error(Exception('Test error'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncValueWidget<int>(
              value: asyncValue,
              data: (data) => Text('Data: $data'),
              error: (err, stack) => Text('Custom Error: $err'),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains('Custom Error'),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });
  });
}
