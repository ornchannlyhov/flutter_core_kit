class PagedResponse<T> {
  final List<T> items;
  final int currentPage;
  final int totalPages;
  final int totalItems;

  bool get hasNext => currentPage < totalPages;

  PagedResponse({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
  });

  // Generic factory to parse pagination JSON
  factory PagedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PagedResponse(
      items: (json['items'] as List)
          .map((e) => fromJsonT(e as Map<String, dynamic>))
          .toList(),
      currentPage: json['current_page'] as int,
      totalPages: json['total_pages'] as int,
      totalItems: json['total_items'] as int,
    );
  }
}
