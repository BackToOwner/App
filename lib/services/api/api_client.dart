import 'dart:async';
import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import 'api_exception.dart';
import 'token_store.dart';

/// The single HTTP entry point to the backend.
///
/// Owns three things every call needs: the base URL, the bearer token, and silent re-auth when a
/// 15-minute access token expires mid-session.
class ApiClient {
  final Dio _dio;
  final TokenStore tokens;

  /// Called when the session is gone for good (refresh rejected, account suspended), so the app
  /// can drop the user back at the auth screen instead of showing errors on every screen.
  void Function()? onSessionExpired;

  ApiClient({TokenStore? tokenStore, Dio? dio})
      : tokens = tokenStore ?? TokenStore(),
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: ApiConfig.connectTimeout,
              receiveTimeout: ApiConfig.receiveTimeout,
              // Never throw on a status code — errors are unwrapped from the response body below,
              // which keeps the backend's own message rather than "Http status error [400]".
              validateStatus: (_) => true,
            )) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] != true) {
            final token = await tokens.accessToken;
            if (token != null) options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  /// Guards the refresh call. Without it, several requests failing at once would each refresh, and
  /// the backend revokes the whole session family when a rotated refresh token is presented twice
  /// — so a burst of parallel requests would sign the user out.
  Future<bool>? _refreshInFlight;

  Future<bool> _refreshToken() {
    return _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await tokens.refreshToken;
    if (refreshToken == null) return false;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );
      final body = response.data;
      if (response.statusCode == 200 && body?['success'] == true) {
        final data = body!['data'] as Map<String, dynamic>;
        await tokens.save(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
        );
        return true;
      }
    } catch (_) {
      // Fall through: a failed refresh is a signed-out session, not a crash.
    }

    await tokens.clear();
    onSessionExpired?.call();
    return false;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    bool skipAuth = false,
    bool isRetry = false,
  }) async {
    late Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method, extra: {'skipAuth': skipAuth}),
      );
    } on DioException catch (e) {
      throw ApiException(_networkMessage(e));
    }

    final body = response.data;
    final status = response.statusCode ?? 0;

    if (status >= 200 && status < 300 && body is Map<String, dynamic>) {
      return body;
    }

    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    final details = map['details'];
    final code = details is Map<String, dynamic> ? details['code'] as String? : null;

    // An expired access token is recoverable: refresh once, then replay the original request.
    if (status == 401 && code == 'TOKEN_EXPIRED' && !isRetry && !skipAuth) {
      if (await _refreshToken()) {
        return _send(method, path, data: data, query: query, isRetry: true);
      }
    }

    if (status == 401 && !skipAuth) {
      await tokens.clear();
      onSessionExpired?.call();
    }

    throw ApiException(
      (map['message'] as String?) ?? 'Something went wrong. Please try again.',
      statusCode: status,
      code: code,
      fieldErrors: details is List
          ? details
              .whereType<Map<String, dynamic>>()
              .map((d) => FieldError(d['path']?.toString() ?? '', d['message']?.toString() ?? ''))
              .toList()
          : const [],
    );
  }

  String _networkMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The server took too long to respond. Check your connection and try again.';
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return 'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
            'Make sure the backend is running and that this address is reachable from this device.';
      default:
        return 'Network error. Please try again.';
    }
  }

  /// The `data` field of a `{ success, data }` envelope.
  Future<T> get<T>(String path, {Map<String, dynamic>? query, bool skipAuth = false}) async =>
      (await _send('GET', path, query: query, skipAuth: skipAuth))['data'] as T;

  Future<T> post<T>(String path, {Object? data, bool skipAuth = false}) async =>
      (await _send('POST', path, data: data, skipAuth: skipAuth))['data'] as T;

  Future<T> patch<T>(String path, {Object? data}) async =>
      (await _send('PATCH', path, data: data))['data'] as T;

  Future<T> put<T>(String path, {Object? data}) async =>
      (await _send('PUT', path, data: data))['data'] as T;

  Future<T> delete<T>(String path, {Object? data}) async =>
      (await _send('DELETE', path, data: data))['data'] as T;

  /// For list endpoints, which also carry `pagination` alongside `data`.
  Future<List<Map<String, dynamic>>> getList(String path, {Map<String, dynamic>? query}) async {
    final body = await _send('GET', path, query: query);
    return (body['data'] as List).whereType<Map<String, dynamic>>().toList();
  }

  /// Multipart upload. [field] is `image` for an avatar, `images` for report photos.
  Future<Map<String, dynamic>> uploadFile(
    String path,
    String filePath, {
    String field = 'images',
  }) async {
    final form = FormData.fromMap({
      field: await MultipartFile.fromFile(filePath),
    });
    final body = await _send('POST', path, data: form);
    return body['data'] as Map<String, dynamic>;
  }
}
