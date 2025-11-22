# Flutter Core Kit Plus

A robust, production-ready foundation for Flutter applications with **v0.1.0** bringing enterprise-grade features. This package combines an internet-aware HTTP client, type-safe state management, response caching, authentication handling, and reusable UI components to reduce boilerplate code by up to 70%.

## ✨ Features

*   **📡 RestClient**: Enhanced Dio wrapper with automatic network checks, caching, retries, and request cancellation
*   **🔐 Authentication**: Built-in token management with automatic refresh and secure storage
*   **💾 Response Caching**: Offline-first HTTP caching with configurable TTL and policies
*   **⚡ AsyncValue**: Type-safe state management for `Loading`, `Error`, and `Success` states
*   **🛡️ Advanced Error Handling**: Typed exceptions with retry strategies and user-friendly error mapping
*   **🎨 UI Widgets**: Ready-to-use widgets including `AsyncValueWidget`, `PaginatedListView`, and sliver variants
*   **🛠️ Utilities**: `Debouncer`, `PagedResponse`, and `ErrorMapper` for common tasks

## 📦 Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_core_kit_plus: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## 🚀 Quick Start

### 1. Basic Setup with Caching

```dart
import 'package:flutter_core_kit_plus/flutter_core_kit_plus.dart';

// Initialize cache (call once at app startup)
await CacheManager.instance.initialize(
  maxAge: Duration(hours: 1),
  maxStale: Duration(days: 7),
);

// Create API client with caching enabled
final api = RestClient(
  baseUrl: 'https://api.example.com',
  enableLogging: true,
  enableCache: true,
  enableRetry: true,
  maxRetries: 3,
);
```

### 2. Authentication Setup

```dart
// Initialize token manager
final tokenManager = AuthTokenManager(useSecureStorage: true);

// Create auth interceptor
final authInterceptor = AuthInterceptor.withTokenManager(
  tokenManager: tokenManager,
  onTokenRefresh: (refreshToken) async {
    // Call your refresh endpoint
    final response = await api.post('/auth/refresh', data: {
      'refresh_token': refreshToken,
    });
    return response['access_token'];
  },
  onRefreshFailed: () async {
    // Handle logout
    await tokenManager.clearTokens();
    // Navigate to login
  },
);

// Create API client with auth
final authenticatedApi = RestClient(
  baseUrl: 'https://api.example.com',
  interceptors: [authInterceptor],
  enableCache: true,
);
```

### 3. Making Requests with Advanced Features

```dart
class UserRepository {
  final RestClient api;
  UserRepository(this.api);

  // GET with query params
  Future<User> getUser(String id) async {
    final data = await api.get('/users/$id');
    return User.fromJson(data);
  }

  // POST with data
  Future<User> createUser(User user) async {
    final data = await api.post('/users', data: user.toJson());
    return User.fromJson(data);
  }

  // Upload file with progress
  Future<void> uploadAvatar(File file) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(file.path),
    });

    await api.upload(
      '/users/avatar',
      formData: formData,
      onSendProgress: (sent, total) {
        print('Upload progress: ${(sent / total * 100).toStringAsFixed(0)}%');
      },
    );
  }

  // Download file
  Future<void> downloadReport(String path) async {
    await api.download(
      '/reports/export',
      path,
      onReceiveProgress: (received, total) {
        print('Download: ${(received / total * 100).toStringAsFixed(0)}%');
      },
    );
  }
}
```

### 4. State Management with AsyncValue

```dart
class UserNotifier extends ChangeNotifier {
  final UserRepository _repo;
  AsyncValue<User> userState = const AsyncValue.loading();

  UserNotifier(this._repo);

  Future<void> fetchUser(String id) async {
    userState = const AsyncValue.loading();
    notifyListeners();

    userState = await AsyncValue.guard(() => _repo.getUser(id));
    notifyListeners();
  }
}
```

### 5. UI with AsyncValueWidget

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: AsyncValueWidget<User>(
      value: userNotifier.userState,
      onRetry: () => userNotifier.fetchUser('123'),
      data: (user) => UserProfile(user: user),
    ),
  );
}
```

## 📚 Advanced Features

### Response Caching

```dart
// Initialize with custom settings
await CacheManager.instance.initialize(
  maxAge: Duration(minutes: 30),      // Cache validity
  maxStale: Duration(days: 7),        // Offline fallback duration
  policy: CachePolicy.request,        // Cache strategy
);

// Clear all cache
await CacheManager.instance.clearCache();

// Delete specific cache
await CacheManager.instance.deleteCache('cache_key');

// Use offline-first mode
final api = RestClient(
  baseUrl: 'https://api.example.com',
  enableCache: true,
  cacheOptions: CacheOptions(
    store: CacheManager.instance.cacheOptions!.store,
    policy: CachePolicyPreset.offlineFirst, // Cache first, then network
  ),
);
```

### Error Handling

```dart
try {
  final data = await api.get('/users/123');
} on NoInternetException catch (e) {
  // Handle no internet
  showSnackbar('No internet connection');
} on AuthException catch (e) {
  // Handle auth error
  navigateToLogin();
} on ServerException catch (e) {
  // Handle server error
  showSnackbar('Server error, please try later');
} on NetworkException catch (e) {
  // Catch all other network errors
  if (e.isRetryable) {
    // Retry logic already handled by RetryInterceptor
  }
  
  // Get user-friendly message
  final message = ErrorMapper.mapError(e);
  showSnackbar(message);
}
```

### Pagination with PaginatedListView

```dart
class ProductsScreen extends StatefulWidget {
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  AsyncValue<PagedResponse<Product>> productsState = 
    const AsyncValue.loading();
  int currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts({bool refresh = false}) async {
    if (refresh) currentPage = 1;

    final newState = await AsyncValue.guard(() async {
      final response = await api.get('/products?page=$currentPage');
      return PagedResponse<Product>.fromJson(
        response,
        (json) => Product.fromJson(json),
      );
    });

    setState(() => productsState = newState);
  }

  Future<void> _loadMore() async {
    if (productsState.hasData && productsState.data!.hasNext) {
      currentPage++;
      await _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Products')),
      body: PaginatedListView<Product>(
        value: productsState,
        itemBuilder: (context, product, index) {
          return ProductCard(product: product);
        },
        onLoadMore: _loadMore,
        onRefresh: () => _loadProducts(refresh: true),
        separator: Divider(),
      ),
    );
  }
}
```

### Request Cancellation

```dart
class SearchNotifier extends ChangeNotifier {
  final RestClient api;
  final Debouncer debouncer = Debouncer();
  AsyncValue<List<Product>> results = const AsyncValue.loading();

  void search(String query) {
    // Cancel previous search
    api.cancelRequest('/search');
    debouncer.cancel();

    debouncer.run(() async {
      results = const AsyncValue.loading();
      notifyListeners();

      results = await AsyncValue.guard(() async {
        final data = await api.get('/search', queryParams: {'q': query});
        return (data['items'] as List)
            .map((e) => Product.fromJson(e))
            .toList();
      });

      notifyListeners();
    });
  }

  @override
  void dispose() {
    api.cancelAllRequests();
    debouncer.dispose();
    super.dispose();
  }
}
```

### Custom Error Messages

```dart
// Add custom error mappings
ErrorMapper.addStatusCodeMapping(404, 'Product not found');
ErrorMapper.addMapping(
  TimeoutException,
  'Request is taking too long. Please check your connection.',
);

// Use in catch blocks
try {
  await api.get('/products/123');
} catch (e) {
  final friendlyMessage = ErrorMapper.mapError(e);
  showDialog(context, message: friendlyMessage);
}
```

## 🛠️ All Available Widgets

### AsyncValueWidget
Standard widget for displaying AsyncValue states:
```dart
AsyncValueWidget<User>(
  value: asyncValue,
  onRetry: () => fetchUser(),
  data: (user) => Text(user.name),
)
```

### AsyncValueBuilder
Full control over UI rendering:
```dart
AsyncValueBuilder<User>(
  value: asyncValue,
  builder: (context, value) {
    return value.when(
      loading: () => CustomLoadingWidget(),
      error: (err, stack) => CustomErrorWidget(err),
      success: (user) => UserWidget(user),
    );
  },
)
```

### AsyncValueSliverWidget
For use in CustomScrollView:
```dart
CustomScrollView(
  slivers: [
    AsyncValueSliverWidget<User>(
      value: asyncValue,
      onRetry: () => fetchUser(),
      data: (user) => SliverList(...),
    ),
  ],
)
```

## 🙏 Acknowledgments

This package is built on top of these excellent open-source libraries:

- [Dio](https://pub.dev/packages/dio) - Powerful HTTP client
- [connectivity_plus](https://pub.dev/packages/connectivity_plus) - Network connectivity checking
- [equatable](https://pub.dev/packages/equatable) - Value equality
- [dio_cache_interceptor](https://pub.dev/packages/dio_cache_interceptor) - HTTP caching
- [hive](https://pub.dev/packages/hive) - Fast local storage
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) - Secure token storage

## 📝 License

MIT License - see LICENSE file for details

## ❤️ Contributing

Contributions are welcome! Please open an issue or PR on the [GitHub repository](https://github.com/ornchannlyhov/flutter_core_kit).