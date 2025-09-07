import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  final Dio dio = Dio();
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  ApiClient() {
    // Configure SSL handling for Android in development
    _configureSSL();
    
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // read token from secure storage
          final accessToken = await storage.read(key: 'access_token');
          debugPrint("Access Token: $accessToken");
          if (accessToken != null) {
            options.headers["Authorization"] = "Bearer $accessToken";
            options.headers["ngrok-skip-browser-warning"] = "69420";
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle SSL errors specifically
          final errorMsg = error.toString().toLowerCase();
          if (errorMsg.contains('handshake') || 
              errorMsg.contains('certificate') ||
              error.type == DioExceptionType.unknown) {
            // This might be an SSL certificate issue
            debugPrint("SSL Certificate error detected: ${error.message}");
          }
          
          // Handle token expiration or other auth errors
          if (error.response?.statusCode == 401) {
            // Token might be expired, try to refresh it
            if (await _refreshToken()) {
              // Retry the request with new token
              final request = error.requestOptions;
              final accessToken = await storage.read(key: 'access_token');
              request.headers["Authorization"] = "Bearer $accessToken";
              return handler.resolve(await dio.fetch(request));
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  // Configure SSL handling for development
  void _configureSSL() {
    if (!kReleaseMode) {
      // Use a try-catch approach to handle any platform-specific issues
      try {
        // For Dio version compatibility
        dio.options.validateStatus = (status) => true;
        
        // Bypass SSL certificate verification in development
        // This is a more compatible approach
        (dio.httpClientAdapter as dynamic).onHttpClientCreate = (client) {
          client.badCertificateCallback = (cert, host, port) => true;
          return client;
        };
      } catch (e) {
        debugPrint('Error configuring SSL: $e');
      }
    }
  }

  // Token refresh logic
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;
      
      final response = await dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      
      if (response.statusCode == 200) {
        await storage.write(
          key: 'access_token', 
          value: response.data['access_token']
        );
        return true;
      }
    } catch (e) {
      debugPrint('Token refresh failed: $e');
    }
    return false;
  }
}