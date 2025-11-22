// Import your package
import 'package:flutter/material.dart';
import 'package:flutter_core_kit_plus/flutter_core_kit_plus.dart';

// 1. Define a Model
class User {
  final String name;
  User({required this.name});
  factory User.fromJson(Map<String, dynamic> json) => User(name: json['name']);
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: UserScreen());
  }
}

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  // 2. Initialize Client (Usually done in a Provider)
  final _client = RestClient(baseUrl: 'https://jsonplaceholder.typicode.com');

  // 3. Initialize State
  AsyncValue<User> _userState = const AsyncValue.loading();

  // 4. Initialize Debouncer for search
  final _debouncer = Debouncer();

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    // 5. Use Guard to handle API call safely
    setState(() => _userState = const AsyncValue.loading());

    final newState = await AsyncValue.guard(() async {
      // Example: Fetch user ID 1
      final data = await _client.get<Map<String, dynamic>>('/users/1');
      return User.fromJson(data);
    });

    if (mounted) {
      setState(() => _userState = newState);
    }
  }

  @override
  void dispose() {
    // 8. Clean up debouncer to prevent memory leaks
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Flutter Core Kit Demo")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: "Search (Debounced)",
              ),
              onChanged: (val) {
                // 6. Use Debouncer
                _debouncer.run(() {
                  debugPrint("Searching API for: $val");
                  // Call search API here
                });
              },
            ),
          ),
          Expanded(
            // 7. Use AsyncValueWidget to handle UI
            child: AsyncValueWidget<User>(
              value: _userState,
              onRetry: _fetchUser,
              data: (user) => Center(
                child: Text(
                  "User Found: ${user.name}",
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
