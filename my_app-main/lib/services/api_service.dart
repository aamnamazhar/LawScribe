import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  // Backend URL. Override at run time with:
  //   flutter run --dart-define=BACKEND_URL=https://your-production-url.com
  // IMPORTANT: Use HTTPS in production for SRS compliance (S2).
  // The HTTP default below is for local development only.
  static const String baseUrl = String.fromEnvironment(
    "BACKEND_URL",
    defaultValue: "http://192.168.1.4:8000",
  );

  static const _timeout = Duration(seconds: 60);
  static const _aiTimeout = Duration(seconds: 120);
  static const _uploadTimeout = Duration(seconds: 180);

  // ── Auth header ───────────────────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {"Content-Type": "application/json"};
    final token = await user.getIdToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // ── Upload ────────────────────────────────────────────────────────────────

  static Future<http.StreamedResponse> uploadDocument(String filePath) async {
    final uri = Uri.parse("$baseUrl/documents/upload");
    final request = http.MultipartRequest("POST", uri);
    request.files.add(await http.MultipartFile.fromPath("file", filePath));

    // Attach Firebase auth token so backend can write to user's Firestore paths
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      request.headers['Authorization'] = 'Bearer $token';
    }

    return await request.send().timeout(_uploadTimeout);
  }

  // ── Summary ───────────────────────────────────────────────────────────────

  static Future<String> getSummary(String docId) async {
    final uri = Uri.parse(
      "$baseUrl/ai/summary?doc_id=${Uri.encodeComponent(docId)}",
    );
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers).timeout(_timeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)["summary"];
    }
    throw Exception("Summary failed: ${response.body}");
  }

  // ── Q&A ───────────────────────────────────────────────────────────────────

  static Future<String> queryDocument(String docId, String question) async {
    final uri = Uri.parse("$baseUrl/ai/query");
    final headers = await _authHeaders();
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({"doc_id": docId, "question": question}),
    ).timeout(_timeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)["answer"];
    }
    throw Exception("Query failed: ${response.body}");
  }

  // ── Clause Detection ──────────────────────────────────────────────────────

  static Future<List<dynamic>> getClauses(String docId) async {
    final uri = Uri.parse("$baseUrl/ai/clauses");
    final headers = await _authHeaders();
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({"doc_id": docId}),
    ).timeout(_aiTimeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)["clauses"];
    }
    throw Exception("Clause detection failed: ${response.body}");
  }

  // ── Insights ──────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getInsights(String docId) async {
    final uri = Uri.parse("$baseUrl/ai/insights");
    final headers = await _authHeaders();
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({"doc_id": docId}),
    ).timeout(_aiTimeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)["insights"];
    }
    throw Exception("Insights failed: ${response.body}");
  }

  // ── Provision Classification (LEDGAR) ─────────────────────────────────────

  static Future<List<dynamic>> classifyProvision(String text) async {
    final uri = Uri.parse("$baseUrl/ai/classify-provision");
    final headers = await _authHeaders();
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({"text": text}),
    ).timeout(_aiTimeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)["categories"];
    }
    throw Exception("Provision classification failed: ${response.body}");
  }

  // ── Streaming Summary (SSE) ───────────────────────────────────────────────

  static Stream<String> getSummaryStream(String docId) async* {
    final uri = Uri.parse(
      "$baseUrl/ai/summary/stream?doc_id=${Uri.encodeComponent(docId)}",
    );
    final headers = await _authHeaders();
    final request = http.Request("GET", uri)..headers.addAll(headers);
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception("Summary stream failed: ${response.statusCode}");
    }

    yield* _parseSseStream(response.stream);
  }

  // ── Streaming Q&A (SSE) ──────────────────────────────────────────────────

  static Stream<String> queryDocumentStream(
    String docId,
    String question,
  ) async* {
    final uri = Uri.parse("$baseUrl/ai/query/stream");
    final headers = await _authHeaders();
    final request = http.Request("POST", uri)
      ..headers.addAll(headers)
      ..body = jsonEncode({"doc_id": docId, "question": question});
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception("Query stream failed: ${response.statusCode}");
    }

    yield* _parseSseStream(response.stream);
  }

  // ── Streaming General Q&A — no document (SSE) ────────────────────────────

  static Stream<String> generalQueryStream(String question) async* {
    final uri = Uri.parse("$baseUrl/ai/general/stream");
    final headers = await _authHeaders();
    final request = http.Request("POST", uri)
      ..headers.addAll(headers)
      ..body = jsonEncode({"question": question});
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception("General query stream failed: ${response.statusCode}");
    }

    yield* _parseSseStream(response.stream);
  }

  /// Parse an SSE byte stream into individual text tokens.
  static Stream<String> _parseSseStream(
    Stream<List<int>> byteStream,
  ) async* {
    String buffer = '';
    await for (final bytes in byteStream) {
      buffer += utf8.decode(bytes);
      // SSE events are separated by double newlines
      while (buffer.contains('\n\n')) {
        final idx = buffer.indexOf('\n\n');
        final event = buffer.substring(0, idx).trim();
        buffer = buffer.substring(idx + 2);

        if (event.startsWith('data: ')) {
          final payload = event.substring(6);
          if (payload == '[DONE]') return;
          try {
            final data = jsonDecode(payload);
            if (data['token'] != null) {
              yield data['token'] as String;
            }
          } catch (_) {
            // skip malformed events
          }
        }
      }
    }
  }

  // ── Blockchain Verify ─────────────────────────────────────────────────────

  static Future<bool> verifyDocument(String docId, String fileHash) async {
    final uri = Uri.parse(
      "$baseUrl/ai/verify?doc_id=${Uri.encodeComponent(docId)}&file_hash=${Uri.encodeComponent(fileHash)}",
    );
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers).timeout(_timeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)["verified"] as bool;
    }
    throw Exception("Verify failed: ${response.body}");
  }
}
