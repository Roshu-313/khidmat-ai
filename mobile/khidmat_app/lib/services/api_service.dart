// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

// Change to your Railway URL after deploy
const String baseUrl = 'http://127.0.0.1:8000';
// For local test: 'http://10.0.2.2:8000'

class ApiService {
  static Future<Map<String, dynamic>> processRequest(String input,
      {String name = 'Guest', String? phone}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/process-request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_input': input, 'user_name': name, 'user_phone': phone}),
    ).timeout(const Duration(seconds: 30));
    if (res.statusCode == 200) return jsonDecode(utf8.decode(res.bodyBytes));
    throw Exception('Error ${res.statusCode}: ${res.body}');
  }

  static Future<Map<String, dynamic>> raiseDispute(
      String bookingId, String type, String desc) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/dispute?booking_id=$bookingId&dispute_type=$type&description=${Uri.encodeComponent(desc)}'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Dispute failed');
  }

  static Future<Map<String, dynamic>> submitFeedback(
      String bookingId, int rating, String comment) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/submit-feedback?booking_id=$bookingId&rating=$rating&comment=${Uri.encodeComponent(comment)}'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Feedback failed');
  }

  static Future<Map<String, dynamic>> stressTest(String scenario) async {
    final res = await http.get(Uri.parse('$baseUrl/api/stress-test/$scenario'));
    if (res.statusCode == 200) return jsonDecode(utf8.decode(res.bodyBytes));
    throw Exception('Stress test failed');
  }
}