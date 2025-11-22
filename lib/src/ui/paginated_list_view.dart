import 'package:flutter/material.dart';
import '../state/async_value.dart';
import '../utils/pagination.dart';

/// Ready-to-use paginated list view with AsyncValue and PagedResponse
class PaginatedListView<T> extends StatefulWidget {
  final AsyncValue<PagedResponse<T>> value;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Future<void> Function()? onLoadMore;
  final Future<void> Function()? onRefresh;
  final Widget Function()? loadingBuilder;
  final Widget Function(Object error, StackTrace? stack)? errorBuilder;
  final Widget Function()? emptyBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final Widget? separator;

  const PaginatedListView({
    super.key,
    required this.value,
    required this.itemBuilder,
    this.onLoadMore,
    this.onRefresh,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
    this.separator,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll * 0.8; // Load more at 80% scroll

    if (currentScroll >= threshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (!widget.value.hasData) return;

    final pagedResponse = widget.value.data!;
    if (!pagedResponse.hasNext) return;

    setState(() => _isLoadingMore = true);

    try {
      await widget.onLoadMore?.call();
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.value.when(
      loading: () =>
          widget.loadingBuilder?.call() ??
          const Center(child: CircularProgressIndicator()),
      error: (err, stack) =>
          widget.errorBuilder?.call(err, stack) ??
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  if (widget.onRefresh != null) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: widget.onRefresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
      success: (pagedResponse) {
        if (pagedResponse.items.isEmpty) {
          return widget.emptyBuilder?.call() ??
              const Center(child: Text('No items found'));
        }

        final listView = ListView.separated(
          controller: _scrollController,
          padding: widget.padding,
          physics: widget.physics,
          shrinkWrap: widget.shrinkWrap,
          itemCount: pagedResponse.items.length + (_isLoadingMore ? 1 : 0),
          separatorBuilder: (context, index) {
            if (widget.separator != null &&
                index < pagedResponse.items.length - 1) {
              return widget.separator!;
            }
            return const SizedBox.shrink();
          },
          itemBuilder: (context, index) {
            if (index >= pagedResponse.items.length) {
              // Loading indicator at bottom
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            return widget.itemBuilder(
              context,
              pagedResponse.items[index],
              index,
            );
          },
        );

        if (widget.onRefresh != null) {
          return RefreshIndicator(
            onRefresh: widget.onRefresh!,
            child: listView,
          );
        }

        return listView;
      },
    );
  }
}
