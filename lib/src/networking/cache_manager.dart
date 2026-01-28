import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

/// Manages HTTP response caching with configurable policies
class CacheManager {
  static CacheManager? _instance;
  CacheStore? _cacheStore;
  CacheOptions? _cacheOptions;

  CacheManager._();

  /// Singleton instance
  static CacheManager get instance {
    _instance ??= CacheManager._();
    return _instance!;
  }

  /// Initialize the cache manager
  /// [store] Optional cache store. Defaults to MemCacheStore if not provided.
  Future<void> initialize({
    CacheStore? store,
    Duration maxStale = const Duration(days: 7),
    Duration maxAge = const Duration(hours: 1),
    CachePolicy policy = CachePolicy.request,
    int maxSize = 10 * 1024 * 1024, // 10MB default
  }) async {
    if (_cacheStore != null) {
      return; // Already initialized
    }

    _cacheStore = store ?? MemCacheStore(maxSize: maxSize);

    _cacheOptions = CacheOptions(
      store: _cacheStore!,
      policy: policy,
      maxStale: maxStale,
      priority: CachePriority.high,
      cipher: null,
      keyBuilder: CacheOptions.defaultCacheKeyBuilder,
      allowPostMethod: false,
    );
  }

  /// Get cache options for Dio
  CacheOptions? get cacheOptions => _cacheOptions;

  /// Create a cache interceptor
  DioCacheInterceptor? get cacheInterceptor {
    if (_cacheOptions == null) return null;
    return DioCacheInterceptor(options: _cacheOptions!);
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    await _cacheStore?.clean();
  }

  /// Delete specific cache entry by key
  Future<void> deleteCache(String key) async {
    await _cacheStore?.delete(key);
  }

  /// Check if cache is initialized
  bool get isInitialized => _cacheStore != null && _cacheOptions != null;

  /// Close cache store
  Future<void> close() async {
    await _cacheStore?.close();
    _cacheStore = null;
    _cacheOptions = null;
  }
}

/// Cache policy presets
class CachePolicyPreset {
  /// Cache first, then network (offline-first)
  static const CachePolicy offlineFirst = CachePolicy.forceCache;

  /// Network first, cache as fallback
  static const CachePolicy networkFirst = CachePolicy.request;

  /// Always use network, update cache
  static const CachePolicy networkOnly = CachePolicy.refresh;

  /// Only use cache, never network
  static const CachePolicy cacheOnly = CachePolicy.forceCache;

  /// Use cache if available and not stale, otherwise network
  static const CachePolicy cacheOrNetwork = CachePolicy.request;
}
