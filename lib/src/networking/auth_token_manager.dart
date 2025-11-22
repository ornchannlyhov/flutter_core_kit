import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages authentication tokens with secure storage
class AuthTokenManager {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';

  final FlutterSecureStorage? _secureStorage;
  final Map<String, String> _memoryStorage = {};
  final bool _useSecureStorage;

  AuthTokenManager({bool useSecureStorage = true})
    : _useSecureStorage = useSecureStorage,
      _secureStorage = useSecureStorage ? const FlutterSecureStorage() : null;

  /// Save access token
  Future<void> saveAccessToken(String token) async {
    await _write(_accessTokenKey, token);
  }

  /// Save refresh token
  Future<void> saveRefreshToken(String token) async {
    await _write(_refreshTokenKey, token);
  }

  /// Save both tokens at once
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) async {
    await saveAccessToken(accessToken);
    if (refreshToken != null) {
      await saveRefreshToken(refreshToken);
    }
    if (expiresAt != null) {
      await saveTokenExpiry(expiresAt);
    }
  }

  /// Save token expiry time
  Future<void> saveTokenExpiry(DateTime expiresAt) async {
    await _write(_tokenExpiryKey, expiresAt.toIso8601String());
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    return await _read(_accessTokenKey);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return await _read(_refreshTokenKey);
  }

  /// Get token expiry time
  Future<DateTime?> getTokenExpiry() async {
    final expiryStr = await _read(_tokenExpiryKey);
    if (expiryStr == null) return null;
    try {
      return DateTime.parse(expiryStr);
    } catch (e) {
      return null;
    }
  }

  /// Check if access token is expired
  Future<bool> isAccessTokenExpired() async {
    final expiry = await getTokenExpiry();
    if (expiry == null) return true;
    return DateTime.now().isAfter(expiry);
  }

  /// Check if access token exists and is valid
  Future<bool> hasValidAccessToken() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) return false;
    return !(await isAccessTokenExpired());
  }

  /// Clear all tokens
  Future<void> clearTokens() async {
    await _delete(_accessTokenKey);
    await _delete(_refreshTokenKey);
    await _delete(_tokenExpiryKey);
  }

  /// Internal write method
  Future<void> _write(String key, String value) async {
    if (_useSecureStorage && _secureStorage != null) {
      try {
        await _secureStorage.write(key: key, value: value);
      } catch (e) {
        // Fallback to memory storage if secure storage fails
        _memoryStorage[key] = value;
      }
    } else {
      _memoryStorage[key] = value;
    }
  }

  /// Internal read method
  Future<String?> _read(String key) async {
    if (_useSecureStorage && _secureStorage != null) {
      try {
        return await _secureStorage.read(key: key);
      } catch (e) {
        // Fallback to memory storage if secure storage fails
        return _memoryStorage[key];
      }
    } else {
      return _memoryStorage[key];
    }
  }

  /// Internal delete method
  Future<void> _delete(String key) async {
    if (_useSecureStorage && _secureStorage != null) {
      try {
        await _secureStorage.delete(key: key);
      } catch (e) {
        // Fallback to memory storage if secure storage fails
        _memoryStorage.remove(key);
      }
    } else {
      _memoryStorage.remove(key);
    }
  }
}
