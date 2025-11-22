import 'package:flutter/material.dart';
import 'package:flutter_core_kit_plus/flutter_core_kit_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize cache
  await CacheManager.instance.initialize(
    maxAge: const Duration(hours: 1),
    maxStale: const Duration(days: 7),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Core Kit Plus Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DemoScreen(),
    );
  }
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  // Initialize API client with caching and retry
  final _client = RestClient(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    enableLogging: true,
    enableCache: true,
    enableRetry: true,
    maxRetries: 2,
  );

  // State management
  AsyncValue<User> _userState = const AsyncValue.loading();
  AsyncValue<PagedResponse<Post>> _postsState = const AsyncValue.loading();

  // Debouncer for search
  final _debouncer = Debouncer(duration: const Duration(milliseconds: 500));

  @override
  void initState() {
    super.initState();
    _fetchUser();
    _fetchPosts();
  }

  Future<void> _fetchUser() async {
    setState(() => _userState = const AsyncValue.loading());

    final newState = await AsyncValue.guard(() async {
      final data = await _client.get<Map<String, dynamic>>('/users/1');
      return User.fromJson(data);
    });

    if (mounted) {
      setState(() => _userState = newState);
    }
  }

  Future<void> _fetchPosts() async {
    setState(() => _postsState = const AsyncValue.loading());

    final newState = await AsyncValue.guard(() async {
      final data = await _client.get<List<dynamic>>('/posts?_limit=10');

      // Convert to PagedResponse format
      return PagedResponse<Post>(
        items: data.map((e) => Post.fromJson(e)).toList(),
        currentPage: 1,
        totalPages: 1,
        totalItems: data.length,
      );
    });

    if (mounted) {
      setState(() => _postsState = newState);
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _client.cancelAllRequests();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Flutter Core Kit Plus Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear Cache',
            onPressed: () async {
              await CacheManager.instance.clearCache();
              await _fetchUser();
              await _fetchPosts();
              if (mounted) {
                ScaffoldMessenger.of(
                  // ignore: use_build_context_synchronously
                  context,
                ).showSnackBar(const SnackBar(content: Text('Cache cleared!')));
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchUser();
          await _fetchPosts();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Section with AsyncValueWidget
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'User Profile (AsyncValueWidget)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AsyncValueWidget<User>(
                        value: _userState,
                        onRetry: _fetchUser,
                        data: (user) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Name: ${user.name}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Email: ${user.email}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Search with Debouncer
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Debounced Search',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search (debounced 500ms)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (text) {
                          _debouncer.run(() {
                            debugPrint('Searching for: $text');
                            // In a real app, you'd call search API here
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Debouncer status: ${_debouncer.isActive ? "Pending" : "Idle"}',
                        style: TextStyle(
                          color: _debouncer.isActive
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Posts List
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Posts (with Caching & Retry)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 300,
                        child: AsyncValueWidget<PagedResponse<Post>>(
                          value: _postsState,
                          onRetry: _fetchPosts,
                          data: (pagedResponse) => ListView.separated(
                            itemCount: pagedResponse.items.length,
                            separatorBuilder: (context, index) =>
                                const Divider(),
                            itemBuilder: (context, index) {
                              final post = pagedResponse.items[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text('${post.id}'),
                                ),
                                title: Text(
                                  post.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  post.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Info card
              Card(
                color: Colors.blue.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Features Demo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('✓ HTTP Caching (1 hour TTL)'),
                      Text('✓ Automatic Retry (max 2 retries)'),
                      Text('✓ AsyncValue State Management'),
                      Text('✓ Debounced Search'),
                      Text('✓ Pull-to-Refresh'),
                      Text('✓ Error Handling with Retry'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Models
class User {
  final String name;
  final String email;

  User({required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) =>
      User(name: json['name'], email: json['email']);
}

class Post {
  final int id;
  final String title;
  final String body;

  Post({required this.id, required this.title, required this.body});

  factory Post.fromJson(Map<String, dynamic> json) =>
      Post(id: json['id'], title: json['title'], body: json['body']);
}
