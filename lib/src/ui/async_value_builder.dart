import 'package:flutter/material.dart';
import '../state/async_value.dart';

/// Builder widget for AsyncValue with full control over UI
class AsyncValueBuilder<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(BuildContext context, AsyncValue<T> value) builder;

  const AsyncValueBuilder({
    super.key,
    required this.value,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, value);
  }
}
