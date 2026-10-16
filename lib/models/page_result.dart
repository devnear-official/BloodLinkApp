class PageResult<T> {
  const PageResult({
    required this.items,
    required this.hasMore,
    required this.page,
    required this.total,
  });

  final List<T> items;
  final bool hasMore;
  final int page;
  final int total;

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final rawItems = json['items'] as List<dynamic>;
    return PageResult<T>(
      items: rawItems
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList(),
      hasMore: json['hasMore'] == true,
      page: (json['page'] as num?)?.toInt() ?? 1,
      total: (json['total'] as num?)?.toInt() ?? rawItems.length,
    );
  }
}
