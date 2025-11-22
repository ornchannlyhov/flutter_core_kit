# Flutter Core Kit Plus

A robust, production-ready foundation for Flutter applications. This package combines an internet-aware HTTP client, type-safe state management, and reusable UI components to reduce boilerplate code by up to 70%.

## ✨ Features

*   **📡 RestClient**: A wrapper around `Dio` that automatically handles network connectivity checks, global error handling, and logging.
*   **⚡ AsyncValue**: A state management wrapper (inspired by Riverpod) to handle `Loading`, `Error`, and `Success` states easily.
*   **🛡️ AsyncValueWidget**: A UI component that automatically handles loading spinners and error retry screens based on your state.
*   **🛠️ Utilities**: Includes a `Debouncer` for search inputs and `PagedResponse` for parsing paginated API lists.

## 📦 Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_core_kit_plus: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## 🚀 Getting Started

### 1. Setup the API Client

The RestClient is environment-agnostic. You pass the URL and interceptors (like Auth) when you create it.

```dart
import 'package:flutter_core_kit_plus/flutter_core_kit_plus.dart';

final api = RestClient(
  baseUrl: 'https://api.example.com',
  enableLogging: true, // Logs requests to console
  interceptors: [
    // Add your AuthInterceptor here if needed
  ],
);
```

### 2. Fetching Data (The Safe Way)

Use `AsyncValue.guard` to handle try/catch blocks automatically. It converts exceptions into an `AsyncError` state without crashing your app.

```dart
class UserNotifier extends ChangeNotifier {
  final RestClient _api;
  
  // 1. Define your state
  AsyncValue<User> userState = const AsyncValue.loading();

  UserNotifier(this._api);

  Future<void> fetchUser() async {
    // 2. Set loading
    userState = const AsyncValue.loading();
    notifyListeners();

    // 3. Fetch data safely
    userState = await AsyncValue.guard(() async {
      final data = await _api.get('/user/profile');
      return User.fromJson(data);
    });
    
    notifyListeners();
  }
}
```

### 3. The UI (AsyncValueWidget)

Stop writing `if (loading) ... else if (error) ...`. Use the widget:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: AsyncValueWidget<User>(
      value: userNotifier.userState,
      onRetry: () => userNotifier.fetchUser(), // Auto-shows Retry Button on error
      data: (user) {
        return Text("Hello, ${user.name}!");
      },
    ),
  );
}
```

## 🛠️ Utilities

### Debouncer

Prevent API spam when users type in search bars.

```dart
final _debouncer = Debouncer(duration: Duration(milliseconds: 500));

TextField(
  onChanged: (text) {
    _debouncer.run(() {
      // This runs only after the user stops typing for 500ms
      performSearch(text);
    });
  },
);
```

### Pagination Helper

Easily parse paginated responses from JSON.

```dart
final response = await api.get('/products?page=1');
final pagedData = PagedResponse.fromJson(
  response, 
  (json) => Product.fromJson(json)
);

print(pagedData.currentPage);
print(pagedData.hasNext);
```

## 🐞 Error Handling

`RestClient` automatically throws a `NetworkException` if there is no internet connection. You do not need to manually check for `Connectivity()` in your UI code.

## 🙏 Acknowledgments

This package is built on top of these excellent open-source libraries:

- [Dio](https://pub.dev/packages/dio) - Powerful HTTP client for Dart
- [connectivity_plus](https://pub.dev/packages/connectivity_plus) - Network connectivity checking
- [equatable](https://pub.dev/packages/equatable) - Value equality for Dart classes

## ❤️ Contributing

Contributions are welcome! Please open an issue or PR on the GitHub repository.