// lib/services/sse_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_service.dart' show baseUrl;

class SseService {
  static Stream<Map<String, dynamic>> processRequest(String input,
      {String name = 'Guest', String? phone}) async* {

    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/api/process-stream'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.body = jsonEncode({
        'user_input': input,
        'user_name': name,
        'user_phone': phone,
      });

      final response = await client.send(request);
      if (response.statusCode != 200) {
        final err =
            await response.stream.transform(utf8.decoder).join();
        throw Exception('Stream error ${response.statusCode}: $err');
      }
      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (line.startsWith('data: ')) {
          final jsonStr = line.substring(6).trim();
          if (jsonStr.isEmpty) continue;
          try {
            final event = jsonDecode(jsonStr) as Map<String, dynamic>;
            yield event;
            if (event['type'] == 'complete' || event['type'] == 'error') {
              break;
            }
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
  }
}