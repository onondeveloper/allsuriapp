import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/order.dart';
import '../models/user.dart';

class ApiService {
  static const String baseUrl = 'https://api.allsuri.com'; // TODO: 실제 API URL로 변경
  final Dio _dio = Dio();

  // 예시: 로그인, 주문, 사용자 등 API 메서드 구현
  // ...
} 