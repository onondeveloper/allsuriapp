import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/admin_message.dart';
import '../models/admin_statistics.dart';
import '../models/user.dart';
import '../models/estimate.dart';

class AdminService {
  static const String baseUrl = 'http://localhost:3000/api/admin';

  // 메시징 기능
  static Future<List<AdminMessage>> getMessages() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/messages'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => AdminMessage.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }

  static Future<bool> sendMessage(AdminMessage message) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/messages'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(message.toJson()),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  static Future<bool> deleteMessage(String messageId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/messages/$messageId'));
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  // 통계 기능
  static Future<AdminStatistics?> getStatistics() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/statistics'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AdminStatistics.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error fetching statistics: $e');
      return null;
    }
  }

  static Future<List<BusinessBilling>> getBusinessBillings() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/business-billings'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => BusinessBilling.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching business billings: $e');
      return [];
    }
  }

  // 사용자 관리
  static Future<List<User>> getAllUsers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/users'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => User.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  static Future<bool> updateUserStatus(String userId, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/users/$userId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': status}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating user status: $e');
      return false;
    }
  }

  static Future<bool> deleteUser(String userId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/users/$userId'));
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  // 견적 관리
  static Future<List<Estimate>> getAllEstimates() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/estimates'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Estimate.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching estimates: $e');
      return [];
    }
  }

  static Future<bool> updateEstimateStatus(String estimateId, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/estimates/$estimateId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': status}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating estimate status: $e');
      return false;
    }
  }

  // 검색 기능
  static Future<List<User>> searchUsers(String query, String userType, String status) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/search').replace(queryParameters: {
          'q': query,
          'type': userType,
          'status': status,
        }),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => User.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  static Future<List<Estimate>> searchEstimates(String query, String status) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/estimates/search').replace(queryParameters: {
          'q': query,
          'status': status,
        }),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Estimate.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error searching estimates: $e');
      return [];
    }
  }

  // 대시보드 데이터
  static Future<Map<String, dynamic>> getDashboardData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/dashboard'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      print('Error fetching dashboard data: $e');
      return {};
    }
  }

  // 시스템 설정
  static Future<Map<String, dynamic>> getSystemSettings() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/settings'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      print('Error fetching system settings: $e');
      return {};
    }
  }

  static Future<bool> updateSystemSettings(Map<String, dynamic> settings) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/settings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(settings),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating system settings: $e');
      return false;
    }
  }
} 