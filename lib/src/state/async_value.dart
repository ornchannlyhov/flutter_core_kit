import 'package:equatable/equatable.dart';

enum AsyncValueState { loading, success, error }

class AsyncValue<T> extends Equatable {
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

  const factory AsyncValue.loading() = AsyncLoading<T>;
  const factory AsyncValue.success(T data) = AsyncSuccess<T>;
  const factory AsyncValue.error(Object error, [StackTrace? stack]) =
      AsyncError<T>;

  /// Guard: Automatically catches errors from a Future
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
  List<Object?> get props => [state, data, error, stackTrace];
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
