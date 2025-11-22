## 0.1.0

### 🎉 Major Release - Production-Ready Enhancements

#### ✨ New Features

**Response Caching & Offline Support**
* Added `CacheManager` for HTTP response caching with Hive storage
* Configurable cache policies (TTL, max size, offline-first mode)
* Automatic cache fallback when network is unavailable
* Cache management utilities (clear, delete specific entries)

**Authentication Support**
* Added `AuthTokenManager` for secure token storage with support for access/refresh tokens
* Added `AuthInterceptor` for automatic token injection and refresh
* Automatic token refresh on 401 responses with request queuing
* Fallback to memory storage if secure storage is unavailable

**Request Cancellation & Management**
* Added `CancelToken` support to all HTTP methods
* Automatic request deduplication to prevent duplicate simultaneous requests
* Request tracking and cancellation utilities
* Enhanced `Debouncer` with `cancel()` method and `isActive` getter

**Advanced Error Handling**
* Complete typed error hierarchy (`NetworkException`, `NoInternetException`, `TimeoutException`, `AuthException`, `ForbiddenException`, `NotFoundException`, `ServerException`)
* HTTP status code categorization (4xx client errors, 5xx server errors)
* `RetryInterceptor` with exponential backoff for network errors
* `ErrorMapper` utility for user-friendly error messages
* `isRetryable` property to intelligently retry failed requests

**Enhanced UI Widgets**
* Added `AsyncValueBuilder` for full control over AsyncValue UI rendering
* Added `AsyncValueSliverWidget` for sliver-based layouts in `CustomScrollView`
* Added `PaginatedListView` with infinite scroll and pull-to-refresh
* Automatic pagination detection with loading indicators

**File Upload/Download**
* Added `upload()` method with multipart form-data support
* Added `download()` method with progress tracking
* Progress callbacks for uploads and downloads

#### 🔧 Improvements

* Enhanced `RestClient` with cache and retry configuration options
* Improved error messages with DioException extension converter
* Better type safety across all components
* Memory-efficient caching with configurable size limits

#### 📦 New Dependencies

* `dio_cache_interceptor: ^3.5.0` - HTTP caching
* `dio_cache_interceptor_hive_store: ^3.2.2` - Hive-based cache storage
* `hive: ^2.2.3` - Local storage
* `path_provider: ^2.1.0` - Path utilities
* `flutter_secure_storage: ^9.0.0` - Secure token storage

#### ⚠️ Breaking Changes

None - All changes are backward compatible. Existing code will continue to work without modifications.

---

## 0.0.1

* Initial release.
* Added RestClient with Dio and ConnectivityPlus.
* Added AsyncValue for state management.
* Added AsyncValueWidget for standardized UI.
* Added Debouncer and Pagination utilities.
