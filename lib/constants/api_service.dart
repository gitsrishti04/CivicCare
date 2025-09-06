import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class ApiClient {
  final Dio dio = Dio();
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  ApiClient() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // read token from secure storage
          final accessToken = await storage.read(key: 'access_token');
          debugPrint("Access Token: $accessToken");
          if (accessToken != null) {
            options.headers["Authorization"] = "Bearer $accessToken";
          }
          return handler.next(options);
        },
      ),
    );
  }
}
