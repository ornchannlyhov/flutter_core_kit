import 'package:flutter/material.dart';
import 'package:flutter_core_kit_plus/flutter_core_kit_plus.dart';

/// Pagination example with infinite scroll and pull-to-refresh
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheManager.instance.initialize();
  runApp(const PaginationExampleApp());
}

class PaginationExampleApp extends StatelessWidget {
  const PaginationExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pagination Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ProductListScreen(),
    );
  }
}

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _api = RestClient(
    baseUrl: 'https://dummyjson.com',
    enableCache: true,
    enableLogging: true,
  );

  AsyncValue<PagedResponse<Product>> _productsState =
      const AsyncValue.loading();
  int _currentPage = 0;
  final int _limit = 10;
  List<Product> _allProducts = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 0;
      _allProducts = [];
    }

    setState(() => _productsState = const AsyncValue.loading());

    final newState = await AsyncValue.guard(() async {
      final skip = _currentPage * _limit;
      final response = await _api.get('/products?limit=$_limit&skip=$skip');

      final products = (response['products'] as List)
          .map((e) => Product.fromJson(e))
          .toList();

      _allProducts.addAll(products);

      final total = response['total'] as int;
      final totalPages = (total / _limit).ceil();

      return PagedResponse<Product>(
        items: List.from(_allProducts),
        currentPage: _currentPage + 1,
        totalPages: totalPages,
        totalItems: total,
      );
    });

    if (mounted) {
      setState(() => _productsState = newState);
    }
  }

  Future<void> _loadMore() async {
    if (_productsState.hasData && _productsState.data!.hasNext) {
      _currentPage++;
      await _loadProducts();
    }
  }

  Future<void> _refresh() async {
    await _loadProducts(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products (Pagination)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfo(context),
          ),
        ],
      ),
      body: PaginatedListView<Product>(
        value: _productsState,
        itemBuilder: (context, product, index) {
          return ProductCard(product: product, index: index);
        },
        onLoadMore: _loadMore,
        onRefresh: _refresh,
        separator: const Divider(height: 1),
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pagination Features'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✓ Infinite Scroll (auto-loads at 80%)'),
            SizedBox(height: 4),
            Text('✓ Pull-to-Refresh'),
            SizedBox(height: 4),
            Text('✓ Loading Indicators'),
            SizedBox(height: 4),
            Text('✓ Error Handling with Retry'),
            SizedBox(height: 4),
            Text('✓ Response Caching'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final int index;

  const ProductCard({super.key, required this.product, required this.index});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.shade100,
        child: Text('${index + 1}'),
      ),
      title: Text(product.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        product.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '\$${product.price.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 16, color: Colors.amber),
              Text('${product.rating}'),
            ],
          ),
        ],
      ),
      onTap: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Tapped: ${product.title}')));
      },
    );
  }
}

class Product {
  final int id;
  final String title;
  final String description;
  final double price;
  final double rating;

  Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.rating,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    price: (json['price'] as num).toDouble(),
    rating: (json['rating'] as num).toDouble(),
  );
}
