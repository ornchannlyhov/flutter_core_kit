/// Enum defining the current state of the AsyncValue
enum AsyncValueState { loading, success, error }

/// A value that is loaded asynchronously
class AsyncValue<T> {
  final T? data;
  final Object? error;
  final StackTrace? stackTrace;
  final AsyncValueState state;

  const AsyncValue._({
    this.data,
    this.error,
    this.stackTrace,
    required this.state,
  });

  /// Creates an [AsyncValue] in loading state
  const factory AsyncValue.loading() = AsyncLoading<T>;

  /// Creates an [AsyncValue] in success state
  const factory AsyncValue.success(T data) = AsyncSuccess<T>;

  /// Creates an [AsyncValue] in error state
  const factory AsyncValue.error(Object error, [StackTrace? stack]) =
      AsyncError<T>;

  /// Guard: Automatically catches errors from a Future and converts them to AsyncValue
  static Future<AsyncValue<T>> guard<T>(Future<T> Function() future) async {
    try {
      final result = await future();
      return AsyncValue.success(result);
    } catch (e, s) {
      return AsyncValue.error(e, s);
    }
  }

  bool get isLoading => state == AsyncValueState.loading;
  bool get hasData => state == AsyncValueState.success && data != null;
  bool get hasError => state == AsyncValueState.error;

  /// Returns a copy of this AsyncValue with the given fields replaced
  AsyncValue<T> copyWith({
    T? data,
    Object? error,
    StackTrace? stackTrace,
    AsyncValueState? state,
  }) {
    return AsyncValue._(
      data: data ?? this.data,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
      state: state ?? this.state,
    );
  }

  /// Pattern matching for AsyncValue
  R when<R>({
    required R Function() loading,
    required R Function(Object error, StackTrace? stack) error,
    required R Function(T data) success,
  }) {
    switch (state) {
      case AsyncValueState.loading:
        return loading();
      case AsyncValueState.error:
        return error(this.error!, this.stackTrace);
      case AsyncValueState.success:
        return success(this.data as T);
    }
  }

  /// Pattern matching for AsyncValue with default fallback
  R maybeWhen<R>({
    R Function()? loading,
    R Function(Object error, StackTrace? stack)? error,
    R Function(T data)? success,
    required R Function() orElse,
  }) {
    switch (state) {
      case AsyncValueState.loading:
        return loading != null ? loading() : orElse();
      case AsyncValueState.error:
        return error != null ? error(this.error!, this.stackTrace) : orElse();
      case AsyncValueState.success:
        return success != null ? success(this.data as T) : orElse();
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AsyncValue<T> &&
        other.data == data &&
        other.error == error &&
        other.stackTrace == stackTrace &&
        other.state == state;
  }

  @override
  int get hashCode {
    return Object.hash(data, error, stackTrace, state);
  }
}

class AsyncLoading<T> extends AsyncValue<T> {
  const AsyncLoading() : super._(state: AsyncValueState.loading);
}

class AsyncSuccess<T> extends AsyncValue<T> {
  const AsyncSuccess(T data)
    : super._(data: data, state: AsyncValueState.success);
}

class AsyncError<T> extends AsyncValue<T> {
  const AsyncError(Object error, [StackTrace? stack])
    : super._(error: error, stackTrace: stack, state: AsyncValueState.error);
}
