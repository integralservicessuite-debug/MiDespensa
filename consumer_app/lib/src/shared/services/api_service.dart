import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  late Dio _dio;
  
  // Singleton pattern
  factory ApiService() {
    return _instance;
  }
  
  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _getBaseUrl(),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }
    ));
    
    _setupInterceptors();
  }
  
  static String _getBaseUrl() {
    const apiPath = '/api/v1';
    if (kIsWeb) return 'http://localhost:3000$apiPath';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000$apiPath';
    return 'http://localhost:3000$apiPath';
  }
  
  static String get baseUrl => _getBaseUrl();

  void _setupInterceptors() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        print('🌐 [DIO] Req: ${options.method} ${options.uri}');
        if (options.data != null) print('   Body: ${options.data}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('📥 [DIO] Res: ${response.statusCode}');
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        print('❌ [DIO] Err: ${e.response?.statusCode} - ${e.message}');
        if (e.response?.data != null) {
           print('   Data: ${e.response?.data}');
        }
        return handler.next(e);
      }
    ));
  }

  // Get Dio instance directly if needed for specialized calls
  Dio get dio => _dio;

  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(endpoint, data: data);
      return response.data;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(endpoint, queryParameters: queryParameters);
      return response.data;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  void _handleDioError(DioException e) {
    if (e.response != null && e.response!.data != null) {
      // Backend error (NestJS filter format)
      final errorData = e.response!.data;
      final message = errorData['message'] ?? 'Error desconocido';
      throw Exception('Error ${e.response!.statusCode}: $message');
    } else {
      // Network error
      throw Exception('Network Error: ${e.message}');
    }
  }
}
