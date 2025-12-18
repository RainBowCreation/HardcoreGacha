import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class Api {
  static String? token;

  static Future<Map<String, dynamic>> request(String endpoint, {bool isV1 = true, String method = "GET", Map<String, dynamic>? body, Map<String, dynamic>? query}) async {
    
    final String baseUrl = isV1 ? API_BASE : API_ROOT;
    
    final uri = Uri.parse("$baseUrl$endpoint").replace(queryParameters: query);
    final headers = {
      "Content-Type": "application/json",
      if (token != null) "X-Auth": token!,
    };

    http.Response response;
    try {
      final request = http.Request(method, uri);
      
      request.headers.addAll(headers);

      if (body != null) {
        request.body = jsonEncode(body);
      }

      final streamedResponse = await request.send();
      
      response = await http.Response.fromStream(streamedResponse);

      if (response.headers['content-type']?.contains('application/json') ?? false) {
        final data = jsonDecode(response.body);
        return {'status': response.statusCode, ...data};
      }
      return {'status': response.statusCode};
    } catch (e) {
      return {'status': 500, 'error': e.toString()};
    }
  }
}