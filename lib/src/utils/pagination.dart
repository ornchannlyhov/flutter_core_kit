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
  // For JSON structure like: { "data": [], "meta": { "current_page": 1 } }
  factory PagedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PagedResponse(
      items: (json['data'] as List).map((e) => fromJsonT(e)).toList(),
      currentPage: json['meta']?['current_page'] ?? 1,
      totalPages: json['meta']?['last_page'] ?? 1,
      totalItems: json['meta']?['total'] ?? 0,
    );
  }
}
