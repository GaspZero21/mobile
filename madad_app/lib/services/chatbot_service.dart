import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart'; // your existing api config

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatbotService {
  static Future<String> askQuestion(String message) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/chatbot/ask'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}), // ✅ API expects "message"
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // ✅ API returns { "success": true, "data": { "reply": "..." } }
        return data['data']['reply'] ?? 'No reply received.';
      } else if (response.statusCode == 422) {
        // Validation failed: message missing or too long
        return 'Your message is invalid or too long. Please try again.';
      } else if (response.statusCode == 503) {
        // Chatbot not configured on server side
        return 'The assistant is currently unavailable. Please try again later.';
      } else {
        return data['message'] ?? 'Something went wrong. Please try again.';
      }
    } catch (e) {
      return 'Unable to connect. Please check your internet connection.';
    }
  }
}