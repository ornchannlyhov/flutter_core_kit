import 'package:flutter/material.dart';
import 'package:flutter_core_kit_plus/flutter_core_kit_plus.dart';

/// Complete authentication flow example with login, token refresh, and logout
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize cache for auth endpoints
  await CacheManager.instance.initialize();

  runApp(const AuthExampleApp());
}

class AuthExampleApp extends StatelessWidget {
  const AuthExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth Example',
      theme: ThemeData.dark(),
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _tokenManager = AuthTokenManager(useSecureStorage: true);
  late final RestClient _api;
  late final AuthInterceptor _authInterceptor;

  AsyncValue<User> _userState = const AsyncValue.loading();
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _setupAuth();
    _checkAuthStatus();
  }

  void _setupAuth() {
    // Create auth interceptor
    _authInterceptor = AuthInterceptor.withTokenManager(
      tokenManager: _tokenManager,
      onTokenRefresh: (refreshToken) async {
        debugPrint('Refreshing token...');

        // Call your refresh endpoint
        final response = await _api.post(
          '/auth/refresh',
          data: {'refresh_token': refreshToken},
        );

        final newAccessToken = response['access_token'];
        final expiresIn = response['expires_in'] ?? 3600;

        // Save new token with expiry
        await _tokenManager.saveTokens(
          accessToken: newAccessToken,
          refreshToken: response['refresh_token'],
          expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
        );

        return newAccessToken;
      },
      onRefreshFailed: () async {
        debugPrint('Token refresh failed, logging out...');
        await _logout();
      },
    );

    // Create API client with auth
    _api = RestClient(
      baseUrl: 'https://api.example.com',
      interceptors: [_authInterceptor],
      enableLogging: true,
    );
  }

  Future<void> _checkAuthStatus() async {
    final hasValidToken = await _tokenManager.hasValidAccessToken();
    setState(() => _isLoggedIn = hasValidToken);

    if (hasValidToken) {
      _fetchUserProfile();
    }
  }

  Future<void> _login(String email, String password) async {
    setState(() => _userState = const AsyncValue.loading());

    try {
      // Call login endpoint (without auth interceptor)
      final loginApi = RestClient(
        baseUrl: 'https://api.example.com',
        enableLogging: true,
      );

      final response = await loginApi.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      // Save tokens
      await _tokenManager.saveTokens(
        accessToken: response['access_token'],
        refreshToken: response['refresh_token'],
        expiresAt: DateTime.now().add(
          Duration(seconds: response['expires_in'] ?? 3600),
        ),
      );

      setState(() => _isLoggedIn = true);

      // Fetch user profile
      await _fetchUserProfile();
    } on NetworkException catch (e) {
      final message = ErrorMapper.mapError(e);

      setState(() {
        _userState = AsyncValue.error(e, StackTrace.current);
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _fetchUserProfile() async {
    setState(() => _userState = const AsyncValue.loading());

    final newState = await AsyncValue.guard(() async {
      final data = await _api.get('/auth/profile');
      return User.fromJson(data);
    });

    setState(() => _userState = newState);
  }

  Future<void> _logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (e) {
      debugPrint('Logout error: $e');
    }

    await _tokenManager.clearTokens();
    setState(() {
      _isLoggedIn = false;
      _userState = const AsyncValue.loading();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authentication Example'),
        actions: [
          if (_isLoggedIn)
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _isLoggedIn ? _buildLoggedInView() : _buildLoginView(),
    );
  }

  Widget _buildLoginView() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 24),
            const Text(
              'Login',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.password),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _login(emailController.text, passwordController.text);
                },
                child: const Text('Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedInView() {
    return AsyncValueWidget<User>(
      value: _userState,
      onRetry: _fetchUserProfile,
      data: (user) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 48,
                child: Icon(Icons.person, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(user.email, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 32),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Authentication Features',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('✓ Secure Token Storage'),
                      Text('✓ Automatic Token Refresh'),
                      Text('✓ Request Queuing During Refresh'),
                      Text('✓ Auto Logout on Refresh Failure'),
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

class User {
  final String name;
  final String email;

  User({required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) =>
      User(name: json['name'], email: json['email']);
}
